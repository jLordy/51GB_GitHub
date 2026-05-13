"""
File Service — Patient Document Storage.

Firestore collections:
  file_folders/{id}           — patient-owned folders
  file_documents/{id}         — documents inside folders
  file_storage_summary/{uid}  — per-patient storage counter (atomic updates)

Azure Blob path: documents/{patient_uid}/{folder_id}/{uuid}.{ext}

Storage cap: 500 MB (524_288_000 bytes) per patient.
Default folders (Prescription, Medical Records, Laboratories) are created
lazily on the first call to list_folders; they cannot be renamed or deleted.
"""

import logging
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from azure.storage.blob import BlobServiceClient, ContentSettings
from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1 import Transaction
from dotenv import load_dotenv

from src.schemas.file_schemas import (
    FileFolderResponse,
    FileFoldersListResponse,
    FileDocumentResponse,
    FileDocumentsListResponse,
    StorageSummaryResponse,
)

load_dotenv()

logger = logging.getLogger(__name__)

_FOLDERS_COLLECTION = "file_folders"
_DOCUMENTS_COLLECTION = "file_documents"
_SUMMARY_COLLECTION = "file_storage_summary"
_CONNECTIONS_COLLECTION = "connections"

_MAX_BYTES = 524_288_000  # 500 MB

_ALLOWED_MIME_TYPES = {
    "application/pdf": ("pdf", "pdf"),
    "image/jpeg": ("image", "jpg"),
    "image/png": ("image", "png"),
    "image/webp": ("image", "webp"),
    "application/msword": ("document", "doc"),
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ("document", "docx"),
}

_DEFAULT_FOLDERS = [
    {"name": "Prescription", "is_default": True},
    {"name": "Medical Records", "is_default": True},
    {"name": "Laboratories", "is_default": True},
]


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _is_directly_connected(uid_a: str, uid_b: str, db) -> bool:
    """Return True if uid_a and uid_b share an accepted connection."""
    for req, rec in ((uid_a, uid_b), (uid_b, uid_a)):
        docs = list(
            db.collection(_CONNECTIONS_COLLECTION)
            .where(filter=FieldFilter("requester_uid", "==", req))
            .where(filter=FieldFilter("recipient_uid", "==", rec))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .limit(1)
            .stream()
        )
        if docs:
            return True
    return False


def _secretary_connected_to_patient(secretary_uid: str, patient_uid: str, db) -> bool:
    """Return True if the secretary is connected to any doctor who is connected to patient_uid."""
    seen: set[str] = set()
    doctor_uids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        for doc in (
            db.collection(_CONNECTIONS_COLLECTION)
            .where(filter=FieldFilter(field, "==", secretary_uid))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .stream()
        ):
            if doc.id in seen:
                continue
            seen.add(doc.id)
            data = doc.to_dict() or {}
            req = data.get("requester_uid")
            rec = data.get("recipient_uid")
            other = rec if req == secretary_uid else req
            if other and other != secretary_uid:
                user_snap = db.collection("users").document(other).get()
                if user_snap.exists:
                    role = str((user_snap.to_dict() or {}).get("role") or "").strip().lower()
                    if role == "doctor":
                        doctor_uids.add(other)

    for doctor_uid in doctor_uids:
        if _is_directly_connected(doctor_uid, patient_uid, db):
            return True
    return False


def _assert_connected(viewer_uid: str, patient_uid: str, db, viewer_role: str = "") -> None:
    """Verify viewer_uid may access patient_uid's documents.

    Doctors and caregivers need a direct accepted connection.
    Secretaries are authorised when connected to any doctor who is
    directly connected to the patient.
    """
    if viewer_role == "secretary":
        if not _secretary_connected_to_patient(viewer_uid, patient_uid, db):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not connected to this patient through a doctor.",
            )
        return

    if not _is_directly_connected(viewer_uid, patient_uid, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not connected to this patient.",
        )


def _ensure_default_folders(patient_uid: str, db) -> None:
    """Idempotently create the 3 default folders if they do not exist yet."""
    for folder_meta in _DEFAULT_FOLDERS:
        existing = list(
            db.collection(_FOLDERS_COLLECTION)
            .where(filter=FieldFilter("patient_uid", "==", patient_uid))
            .where(filter=FieldFilter("name", "==", folder_meta["name"]))
            .where(filter=FieldFilter("is_default", "==", True))
            .limit(1)
            .stream()
        )
        if not existing:
            now = datetime.now(tz=timezone.utc)
            db.collection(_FOLDERS_COLLECTION).add({
                "patient_uid": patient_uid,
                "name": folder_meta["name"],
                "is_default": True,
                "item_count": 0,
                "created_at": now,
            })


def _get_storage_summary_data(patient_uid: str, db) -> dict:
    doc = db.collection(_SUMMARY_COLLECTION).document(patient_uid).get()
    if doc.exists:
        return doc.to_dict()
    return {"patient_uid": patient_uid, "total_bytes": 0, "file_count": 0}


def _check_storage_limit(patient_uid: str, file_size_bytes: int, db) -> None:
    """Raise HTTP 413 if adding file_size_bytes would exceed 500 MB."""
    summary = _get_storage_summary_data(patient_uid, db)
    total = summary.get("total_bytes", 0)
    if total + file_size_bytes > _MAX_BYTES:
        remaining = max(0, _MAX_BYTES - total)
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"Storage limit exceeded. "
                f"Remaining capacity: {remaining / (1024 * 1024):.1f} MB. "
                f"File size: {file_size_bytes / (1024 * 1024):.1f} MB."
            ),
        )


def _update_storage_summary(
    patient_uid: str, delta_bytes: int, delta_count: int, db
) -> None:
    """Atomically update the per-patient storage counter."""
    ref = db.collection(_SUMMARY_COLLECTION).document(patient_uid)

    @firestore.transactional
    def _txn(transaction: Transaction) -> None:
        snapshot = ref.get(transaction=transaction)
        if snapshot.exists:
            data = snapshot.to_dict()
            new_bytes = max(0, data.get("total_bytes", 0) + delta_bytes)
            new_count = max(0, data.get("file_count", 0) + delta_count)
        else:
            new_bytes = max(0, delta_bytes)
            new_count = max(0, delta_count)

        transaction.set(ref, {
            "patient_uid": patient_uid,
            "total_bytes": new_bytes,
            "file_count": new_count,
            "updated_at": datetime.now(tz=timezone.utc),
        })

    _txn(db.transaction())


def _folder_to_response(doc) -> FileFolderResponse:
    d = doc.to_dict()
    return FileFolderResponse(
        id=doc.id,
        patient_uid=d["patient_uid"],
        name=d["name"],
        is_default=d.get("is_default", False),
        item_count=d.get("item_count", 0),
        created_at=d["created_at"],
    )


def _document_to_response(doc) -> FileDocumentResponse:
    d = doc.to_dict()
    return FileDocumentResponse(
        id=doc.id,
        patient_uid=d["patient_uid"],
        folder_id=d["folder_id"],
        name=d["name"],
        file_url=d["file_url"],
        file_type=d["file_type"],
        mime_type=d["mime_type"],
        size_bytes=d["size_bytes"],
        uploaded_by_uid=d["uploaded_by_uid"],
        created_at=d["created_at"],
        updated_at=d["updated_at"],
    )


def _upload_blob(
    file_bytes: bytes,
    patient_uid: str,
    folder_id: str,
    mime_type: str,
    ext: str,
) -> str:
    """Upload raw bytes to Azure Blob Storage, return the public URL."""
    conn_str = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
    container = os.environ["AZURE_STORAGE_CONTAINER_NAME"]
    blob_name = f"documents/{patient_uid}/{folder_id}/{uuid.uuid4()}.{ext}"
    client = BlobServiceClient.from_connection_string(conn_str)
    blob = client.get_blob_client(container=container, blob=blob_name)
    blob.upload_blob(
        file_bytes,
        content_settings=ContentSettings(content_type=mime_type),
    )
    return blob.url


def _delete_blob_by_url(file_url: str) -> None:
    """Delete a blob given its full URL. Logs but does not raise on failure."""
    try:
        conn_str = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
        container = os.environ["AZURE_STORAGE_CONTAINER_NAME"]
        client = BlobServiceClient.from_connection_string(conn_str)
        # Extract blob name from URL: everything after the container segment
        # URL format: https://<account>.blob.core.windows.net/<container>/<blob_name>
        marker = f"/{container}/"
        idx = file_url.find(marker)
        if idx == -1:
            logger.warning("Could not parse blob name from URL: %s", file_url)
            return
        blob_name = file_url[idx + len(marker):]
        blob = client.get_blob_client(container=container, blob=blob_name)
        blob.delete_blob()
    except Exception as exc:
        logger.warning("Failed to delete blob %s: %s", file_url, exc)


# ---------------------------------------------------------------------------
# Folder operations
# ---------------------------------------------------------------------------

def list_folders(patient_uid: str, db) -> FileFoldersListResponse:
    _ensure_default_folders(patient_uid, db)
    docs = (
        db.collection(_FOLDERS_COLLECTION)
        .where(filter=FieldFilter("patient_uid", "==", patient_uid))
        .order_by("created_at")
        .stream()
    )
    folders = [_folder_to_response(doc) for doc in docs]
    # Default folders sorted first
    folders.sort(key=lambda f: (0 if f.is_default else 1, f.created_at))
    return FileFoldersListResponse(folders=folders)


def create_folder(patient_uid: str, name: str, db) -> FileFolderResponse:
    name = name.strip()
    if not name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Folder name must not be empty.",
        )
    # Prevent duplicates
    existing = list(
        db.collection(_FOLDERS_COLLECTION)
        .where(filter=FieldFilter("patient_uid", "==", patient_uid))
        .where(filter=FieldFilter("name", "==", name))
        .limit(1)
        .stream()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"A folder named '{name}' already exists.",
        )
    now = datetime.now(tz=timezone.utc)
    _, ref = db.collection(_FOLDERS_COLLECTION).add({
        "patient_uid": patient_uid,
        "name": name,
        "is_default": False,
        "item_count": 0,
        "created_at": now,
    })
    doc = ref.get()
    return _folder_to_response(doc)


def update_folder(patient_uid: str, folder_id: str, name: str, db) -> FileFolderResponse:
    ref = db.collection(_FOLDERS_COLLECTION).document(folder_id)
    doc = ref.get()
    if not doc.exists or doc.to_dict().get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found.")
    if doc.to_dict().get("is_default"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Default folders cannot be renamed.",
        )
    name = name.strip()
    if not name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Folder name must not be empty.",
        )
    ref.update({"name": name})
    return _folder_to_response(ref.get())


def delete_folder(patient_uid: str, folder_id: str, db) -> None:
    ref = db.collection(_FOLDERS_COLLECTION).document(folder_id)
    doc = ref.get()
    if not doc.exists or doc.to_dict().get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found.")
    if doc.to_dict().get("is_default"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Default folders cannot be deleted.",
        )
    # Delete all documents inside the folder
    child_docs = list(
        db.collection(_DOCUMENTS_COLLECTION)
        .where(filter=FieldFilter("patient_uid", "==", patient_uid))
        .where(filter=FieldFilter("folder_id", "==", folder_id))
        .stream()
    )
    for child in child_docs:
        d = child.to_dict()
        _delete_blob_by_url(d["file_url"])
        _update_storage_summary(patient_uid, -d["size_bytes"], -1, db)
        db.collection(_DOCUMENTS_COLLECTION).document(child.id).delete()

    ref.delete()


# ---------------------------------------------------------------------------
# Document operations
# ---------------------------------------------------------------------------

def list_documents(patient_uid: str, folder_id: str, db) -> FileDocumentsListResponse:
    # Verify folder belongs to patient
    folder = db.collection(_FOLDERS_COLLECTION).document(folder_id).get()
    if not folder.exists or folder.to_dict().get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found.")

    docs = (
        db.collection(_DOCUMENTS_COLLECTION)
        .where(filter=FieldFilter("patient_uid", "==", patient_uid))
        .where(filter=FieldFilter("folder_id", "==", folder_id))
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .stream()
    )
    return FileDocumentsListResponse(documents=[_document_to_response(d) for d in docs])


def create_document(
    patient_uid: str,
    folder_id: str,
    name: str,
    file_bytes: bytes,
    mime_type: str,
    uploaded_by_uid: str,
    db,
) -> FileDocumentResponse:
    # Validate folder
    folder_ref = db.collection(_FOLDERS_COLLECTION).document(folder_id)
    folder_doc = folder_ref.get()
    if not folder_doc.exists or folder_doc.to_dict().get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found.")

    # Validate MIME type
    if mime_type not in _ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file type: {mime_type}. Allowed: PDF, images (JPG, PNG, WEBP), Word documents.",
        )
    file_type, ext = _ALLOWED_MIME_TYPES[mime_type]
    file_size = len(file_bytes)

    # Enforce 500 MB cap
    _check_storage_limit(patient_uid, file_size, db)

    name = name.strip() or Path(f"file.{ext}").stem

    # Upload to Azure Blob
    file_url = _upload_blob(file_bytes, patient_uid, folder_id, mime_type, ext)

    now = datetime.now(tz=timezone.utc)
    _, ref = db.collection(_DOCUMENTS_COLLECTION).add({
        "patient_uid": patient_uid,
        "folder_id": folder_id,
        "name": name,
        "file_url": file_url,
        "file_type": file_type,
        "mime_type": mime_type,
        "size_bytes": file_size,
        "uploaded_by_uid": uploaded_by_uid,
        "created_at": now,
        "updated_at": now,
    })

    # Increment folder item count and storage summary
    folder_ref.update({"item_count": firestore.Increment(1)})
    _update_storage_summary(patient_uid, file_size, 1, db)

    return _document_to_response(ref.get())


def update_document(
    patient_uid: str,
    folder_id: str,
    doc_id: str,
    name: str,
    db,
) -> FileDocumentResponse:
    ref = db.collection(_DOCUMENTS_COLLECTION).document(doc_id)
    doc = ref.get()
    if (
        not doc.exists
        or doc.to_dict().get("patient_uid") != patient_uid
        or doc.to_dict().get("folder_id") != folder_id
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found.")

    name = name.strip()
    if not name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Document name must not be empty.",
        )
    ref.update({"name": name, "updated_at": datetime.now(tz=timezone.utc)})
    return _document_to_response(ref.get())


def delete_document(
    patient_uid: str,
    folder_id: str,
    doc_id: str,
    db,
) -> None:
    ref = db.collection(_DOCUMENTS_COLLECTION).document(doc_id)
    doc = ref.get()
    if (
        not doc.exists
        or doc.to_dict().get("patient_uid") != patient_uid
        or doc.to_dict().get("folder_id") != folder_id
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found.")

    d = doc.to_dict()
    _delete_blob_by_url(d["file_url"])

    # Decrement folder item_count
    folder_ref = db.collection(_FOLDERS_COLLECTION).document(folder_id)
    folder_snap = folder_ref.get()
    if folder_snap.exists:
        folder_ref.update({"item_count": firestore.Increment(-1)})

    _update_storage_summary(patient_uid, -d["size_bytes"], -1, db)
    ref.delete()


# ---------------------------------------------------------------------------
# Storage summary
# ---------------------------------------------------------------------------

def get_storage_summary(patient_uid: str, db) -> StorageSummaryResponse:
    data = _get_storage_summary_data(patient_uid, db)
    total = data.get("total_bytes", 0)
    return StorageSummaryResponse(
        patient_uid=patient_uid,
        total_bytes=total,
        file_count=data.get("file_count", 0),
        usage_percentage=round((total / _MAX_BYTES) * 100, 2),
    )

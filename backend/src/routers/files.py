"""
Files Router — Patient Document Storage.

Self-access (patient's own documents):
  GET    /api/files/folders
  POST   /api/files/folders
  PATCH  /api/files/folders/{folder_id}
  DELETE /api/files/folders/{folder_id}
  GET    /api/files/folders/{folder_id}/documents
  POST   /api/files/folders/{folder_id}/documents
  PATCH  /api/files/folders/{folder_id}/documents/{doc_id}
  DELETE /api/files/folders/{folder_id}/documents/{doc_id}
  GET    /api/files/storage-summary

Connected-user access (doctor/caregiver/secretary → patient):
  GET    /api/files/patients/{patient_uid}/folders
  POST   /api/files/patients/{patient_uid}/folders                  [caregiver]
  PATCH  /api/files/patients/{patient_uid}/folders/{folder_id}      [caregiver]
  DELETE /api/files/patients/{patient_uid}/folders/{folder_id}      [caregiver]
  GET    /api/files/patients/{patient_uid}/folders/{folder_id}/documents
  POST   /api/files/patients/{patient_uid}/folders/{folder_id}/documents   [caregiver]
  PATCH  /api/files/patients/{patient_uid}/folders/{folder_id}/documents/{doc_id}  [caregiver]
  DELETE /api/files/patients/{patient_uid}/folders/{folder_id}/documents/{doc_id}  [caregiver]
  GET    /api/files/patients/{patient_uid}/storage-summary
"""

from fastapi import APIRouter, Depends, File, Form, UploadFile, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, get_current_user, require_roles
from src.schemas.file_schemas import (
    FileFolderCreate,
    FileFolderResponse,
    FileFolderUpdate,
    FileFoldersListResponse,
    FileDocumentResponse,
    FileDocumentUpdate,
    FileDocumentsListResponse,
    StorageSummaryResponse,
)
from src.services.file_service import (
    _assert_connected,
    create_document,
    create_folder,
    delete_document,
    delete_folder,
    get_storage_summary,
    list_documents,
    list_folders,
    update_document,
    update_folder,
)

router = APIRouter(prefix="/files", tags=["files"])


# ===========================================================================
# Self-access — patient's own documents
# ===========================================================================

@router.get("/folders", response_model=FileFoldersListResponse)
def get_own_folders(
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> FileFoldersListResponse:
    return list_folders(current_user.uid, db)


@router.post("/folders", response_model=FileFolderResponse, status_code=status.HTTP_201_CREATED)
def create_own_folder(
    payload: FileFolderCreate,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> FileFolderResponse:
    return create_folder(current_user.uid, payload.name, db)


@router.patch("/folders/{folder_id}", response_model=FileFolderResponse)
def rename_own_folder(
    folder_id: str,
    payload: FileFolderUpdate,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> FileFolderResponse:
    return update_folder(current_user.uid, folder_id, payload.name, db)


@router.delete("/folders/{folder_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_own_folder(
    folder_id: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> None:
    delete_folder(current_user.uid, folder_id, db)


@router.get("/folders/{folder_id}/documents", response_model=FileDocumentsListResponse)
def get_own_documents(
    folder_id: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> FileDocumentsListResponse:
    return list_documents(current_user.uid, folder_id, db)


@router.post(
    "/folders/{folder_id}/documents",
    response_model=FileDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_own_document(
    folder_id: str,
    file: UploadFile = File(...),
    name: str = Form(""),
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> FileDocumentResponse:
    file_bytes = await file.read()
    display_name = name.strip() or (file.filename or "document")
    return create_document(
        patient_uid=current_user.uid,
        folder_id=folder_id,
        name=display_name,
        file_bytes=file_bytes,
        mime_type=file.content_type or "application/octet-stream",
        uploaded_by_uid=current_user.uid,
        db=db,
    )


@router.patch(
    "/folders/{folder_id}/documents/{doc_id}",
    response_model=FileDocumentResponse,
)
def rename_own_document(
    folder_id: str,
    doc_id: str,
    payload: FileDocumentUpdate,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> FileDocumentResponse:
    return update_document(current_user.uid, folder_id, doc_id, payload.name, db)


@router.delete(
    "/folders/{folder_id}/documents/{doc_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_own_document(
    folder_id: str,
    doc_id: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> None:
    delete_document(current_user.uid, folder_id, doc_id, db)


@router.get("/storage-summary", response_model=StorageSummaryResponse)
def get_own_storage_summary(
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> StorageSummaryResponse:
    return get_storage_summary(current_user.uid, db)


# ===========================================================================
# Connected-user access — doctor / caregiver / secretary → patient
# ===========================================================================

_READ_ROLES = ("doctor", "caregiver", "secretary")
_WRITE_ROLES = ("doctor", "caregiver", "secretary")


@router.get(
    "/patients/{patient_uid}/folders",
    response_model=FileFoldersListResponse,
)
def get_patient_folders(
    patient_uid: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_READ_ROLES)),
) -> FileFoldersListResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    return list_folders(patient_uid, db)


@router.post(
    "/patients/{patient_uid}/folders",
    response_model=FileFolderResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_patient_folder(
    patient_uid: str,
    payload: FileFolderCreate,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_WRITE_ROLES)),
) -> FileFolderResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    return create_folder(patient_uid, payload.name, db)


@router.patch(
    "/patients/{patient_uid}/folders/{folder_id}",
    response_model=FileFolderResponse,
)
def rename_patient_folder(
    patient_uid: str,
    folder_id: str,
    payload: FileFolderUpdate,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_WRITE_ROLES)),
) -> FileFolderResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    return update_folder(patient_uid, folder_id, payload.name, db)


@router.delete(
    "/patients/{patient_uid}/folders/{folder_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_patient_folder(
    patient_uid: str,
    folder_id: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_WRITE_ROLES)),
) -> None:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    delete_folder(patient_uid, folder_id, db)


@router.get(
    "/patients/{patient_uid}/folders/{folder_id}/documents",
    response_model=FileDocumentsListResponse,
)
def get_patient_documents(
    patient_uid: str,
    folder_id: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_READ_ROLES)),
) -> FileDocumentsListResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    return list_documents(patient_uid, folder_id, db)


@router.post(
    "/patients/{patient_uid}/folders/{folder_id}/documents",
    response_model=FileDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_patient_document(
    patient_uid: str,
    folder_id: str,
    file: UploadFile = File(...),
    name: str = Form(""),
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_WRITE_ROLES)),
) -> FileDocumentResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    file_bytes = await file.read()
    display_name = name.strip() or (file.filename or "document")
    return create_document(
        patient_uid=patient_uid,
        folder_id=folder_id,
        name=display_name,
        file_bytes=file_bytes,
        mime_type=file.content_type or "application/octet-stream",
        uploaded_by_uid=current_user.uid,
        db=db,
    )


@router.patch(
    "/patients/{patient_uid}/folders/{folder_id}/documents/{doc_id}",
    response_model=FileDocumentResponse,
)
def rename_patient_document(
    patient_uid: str,
    folder_id: str,
    doc_id: str,
    payload: FileDocumentUpdate,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_WRITE_ROLES)),
) -> FileDocumentResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    return update_document(patient_uid, folder_id, doc_id, payload.name, db)


@router.delete(
    "/patients/{patient_uid}/folders/{folder_id}/documents/{doc_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_patient_document(
    patient_uid: str,
    folder_id: str,
    doc_id: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_WRITE_ROLES)),
) -> None:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    delete_document(patient_uid, folder_id, doc_id, db)


@router.get(
    "/patients/{patient_uid}/storage-summary",
    response_model=StorageSummaryResponse,
)
def get_patient_storage_summary(
    patient_uid: str,
    db=Depends(get_firestore_client),
    current_user: CurrentUser = Depends(require_roles(*_READ_ROLES)),
) -> StorageSummaryResponse:
    _assert_connected(current_user.uid, patient_uid, db, current_user.role)
    return get_storage_summary(patient_uid, db)

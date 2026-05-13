"""
File Module Schemas — Patient Document Storage.

Firestore collections:
  file_folders/{id}              — patient-owned folders (3 default + custom)
  file_documents/{id}            — documents inside folders (blobs on Azure)
  file_storage_summary/{uid}     — per-patient storage usage counter

Azure Blob path: documents/{patient_uid}/{folder_id}/{uuid}.{ext}
"""

from datetime import datetime

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Folders
# ---------------------------------------------------------------------------

class FileFolderCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)


class FileFolderUpdate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)


class FileFolderResponse(BaseModel):
    id: str
    patient_uid: str
    name: str
    is_default: bool
    item_count: int
    created_at: datetime


class FileFoldersListResponse(BaseModel):
    folders: list[FileFolderResponse]


# ---------------------------------------------------------------------------
# Documents
# ---------------------------------------------------------------------------

class FileDocumentUpdate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)


class FileDocumentResponse(BaseModel):
    id: str
    patient_uid: str
    folder_id: str
    name: str
    file_url: str
    file_type: str          # "image" | "pdf" | "document"
    mime_type: str
    size_bytes: int
    uploaded_by_uid: str
    created_at: datetime
    updated_at: datetime


class FileDocumentsListResponse(BaseModel):
    documents: list[FileDocumentResponse]


# ---------------------------------------------------------------------------
# Storage summary
# ---------------------------------------------------------------------------

class StorageSummaryResponse(BaseModel):
    patient_uid: str
    total_bytes: int
    max_bytes: int = 524_288_000   # 500 MB
    file_count: int
    usage_percentage: float

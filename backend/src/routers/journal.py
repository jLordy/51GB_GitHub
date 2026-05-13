"""Journal Router — Phase 2.2 + connection-gated caregiver/doctor access.

Mounts at /api/journal (registered in api_router.py).

Patient-only endpoints:
  GET    /api/journal/questions                                       — fetch today's questions
  GET    /api/journal/entries                                         — list own entries
  POST   /api/journal/entries                                         — submit a session
  PATCH  /api/journal/entries/{id}                                    — update own entry
  DELETE /api/journal/entries/{id}                                    — delete own entry + history
  GET    /api/journal/entries/{id}/history                            — own entry edit history

Connection-gated endpoints (doctor + caregiver read; caregiver write):
  GET    /api/journal/patients/{patient_uid}/entries                  — list patient entries
  GET    /api/journal/patients/{patient_uid}/entries/{id}/history     — patient entry edit history
  POST   /api/journal/patients/{patient_uid}/entries                  — create entry for patient
  PATCH  /api/journal/patients/{patient_uid}/entries/{id}             — update patient entry
"""

import logging

from fastapi import APIRouter, Depends, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, require_roles
from src.schemas.journal_schemas import (
    EditHistoryListResponse,
    JournalEntriesListResponse,
    JournalEntryCreate,
    JournalEntryResponse,
    JournalEntryUpdate,
    JournalQuestionsResponse,
)
from src.services.journal_service import (
    create_entry_for_patient,
    delete_journal_entry,
    get_daily_questions,
    get_entry_history,
    get_patient_entry_history,
    get_patient_questions,
    list_journal_entries,
    list_patient_entries,
    save_journal_entry,
    update_journal_entry,
    update_patient_entry,
)

router = APIRouter(prefix="/journal", tags=["journal"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# GET /api/journal/questions
# ---------------------------------------------------------------------------

@router.get(
    "/questions",
    response_model=JournalQuestionsResponse,
    summary="Get today's daily monitoring questions",
    description=(
        "Returns the assembled flat list of daily monitoring questions for the "
        "authenticated patient. Questions are ordered: universal first, then "
        "illness-specific (resolved from the patient's own profile). "
        "The client renders each question in sequence using `ui_component` as the "
        "widget discriminator. No doctor registration required."
    ),
)
def get_questions(
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> JournalQuestionsResponse:
    return get_daily_questions(current_user.uid, db, logger)


# ---------------------------------------------------------------------------
# GET /api/journal/entries
# ---------------------------------------------------------------------------

@router.get(
    "/entries",
    response_model=JournalEntriesListResponse,
    summary="List the authenticated patient's journal entries",
    description=(
        "Returns all journal entries for the current patient ordered by most recent first. "
        "Returns an empty list when no entries exist — not a 404. "
        "Requires a Firestore composite index on (user_uid ASC, submitted_at DESC) "
        "under the journal_entries collection."
    ),
)
def get_entries(
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> JournalEntriesListResponse:
    return list_journal_entries(current_user.uid, db, logger)


# ---------------------------------------------------------------------------
# POST /api/journal/entries
# ---------------------------------------------------------------------------

@router.post(
    "/entries",
    response_model=JournalEntryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit a completed journal session",
    description=(
        "Persists the patient's answers for this session to Firestore. "
        "`illness_type` is always resolved server-side from the patient's profile — "
        "it is never accepted from the request body. "
        "`answers` should be a map of question_id → value where the value type "
        "depends on the question's `ui_component` (see JournalEntryCreate for details)."
    ),
)
def create_entry(
    payload: JournalEntryCreate,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> JournalEntryResponse:
    return save_journal_entry(current_user.uid, payload, db, logger)


# ---------------------------------------------------------------------------
# PATCH /api/journal/entries/{entry_id}
# ---------------------------------------------------------------------------

@router.patch(
    "/entries/{entry_id}",
    response_model=JournalEntryResponse,
    summary="Update the answers of an existing journal entry",
    description=(
        "Replaces the `answers` map on an existing journal entry. "
        "Only the owning patient may update their own entry. "
        "`illness_type` and `question_set_type` are immutable and cannot be changed."
    ),
)
def update_entry(
    entry_id: str,
    payload: JournalEntryUpdate,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> JournalEntryResponse:
    return update_journal_entry(current_user.uid, entry_id, payload, db, logger)


# ---------------------------------------------------------------------------
# GET /api/journal/entries/{entry_id}/history
# ---------------------------------------------------------------------------

@router.get(
    "/entries/{entry_id}/history",
    response_model=EditHistoryListResponse,
    summary="Get the edit history for a journal entry",
    description=(
        "Returns all edit snapshots for a single journal entry, ordered by most "
        "recent edit first. Each snapshot contains the `previous_answers` map "
        "(state before that edit), the `edit_number`, and the UTC timestamp. "
        "Only the owning patient may read their own history. Returns an empty "
        "list when the entry has never been edited."
    ),
)
def get_history(
    entry_id: str,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> EditHistoryListResponse:
    return get_entry_history(current_user.uid, entry_id, db, logger)


# ---------------------------------------------------------------------------
# DELETE /api/journal/entries/{entry_id}
# ---------------------------------------------------------------------------

@router.delete(
    "/entries/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a journal entry",
    description=(
        "Permanently deletes a journal entry and all of its edit history snapshots. "
        "Only the owning patient may delete their own entry."
    ),
)
def delete_entry(
    entry_id: str,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> None:
    delete_journal_entry(current_user.uid, entry_id, db, logger)


# ---------------------------------------------------------------------------
# Connection-gated endpoints — doctor + caregiver access to patient journals
# ---------------------------------------------------------------------------

@router.get(
    "/patients/{patient_uid}/questions",
    response_model=JournalQuestionsResponse,
    summary="Get daily questions for a connected patient",
    description=(
        "Returns the assembled daily monitoring questions for the specified patient. "
        "Requires an accepted connection between the caller and the patient. "
        "Accessible by connected doctors and caregivers."
    ),
)
def get_patient_questions_route(
    patient_uid: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> JournalQuestionsResponse:
    return get_patient_questions(current_user.uid, patient_uid, db, logger, viewer_role=current_user.role)


@router.get(
    "/patients/{patient_uid}/entries",
    response_model=JournalEntriesListResponse,
    summary="List a connected patient's journal entries",
    description=(
        "Returns all journal entries for the specified patient. "
        "Requires an accepted connection between the caller and the patient. "
        "Accessible by connected doctors (read-only) and caregivers (read + write)."
    ),
)
def get_patient_entries(
    patient_uid: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> JournalEntriesListResponse:
    return list_patient_entries(current_user.uid, patient_uid, db, logger, viewer_role=current_user.role)


@router.get(
    "/patients/{patient_uid}/entries/{entry_id}/history",
    response_model=EditHistoryListResponse,
    summary="Get edit history for a connected patient's journal entry",
    description=(
        "Returns all edit snapshots for a single journal entry belonging to the specified patient. "
        "Requires an accepted connection between the caller and the patient. "
        "Accessible by connected doctors (read-only) and caregivers (read + write)."
    ),
)
def get_patient_history(
    patient_uid: str,
    entry_id: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> EditHistoryListResponse:
    return get_patient_entry_history(current_user.uid, patient_uid, entry_id, db, logger, viewer_role=current_user.role)


@router.post(
    "/patients/{patient_uid}/entries",
    response_model=JournalEntryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a journal entry on behalf of a connected patient",
    description=(
        "Submits a journal session on behalf of the specified patient. "
        "`illness_type` is resolved server-side from the patient's own profile. "
        "The caller's uid is recorded in `created_by_uid` for auditing. "
        "Requires an accepted connection. Accessible by caregivers only."
    ),
)
def create_patient_entry(
    patient_uid: str,
    payload: JournalEntryCreate,
    current_user: CurrentUser = Depends(require_roles("caregiver")),
) -> JournalEntryResponse:
    return create_entry_for_patient(current_user.uid, patient_uid, payload, db, logger)


@router.patch(
    "/patients/{patient_uid}/entries/{entry_id}",
    response_model=JournalEntryResponse,
    summary="Update a connected patient's journal entry",
    description=(
        "Replaces the `answers` map on an existing journal entry belonging to the specified patient. "
        "The caller's uid is recorded in `last_edited_by_uid` for auditing. "
        "Requires an accepted connection. Accessible by caregivers only."
    ),
)
def update_patient_entry_route(
    patient_uid: str,
    entry_id: str,
    payload: JournalEntryUpdate,
    current_user: CurrentUser = Depends(require_roles("caregiver")),
) -> JournalEntryResponse:
    return update_patient_entry(current_user.uid, patient_uid, entry_id, payload, db, logger)

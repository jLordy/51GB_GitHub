"""
Journal Service — Phase 2.2 (User-Centric Daily Monitoring).

Fetches questionnaire modules directly from Firestore and persists patient
journal entries — with NO dependency on the `patients` collection.

Patient identity is resolved from:
  patients/{auto_id}   — written during patient onboarding
    Required field: illness_type (open string or list[str], e.g. "diabetes",
                   "hypertension", ["diabetes", "ckd"], or ["none"])

Question data is read from questionnaire documents seeded by seed_questionnaires.py:
  questionnaires/daily_universal                   — always loaded
  questionnaires/daily_{illness_type}              — loaded if present (optional)
  questionnaires/daily_medication_{illness_type}   — loaded if present (optional)
  questionnaires/daily_food_{illness_type}         — loaded if present (optional)

Illness types without a specific Firestore module (e.g. "hypertension",
"asthma", "none") gracefully fall back to universal-only questions.

Journal entries are written to:
  journal_entries/{auto_id}
"""

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from src.schemas.journal_schemas import (
    EditHistoryListResponse,
    JournalEntriesListResponse,
    JournalEntryCreate,
    JournalEntryResponse,
    JournalEntryUpdate,
    JournalQuestionsResponse,
)
from src.schemas.questionnaire_schemas import DailyModule, QuestionOption

_PATIENTS_COLLECTION = "patients"
_QUESTIONNAIRES_COLLECTION = "questionnaires"
_JOURNAL_ENTRIES_COLLECTION = "journal_entries"
_EDIT_HISTORY_SUBCOLLECTION = "edit_history"
_CONNECTIONS_COLLECTION = "connections"
_USER_PROFILES_COLLECTION = "user_profiles"
_LEARNED_MEDICATIONS_SUBCOLLECTION = "learned_medications"
_LEARNED_FOODS_SUBCOLLECTION = "learned_foods"



# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _assert_connected(viewer_uid: str, patient_uid: str, db) -> None:
    """
    Verify that viewer_uid has an accepted connection with patient_uid.

    The connections collection stores each request as a single document with
    requester_uid and recipient_uid.  Either party may have initiated the
    request, so both orientations are queried separately.

    Raises HTTP 403 if no accepted connection is found.
    """
    # Orientation 1: viewer initiated the connection request.
    q1 = list(
        db.collection(_CONNECTIONS_COLLECTION)
        .where(filter=FieldFilter("requester_uid", "==", viewer_uid))
        .where(filter=FieldFilter("recipient_uid", "==", patient_uid))
        .where(filter=FieldFilter("status", "==", "accepted"))
        .limit(1)
        .stream()
    )

    if q1:
        return

    # Orientation 2: patient initiated the connection request.
    q2 = list(
        db.collection(_CONNECTIONS_COLLECTION)
        .where(filter=FieldFilter("requester_uid", "==", patient_uid))
        .where(filter=FieldFilter("recipient_uid", "==", viewer_uid))
        .where(filter=FieldFilter("status", "==", "accepted"))
        .limit(1)
        .stream()
    )

    if not q2:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not connected to this patient.",
        )


def _assert_secretary_can_view_patient(viewer_uid: str, patient_uid: str, db) -> None:
    """
    Verify that a secretary can view a patient's journal via the
    secretary → doctor → patient connection chain.

    Steps:
      1. Find all doctors that the secretary has an accepted connection with.
      2. Check whether any of those doctors has an accepted connection with
         the patient.

    Raises HTTP 403 if no valid chain is found.
    """
    # Collect UIDs of doctors the secretary is connected to.
    doctor_uids: list[str] = []
    seen_conn_ids: set[str] = set()

    for field, other_field in [
        ("requester_uid", "recipient_uid"),
        ("recipient_uid", "requester_uid"),
    ]:
        docs = (
            db.collection(_CONNECTIONS_COLLECTION)
            .where(filter=FieldFilter(field, "==", viewer_uid))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_conn_ids:
                continue
            seen_conn_ids.add(doc.id)
            data = doc.to_dict() or {}
            other_uid = data.get(other_field)
            if not other_uid:
                continue
            user_snap = db.collection("users").document(other_uid).get()
            if user_snap.exists:
                user_data = user_snap.to_dict() or {}
                if (user_data.get("role") or "").strip().lower() == "doctor":
                    doctor_uids.append(other_uid)

    if not doctor_uids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorised to view this patient's journal.",
        )

    # Check whether any of those doctors is connected to the patient.
    for doctor_uid in doctor_uids:
        for req_uid, rec_uid in [(doctor_uid, patient_uid), (patient_uid, doctor_uid)]:
            found = list(
                db.collection(_CONNECTIONS_COLLECTION)
                .where(filter=FieldFilter("requester_uid", "==", req_uid))
                .where(filter=FieldFilter("recipient_uid", "==", rec_uid))
                .where(filter=FieldFilter("status", "==", "accepted"))
                .limit(1)
                .stream()
            )
            if found:
                return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You are not authorised to view this patient's journal.",
    )


def _assert_can_view_patient(viewer_uid: str, viewer_role: str, patient_uid: str, db) -> None:
    """
    Unified access check for patient journal read endpoints.

    - doctor / caregiver: must have a direct accepted connection to the patient.
    - secretary: must share a doctor with the patient (secretary→doctor→patient chain).
    """
    if viewer_role == "secretary":
        _assert_secretary_can_view_patient(viewer_uid, patient_uid, db)
    else:
        _assert_connected(viewer_uid, patient_uid, db)


def _resolve_illness_type(user_uid: str, db) -> str:
    """
    Returns the primary illness_type for a patient (first non-'none' entry, or
    'none' if the patient is apparently well).
    Raises 404 if no patient record exists.
    Raises 422 if illness_type is missing entirely.
    """
    results = list(
        db.collection(_PATIENTS_COLLECTION)
        .where(filter=firestore.FieldFilter("user_uid", "==", user_uid))
        .limit(1)
        .stream()
    )
    if not results:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                "Patient profile not found. "
                "Complete onboarding to set up your health profile before using the journal."
            ),
        )
    raw = results[0].to_dict().get("illness_type")
    if isinstance(raw, list):
        # Prefer the first meaningful illness; fall back to "none" if all entries are "none".
        meaningful = [t for t in raw if t and t != "none"]
        illness_type: str | None = meaningful[0] if meaningful else (raw[0] if raw else None)
    else:
        illness_type = raw if raw else None
    if not illness_type:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Your patient profile is missing illness_type. "
                "Please complete onboarding before submitting a journal entry."
            ),
        )
    return illness_type


def _fetch_daily_module(doc_id: str, label: str, db) -> DailyModule:
    """
    Read a daily questionnaire module from Firestore.
    Raises 503 if the document is absent — this is a seed/deployment error,
    not a user error, so 503 (Service Unavailable) is more accurate than 500.
    """
    doc = db.collection(_QUESTIONNAIRES_COLLECTION).document(doc_id).get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"{label} module (questionnaires/{doc_id}) not found in Firestore. "
                "Run `python seed_questionnaires.py` from the backend/ directory."
            ),
        )
    return DailyModule.model_validate(doc.to_dict())


def _try_fetch_daily_module(doc_id: str, db) -> DailyModule | None:
    """Like _fetch_daily_module but returns None instead of raising when absent."""
    doc = db.collection(_QUESTIONNAIRES_COLLECTION).document(doc_id).get()
    if not doc.exists:
        return None
    return DailyModule.model_validate(doc.to_dict())


def _parse_optional_ts(raw) -> datetime | None:
    """Coerce a Firestore DatetimeWithNanoseconds (or None) to a UTC datetime."""
    if raw is None:
        return None
    if isinstance(raw, datetime):
        return raw if raw.tzinfo is not None else raw.replace(tzinfo=timezone.utc)
    return None


def _extract_string_values(value: Any) -> list[str]:
    """Normalize a string/list payload into a cleaned list of non-empty strings."""
    if isinstance(value, str):
        s = value.strip()
        return [s] if s else []
    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            if item is None:
                continue
            s = str(item).strip()
            if s:
                out.append(s)
        return out
    return []


def _persist_learned_inputs(
    *,
    user_uid: str,
    illness_type: str,
    answers: dict[str, Any],
    db,
    logger: logging.Logger,
) -> None:
    """Store learned 'other' medication/food values under user_profiles/{uid}/..."""
    meds = _extract_string_values(answers.get("medication_other_input"))
    foods = _extract_string_values(answers.get("food_other_input"))

    profile_ref = db.collection(_USER_PROFILES_COLLECTION).document(user_uid)

    try:
        for name in meds:
            profile_ref.collection(_LEARNED_MEDICATIONS_SUBCOLLECTION).add(
                {
                    "name": name,
                    "illness_type": illness_type,
                    "created_at": firestore.SERVER_TIMESTAMP,
                }
            )

        for name in foods:
            profile_ref.collection(_LEARNED_FOODS_SUBCOLLECTION).add(
                {
                    "name": name,
                    "illness_type": illness_type,
                    "created_at": firestore.SERVER_TIMESTAMP,
                }
            )
    except Exception as exc:
        # Learning is an enhancement only; do not fail journal save/update.
        logger.warning(
            "Failed to persist learned inputs",
            extra={
                "user_uid": user_uid,
                "illness_type": illness_type,
                "error": str(exc),
            },
        )


def _load_learned_option_labels(
    *,
    user_uid: str,
    illness_type: str,
    subcollection: str,
    db,
) -> list[str]:
    """Fetch learned labels for one illness and de-duplicate case-insensitively."""
    docs = (
        db.collection(_USER_PROFILES_COLLECTION)
        .document(user_uid)
        .collection(subcollection)
        .where(filter=FieldFilter("illness_type", "==", illness_type))
        .stream()
    )

    seen: set[str] = set()
    labels: list[str] = []
    for doc in docs:
        data = doc.to_dict()
        raw = data.get("name")
        if raw is None:
            continue
        label = str(raw).strip()
        if not label:
            continue
        key = label.casefold()
        if key in seen:
            continue
        seen.add(key)
        labels.append(label)
    return labels


def _merge_learned_options_into_question(
    *,
    module: DailyModule,
    question_id: str,
    learned_labels: list[str],
) -> None:
    """Append learned labels as chip options when they are not already present."""
    if not learned_labels:
        return

    for question in module.questions:
        if question.id != question_id:
            continue
        if question.options is None:
            question.options = []

        existing = {
            (opt.value or "").casefold()
            for opt in question.options
        }
        existing.update({
            (opt.label or "").casefold()
            for opt in question.options
        })

        for label in learned_labels:
            key = label.casefold()
            if key in existing:
                continue
            question.options.append(QuestionOption(value=label, label=label))
            existing.add(key)
        break


# ---------------------------------------------------------------------------
# Public service functions
# ---------------------------------------------------------------------------

def get_daily_questions(
    user_uid: str,
    db,
    logger: logging.Logger,
) -> JournalQuestionsResponse:
    """
    Assemble the daily monitoring questions for an authenticated patient.

    Resolution order:
      1. Read patients collection → primary illness_type
      2. Always fetch questionnaires/daily_universal
      3. Optionally fetch questionnaires/daily_{illness_type}        (skipped if absent)
      4. Optionally fetch questionnaires/daily_medication_{illness_type} (skipped if absent)
      5. Optionally fetch questionnaires/daily_food_{illness_type}   (skipped if absent)

    Illness types without seeded Firestore modules (e.g. "hypertension", "asthma",
    "none") simply receive universal questions only — no error is raised.

    Firestore cost: 1 read (patient) + 1–4 reads (modules).
    """
    illness_type = _resolve_illness_type(user_uid, db)

    universal_module = _fetch_daily_module("daily_universal", "Universal daily", db)

    illness_module = _try_fetch_daily_module(f"daily_{illness_type}", db)
    medication_module = _try_fetch_daily_module(f"daily_medication_{illness_type}", db)
    food_module = _try_fetch_daily_module(f"daily_food_{illness_type}", db)

    # Merge user-learned "other" values into medication/food chip options when present.
    if medication_module:
        learned_medication_labels = _load_learned_option_labels(
            user_uid=user_uid,
            illness_type=illness_type,
            subcollection=_LEARNED_MEDICATIONS_SUBCOLLECTION,
            db=db,
        )
        _merge_learned_options_into_question(
            module=medication_module,
            question_id="medication_list",
            learned_labels=learned_medication_labels,
        )

    if food_module:
        learned_food_labels = _load_learned_option_labels(
            user_uid=user_uid,
            illness_type=illness_type,
            subcollection=_LEARNED_FOODS_SUBCOLLECTION,
            db=db,
        )
        _merge_learned_options_into_question(
            module=food_module,
            question_id="food_list",
            learned_labels=learned_food_labels,
        )

    all_questions = list(universal_module.questions)
    if illness_module:
        all_questions.extend(illness_module.questions)
    if medication_module:
        all_questions.extend(medication_module.questions)
    if food_module:
        all_questions.extend(food_module.questions)

    logger.info(
        "Daily questions assembled for journal",
        extra={"user_uid": user_uid, "illness_type": illness_type, "question_count": len(all_questions)},
    )

    return JournalQuestionsResponse(
        question_set_type="daily",
        illness_type=illness_type,
        questions=all_questions,
        version="1.0.0",
        assembled_at=datetime.now(timezone.utc),
    )


def save_journal_entry(
    user_uid: str,
    payload: JournalEntryCreate,
    db,
    logger: logging.Logger,
) -> JournalEntryResponse:
    """
    Persist a completed journal session to Firestore.

    illness_type is always resolved server-side from patient_profiles/{user_uid}
    — never accepted from the client (prevents spoofed illness_type in stored data).

    Firestore cost: 1 read (patient profile) + 1 write (journal_entries).
    """
    illness_type = _resolve_illness_type(user_uid, db)
    now = datetime.now(timezone.utc)

    doc_data: dict[str, Any] = {
        "user_uid": user_uid,
        "question_set_type": payload.question_set_type,
        "illness_type": illness_type,
        "answers": payload.answers,
        "submitted_at": firestore.SERVER_TIMESTAMP,
        "edit_count": 0,
    }

    try:
        _, doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).add(doc_data)
    except Exception as exc:
        logger.error("Failed to save journal entry", extra={"user_uid": user_uid, "error": str(exc)})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save journal entry. Please try again.",
        ) from exc

    _persist_learned_inputs(
        user_uid=user_uid,
        illness_type=illness_type,
        answers=payload.answers,
        db=db,
        logger=logger,
    )

    logger.info(
        "Journal entry saved",
        extra={"entry_id": doc_ref.id, "user_uid": user_uid, "illness_type": illness_type},
    )

    return JournalEntryResponse(
        entry_id=doc_ref.id,
        user_uid=user_uid,
        question_set_type=payload.question_set_type,
        illness_type=illness_type,
        answers=payload.answers,
        # SERVER_TIMESTAMP is unresolved in-process after add(); substitute local now.
        submitted_at=now,
        edit_count=0,
    )


def update_journal_entry(
    user_uid: str,
    entry_id: str,
    payload: JournalEntryUpdate,
    db,
    logger: logging.Logger,
) -> JournalEntryResponse:
    """
    Update the answers of an existing journal entry.

    Only the owning patient may update their own entry (user_uid must match).
    illness_type and question_set_type are immutable.

    Firestore cost: 1 read (ownership check) + 1 write (update).
    """
    doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).document(entry_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    data: dict[str, Any] = doc.to_dict()
    if data.get("user_uid") != user_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only edit your own journal entries.",
        )

    new_edit_count: int = int(data.get("edit_count", 0)) + 1
    now = datetime.now(timezone.utc)

    # Resolve editor's display name from the users collection.
    try:
        editor_doc = db.collection("users").document(user_uid).get()
        editor_name: str | None = editor_doc.to_dict().get("display_name") if editor_doc.exists else None
    except Exception:
        editor_name = None

    # Snapshot previous answers into the edit_history subcollection.
    history_ref = (
        db.collection(_JOURNAL_ENTRIES_COLLECTION)
        .document(entry_id)
        .collection(_EDIT_HISTORY_SUBCOLLECTION)
    )
    try:
        history_ref.add({
            "edit_number": new_edit_count,
            "edited_at": firestore.SERVER_TIMESTAMP,
            "previous_answers": data.get("answers", {}),
            "edited_by_uid": user_uid,
            "editor_name": editor_name,
        })
    except Exception as exc:
        logger.error(
            "Failed to write edit history snapshot",
            extra={"entry_id": entry_id, "user_uid": user_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save edit history. Please try again.",
        ) from exc

    try:
        doc_ref.update(
            {
                "answers": payload.answers,
                "updated_at": firestore.SERVER_TIMESTAMP,
                "edit_count": new_edit_count,
            }
        )
    except Exception as exc:
        logger.error(
            "Failed to update journal entry",
            extra={"entry_id": entry_id, "user_uid": user_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update journal entry. Please try again.",
        ) from exc

    _persist_learned_inputs(
        user_uid=user_uid,
        illness_type=data.get("illness_type", ""),
        answers=payload.answers,
        db=db,
        logger=logger,
    )

    logger.info(
        "Journal entry updated",
        extra={"entry_id": entry_id, "user_uid": user_uid},
    )

    raw_ts = data.get("submitted_at")
    submitted_at = raw_ts if isinstance(raw_ts, datetime) else datetime.now(timezone.utc)
    if submitted_at.tzinfo is None:
        submitted_at = submitted_at.replace(tzinfo=timezone.utc)

    return JournalEntryResponse(
        entry_id=entry_id,
        user_uid=user_uid,
        question_set_type=data.get("question_set_type", "daily"),
        illness_type=data.get("illness_type", ""),
        answers=payload.answers,
        submitted_at=submitted_at,
        updated_at=now,
        edit_count=new_edit_count,
    )


def list_journal_entries(
    user_uid: str,
    db,
    logger: logging.Logger,
) -> JournalEntriesListResponse:
    """
    Fetch all journal entries for the authenticated patient, ordered newest first.

    Firestore query: journal_entries WHERE user_uid == uid ORDER BY submitted_at DESC
    This query requires a composite index on (user_uid ASC, submitted_at DESC).
    If the index does not exist Firestore returns an error with a URL to auto-create it.

    Returns an empty list when the patient has no entries yet (not a 404).
    """
    try:
        docs = (
            db.collection(_JOURNAL_ENTRIES_COLLECTION)
            .where(filter=FieldFilter("user_uid", "==", user_uid))
            .order_by("submitted_at", direction="DESCENDING")
            .stream()
        )
    except Exception as exc:
        logger.error("Failed to query journal entries", extra={"user_uid": user_uid, "error": str(exc)})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve journal entries. Please try again.",
        ) from exc

    entries: list[JournalEntryResponse] = []
    for doc in docs:
        data: dict[str, Any] = doc.to_dict()
        raw_ts = data.get("submitted_at")
        submitted_at = raw_ts if isinstance(raw_ts, datetime) else datetime.now(timezone.utc)
        if submitted_at.tzinfo is None:
            submitted_at = submitted_at.replace(tzinfo=timezone.utc)

        entries.append(
            JournalEntryResponse(
                entry_id=doc.id,
                user_uid=data.get("user_uid", user_uid),
                question_set_type=data.get("question_set_type", "daily"),
                illness_type=data.get("illness_type", ""),
                answers=data.get("answers", {}),
                submitted_at=submitted_at,
                updated_at=_parse_optional_ts(data.get("updated_at")),
                edit_count=int(data.get("edit_count", 0)),
            )
        )

    logger.info(
        "Journal entries fetched",
        extra={"user_uid": user_uid, "count": len(entries)},
    )
    return JournalEntriesListResponse(entries=entries, total=len(entries))


# ---------------------------------------------------------------------------
# GET /api/journal/entries/{entry_id}/history
# ---------------------------------------------------------------------------

def get_entry_history(
    user_uid: str,
    entry_id: str,
    db,
    logger: logging.Logger,
) -> EditHistoryListResponse:
    """
    Return the edit history for a single journal entry, newest edit first.

    Only the owning patient may read their own history.

    Firestore cost: 1 read (ownership check) + N reads (history subcollection).
    """
    from src.schemas.journal_schemas import EditHistoryEntry  # local import avoids circular reference risk

    doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).document(entry_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    data: dict[str, Any] = doc.to_dict()
    if data.get("user_uid") != user_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view history for your own journal entries.",
        )

    try:
        history_docs = (
            doc_ref.collection(_EDIT_HISTORY_SUBCOLLECTION)
            .order_by("edit_number", direction="DESCENDING")
            .stream()
        )
    except Exception as exc:
        logger.error(
            "Failed to query edit history",
            extra={"entry_id": entry_id, "user_uid": user_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve edit history. Please try again.",
        ) from exc

    history: list[EditHistoryEntry] = []
    for h_doc in history_docs:
        h_data: dict[str, Any] = h_doc.to_dict()
        raw_ts = h_data.get("edited_at")
        edited_at = raw_ts if isinstance(raw_ts, datetime) else datetime.now(timezone.utc)
        if edited_at.tzinfo is None:
            edited_at = edited_at.replace(tzinfo=timezone.utc)
        history.append(
            EditHistoryEntry(
                edit_number=int(h_data.get("edit_number", 0)),
                edited_at=edited_at,
                previous_answers=h_data.get("previous_answers", {}),
                edited_by_uid=h_data.get("edited_by_uid"),
                editor_name=h_data.get("editor_name"),
            )
        )

    logger.info(
        "Edit history fetched",
        extra={"entry_id": entry_id, "user_uid": user_uid, "history_count": len(history)},
    )
    return EditHistoryListResponse(entry_id=entry_id, history=history)


# ---------------------------------------------------------------------------
# DELETE /api/journal/entries/{entry_id}
# ---------------------------------------------------------------------------

def delete_journal_entry(
    user_uid: str,
    entry_id: str,
    db,
    logger: logging.Logger,
) -> None:
    """
    Hard-delete a journal entry and its edit_history subcollection.

    Only the owning patient may delete their own entry (OWASP A01).
    Firestore does NOT auto-delete subcollections, so edit_history docs are
    purged explicitly before the root document is removed.

    Firestore cost: 1 read (ownership check) + N reads (history) + N+1 deletes.
    """
    doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).document(entry_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    data: dict[str, Any] = doc.to_dict()
    if data.get("user_uid") != user_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own journal entries.",
        )

    # Purge edit_history subcollection first.
    try:
        history_docs = doc_ref.collection(_EDIT_HISTORY_SUBCOLLECTION).stream()
        for h_doc in history_docs:
            h_doc.reference.delete()
    except Exception as exc:
        logger.error(
            "Failed to purge edit history before delete",
            extra={"entry_id": entry_id, "user_uid": user_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete journal entry. Please try again.",
        ) from exc

    try:
        doc_ref.delete()
    except Exception as exc:
        logger.error(
            "Failed to delete journal entry",
            extra={"entry_id": entry_id, "user_uid": user_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete journal entry. Please try again.",
        ) from exc

    logger.info(
        "Journal entry deleted",
        extra={"entry_id": entry_id, "user_uid": user_uid},
    )


# ---------------------------------------------------------------------------
# Connection-gated helpers (doctor / caregiver access to patient journals)
# ---------------------------------------------------------------------------

def get_patient_questions(
    viewer_uid: str,
    patient_uid: str,
    db,
    logger: logging.Logger,
    viewer_role: str = "doctor",
) -> JournalQuestionsResponse:
    """
    Return the daily monitoring questions for *patient_uid*, accessible by a
    connected doctor, caregiver, or secretary.  Thin wrapper around get_daily_questions —
    the illness_type is resolved from the patient's profile, not the viewer's.

    Firestore cost: up to 2 reads (connection) + 3 reads (questions assembly).
    """
    _assert_can_view_patient(viewer_uid, viewer_role, patient_uid, db)
    return get_daily_questions(patient_uid, db, logger)


def list_patient_entries(
    viewer_uid: str,
    patient_uid: str,
    db,
    logger: logging.Logger,
    viewer_role: str = "doctor",
) -> JournalEntriesListResponse:
    """
    Return all journal entries for *patient_uid*, accessible by a connected
    doctor, caregiver, or secretary (read-only).

    Steps:
      1. Assert viewer is authorised to view the patient (direct connection for
         doctor/caregiver; secretary→doctor→patient chain for secretary).
      2. Query journal_entries WHERE user_uid == patient_uid, newest first.

    Firestore cost: 2 reads (connection check × 2 orientations, early-exit) +
                    N reads (journal entries).
    """
    _assert_can_view_patient(viewer_uid, viewer_role, patient_uid, db)

    try:
        docs = (
            db.collection(_JOURNAL_ENTRIES_COLLECTION)
            .where(filter=FieldFilter("user_uid", "==", patient_uid))
            .order_by("submitted_at", direction="DESCENDING")
            .stream()
        )
    except Exception as exc:
        logger.error(
            "Failed to query patient journal entries",
            extra={"viewer_uid": viewer_uid, "patient_uid": patient_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve journal entries. Please try again.",
        ) from exc

    entries: list[JournalEntryResponse] = []
    for doc in docs:
        data: dict[str, Any] = doc.to_dict()
        raw_ts = data.get("submitted_at")
        submitted_at = raw_ts if isinstance(raw_ts, datetime) else datetime.now(timezone.utc)
        if submitted_at.tzinfo is None:
            submitted_at = submitted_at.replace(tzinfo=timezone.utc)

        entries.append(
            JournalEntryResponse(
                entry_id=doc.id,
                user_uid=data.get("user_uid", patient_uid),
                question_set_type=data.get("question_set_type", "daily"),
                illness_type=data.get("illness_type", ""),
                answers=data.get("answers", {}),
                submitted_at=submitted_at,
                updated_at=_parse_optional_ts(data.get("updated_at")),
                edit_count=int(data.get("edit_count", 0)),
                created_by_uid=data.get("created_by_uid"),
                last_edited_by_uid=data.get("last_edited_by_uid"),
            )
        )

    logger.info(
        "Patient journal entries fetched by connected user",
        extra={"viewer_uid": viewer_uid, "patient_uid": patient_uid, "count": len(entries)},
    )
    return JournalEntriesListResponse(entries=entries, total=len(entries))


def get_patient_entry_history(
    viewer_uid: str,
    patient_uid: str,
    entry_id: str,
    db,
    logger: logging.Logger,
    viewer_role: str = "doctor",
) -> EditHistoryListResponse:
    """
    Return the edit history for a single patient journal entry, accessible by
    a connected doctor, caregiver, or secretary.

    Steps:
      1. Assert authorised (direct connection or secretary chain).
      2. Fetch the entry and verify it belongs to patient_uid.
      3. Stream the edit_history subcollection, newest edit first.

    Firestore cost: up to 2 reads (connection) + 1 read (entry) + N reads (history).
    """
    from src.schemas.journal_schemas import EditHistoryEntry  # avoid circular-import risk

    _assert_can_view_patient(viewer_uid, viewer_role, patient_uid, db)

    doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).document(entry_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    data: dict[str, Any] = doc.to_dict()
    if data.get("user_uid") != patient_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This entry does not belong to the specified patient.",
        )

    try:
        history_docs = (
            doc_ref.collection(_EDIT_HISTORY_SUBCOLLECTION)
            .order_by("edit_number", direction="DESCENDING")
            .stream()
        )
    except Exception as exc:
        logger.error(
            "Failed to query patient entry edit history",
            extra={"viewer_uid": viewer_uid, "patient_uid": patient_uid, "entry_id": entry_id, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve edit history. Please try again.",
        ) from exc

    history: list[EditHistoryEntry] = []
    for h_doc in history_docs:
        h_data: dict[str, Any] = h_doc.to_dict()
        raw_ts = h_data.get("edited_at")
        edited_at = raw_ts if isinstance(raw_ts, datetime) else datetime.now(timezone.utc)
        if edited_at.tzinfo is None:
            edited_at = edited_at.replace(tzinfo=timezone.utc)
        history.append(
            EditHistoryEntry(
                edit_number=int(h_data.get("edit_number", 0)),
                edited_at=edited_at,
                previous_answers=h_data.get("previous_answers", {}),
                edited_by_uid=h_data.get("edited_by_uid"),
                editor_name=h_data.get("editor_name"),
            )
        )

    logger.info(
        "Patient entry history fetched by connected user",
        extra={"viewer_uid": viewer_uid, "patient_uid": patient_uid, "entry_id": entry_id, "history_count": len(history)},
    )
    return EditHistoryListResponse(entry_id=entry_id, history=history)


def create_entry_for_patient(
    viewer_uid: str,
    patient_uid: str,
    payload: JournalEntryCreate,
    db,
    logger: logging.Logger,
) -> JournalEntryResponse:
    """
    Create a journal entry on behalf of *patient_uid* by a connected caregiver.

    illness_type is resolved from the *patient's* profile (not the viewer's),
    so the entry is medically accurate regardless of who is submitting it.
    The viewer's uid is stored in created_by_uid for audit purposes.

    Steps:
      1. Assert connected.
      2. Resolve illness_type from patient_uid.
      3. Write entry with user_uid=patient_uid, created_by_uid=viewer_uid.

    Firestore cost: up to 2 reads (connection) + 1 read (patient profile) + 1 write.
    """
    _assert_connected(viewer_uid, patient_uid, db)

    illness_type = _resolve_illness_type(patient_uid, db)
    now = datetime.now(timezone.utc)

    doc_data: dict[str, Any] = {
        "user_uid": patient_uid,
        "created_by_uid": viewer_uid,
        "question_set_type": payload.question_set_type,
        "illness_type": illness_type,
        "answers": payload.answers,
        "submitted_at": firestore.SERVER_TIMESTAMP,
        "edit_count": 0,
    }

    try:
        _, doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).add(doc_data)
    except Exception as exc:
        logger.error(
            "Failed to create patient journal entry",
            extra={"viewer_uid": viewer_uid, "patient_uid": patient_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save journal entry. Please try again.",
        ) from exc

    _persist_learned_inputs(
        user_uid=patient_uid,
        illness_type=illness_type,
        answers=payload.answers,
        db=db,
        logger=logger,
    )

    logger.info(
        "Journal entry created for patient by caregiver",
        extra={"entry_id": doc_ref.id, "viewer_uid": viewer_uid, "patient_uid": patient_uid},
    )

    return JournalEntryResponse(
        entry_id=doc_ref.id,
        user_uid=patient_uid,
        question_set_type=payload.question_set_type,
        illness_type=illness_type,
        answers=payload.answers,
        submitted_at=now,
        edit_count=0,
        created_by_uid=viewer_uid,
    )


def update_patient_entry(
    viewer_uid: str,
    patient_uid: str,
    entry_id: str,
    payload: JournalEntryUpdate,
    db,
    logger: logging.Logger,
) -> JournalEntryResponse:
    """
    Update a patient's journal entry on behalf of *patient_uid* by a connected
    caregiver.

    Only entries whose user_uid matches patient_uid may be updated through this
    path (prevents a caregiver on patient A from editing entries of patient B).
    Edit history is snapshotted identically to the patient's own update path.
    The viewer's uid is stored in last_edited_by_uid for audit purposes.

    Steps:
      1. Assert connected.
      2. Fetch entry, verify user_uid == patient_uid.
      3. Snapshot previous answers into edit_history subcollection.
      4. Update entry answers + last_edited_by_uid.

    Firestore cost: up to 2 reads (connection) + 1 read (entry) + 1 write (history) + 1 write (update).
    """
    _assert_connected(viewer_uid, patient_uid, db)

    doc_ref = db.collection(_JOURNAL_ENTRIES_COLLECTION).document(entry_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    data: dict[str, Any] = doc.to_dict()
    if data.get("user_uid") != patient_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This entry does not belong to the specified patient.",
        )

    new_edit_count: int = int(data.get("edit_count", 0)) + 1
    now = datetime.now(timezone.utc)

    # Resolve editor's display name from the users collection.
    try:
        editor_doc = db.collection("users").document(viewer_uid).get()
        editor_name: str | None = editor_doc.to_dict().get("display_name") if editor_doc.exists else None
    except Exception:
        editor_name = None

    # Snapshot previous answers into the edit_history subcollection.
    history_ref = (
        db.collection(_JOURNAL_ENTRIES_COLLECTION)
        .document(entry_id)
        .collection(_EDIT_HISTORY_SUBCOLLECTION)
    )
    try:
        history_ref.add({
            "edit_number": new_edit_count,
            "edited_at": firestore.SERVER_TIMESTAMP,
            "previous_answers": data.get("answers", {}),
            "edited_by_uid": viewer_uid,
            "editor_name": editor_name,
        })
    except Exception as exc:
        logger.error(
            "Failed to write edit history for patient entry update",
            extra={"entry_id": entry_id, "viewer_uid": viewer_uid, "patient_uid": patient_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save edit history. Please try again.",
        ) from exc

    try:
        doc_ref.update({
            "answers": payload.answers,
            "updated_at": firestore.SERVER_TIMESTAMP,
            "edit_count": new_edit_count,
            "last_edited_by_uid": viewer_uid,
        })
    except Exception as exc:
        logger.error(
            "Failed to update patient journal entry",
            extra={"entry_id": entry_id, "viewer_uid": viewer_uid, "patient_uid": patient_uid, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update journal entry. Please try again.",
        ) from exc

    _persist_learned_inputs(
        user_uid=patient_uid,
        illness_type=data.get("illness_type", ""),
        answers=payload.answers,
        db=db,
        logger=logger,
    )

    logger.info(
        "Patient journal entry updated by caregiver",
        extra={"entry_id": entry_id, "viewer_uid": viewer_uid, "patient_uid": patient_uid},
    )

    raw_ts = data.get("submitted_at")
    submitted_at = raw_ts if isinstance(raw_ts, datetime) else datetime.now(timezone.utc)
    if submitted_at.tzinfo is None:
        submitted_at = submitted_at.replace(tzinfo=timezone.utc)

    return JournalEntryResponse(
        entry_id=entry_id,
        user_uid=patient_uid,
        question_set_type=data.get("question_set_type", "daily"),
        illness_type=data.get("illness_type", ""),
        answers=payload.answers,
        submitted_at=submitted_at,
        updated_at=now,
        edit_count=new_edit_count,
        created_by_uid=data.get("created_by_uid"),
        last_edited_by_uid=viewer_uid,
    )

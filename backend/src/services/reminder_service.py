"""
Reminder Service — Medication Reminders feature.

All reminders are scoped to a single Firestore collection:
  medication_reminders/{reminder_id}

Security model:
  - CRUD (list/create/update/delete): caller must own the reminder (user_uid match).
  - markStatus: caller is either the owning patient OR a caregiver who is
    connected to the patient.  caregiver_id in the body activates the
    connection check; absence means the patient is calling directly.
"""

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from src.schemas.reminder_schemas import (
    ReminderCreate,
    ReminderResponse,
    ReminderUpdate,
    StatusUpdate,
)

_COLLECTION = "medication_reminders"
_CONNECTIONS_COLLECTION = "connections"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _ts(raw: Any) -> datetime:
    """Coerce a Firestore timestamp or None to a UTC-aware datetime."""
    if isinstance(raw, datetime):
        return raw if raw.tzinfo is not None else raw.replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc)


def _to_response(doc_id: str, data: dict[str, Any]) -> ReminderResponse:
    return ReminderResponse(
        id=doc_id,
        user_uid=data["user_uid"],
        med_name=data["med_name"],
        dosage=data["dosage"],
        scheduled_time=_ts(data.get("scheduled_time")),
        frequency=data.get("frequency", "daily"),
        is_alarm_enabled=bool(data.get("is_alarm_enabled", True)),
        caregiver_id=data.get("caregiver_id"),
        status=data.get("status", "upcoming"),
        created_at=_ts(data.get("created_at")),
        updated_at=_ts(data["updated_at"]) if data.get("updated_at") else None,
    )


def _assert_owns(data: dict[str, Any], user_uid: str) -> None:
    if data.get("user_uid") != user_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to modify this reminder.",
        )


def _assert_connected(caregiver_uid: str, patient_uid: str, db) -> None:
    """Raise 403 unless caregiver_uid has an accepted connection with patient_uid."""
    for req_uid, rec_uid in [
        (caregiver_uid, patient_uid),
        (patient_uid, caregiver_uid),
    ]:
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
        detail="You are not connected to this patient.",
    )


# ---------------------------------------------------------------------------
# Public service functions
# ---------------------------------------------------------------------------


def list_reminders(
    user_uid: str,
    db,
    logger: logging.Logger,
) -> list[ReminderResponse]:
    """Return all reminders owned by user_uid, ordered by scheduled_time ascending."""
    try:
        docs = (
            db.collection(_COLLECTION)
            .where(filter=FieldFilter("user_uid", "==", user_uid))
            .order_by("scheduled_time")
            .stream()
        )
    except Exception as exc:
        logger.error("Failed to list reminders", extra={"user_uid": user_uid, "error": str(exc)})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve reminders.",
        ) from exc

    results: list[ReminderResponse] = []
    for doc in docs:
        data = doc.to_dict() or {}
        results.append(_to_response(doc.id, data))

    logger.info("Reminders listed", extra={"user_uid": user_uid, "count": len(results)})
    return results


def create_reminder(
    user_uid: str,
    payload: ReminderCreate,
    db,
    logger: logging.Logger,
) -> ReminderResponse:
    """
    Create a new reminder using the client-supplied `payload.id` as the
    Firestore document ID so both the local cache and server stay in sync.
    """
    doc_ref = db.collection(_COLLECTION).document(payload.id)
    if doc_ref.get().exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A reminder with this ID already exists.",
        )

    now = datetime.now(timezone.utc)
    doc_data: dict[str, Any] = {
        "user_uid": user_uid,
        "med_name": payload.med_name,
        "dosage": payload.dosage,
        "scheduled_time": payload.scheduled_time,
        "frequency": payload.frequency,
        "is_alarm_enabled": payload.is_alarm_enabled,
        "caregiver_id": payload.caregiver_id,
        "status": payload.status,
        "created_at": firestore.SERVER_TIMESTAMP,
        "updated_at": None,
    }

    try:
        doc_ref.set(doc_data)
    except Exception as exc:
        logger.error(
            "Failed to create reminder",
            extra={"user_uid": user_uid, "reminder_id": payload.id, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create reminder.",
        ) from exc

    logger.info(
        "Reminder created",
        extra={"user_uid": user_uid, "reminder_id": payload.id},
    )
    return ReminderResponse(
        id=payload.id,
        user_uid=user_uid,
        med_name=payload.med_name,
        dosage=payload.dosage,
        scheduled_time=payload.scheduled_time,
        frequency=payload.frequency,
        is_alarm_enabled=payload.is_alarm_enabled,
        caregiver_id=payload.caregiver_id,
        status=payload.status,
        created_at=now,
        updated_at=None,
    )


def update_reminder(
    user_uid: str,
    reminder_id: str,
    payload: ReminderUpdate,
    db,
    logger: logging.Logger,
) -> ReminderResponse:
    """Full replacement of mutable fields. user_uid and created_at are immutable."""
    doc_ref = db.collection(_COLLECTION).document(reminder_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found.")

    data = doc.to_dict() or {}
    _assert_owns(data, user_uid)

    now = datetime.now(timezone.utc)
    updates: dict[str, Any] = {
        "med_name": payload.med_name,
        "dosage": payload.dosage,
        "scheduled_time": payload.scheduled_time,
        "frequency": payload.frequency,
        "is_alarm_enabled": payload.is_alarm_enabled,
        "caregiver_id": payload.caregiver_id,
        "status": payload.status,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }

    try:
        doc_ref.update(updates)
    except Exception as exc:
        logger.error(
            "Failed to update reminder",
            extra={"user_uid": user_uid, "reminder_id": reminder_id, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update reminder.",
        ) from exc

    logger.info("Reminder updated", extra={"user_uid": user_uid, "reminder_id": reminder_id})
    return ReminderResponse(
        id=reminder_id,
        user_uid=user_uid,
        med_name=payload.med_name,
        dosage=payload.dosage,
        scheduled_time=payload.scheduled_time,
        frequency=payload.frequency,
        is_alarm_enabled=payload.is_alarm_enabled,
        caregiver_id=payload.caregiver_id,
        status=payload.status,
        created_at=_ts(data.get("created_at")),
        updated_at=now,
    )


def delete_reminder(
    user_uid: str,
    reminder_id: str,
    db,
    logger: logging.Logger,
) -> None:
    doc_ref = db.collection(_COLLECTION).document(reminder_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found.")

    _assert_owns(doc.to_dict() or {}, user_uid)

    try:
        doc_ref.delete()
    except Exception as exc:
        logger.error(
            "Failed to delete reminder",
            extra={"user_uid": user_uid, "reminder_id": reminder_id, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete reminder.",
        ) from exc

    logger.info("Reminder deleted", extra={"user_uid": user_uid, "reminder_id": reminder_id})


def mark_status(
    caller_uid: str,
    reminder_id: str,
    payload: StatusUpdate,
    db,
    logger: logging.Logger,
) -> ReminderResponse:
    """
    Update only the status field.

    Access rules:
    - If `caregiver_id` is absent: caller must own the reminder (patient path).
    - If `caregiver_id` is present: caller must be a connected caregiver of the patient
      who owns the reminder.
    """
    doc_ref = db.collection(_COLLECTION).document(reminder_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found.")

    data = doc.to_dict() or {}
    owner_uid: str = data.get("user_uid", "")

    if payload.caregiver_id:
        # Caregiver path: verify the caller is the stated caregiver and is connected.
        if caller_uid != payload.caregiver_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="caregiver_id must match the authenticated user.",
            )
        _assert_connected(caller_uid, owner_uid, db)
    else:
        # Patient path: caller must own the reminder.
        _assert_owns(data, caller_uid)

    now = datetime.now(timezone.utc)
    try:
        doc_ref.update({"status": payload.status, "updated_at": firestore.SERVER_TIMESTAMP})
    except Exception as exc:
        logger.error(
            "Failed to update reminder status",
            extra={"caller_uid": caller_uid, "reminder_id": reminder_id, "error": str(exc)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update reminder status.",
        ) from exc

    logger.info(
        "Reminder status updated",
        extra={"caller_uid": caller_uid, "reminder_id": reminder_id, "status": payload.status},
    )
    return ReminderResponse(
        id=reminder_id,
        user_uid=owner_uid,
        med_name=data["med_name"],
        dosage=data["dosage"],
        scheduled_time=_ts(data.get("scheduled_time")),
        frequency=data.get("frequency", "daily"),
        is_alarm_enabled=bool(data.get("is_alarm_enabled", True)),
        caregiver_id=data.get("caregiver_id"),
        status=payload.status,
        created_at=_ts(data.get("created_at")),
        updated_at=now,
    )

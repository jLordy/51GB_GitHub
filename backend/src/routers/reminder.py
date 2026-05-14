"""
Reminder Router — Medication Reminders feature.

Mounts at /api/reminders (registered in api_router.py).

Patient endpoints:
  GET    /api/reminders               — list own reminders
  POST   /api/reminders               — create a reminder
  PUT    /api/reminders/{id}          — full update
  DELETE /api/reminders/{id}          — delete

Shared endpoint (patient or connected caregiver):
  PATCH  /api/reminders/{id}/status   — update status only
"""

import logging

from fastapi import APIRouter, Depends, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, get_current_user, require_roles
from src.schemas.reminder_schemas import (
    ReminderCreate,
    ReminderResponse,
    ReminderUpdate,
    StatusUpdate,
)
from src.services.reminder_service import (
    create_reminder,
    delete_reminder,
    list_reminders,
    mark_status,
    update_reminder,
)

router = APIRouter(prefix="/reminders", tags=["reminders"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


@router.get(
    "",
    response_model=list[ReminderResponse],
    summary="List the authenticated user's medication reminders",
)
def get_reminders(
    current_user: CurrentUser = Depends(get_current_user),
) -> list[ReminderResponse]:
    return list_reminders(current_user.uid, db, logger)


@router.post(
    "",
    response_model=ReminderResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a medication reminder",
)
def post_reminder(
    payload: ReminderCreate,
    current_user: CurrentUser = Depends(get_current_user),
) -> ReminderResponse:
    return create_reminder(current_user.uid, payload, db, logger)


@router.put(
    "/{reminder_id}",
    response_model=ReminderResponse,
    summary="Replace a medication reminder",
)
def put_reminder(
    reminder_id: str,
    payload: ReminderUpdate,
    current_user: CurrentUser = Depends(get_current_user),
) -> ReminderResponse:
    return update_reminder(current_user.uid, reminder_id, payload, db, logger)


@router.delete(
    "/{reminder_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a medication reminder",
)
def remove_reminder(
    reminder_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    delete_reminder(current_user.uid, reminder_id, db, logger)


@router.patch(
    "/{reminder_id}/status",
    response_model=ReminderResponse,
    summary="Update only the status of a reminder (patient or connected caregiver)",
)
def patch_status(
    reminder_id: str,
    payload: StatusUpdate,
    current_user: CurrentUser = Depends(get_current_user),
) -> ReminderResponse:
    return mark_status(current_user.uid, reminder_id, payload, db, logger)

"""
Notifications Router.

Mounts at /api/notifications (registered in api_router.py).

  GET    /api/notifications                         — fetch feed (newest-first)
  PATCH  /api/notifications/read                    — mark list of IDs as read
  DELETE /api/notifications                         — delete all for current user
  PATCH  /api/notifications/{id}/payload-status     — persist accepted/declined state
  DELETE /api/notifications/{id}                    — delete single notification
"""

import logging

from fastapi import APIRouter, Body, Depends, Query, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, get_current_user
from src.services.notification_service import (
    delete_all_notifications,
    delete_single_notification,
    fetch_notifications,
    mark_notifications_read,
    patch_notification_payload_status,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


@router.get("", summary="Fetch the authenticated user's notification feed")
def get_notifications(
    limit: int = Query(default=40, ge=1, le=100),
    current_user: CurrentUser = Depends(get_current_user),
) -> list[dict]:
    return fetch_notifications(db, user_id=current_user.uid, limit=limit, logger=logger)


# Static sub-paths must be declared before /{notification_id} to avoid
# FastAPI routing /{notification_id} matching "read" or "payload-status".

@router.patch("/read", status_code=status.HTTP_204_NO_CONTENT, summary="Mark notifications as read")
def mark_read(
    body: dict = Body(...),
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    ids: list[str] = body.get("notification_ids") or []
    mark_notifications_read(db, user_id=current_user.uid, notification_ids=ids, logger=logger)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT, summary="Delete all notifications")
def clear_all(
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    delete_all_notifications(db, user_id=current_user.uid, logger=logger)


@router.patch(
    "/{notification_id}/payload-status",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Persist accepted/declined state on a connection-request notification",
)
def update_payload_status(
    notification_id: str,
    body: dict = Body(...),
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    patch_notification_payload_status(
        db,
        user_id=current_user.uid,
        notification_id=notification_id,
        status=body.get("status", ""),
        logger=logger,
    )


@router.delete(
    "/{notification_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a single notification",
)
def delete_one(
    notification_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    delete_single_notification(
        db, user_id=current_user.uid, notification_id=notification_id, logger=logger
    )

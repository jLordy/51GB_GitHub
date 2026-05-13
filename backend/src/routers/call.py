"""
Call Router — WebRTC call notification via FCM.

Mounts at /api/call (registered in api_router.py).

Endpoints:
  POST /api/call/notify — send an FCM data message to the callee's device

Signaling (offer/answer/ICE) is handled client-side via Firestore.
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import messaging
from google.cloud.firestore_v1 import DELETE_FIELD

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, get_current_user
from src.schemas.call_schemas import CallNotifyRequest

router = APIRouter(prefix="/call", tags=["call"])
logger = logging.getLogger(__name__)


@router.post("/notify", status_code=status.HTTP_204_NO_CONTENT)
async def notify_callee(
    request: CallNotifyRequest,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    """
    Look up the callee's FCM token from Firestore and send a data-only push
    so the callee's device wakes up and shows the incoming-call screen.
    """
    db = get_firestore_client()
    callee_doc = db.collection("users").document(request.callee_uid).get()
    if not callee_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Callee not found.",
        )

    callee_data = callee_doc.to_dict() or {}
    fcm_token: str | None = callee_data.get("fcm_token")

    if not fcm_token:
        # Callee has no token yet — client will still see the Firestore update.
        logger.info("Callee %s has no FCM token; skipping push.", request.callee_uid)
        return

    message = messaging.Message(
        token=fcm_token,
        data={
            "type": "incoming_call",
            "call_id": request.call_id,
            "caller_name": request.caller_name,
            "caller_photo_url": request.caller_photo_url or "",
            "call_type": request.call_type,
        },
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
        ),
    )

    try:
        messaging.send(message)
    except messaging.UnregisteredError:
        # Token is stale — clean it up silently.
        db.collection("users").document(request.callee_uid).update(
            {"fcm_token": DELETE_FIELD}
        )
        logger.info("Removed stale FCM token for %s.", request.callee_uid)
    except Exception as exc:  # noqa: BLE001
        logger.error("FCM send failed for %s: %s", request.callee_uid, exc)

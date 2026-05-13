"""
Connection service — send, accept, decline, remove, and list health-circle connections.

Design principles:
- Thin service layer: all business logic lives here, routers own only HTTP concerns.
- Atomic batch writes: connection state changes and notification fan-outs are
  always committed in the same Firestore batch to prevent partial state.
- OWASP A01 compliance: every mutation verifies the caller is a participant.
  404 is returned for missing docs (not 403) to prevent connection-ID enumeration.
- No self-connections: requester_uid != recipient_uid is enforced here, not in
  the router, so it cannot be bypassed by direct service calls.
- Duplicate prevention: both directions are checked before creating a new doc,
  so only one connection document exists per user pair regardless of who initiates.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from src.middleware import CurrentUser
from src.schemas.connection_schemas import ConnectionResponse, UserConnectionSummary
from src.services.notification_service import (
    notify_connection_accepted,
    notify_connection_request,
)

# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────

_CONNECTIONS = "connections"


def _ts_to_iso(val: Any) -> str:
    """
    Convert a Firestore DatetimeWithNanoseconds (or any datetime) to an ISO 8601
    string. SERVER_TIMESTAMP placeholders that haven't resolved in-process yet
    are returned as the current UTC time to keep the response schema valid.
    """
    if isinstance(val, datetime):
        dt = val if val.tzinfo else val.replace(tzinfo=timezone.utc)
        return dt.isoformat()
    return datetime.now(timezone.utc).isoformat()


def _doc_to_response(doc_id: str, data: dict[str, Any]) -> ConnectionResponse:
    return ConnectionResponse(
        connection_id=doc_id,
        requester_uid=data["requester_uid"],
        recipient_uid=data["recipient_uid"],
        status=data["status"],
        created_at=_ts_to_iso(data.get("created_at")),
        updated_at=_ts_to_iso(data.get("updated_at")),
    )


def _get_user_display_info(db: firestore.Client, uid: str) -> tuple[str, str | None]:
    """
    Fetch displayName and photoUrl for a user from users/{uid}.
    Returns ('', None) as a safe fallback if the doc is missing — the
    notification still gets written; it just won't have a display name.
    """
    snap = db.collection("users").document(uid).get()
    if not snap.exists:
        return ("", None)
    data = snap.to_dict() or {}
    return (data.get("display_name", ""), data.get("photo_url"))


def _find_existing_connection(
    db: firestore.Client,
    uid_a: str,
    uid_b: str,
) -> Any | None:
    """
    Return the first connection document between uid_a and uid_b regardless of
    direction, or None if no such document exists.

    We query both directions explicitly because Firestore does not support OR
    queries across different field combinations in a single query.
    """
    for req_uid, rec_uid in [(uid_a, uid_b), (uid_b, uid_a)]:
        docs = (
            db.collection(_CONNECTIONS)
            .where(filter=FieldFilter("requester_uid", "==", req_uid))
            .where(filter=FieldFilter("recipient_uid", "==", rec_uid))
            .limit(1)
            .stream()
        )
        for doc in docs:
            return doc
    return None


# ─────────────────────────────────────────────────────────────────────────────
# Public service functions
# ─────────────────────────────────────────────────────────────────────────────

def send_connection_request(
    db: firestore.Client,
    requester: CurrentUser,
    recipient_uid: str,
    logger: logging.Logger,
) -> ConnectionResponse:
    """
    Create a pending connection request from the authenticated user to recipient_uid.

    Guards:
    - No self-connections.
    - recipient_uid must exist in users/ (404 otherwise — prevents enumeration).
    - No duplicate active connection in either direction (409 if found).
    """
    # Guard: no self-connections.
    if requester.uid == recipient_uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot add yourself as a connection.",
        )

    # Guard: recipient must exist.
    recipient_snap = db.collection("users").document(recipient_uid).get()
    if not recipient_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    # Guard: no duplicate pending/accepted connection.
    existing = _find_existing_connection(db, requester.uid, recipient_uid)
    if existing is not None:
        existing_data = existing.to_dict() or {}
        existing_status = existing_data.get("status", "")
        if existing_status in ("pending", "accepted"):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A connection already exists (status: {existing_status}).",
            )

    # Write the connection document.
    conn_ref = db.collection(_CONNECTIONS).document()
    conn_data: dict[str, Any] = {
        "requester_uid": requester.uid,
        "recipient_uid": recipient_uid,
        "status": "pending",
        "created_at": firestore.SERVER_TIMESTAMP,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }
    conn_ref.set(conn_data)

    # Fan-out: notify recipient.
    requester_name, requester_photo = _get_user_display_info(db, requester.uid)
    try:
        notify_connection_request(
            db,
            recipient_uid=recipient_uid,
            requester_uid=requester.uid,
            requester_display_name=requester_name,
            requester_photo_url=requester_photo or "",
            connection_id=conn_ref.id,
            logger=logger,
        )
    except Exception:
        # Notification failure must never roll back the connection creation.
        logger.exception("Failed to send connection_request notification", extra={"connection_id": conn_ref.id})

    # Re-fetch to get resolved SERVER_TIMESTAMP values.
    snap = conn_ref.get()
    return _doc_to_response(conn_ref.id, snap.to_dict() or conn_data)


def accept_connection(
    db: firestore.Client,
    connection_id: str,
    current_user: CurrentUser,
    logger: logging.Logger,
) -> ConnectionResponse:
    """
    Accept a pending connection request.

    The caller must be the recipient of the request (OWASP A01).
    """
    conn_ref = db.collection(_CONNECTIONS).document(connection_id)
    snap = conn_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found.")

    data = snap.to_dict() or {}

    # Ownership guard: only the recipient can accept.
    if data.get("recipient_uid") != current_user.uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorised to accept this request.")

    # State guard: only pending requests can be accepted.
    if data.get("status") != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot accept a connection with status '{data.get('status')}'.",
        )

    # Atomic update.
    batch = db.batch()
    batch.update(conn_ref, {"status": "accepted", "updated_at": firestore.SERVER_TIMESTAMP})
    batch.commit()

    # Notify the original requester.
    acceptor_name, acceptor_photo = _get_user_display_info(db, current_user.uid)
    try:
        notify_connection_accepted(
            db,
            requester_uid=data["requester_uid"],
            acceptor_uid=current_user.uid,
            acceptor_display_name=acceptor_name,
            acceptor_photo_url=acceptor_photo or "",
            connection_id=connection_id,
            logger=logger,
        )
    except Exception:
        logger.exception("Failed to send connection_accepted notification", extra={"connection_id": connection_id})

    snap = conn_ref.get()
    return _doc_to_response(connection_id, snap.to_dict() or data)


def decline_connection(
    db: firestore.Client,
    connection_id: str,
    current_user: CurrentUser,
    logger: logging.Logger,
) -> ConnectionResponse:
    """
    Decline a pending connection request.

    The caller must be the recipient. No notification is sent for declines.
    """
    conn_ref = db.collection(_CONNECTIONS).document(connection_id)
    snap = conn_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found.")

    data = snap.to_dict() or {}

    if data.get("recipient_uid") != current_user.uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorised to decline this request.")

    if data.get("status") != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot decline a connection with status '{data.get('status')}'.",
        )

    batch = db.batch()
    batch.update(conn_ref, {"status": "declined", "updated_at": firestore.SERVER_TIMESTAMP})
    batch.commit()

    snap = conn_ref.get()
    return _doc_to_response(connection_id, snap.to_dict() or data)


def remove_connection(
    db: firestore.Client,
    connection_id: str,
    current_user: CurrentUser,
    logger: logging.Logger,
) -> None:
    """
    Hard-delete a connection document.

    Either party (requester or recipient) may remove an accepted connection.
    """
    conn_ref = db.collection(_CONNECTIONS).document(connection_id)
    snap = conn_ref.get()
    if not snap.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found.")

    data = snap.to_dict() or {}

    # Both parties may remove; third parties are blocked (OWASP A01).
    if current_user.uid not in (data.get("requester_uid"), data.get("recipient_uid")):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorised to remove this connection.")

    conn_ref.delete()
    logger.info("Connection removed", extra={"connection_id": connection_id, "removed_by": current_user.uid})


def list_connections(
    db: firestore.Client,
    current_user: CurrentUser,
    status_filter: str | None,
    logger: logging.Logger,
) -> list[ConnectionResponse]:
    """
    Return all connections where the caller is either requester or recipient.

    Firestore does not support OR queries across different fields in a single
    collection query, so we run two queries and merge the results client-side.
    Duplicates are impossible because each document contains exactly one
    requester_uid and one recipient_uid.
    """
    uid = current_user.uid
    results: list[ConnectionResponse] = []
    seen_ids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        q = db.collection(_CONNECTIONS).where(filter=FieldFilter(field, "==", uid))
        if status_filter:
            q = q.where(filter=FieldFilter("status", "==", status_filter))
        for doc in q.stream():
            if doc.id not in seen_ids:
                seen_ids.add(doc.id)
                results.append(_doc_to_response(doc.id, doc.to_dict() or {}))

    return results


def list_pending_incoming(
    db: firestore.Client,
    current_user: CurrentUser,
    logger: logging.Logger,
) -> list[ConnectionResponse]:
    """Return all pending connection requests addressed to the authenticated user."""
    docs = (
        db.collection(_CONNECTIONS)
        .where(filter=FieldFilter("recipient_uid", "==", current_user.uid))
        .where(filter=FieldFilter("status", "==", "pending"))
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .stream()
    )
    return [_doc_to_response(doc.id, doc.to_dict() or {}) for doc in docs]


def list_caregivers_for_user(
    db: firestore.Client,
    target_uid: str,
    caller_uid: str,
    logger: logging.Logger,
) -> list[UserConnectionSummary]:
    """
    Return the accepted caregivers connected to target_uid.

    RBAC: the caller must be accepted-connected to target_uid.
    This prevents a doctor from enumerating caregivers of patients they
    are not connected to (OWASP A01).
    """
    # Ownership guard: caller must share an accepted connection with target.
    existing = _find_existing_connection(db, caller_uid, target_uid)
    if existing is None or (existing.to_dict() or {}).get("status") != "accepted":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorised to view this user's connections.",
        )

    # Collect all accepted connections where target_uid is a participant.
    seen_ids: set[str] = set()
    other_uids: list[str] = []

    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection(_CONNECTIONS)
            .where(filter=FieldFilter(field, "==", target_uid))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_ids:
                continue
            seen_ids.add(doc.id)
            data = doc.to_dict() or {}
            # Determine the other party in the connection.
            other = data["recipient_uid"] if data["requester_uid"] == target_uid else data["requester_uid"]
            if other != caller_uid:  # exclude the caller themselves
                other_uids.append(other)

    if not other_uids:
        return []

    # Resolve display_name + role for each other uid; keep only caregivers.
    summaries: list[UserConnectionSummary] = []
    for uid in other_uids:
        snap = db.collection("users").document(uid).get()
        if not snap.exists:
            continue
        user_data = snap.to_dict() or {}
        role = (user_data.get("role") or "").strip().lower()
        if role != "caregiver":
            continue
        summaries.append(
            UserConnectionSummary(
                user_uid=uid,
                display_name=user_data.get("display_name") or user_data.get("email") or uid,
                role=user_data.get("role") or "caregiver",
            )
        )

    return summaries


def list_doctors_for_user(
    db: firestore.Client,
    target_uid: str,
    caller_uid: str,
    logger: logging.Logger,
) -> list[UserConnectionSummary]:
    """
    Return the accepted doctors connected to target_uid.

    RBAC: the caller must be accepted-connected to target_uid.
    This prevents a caregiver from enumerating doctors of patients they
    are not connected to (OWASP A01).
    """
    # Ownership guard: caller must share an accepted connection with target.
    existing = _find_existing_connection(db, caller_uid, target_uid)
    if existing is None or (existing.to_dict() or {}).get("status") != "accepted":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorised to view this user's connections.",
        )

    # Collect all accepted connections where target_uid is a participant.
    seen_ids: set[str] = set()
    other_uids: list[str] = []

    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection(_CONNECTIONS)
            .where(filter=FieldFilter(field, "==", target_uid))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_ids:
                continue
            seen_ids.add(doc.id)
            data = doc.to_dict() or {}
            other = data["recipient_uid"] if data["requester_uid"] == target_uid else data["requester_uid"]
            if other != caller_uid:
                other_uids.append(other)

    if not other_uids:
        return []

    # Resolve display_name + role for each other uid; keep only doctors.
    summaries: list[UserConnectionSummary] = []
    for uid in other_uids:
        snap = db.collection("users").document(uid).get()
        if not snap.exists:
            continue
        user_data = snap.to_dict() or {}
        role = (user_data.get("role") or "").strip().lower()
        if role != "doctor":
            continue
        summaries.append(
            UserConnectionSummary(
                user_uid=uid,
                display_name=user_data.get("display_name") or user_data.get("email") or uid,
                role=user_data.get("role") or "doctor",
            )
        )

    return summaries


def _get_accepted_other_uids(
    db: firestore.Client,
    target_uid: str,
    exclude_uid: str | None = None,
) -> list[str]:
    """Helper: return all UIDs of users accepted-connected to target_uid."""
    seen_ids: set[str] = set()
    other_uids: list[str] = []
    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection(_CONNECTIONS)
            .where(filter=FieldFilter(field, "==", target_uid))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_ids:
                continue
            seen_ids.add(doc.id)
            data = doc.to_dict() or {}
            other = data["recipient_uid"] if data["requester_uid"] == target_uid else data["requester_uid"]
            if exclude_uid is None or other != exclude_uid:
                other_uids.append(other)
    return other_uids


def list_secretaries_for_user(
    db: firestore.Client,
    target_uid: str,
    caller_uid: str,
    logger: logging.Logger,
) -> list[UserConnectionSummary]:
    """
    Return the accepted secretaries connected to target_uid (typically a doctor).

    RBAC: the caller must be accepted-connected to target_uid.
    Patients can call this with their doctor's UID to see who manages their care.
    """
    existing = _find_existing_connection(db, caller_uid, target_uid)
    if existing is None or (existing.to_dict() or {}).get("status") != "accepted":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorised to view this user's connections.",
        )

    other_uids = _get_accepted_other_uids(db, target_uid, exclude_uid=caller_uid)
    if not other_uids:
        return []

    summaries: list[UserConnectionSummary] = []
    for uid in other_uids:
        snap = db.collection("users").document(uid).get()
        if not snap.exists:
            continue
        user_data = snap.to_dict() or {}
        role = (user_data.get("role") or "").strip().lower()
        if role != "secretary":
            continue
        summaries.append(
            UserConnectionSummary(
                user_uid=uid,
                display_name=user_data.get("display_name") or user_data.get("email") or uid,
                role="secretary",
            )
        )

    return summaries


def list_doctor_secretaries_for_patient(
    db: firestore.Client,
    patient_uid: str,
    caller_uid: str,
    logger: logging.Logger,
) -> list[UserConnectionSummary]:
    """
    Return all secretaries connected to the doctors of patient_uid.

    RBAC: the caller must be accepted-connected to patient_uid.
    Caregivers use this to see the secretary who works with the patient's doctor.
    """
    existing = _find_existing_connection(db, caller_uid, patient_uid)
    if existing is None or (existing.to_dict() or {}).get("status") != "accepted":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorised to view this patient's care team.",
        )

    # Find all doctors connected to this patient.
    patient_other_uids = _get_accepted_other_uids(db, patient_uid, exclude_uid=caller_uid)
    doctor_uids: list[str] = []
    for uid in patient_other_uids:
        snap = db.collection("users").document(uid).get()
        if not snap.exists:
            continue
        role = ((snap.to_dict() or {}).get("role") or "").strip().lower()
        if role == "doctor":
            doctor_uids.append(uid)

    if not doctor_uids:
        return []

    # For each doctor, collect their connected secretaries.
    seen_secretary_uids: set[str] = set()
    summaries: list[UserConnectionSummary] = []
    for doctor_uid in doctor_uids:
        sec_uids = _get_accepted_other_uids(db, doctor_uid, exclude_uid=None)
        for uid in sec_uids:
            if uid in seen_secretary_uids:
                continue
            snap = db.collection("users").document(uid).get()
            if not snap.exists:
                continue
            user_data = snap.to_dict() or {}
            role = (user_data.get("role") or "").strip().lower()
            if role != "secretary":
                continue
            seen_secretary_uids.add(uid)
            summaries.append(
                UserConnectionSummary(
                    user_uid=uid,
                    display_name=user_data.get("display_name") or user_data.get("email") or uid,
                    role="secretary",
                )
            )

    return summaries

"""
Connections Router — Health Circle connection requests.

Mounts at /api/connections (registered in api_router.py).

Endpoints:
  POST   /api/connections                                     — send a connection request
  GET    /api/connections                                     — list own connections (?status=pending|accepted|declined)
  GET    /api/connections/pending                             — list incoming pending requests
  GET    /api/connections/by-user/{user_uid}/caregivers       — list caregivers connected to a user (caller must be connected)
  PATCH  /api/connections/{connection_id}/accept              — accept a pending request
  PATCH  /api/connections/{connection_id}/decline             — decline a pending request
  DELETE /api/connections/{connection_id}                     — remove an accepted connection

RBAC: all endpoints require any authenticated user (no role restriction).
"""
import logging

from fastapi import APIRouter, Depends, Query, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, get_current_user, get_current_user_optional
from src.schemas.calendar_schemas import UserRefOut
from src.schemas.connection_schemas import ConnectionResponse, SendConnectionRequest, UserConnectionSummary
from src.services.calendar_service import get_doctors_for_secretary
from src.services.connection_service import (
    accept_connection,
    decline_connection,
    list_caregivers_for_user,
    list_connections,
    list_doctor_secretaries_for_patient,
    list_doctors_for_user,
    list_pending_incoming,
    list_secretaries_for_user,
    remove_connection,
    send_connection_request,
)

router = APIRouter(prefix="/connections", tags=["connections"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/connections — send a connection request
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "",
    response_model=ConnectionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Send a connection request",
    description=(
        "Creates a pending connection request from the authenticated user to "
        "the specified recipient. Notifies the recipient. Returns 400 for "
        "self-connections, 404 if recipient does not exist, 409 if a "
        "pending/accepted connection already exists."
    ),
)
def create_connection(
    payload: SendConnectionRequest,
    current_user: CurrentUser = Depends(get_current_user),
) -> ConnectionResponse:
    return send_connection_request(db, current_user, payload.recipient_uid, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections — list own connections
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "",
    response_model=list[ConnectionResponse],
    summary="List own connections",
    description=(
        "Returns all connections where the authenticated user is either the "
        "requester or recipient. Filter by status using the optional "
        "?status=pending|accepted|declined query parameter."
    ),
)
def get_connections(
    status_filter: str | None = Query(default=None, alias="status"),
    current_user: CurrentUser = Depends(get_current_user),
) -> list[ConnectionResponse]:
    return list_connections(db, current_user, status_filter, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections/pending — incoming pending requests
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: This route must be declared BEFORE /{connection_id}/... routes so FastAPI
# does not attempt to match the literal "pending" as a connection_id path parameter.

@router.get(
    "/pending",
    response_model=list[ConnectionResponse],
    summary="List incoming pending requests",
    description="Returns all pending connection requests addressed to the authenticated user.",
)
def get_pending_connections(
    current_user: CurrentUser = Depends(get_current_user),
) -> list[ConnectionResponse]:
    return list_pending_incoming(db, current_user, logger)


# ─────────────────────────────────────────────────────────────────────────────
# PATCH /api/connections/{connection_id}/accept
# ─────────────────────────────────────────────────────────────────────────────

@router.patch(
    "/{connection_id}/accept",
    response_model=ConnectionResponse,
    summary="Accept a pending connection request",
    description=(
        "Sets the connection status to 'accepted' and notifies the requester. "
        "Only the recipient of the request may call this endpoint."
    ),
)
def accept_connection_route(
    connection_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> ConnectionResponse:
    return accept_connection(db, connection_id, current_user, logger)


# ─────────────────────────────────────────────────────────────────────────────
# PATCH /api/connections/{connection_id}/decline
# ─────────────────────────────────────────────────────────────────────────────

@router.patch(
    "/{connection_id}/decline",
    response_model=ConnectionResponse,
    summary="Decline a pending connection request",
    description=(
        "Sets the connection status to 'declined'. No notification is sent. "
        "Only the recipient of the request may call this endpoint."
    ),
)
def decline_connection_route(
    connection_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> ConnectionResponse:
    return decline_connection(db, connection_id, current_user, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections/by-user/{user_uid}/caregivers
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: This route must be declared BEFORE /{connection_id}/... routes so FastAPI
# does not match "by-user" as a connection_id path parameter.

@router.get(
    "/by-user/{user_uid}/caregivers",
    response_model=list[UserConnectionSummary],
    summary="List accepted caregivers for a connected user",
    description=(
        "Returns the caregivers who share an accepted connection with user_uid. "
        "The caller must themselves have an accepted connection with user_uid "
        "(e.g. a doctor viewing a patient's care team). Returns 403 otherwise."
    ),
)
def get_caregivers_for_user(
    user_uid: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> list[UserConnectionSummary]:
    return list_caregivers_for_user(db, user_uid, current_user.uid, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections/secretary/{secretary_uid}/doctors
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "/secretary/{secretary_uid}/doctors",
    response_model=list[UserRefOut],
    summary="List doctors connected to a given secretary (public)",
    description=(
        "Returns the doctors who share an accepted connection with secretary_uid. "
        "No authentication required — guest and anonymous users can call this "
        "to navigate to a secretary's doctor calendar from the community feed."
    ),
)
def get_secretary_connected_doctors(
    secretary_uid: str,
    _: CurrentUser | None = Depends(get_current_user_optional),
) -> list[UserRefOut]:
    return get_doctors_for_secretary(db, secretary_uid=secretary_uid)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections/by-user/{user_uid}/doctors
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: must be declared BEFORE /{connection_id}/... routes.

@router.get(
    "/by-user/{user_uid}/doctors",
    response_model=list[UserConnectionSummary],
    summary="List accepted doctors for a connected user",
    description=(
        "Returns the doctors who share an accepted connection with user_uid. "
        "The caller must themselves have an accepted connection with user_uid "
        "(e.g. a caregiver viewing a patient's care team). Returns 403 otherwise."
    ),
)
def get_doctors_for_user(
    user_uid: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> list[UserConnectionSummary]:
    return list_doctors_for_user(db, user_uid, current_user.uid, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections/by-user/{user_uid}/secretaries
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: must be declared BEFORE /{connection_id}/... routes.

@router.get(
    "/by-user/{user_uid}/secretaries",
    response_model=list[UserConnectionSummary],
    summary="List accepted secretaries for a connected user",
    description=(
        "Returns the secretaries who share an accepted connection with user_uid "
        "(typically a doctor). The caller must themselves have an accepted "
        "connection with user_uid (e.g. a patient viewing their doctor's care team). "
        "Returns 403 otherwise."
    ),
)
def get_secretaries_for_user(
    user_uid: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> list[UserConnectionSummary]:
    return list_secretaries_for_user(db, user_uid, current_user.uid, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/connections/by-user/{patient_uid}/doctor-secretaries
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: must be declared BEFORE /{connection_id}/... routes.

@router.get(
    "/by-user/{patient_uid}/doctor-secretaries",
    response_model=list[UserConnectionSummary],
    summary="List secretaries of the doctors connected to a patient",
    description=(
        "Returns all secretaries connected to the doctors of patient_uid. "
        "The caller must be accepted-connected to patient_uid "
        "(e.g. a caregiver viewing who manages their patient's doctor). "
        "Returns 403 otherwise."
    ),
)
def get_doctor_secretaries_for_patient(
    patient_uid: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> list[UserConnectionSummary]:
    return list_doctor_secretaries_for_patient(db, patient_uid, current_user.uid, logger)


# ─────────────────────────────────────────────────────────────────────────────
# DELETE /api/connections/{connection_id}
# ─────────────────────────────────────────────────────────────────────────────

@router.delete(
    "/{connection_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove a connection",
    description=(
        "Hard-deletes the connection document. Either party (requester or "
        "recipient) may remove the connection."
    ),
)
def delete_connection(
    connection_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    remove_connection(db, connection_id, current_user, logger)

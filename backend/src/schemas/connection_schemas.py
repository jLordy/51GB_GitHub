from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

# The three valid states for a connection document.
ConnectionStatus = Literal["pending", "accepted", "declined"]


class SendConnectionRequest(BaseModel):
    recipient_uid: str = Field(..., min_length=1, description="Firebase UID of the user to connect with.")


class RespondConnectionRequest(BaseModel):
    action: Literal["accept", "decline"]


class ConnectionResponse(BaseModel):
    connection_id: str
    requester_uid: str
    recipient_uid: str
    status: ConnectionStatus
    created_at: str
    updated_at: str


class UserConnectionSummary(BaseModel):
    """Slim representation of one side of an accepted connection, with user info resolved."""
    user_uid: str
    display_name: str
    role: str

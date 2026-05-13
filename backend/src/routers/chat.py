"""
Chat Router — Direct messaging between users.

Mounts at /api/chat (registered in api_router.py).

Endpoints:
  POST   /api/chat/conversations                                      — get or create a 1-to-1 conversation
  GET    /api/chat/conversations                                      — list conversations for the current user
  DELETE /api/chat/conversations/{conversation_id}                    — delete a conversation
  GET    /api/chat/conversations/{conversation_id}/messages           — list messages (paginated)
  POST   /api/chat/conversations/{conversation_id}/messages           — send a message
  DELETE /api/chat/conversations/{conversation_id}/messages/{msg_id}  — delete own message
  PATCH  /api/chat/conversations/{conversation_id}/read               — mark conversation as read
  GET    /api/chat/key                                                — return the shared encryption key

Real-time delivery is handled client-side via the Firestore SDK (no WebSocket needed).
"""
import logging
import os

from fastapi import APIRouter, Depends, Query, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, get_current_user
from src.schemas.chat_schemas import (
    ConversationOut,
    CreateConversationRequest,
    MessageOut,
    SendMessageRequest,
)
from src.services.chat_service import (
    delete_conversation,
    delete_message,
    get_or_create_conversation,
    list_conversations,
    list_messages,
    mark_conversation_read,
    send_message,
)

router = APIRouter(prefix="/chat", tags=["chat"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/chat/conversations — get or create a 1-to-1 conversation
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/conversations",
    response_model=ConversationOut,
    status_code=status.HTTP_200_OK,
    summary="Get or create a direct conversation",
    description=(
        "Returns an existing direct conversation between the authenticated user "
        "and *other_uid*, or creates one if none exists. "
        "Returns 400 if the user tries to message themselves, "
        "404 if *other_uid* does not exist."
    ),
)
def create_conversation(
    payload: CreateConversationRequest,
    current_user: CurrentUser = Depends(get_current_user),
) -> ConversationOut:
    return get_or_create_conversation(current_user.uid, payload.other_uid, db, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/chat/conversations — list conversations
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "/conversations",
    response_model=list[ConversationOut],
    summary="List conversations",
    description="Returns all direct conversations for the authenticated user, ordered by most recent activity.",
)
def get_conversations(
    current_user: CurrentUser = Depends(get_current_user),
) -> list[ConversationOut]:
    return list_conversations(current_user.uid, db, logger)


# ─────────────────────────────────────────────────────────────────────────────
# DELETE /api/chat/conversations/{conversation_id} — delete a conversation
# ─────────────────────────────────────────────────────────────────────────────

@router.delete(
    "/conversations/{conversation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a conversation",
    description=(
        "Permanently deletes a conversation. "
        "Only participants may delete it. "
        "Returns 403 if the caller is not a participant, "
        "404 if the conversation is not found."
    ),
)
def remove_conversation(
    conversation_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    delete_conversation(conversation_id, current_user.uid, db, logger)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/chat/conversations/{conversation_id}/messages — fetch messages
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "/conversations/{conversation_id}/messages",
    response_model=list[MessageOut],
    summary="List messages in a conversation",
    description=(
        "Returns messages for the conversation in chronological order (oldest first). "
        "Paginates via *limit* (max 100) and *before* (ISO timestamp cursor for the next page)."
    ),
)
def get_messages(
    conversation_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    before: str | None = Query(default=None, description="ISO timestamp cursor — fetch messages older than this"),
    current_user: CurrentUser = Depends(get_current_user),
) -> list[MessageOut]:
    return list_messages(conversation_id, current_user.uid, db, logger, limit=limit, before=before)


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/chat/conversations/{conversation_id}/messages — send a message
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/conversations/{conversation_id}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
    summary="Send a message",
    description=(
        "Appends a message to the conversation and updates the unread counter "
        "for all other participants. "
        "Returns 400 if neither text nor media is provided, "
        "403 if the caller is not a participant, 404 if the conversation does not exist."
    ),
)
def create_message(
    conversation_id: str,
    payload: SendMessageRequest,
    current_user: CurrentUser = Depends(get_current_user),
) -> MessageOut:
    return send_message(
        conversation_id,
        current_user.uid,
        payload.text,
        payload.type,
        payload.media_url,
        db,
        logger,
    )


# ─────────────────────────────────────────────────────────────────────────────
# DELETE /api/chat/conversations/{conversation_id}/messages/{message_id}
# ─────────────────────────────────────────────────────────────────────────────

@router.delete(
    "/conversations/{conversation_id}/messages/{message_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a message",
    description=(
        "Permanently deletes a single message. "
        "Only the original sender may delete their own message. "
        "Returns 403 if the caller is not the sender or not a participant, "
        "404 if the conversation or message is not found."
    ),
)
def remove_message(
    conversation_id: str,
    message_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    delete_message(conversation_id, message_id, current_user.uid, db, logger)


# ─────────────────────────────────────────────────────────────────────────────
# PATCH /api/chat/conversations/{conversation_id}/read — mark as read
# ─────────────────────────────────────────────────────────────────────────────

@router.patch(
    "/conversations/{conversation_id}/read",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Mark conversation as read",
    description="Resets the unread message counter for the authenticated user in this conversation.",
)
def read_conversation(
    conversation_id: str,
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    mark_conversation_read(conversation_id, current_user.uid, db, logger)

# ─────────────────────────────────────────────────────────────────────────────
# GET /api/chat/key — return shared encryption key to authenticated clients
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "/key",
    summary="Get chat encryption key",
    description=(
        "Returns the base64-encoded AES-256 key used to encrypt and decrypt chat messages. "
        "Only accessible by authenticated users."
    ),
)
def get_encryption_key(
    current_user: CurrentUser = Depends(get_current_user),
) -> dict:
    key = os.environ.get("CHAT_ENCRYPTION_KEY", "")
    if not key:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Encryption key not configured on server",
        )
    return {"encryption_key": key}
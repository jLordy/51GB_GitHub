from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from src.schemas.chat_schemas import ConversationOut, MessageOut, MessageType
from src.core.encryption import encrypt_text, try_decrypt

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def _to_iso(value: object) -> str | None:
    """Convert a Firestore timestamp, datetime, or ISO string to an ISO string."""
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if hasattr(value, "isoformat"):
        if getattr(value, "tzinfo", None) is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.isoformat()
    return str(value)


def _fetch_profile(db: firestore.Client, uid: str) -> dict:
    snap = db.collection("users").document(uid).get()
    return snap.to_dict() or {}


def _build_conversation_out(doc: firestore.DocumentSnapshot, viewer_uid: str) -> ConversationOut:
    data = doc.to_dict() or {}
    unread_counts: dict = data.get("unread_counts", {})
    raw_last: str | None = data.get("last_message")
    decrypted_last = try_decrypt(raw_last) if raw_last else None
    return ConversationOut(
        conversation_id=doc.id,
        participants=data.get("participants", []),
        participant_names=data.get("participant_names", {}),
        participant_photos=data.get("participant_photos", {}),
        last_message=decrypted_last,
        last_message_type=data.get("last_message_type"),
        last_sender_id=data.get("last_sender_id"),
        last_message_at=_to_iso(data.get("last_message_at")),
        unread_count=unread_counts.get(viewer_uid, 0),
        created_at=_to_iso(data.get("created_at")) or "",
    )


def _build_message_out(doc: firestore.DocumentSnapshot, conversation_id: str) -> MessageOut:
    data = doc.to_dict() or {}
    raw_text: str | None = data.get("text")
    decrypted_text = try_decrypt(raw_text) if raw_text else None
    return MessageOut(
        message_id=doc.id,
        conversation_id=conversation_id,
        sender_id=data.get("sender_id", ""),
        text=decrypted_text,
        type=data.get("type", MessageType.text),
        media_url=data.get("media_url"),
        created_at=_to_iso(data.get("created_at")) or "",
        read_by=data.get("read_by", []),
    )


# ─────────────────────────────────────────────────────────────────────────────
# Service functions
# ─────────────────────────────────────────────────────────────────────────────

def get_or_create_conversation(
    uid: str,
    other_uid: str,
    db: firestore.Client,
    logger: logging.Logger,
) -> ConversationOut:
    """Return an existing 1-to-1 conversation or create a new one."""
    if uid == other_uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot start a conversation with yourself",
        )

    other_snap = db.collection("users").document(other_uid).get()
    if not other_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Check for an existing conversation between these two users
    existing = (
        db.collection("conversations")
        .where(filter=FieldFilter("participants", "array_contains", uid))
        .stream()
    )

    for doc in existing:
        data = doc.to_dict() or {}
        participants = data.get("participants", [])
        if set(participants) == {uid, other_uid}:
            logger.info("Returning existing conversation %s", doc.id)
            # Patch participant_photos if any are missing (handles legacy docs)
            stored_photos: dict = data.get("participant_photos") or {}
            if any(stored_photos.get(p) is None for p in participants):
                my_profile = _fetch_profile(db, uid)
                other_profile = _fetch_profile(db, other_uid)
                profiles = {uid: my_profile, other_uid: other_profile}

                def _photo_url_patch(profile: dict) -> str | None:
                    return (
                        profile.get("photo_url")
                        or profile.get("profile_photo_url")
                        or profile.get("photoURL")
                    )

                patched = {
                    p: _photo_url_patch(profiles[p])
                    for p in participants
                    if p in profiles
                }
                doc.reference.update({"participant_photos": patched})
                data["participant_photos"] = patched
                doc = doc.reference.get()
            return _build_conversation_out(doc, uid)

    # Create a new conversation
    my_profile = _fetch_profile(db, uid)
    other_profile = _fetch_profile(db, other_uid)

    def _display_name(profile: dict) -> str:
        if profile.get("display_name"):
            return profile["display_name"]
        first = profile.get("first_name") or profile.get("firstName", "")
        last = profile.get("last_name") or profile.get("lastName", "")
        return f"{first} {last}".strip() or profile.get("email", "Unknown")

    def _photo_url(profile: dict) -> str | None:
        return (
            profile.get("photo_url")
            or profile.get("profile_photo_url")
            or profile.get("photoURL")
        )

    now_str = _now_iso()
    conv_ref = db.collection("conversations").document()
    conv_ref.set({
        "participants": [uid, other_uid],
        "participant_names": {
            uid: _display_name(my_profile),
            other_uid: _display_name(other_profile),
        },
        "participant_photos": {
            uid: _photo_url(my_profile),
            other_uid: _photo_url(other_profile),
        },
        "last_message": None,
        "last_message_type": None,
        "last_sender_id": None,
        "last_message_at": None,
        "unread_counts": {uid: 0, other_uid: 0},
        "created_at": now_str,
    })

    logger.info("Created new conversation %s between %s and %s", conv_ref.id, uid, other_uid)
    snap = conv_ref.get()
    return _build_conversation_out(snap, uid)


def list_conversations(
    uid: str,
    db: firestore.Client,
    logger: logging.Logger,
) -> list[ConversationOut]:
    """Return all conversations for the authenticated user, ordered by most recent activity."""
    docs = (
        db.collection("conversations")
        .where(filter=FieldFilter("participants", "array_contains", uid))
        .order_by("last_message_at", direction=firestore.Query.DESCENDING)
        .stream()
    )

    results: list[ConversationOut] = []
    for doc in docs:
        results.append(_build_conversation_out(doc, uid))

    logger.info("Fetched %d conversations for uid=%s", len(results), uid)
    return results


def send_message(
    conversation_id: str,
    sender_id: str,
    text: str | None,
    msg_type: MessageType,
    media_url: str | None,
    db: firestore.Client,
    logger: logging.Logger,
) -> MessageOut:
    """Append a message to the conversation and update the conversation summary."""
    conv_ref = db.collection("conversations").document(conversation_id)
    conv_snap = conv_ref.get()
    if not conv_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    data = conv_snap.to_dict() or {}
    participants: list[str] = data.get("participants", [])
    if sender_id not in participants:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a participant in this conversation",
        )

    if not text and not media_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message must contain text or media",
        )

    now_str = _now_iso()
    encrypted_text = encrypt_text(text) if text else None
    msg_ref = conv_ref.collection("messages").document()
    msg_ref.set({
        "sender_id": sender_id,
        "text": encrypted_text,
        "type": msg_type,
        "media_url": media_url,
        "read_by": [sender_id],
        "created_at": now_str,
    })

    # Update conversation summary — increment unread for every participant except the sender
    unread_increments = {
        f"unread_counts.{uid}": firestore.Increment(1)
        for uid in participants
        if uid != sender_id
    }

    preview_text = encrypt_text(text) if text else f"[{msg_type}]"
    conv_ref.update({
        "last_message": preview_text,
        "last_message_type": msg_type,
        "last_sender_id": sender_id,
        "last_message_at": now_str,
        **unread_increments,
    })

    logger.info("Message %s sent in conversation %s by %s", msg_ref.id, conversation_id, sender_id)
    snap = msg_ref.get()
    return _build_message_out(snap, conversation_id)


def list_messages(
    conversation_id: str,
    uid: str,
    db: firestore.Client,
    logger: logging.Logger,
    limit: int = 50,
    before: str | None = None,
) -> list[MessageOut]:
    """Return messages for a conversation in chronological order (oldest first)."""
    conv_ref = db.collection("conversations").document(conversation_id)
    conv_snap = conv_ref.get()
    if not conv_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    data = conv_snap.to_dict() or {}
    if uid not in data.get("participants", []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a participant in this conversation",
        )

    query = (
        conv_ref.collection("messages")
        .order_by("created_at", direction=firestore.Query.DESCENDING)  # type: ignore[attr-defined]
        .limit(limit)
    )

    if before:
        query = query.start_after({"created_at": before})

    docs = list(query.stream())
    # Reverse so the oldest of this page is first (chronological display)
    docs.reverse()

    results = [_build_message_out(doc, conversation_id) for doc in docs]
    logger.info(
        "Fetched %d messages in conversation %s for uid=%s", len(results), conversation_id, uid
    )
    return results


def mark_conversation_read(
    conversation_id: str,
    uid: str,
    db: firestore.Client,
    logger: logging.Logger,
) -> None:
    """Reset the unread count for *uid* in the given conversation."""
    conv_ref = db.collection("conversations").document(conversation_id)
    conv_snap = conv_ref.get()
    if not conv_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    data = conv_snap.to_dict() or {}
    if uid not in data.get("participants", []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a participant in this conversation",
        )

    conv_ref.update({f"unread_counts.{uid}": 0})


def delete_message(
    conversation_id: str,
    message_id: str,
    uid: str,
    db: firestore.Client,
    logger: logging.Logger,
) -> None:
    """Delete a message. Only the original sender may delete it."""
    conv_ref = db.collection("conversations").document(conversation_id)
    conv_snap = conv_ref.get()
    if not conv_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    data = conv_snap.to_dict() or {}
    if uid not in data.get("participants", []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a participant in this conversation",
        )

    msg_ref = conv_ref.collection("messages").document(message_id)
    msg_snap = msg_ref.get()
    if not msg_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    msg_data = msg_snap.to_dict() or {}
    if msg_data.get("sender_id") != uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own messages",
        )

    msg_ref.delete()
    logger.info("Message %s deleted from conversation %s by %s", message_id, conversation_id, uid)


def delete_conversation(
    conversation_id: str,
    uid: str,
    db: firestore.Client,
    logger: logging.Logger,
) -> None:
    """Delete a conversation for the requesting participant.

    Removes the conversation document. Only participants may delete it.
    """
    conv_ref = db.collection("conversations").document(conversation_id)
    conv_snap = conv_ref.get()
    if not conv_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    data = conv_snap.to_dict() or {}
    if uid not in data.get("participants", []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a participant in this conversation",
        )

    conv_ref.delete()
    logger.info("Conversation %s deleted by %s", conversation_id, uid)

    # Add uid to read_by for all messages not sent by this user (batch write)
    msg_docs = (
        conv_ref.collection("messages")
        .where(filter=FieldFilter("sender_id", "!=", uid))
        .stream()
    )

    batch = db.batch()
    count = 0
    for msg_doc in msg_docs:
        batch.update(msg_doc.reference, {"read_by": firestore.ArrayUnion([uid])})
        count += 1
        if count == 500:  # Firestore batch limit
            batch.commit()
            batch = db.batch()
            count = 0

    if count > 0:
        batch.commit()

    logger.info(
        "Marked conversation %s as read for uid=%s (%d messages updated)",
        conversation_id, uid, count,
    )

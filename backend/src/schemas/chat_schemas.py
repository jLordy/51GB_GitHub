from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field


class MessageType(str, Enum):
    text = "text"
    image = "image"
    video = "video"
    missed_call = "missed_call"


class CreateConversationRequest(BaseModel):
    other_uid: str = Field(min_length=1, max_length=128)


class SendMessageRequest(BaseModel):
    text: str | None = Field(default=None, max_length=10_000)
    type: MessageType = MessageType.text
    media_url: str | None = None


class MarkMessagesReadRequest(BaseModel):
    pass  # body can be empty — the conversation_id comes from the path


class MessageOut(BaseModel):
    message_id: str
    conversation_id: str
    sender_id: str
    text: str | None
    type: str
    media_url: str | None
    created_at: str
    read_by: list[str]


class ConversationOut(BaseModel):
    conversation_id: str
    participants: list[str]
    participant_names: dict[str, str]
    participant_photos: dict[str, str | None]
    last_message: str | None
    last_message_type: str | None
    last_sender_id: str | None
    last_message_at: str | None
    unread_count: int
    created_at: str

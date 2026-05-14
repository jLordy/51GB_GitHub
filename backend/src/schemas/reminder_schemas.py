"""
Reminder Schemas — Medication Reminders feature.

Firestore collection: medication_reminders/{reminder_id}

Endpoints served:
  GET    /api/reminders                — patient: list own reminders
  POST   /api/reminders                — patient: create a reminder
  PUT    /api/reminders/{id}           — patient: full replace
  DELETE /api/reminders/{id}           — patient: delete
  PATCH  /api/reminders/{id}/status    — patient or caregiver: update status only
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


FrequencyLiteral = Literal["daily", "twice_daily", "weekly", "as_needed"]
StatusLiteral = Literal["upcoming", "taken", "missed"]


class ReminderCreate(BaseModel):
    """
    Body for POST /api/reminders.

    `id` is generated client-side (millisecond epoch string) and used as the
    Firestore document ID so the Flutter local cache and the server stay in sync.
    """

    id: str = Field(..., description="Client-generated document ID.")
    med_name: str
    dosage: str
    scheduled_time: datetime = Field(
        ..., description="ISO-8601 UTC timestamp of the next scheduled dose."
    )
    frequency: FrequencyLiteral = "daily"
    is_alarm_enabled: bool = True
    caregiver_id: str | None = None
    status: StatusLiteral = "upcoming"


class ReminderUpdate(BaseModel):
    """Body for PUT /api/reminders/{id} — full replacement of mutable fields."""

    med_name: str
    dosage: str
    scheduled_time: datetime
    frequency: FrequencyLiteral
    is_alarm_enabled: bool
    caregiver_id: str | None = None
    status: StatusLiteral


class StatusUpdate(BaseModel):
    """Body for PATCH /api/reminders/{id}/status."""

    status: StatusLiteral
    caregiver_id: str | None = None


class ReminderResponse(BaseModel):
    """
    Shape returned to the Flutter client.

    Matches MedicationReminder.fromJson() field names exactly so the
    existing deserialisation layer requires no changes.
    """

    id: str
    user_uid: str
    med_name: str
    dosage: str
    scheduled_time: datetime
    frequency: str
    is_alarm_enabled: bool
    caregiver_id: str | None = None
    status: str
    created_at: datetime
    updated_at: datetime | None = None

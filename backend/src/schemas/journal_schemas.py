"""
Journal Schemas — Phase 2.2 (User-Centric Daily Monitoring).

These models represent the contract between the journal API and the Flutter client.
The journal is fully independent of the doctor-patient relationship: any authenticated
user with role=patient can fetch questions and submit answers.

Firestore collections involved:
  patient_profiles/{user_uid}  — patient-owned health profile (illness_type source)
  questionnaires/daily_*       — shared question bank (seeded by seed_questionnaires.py)
  journal_entries              — auto-ID collection for submitted sessions
"""

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

from src.schemas.questionnaire_schemas import Question  # noqa: F401 — re-exported for JournalQuestionsResponse


# ---------------------------------------------------------------------------
# GET /api/journal/questions — response
# ---------------------------------------------------------------------------

class JournalQuestionsResponse(BaseModel):
    """
    Assembled flat list of daily monitoring questions for the authenticated patient.
    Order: universal questions first, then illness-specific questions.

    The client renders each question in sequence using the `ui_component` discriminator
    (same server-driven UI pattern as the intake questionnaire).
    """
    question_set_type: str = "daily"
    # Resolved from patient_profiles/{uid}.illness_type — never client-supplied.
    illness_type: str
    # Flat ordered list: universal + illness-specific merged.
    questions: list[Question]
    # Semver of the underlying questionnaire seed documents.
    version: str = "1.0.0"
    # ISO timestamp — lets the client know when this payload was built.
    assembled_at: datetime


# ---------------------------------------------------------------------------
# POST /api/journal/entries — request / response
# ---------------------------------------------------------------------------

class JournalEntryCreate(BaseModel):
    """
    Patient-submitted answer payload for a completed journal session.

    `answers` is a free-form dict keyed by question `id` values (snake_case).
    Value types mirror the ui_component:
      slider / number_input → float | int
      radio / select        → str
      chip_selector         → list[str]
      toggle                → bool
      bp_input              → {"systolic": int, "diastolic": int}
      weight_input          → {"value": float, "unit": "kg" | "lb"}
      date_picker           → str  (ISO 8601 "YYYY-MM-DD")
      multi_text_input      → list[str]

    The backend stores answers as-is; downstream ML services parse by question ID.
    """
    question_set_type: Literal["daily"] = "daily"
    # Keys must match question.id values from /api/journal/questions.
    answers: dict[str, Any] = Field(
        ...,
        description="Map of question_id → patient answer. "
                    "Value type depends on the question's ui_component.",
    )


# ---------------------------------------------------------------------------
# PATCH /api/journal/entries/{entry_id} — request
# ---------------------------------------------------------------------------

class JournalEntryUpdate(BaseModel):
    """
    Partial update payload for an existing journal entry.
    Only `answers` can be changed; illness_type and question_set_type are immutable.
    """
    answers: dict[str, Any] = Field(
        ...,
        description="Updated map of question_id → patient answer.",
    )


# ---------------------------------------------------------------------------
# Edit history
# ---------------------------------------------------------------------------

class EditHistoryEntry(BaseModel):
    """
    A single snapshot written to journal_entries/{id}/edit_history/ each time
    the entry's answers are updated via PATCH.
    `previous_answers` holds the answers map as it existed *before* the edit.
    """
    edit_number: int
    edited_at: datetime
    previous_answers: dict[str, Any]
    edited_by_uid: str | None = None
    editor_name: str | None = None


class EditHistoryListResponse(BaseModel):
    """Ordered list of edit snapshots for one journal entry (newest first)."""
    entry_id: str
    history: list[EditHistoryEntry]


class JournalEntryResponse(BaseModel):
    """
    Stored journal entry returned after a successful POST /api/journal/entries.
    `entry_id` is the Firestore auto-generated document ID under journal_entries/.
    """
    entry_id: str
    user_uid: str
    question_set_type: str
    # Resolved server-side from patient_profiles; not trusted from client input.
    illness_type: str
    answers: dict[str, Any]
    submitted_at: datetime
    # Populated only after at least one PATCH; None for brand-new entries.
    updated_at: datetime | None = None
    # Incremented on each PATCH; 0 for entries that have never been edited.
    edit_count: int = 0
    # Audit fields — populated when a caregiver creates/edits on behalf of a patient.
    # None for entries created and edited by the patient themselves.
    created_by_uid: str | None = None
    last_edited_by_uid: str | None = None


class JournalEntriesListResponse(BaseModel):
    """
    Paginated list of the authenticated patient's journal entries.
    Ordered by submitted_at descending (most recent first).
    """
    entries: list[JournalEntryResponse]
    total: int

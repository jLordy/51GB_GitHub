"""
Questionnaire Schemas — Phase 2.1 (Server-Driven UI).

These models define the "schema-as-data" contract between the Firestore
questionnaire documents and the Flutter client. The client has no hardcoded
questions — it receives this payload and renders widgets based on `ui_component`.

TypeScript analogy:
  UIComponent     ≈  string union type ('slider' | 'radio' | ...)
  Question        ≈  interface Question { id: string; uiComponent: UIComponent; ... }
  GateConfig      ≈  interface GateConfig { triggerValue: string; reveals: string[] }
  IntakeQuestionnaire ≈  the full parsed response type from GET /questionnaires/intake

Schema versioning strategy:
  `version` is a semver string stored on each questionnaire document.
  The Flutter client caches by version — a bump invalidates the local cache
  and forces a fresh fetch. Bump on any change that alters question IDs or
  adds new ui_component literals (breaking changes for the renderer).
"""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field

IllnessType = str  # was Literal["ckd","diabetes","oncology"] — now open string

# ---------------------------------------------------------------------------
# UI Component discriminator union
# ---------------------------------------------------------------------------
# Adding a new value here is a breaking contract change — bump schema version.
UIComponent = Literal[
    "date_picker",       # returns ISO date string (YYYY-MM-DD)
    "radio",             # single-select from options list
    "select",            # dropdown single-select (long option lists)
    "multi_text_input",  # dynamic list of freeform string entries (e.g., allergy names)
    "number_input",      # numeric field; respects validation.min/max/step + unit display
    "slider",            # stepped range picker; validation.min/max/step required
    "weight_input",      # compound widget: float value + kg/lb unit toggle
    "bp_input",          # compound widget: systolic (int) / diastolic (int) pair
    "chip_selector",     # multi-select chip grid; returns list[str] of selected values
    "toggle",            # boolean switch (yes/taken/present)
]


# ---------------------------------------------------------------------------
# Sub-models
# ---------------------------------------------------------------------------

class QuestionOption(BaseModel):
    """
    A single selectable option for radio, select, or chip_selector questions.

    `value` is the machine-readable key stored in the patient answer map.
    `label` is the human-readable string rendered by the Flutter widget.
    Keeping them separate allows relabeling without breaking stored answer data.
    """
    value: str
    label: str


class ValidationRule(BaseModel):
    """
    Client-side validation constraints forwarded to the Flutter widget.
    The backend enforces the same bounds independently in VitalSubmission
    (defense-in-depth) — these are UI guardrails, not the security boundary.
    """
    min: Optional[float] = None
    max: Optional[float] = None
    # step controls slider tick granularity and number_input increment buttons.
    step: Optional[float] = None
    # unit is display-only — shown as a suffix/label next to the input widget.
    unit: Optional[str] = None  # e.g., "kg", "mmol/L", "mL", "pack-years", "drinks/week"


class GateConfig(BaseModel):
    """
    Conditional-reveal config attached to a gate question.

    When the patient selects `trigger_value`, the Flutter form engine
    unhides all sibling questions whose `parent_gate_id` matches this
    question's `id`. All other selections keep child questions hidden.

    Express/React analogy: this is the server-side equivalent of
    `{answer === 'yes' && <AllergyDetailFields />}` — the rendering
    condition is now a data contract delivered via the API.
    """
    # The option.value that activates the child questions (typically "yes").
    trigger_value: str
    # question.id values that become visible when trigger_value is selected.
    reveals: list[str]


# ---------------------------------------------------------------------------
# Core Question model
# ---------------------------------------------------------------------------

class Question(BaseModel):
    """
    Atomic questionnaire item. The `ui_component` field is the discriminator
    the Flutter client uses to select the correct widget renderer.

    TypeScript discriminated union equivalent:
      type Question =
        | { uiComponent: 'slider'; validation: ValidationRule }
        | { uiComponent: 'radio';  options: QuestionOption[] }
        | ...

    Gate pattern (two-part):
      - Gate question:  has `gate: GateConfig`, no parent_gate_id
      - Gated children: have `parent_gate_id` + `gate_trigger_value`, no gate
    """
    # Stable snake_case key — used as the answer map key in patient response
    # documents. Never rename after patients have submitted answers.
    id: str = Field(
        ...,
        description="Stable snake_case identifier. Used as the answer dict key.",
    )
    label: str
    ui_component: UIComponent
    is_required: bool = True

    # Supplemental instruction shown below the widget label.
    hint_text: Optional[str] = None

    # Required for: radio, select, chip_selector.
    options: Optional[list[QuestionOption]] = None

    # Required for: number_input, slider, weight_input, bp_input.
    validation: Optional[ValidationRule] = None

    # Present only on GATE questions (the controlling question).
    gate: Optional[GateConfig] = None

    # Present only on GATED CHILD questions (the conditionally visible questions).
    parent_gate_id: Optional[str] = None
    # The specific answer value on the parent question that shows this child.
    gate_trigger_value: Optional[str] = None


# ---------------------------------------------------------------------------
# Intake questionnaire structure
# ---------------------------------------------------------------------------

class QuestionnairePhase(BaseModel):
    """
    A named section of the intake questionnaire rendered as a wizard step.
    Questions within a phase are rendered together; the client navigates
    between phases sequentially (Back / Next).
    """
    # Stable snake_case section identifier (e.g., "demographics", "allergies").
    phase_id: str
    title: str
    # 1-based; used for progress indicators ("Step 2 of 5").
    phase_number: int
    questions: list[Question]


class IntakeQuestionnaire(BaseModel):
    """
    Complete patient intake questionnaire schema.
    Stored as a single Firestore document: questionnaires/intake.

    Fetched once when the clinician opens the intake flow; the Flutter
    client caches by `version` and only re-fetches when it changes.
    """
    questionnaire_id: str = "intake"
    title: str = "Patient Intake Profile"
    # Semver — bump the MINOR on new questions, MAJOR on changed question IDs.
    version: str = Field(
        "1.0.0",
        description="Schema version (semver). Bump on any breaking change to invalidate client cache.",
    )
    phases: list[QuestionnairePhase]


# ---------------------------------------------------------------------------
# Daily monitoring module structure
# ---------------------------------------------------------------------------

class DailyModule(BaseModel):
    """
    A single daily monitoring module (universal or illness-specific).
    Each module is stored as its own Firestore document following the convention:
      questionnaires/daily_universal
      questionnaires/daily_{illness_type}          e.g. daily_diabetes, daily_ckd
      questionnaires/daily_medication_{illness_type}
      questionnaires/daily_food_{illness_type}

    Illness types without a seeded module (e.g. "hypertension", "asthma", "none")
    are silently skipped — the patient receives universal questions only.
    """
    # "universal", "diabetes", "ckd", "oncology" — matches the Firestore doc ID suffix.
    module_id: str
    title: str
    # None for the universal module since it applies to all illness types.
    illness_type: Optional[IllnessType] = None
    questions: list[Question]


class DailyQuestionnaireResponse(BaseModel):
    """
    Assembled daily questionnaire payload for a specific patient.
    The endpoint always returns [universal, illness_specific] — the client
    renders modules sequentially, one section per illness-relevant group.

    This is the response type for GET /api/questionnaires/daily/{patient_id}.
    """
    patient_id: str
    illness_type: IllnessType
    # modules[0] = universal (always), modules[1] = illness-specific.
    modules: list[DailyModule]
    # ISO timestamp — lets the client show "questionnaire last updated" and
    # detect when to re-fetch if the backend seeds a new schema version.
    assembled_at: datetime

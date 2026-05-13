"""
Questionnaire Database Seeding Script — Phase 2.1.

Pushes the clinical questionnaire schema into Firestore.
Uses `.set()` (upsert) — idempotent, safe to re-run after schema updates.

Usage:
    # From the backend/ directory:
    python seed_questionnaire.py

    # Against the Firestore emulator:
    set FIRESTORE_EMULATOR_HOST=localhost:8080
    python seed_questionnaire.py

Environment:
    FIREBASE_CREDENTIALS — JSON string of service account credentials.
    If not set, the script falls back to loading from local.settings.json
    (standard Azure Functions local dev config).

Firestore documents written:
    questionnaires/intake                    — 5-phase intake profile
    questionnaires/daily_universal           — universal daily vitals (all patients)
    questionnaires/daily_hypertension        — hypertension-specific daily monitoring
    questionnaires/daily_diabetes            — diabetes-specific daily monitoring
    questionnaires/daily_heart_disease       — heart disease-specific daily monitoring
    questionnaires/daily_asthma              — asthma-specific daily monitoring
    questionnaires/daily_tuberculosis        — tuberculosis-specific daily monitoring
    questionnaires/daily_cancer              — cancer-specific daily monitoring
    questionnaires/daily_ckd                 — CKD-specific daily monitoring
    questionnaires/daily_stroke              — stroke-specific daily monitoring
    questionnaires/daily_arthritis           — arthritis-specific daily monitoring
    questionnaires/daily_mental_health       — mental health-specific daily monitoring
    + daily_medication_{illness} for each above
    + daily_food_{illness} for each above
"""

import json
import os
import sys

# ---------------------------------------------------------------------------
# Bootstrap: make src.* importable when running from the backend/ directory.
# ---------------------------------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Load credentials from local.settings.json if FIREBASE_CREDENTIALS is not set.
if not os.getenv("FIREBASE_CREDENTIALS"):
    settings_path = os.path.join(os.path.dirname(__file__), "local.settings.json")
    if os.path.exists(settings_path):
        with open(settings_path, encoding="utf-8") as _f:
            _local = json.load(_f)
        _creds = _local.get("Values", {}).get("FIREBASE_CREDENTIALS", "")
        if _creds:
            os.environ["FIREBASE_CREDENTIALS"] = _creds
            print("  [seed] Loaded FIREBASE_CREDENTIALS from local.settings.json")

from src.firebase import get_firestore_client  # noqa: E402
from src.schemas.questionnaire_schemas import (  # noqa: E402
    DailyModule,
    GateConfig,
    IntakeQuestionnaire,
    Question,
    QuestionnairePhase,
    QuestionOption,
    ValidationRule,
)

# ---------------------------------------------------------------------------
# Option helpers
# ---------------------------------------------------------------------------

def _opts(*pairs: tuple[str, str]) -> list[QuestionOption]:
    return [QuestionOption(value=v, label=l) for v, l in pairs]


YES_NO = _opts(("yes", "Oo"), ("no", "Hindi"))
YES_NO_EN = _opts(("yes", "Yes"), ("no", "No"))


# ---------------------------------------------------------------------------
# Shared medication / food module builders
# ---------------------------------------------------------------------------

def _medication_module(
    illness_type: str,
    title: str,
    medication_opts: list[tuple[str, str]],
) -> DailyModule:
    """
    Generic medication adherence module reused across all illness types.
    Only the medication chip options differ per illness.
    """
    return DailyModule(
        module_id=f"medication_{illness_type}",
        title=title,
        illness_type=illness_type,
        questions=[
            Question(
                id="took_medication",
                label="Uminom ka na ba ng gamot mo?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(
                    trigger_value="yes",
                    reveals=["medication_list", "dose_interval"],
                ),
            ),
            Question(
                id="medication_list",
                label="Anong gamot ang iniinom mo?",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(*medication_opts, ("other", "Iba pa")),
                gate=GateConfig(trigger_value="other", reveals=["medication_other_input"]),
                parent_gate_id="took_medication",
                gate_trigger_value="yes",
            ),
            Question(
                id="medication_other_input",
                label="Ano pang gamot ang iyong iniinom?",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="Isulat ang pangalan ng gamot.",
                parent_gate_id="medication_list",
                gate_trigger_value="other",
            ),
            Question(
                id="dose_interval",
                label="Ilang oras ang interval ng iyong gamot?",
                ui_component="number_input",
                is_required=False,
                validation=ValidationRule(min=0.5, max=24.0, step=0.5, unit="oras"),
                parent_gate_id="took_medication",
                gate_trigger_value="yes",
            ),
            Question(
                id="missed_reason",
                label="Bakit hindi ka nakainom?",
                ui_component="select",
                is_required=False,
                options=_opts(
                    ("forgot",       "Nakalimutan"),
                    ("no_supply",    "Wala nang gamot"),
                    ("side_effects", "Side effects"),
                    ("other",        "Iba pa"),
                ),
                parent_gate_id="took_medication",
                gate_trigger_value="no",
            ),
        ],
    )


def _food_module(
    illness_type: str,
    title: str,
    food_opts: list[tuple[str, str]],
) -> DailyModule:
    """
    Generic food monitoring module reused across all illness types.
    Only the food chip options differ per illness.
    """
    return DailyModule(
        module_id=f"food_{illness_type}",
        title=title,
        illness_type=illness_type,
        questions=[
            Question(
                id="ate_today",
                label="Kumain ka na ba?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(
                    trigger_value="yes",
                    reveals=["food_list", "meal_count", "ate_restricted"],
                ),
            ),
            Question(
                id="food_list",
                label="Ano ang kinain mo ngayon?",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(*food_opts, ("other", "Iba pa")),
                gate=GateConfig(trigger_value="other", reveals=["food_other_input"]),
                parent_gate_id="ate_today",
                gate_trigger_value="yes",
            ),
            Question(
                id="food_other_input",
                label="Ano pang pagkain ang iyong kinain?",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="Isulat ang pagkain (e.g., Adobo, Sinigang).",
                parent_gate_id="food_list",
                gate_trigger_value="other",
            ),
            Question(
                id="meal_count",
                label="Ilang beses ka kumain ngayong araw?",
                ui_component="number_input",
                is_required=False,
                validation=ValidationRule(min=0.0, max=10.0, step=1.0, unit="beses"),
                parent_gate_id="ate_today",
                gate_trigger_value="yes",
            ),
            Question(
                id="ate_restricted",
                label="Kumain ka ba ng bawal na pagkain?",
                ui_component="radio",
                is_required=False,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["restricted_food_detail"]),
                parent_gate_id="ate_today",
                gate_trigger_value="yes",
            ),
            Question(
                id="restricted_food_detail",
                label="Anong bawal na pagkain ang kinain mo?",
                ui_component="multi_text_input",
                is_required=False,
                parent_gate_id="ate_restricted",
                gate_trigger_value="yes",
            ),
        ],
    )


# ---------------------------------------------------------------------------
# INTAKE QUESTIONNAIRE — 5 Phases
# ---------------------------------------------------------------------------

def _build_intake() -> IntakeQuestionnaire:
    # ── Phase 1: Demographics ─────────────────────────────────────────────
    phase_demographics = QuestionnairePhase(
        phase_id="demographics",
        title="Demographics",
        phase_number=1,
        questions=[
            Question(
                id="dob",
                label="Date of Birth",
                ui_component="date_picker",
                is_required=True,
            ),
            Question(
                id="biological_sex",
                label="Biological Sex",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("male",           "Male"),
                    ("female",         "Female"),
                    ("intersex",       "Intersex"),
                    ("prefer_not_say", "Prefer not to say"),
                ),
            ),
            Question(
                id="ethnicity",
                label="Ethnicity",
                ui_component="select",
                is_required=True,
                options=_opts(
                    ("filipino",       "Filipino"),
                    ("chinese",        "Chinese"),
                    ("malay",          "Malay"),
                    ("indian",         "Indian"),
                    ("caucasian",      "Caucasian"),
                    ("black_african",  "Black / African"),
                    ("middle_eastern", "Middle Eastern"),
                    ("other",          "Other"),
                ),
            ),
        ],
    )

    # ── Phase 2: Allergies ────────────────────────────────────────────────
    phase_allergies = QuestionnairePhase(
        phase_id="allergies",
        title="Allergies",
        phase_number=2,
        questions=[
            Question(
                id="has_allergies",
                label="Do you have any known allergies?",
                ui_component="radio",
                is_required=True,
                options=YES_NO_EN,
                gate=GateConfig(
                    trigger_value="yes",
                    reveals=["allergy_medications", "allergy_food", "allergy_environmental"],
                ),
            ),
            Question(
                id="allergy_medications",
                label="Medication Allergies",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="List each medication (e.g., Penicillin, Aspirin, NSAIDs).",
                parent_gate_id="has_allergies",
                gate_trigger_value="yes",
            ),
            Question(
                id="allergy_food",
                label="Food Allergies",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="List each food (e.g., Peanuts, Tree nuts, Shellfish).",
                parent_gate_id="has_allergies",
                gate_trigger_value="yes",
            ),
            Question(
                id="allergy_environmental",
                label="Environmental Allergies",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="e.g., Dust mites, Pollen, Mold, Pet dander.",
                parent_gate_id="has_allergies",
                gate_trigger_value="yes",
            ),
        ],
    )

    # ── Phase 3: Lifestyle ────────────────────────────────────────────────
    phase_lifestyle = QuestionnairePhase(
        phase_id="lifestyle",
        title="Lifestyle",
        phase_number=3,
        questions=[
            Question(
                id="tobacco_pack_years",
                label="Tobacco Pack-Years",
                ui_component="number_input",
                is_required=True,
                hint_text=(
                    "Enter 0 if non-smoker. "
                    "Pack-year = smoking 1 pack (20 cigarettes) per day for 1 year."
                ),
                validation=ValidationRule(min=0.0, max=200.0, step=0.5, unit="pack-years"),
            ),
            Question(
                id="alcohol_weekly_frequency",
                label="Weekly Alcohol Consumption",
                ui_component="number_input",
                is_required=True,
                hint_text="Enter 0 if non-drinker. Count each standard drink separately.",
                validation=ValidationRule(min=0.0, max=100.0, step=1.0, unit="drinks / week"),
            ),
        ],
    )

    # ── Phase 4: Social Determinants of Health ─────────────────────────────
    phase_sdoh = QuestionnairePhase(
        phase_id="sdoh",
        title="Social Determinants of Health",
        phase_number=4,
        questions=[
            Question(
                id="living_situation",
                label="Current Living Situation",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("alone",           "Alone"),
                    ("with_family",     "With Family"),
                    ("with_partner",    "With Partner / Spouse"),
                    ("assisted_living", "Assisted Living Facility"),
                    ("other",           "Other"),
                ),
            ),
            Question(
                id="support_system_strength",
                label="Perceived Support System",
                ui_component="radio",
                is_required=True,
                hint_text=(
                    "How supported do you feel by your social network "
                    "(family, friends, community)?"
                ),
                options=_opts(
                    ("strong",   "Strong — I have reliable people I can count on"),
                    ("moderate", "Moderate — Some support, but gaps exist"),
                    ("minimal",  "Minimal — Very little support available"),
                    ("none",     "None — I feel largely unsupported"),
                ),
            ),
        ],
    )

    # ── Phase 5: Family History ────────────────────────────────────────────
    phase_family_history = QuestionnairePhase(
        phase_id="family_history",
        title="Family History",
        phase_number=5,
        questions=[
            Question(
                id="has_family_history",
                label=(
                    "Does anyone in your immediate family (parents, siblings, "
                    "grandparents) have a history of a chronic illness?"
                ),
                ui_component="radio",
                is_required=True,
                options=YES_NO_EN,
                gate=GateConfig(
                    trigger_value="yes",
                    reveals=["family_history_conditions"],
                ),
            ),
            Question(
                id="family_history_conditions",
                label="Which conditions? (select all that apply)",
                ui_component="chip_selector",
                is_required=False,
                hint_text="Maaaring pumili ng higit sa isa.",
                options=_opts(
                    ("hypertension",  "Hypertension"),
                    ("diabetes",      "Diabetes"),
                    ("heart_disease", "Heart Disease"),
                    ("cancer",        "Cancer"),
                    ("ckd",           "Kidney Disease (CKD)"),
                    ("stroke",        "Stroke"),
                    ("asthma",        "Asthma"),
                    ("tuberculosis",  "Tuberculosis"),
                    ("arthritis",     "Arthritis"),
                    ("mental_health", "Mental Health Condition"),
                ),
                parent_gate_id="has_family_history",
                gate_trigger_value="yes",
            ),
        ],
    )

    return IntakeQuestionnaire(
        phases=[
            phase_demographics,
            phase_allergies,
            phase_lifestyle,
            phase_sdoh,
            phase_family_history,
        ]
    )


# ---------------------------------------------------------------------------
# DAILY MONITORING — Universal
# ---------------------------------------------------------------------------

def _build_daily_universal() -> DailyModule:
    return DailyModule(
        module_id="universal",
        title="Pang-araw-araw na Pakiramdam",
        illness_type=None,
        questions=[
            Question(
                id="overall_condition",
                label="Overall condition today:",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("better", "Mas mabuti"),
                    ("same",   "Pareho"),
                    ("worse",  "Mas masama"),
                ),
            ),
            Question(
                id="discomfort_status",
                label="May sakit o discomfort ba?",
                ui_component="radio",
                is_required=True,
                options=_opts(("meron", "Meron"), ("wala", "Wala")),
                gate=GateConfig(trigger_value="meron", reveals=["discomfort_description"]),
            ),
            Question(
                id="discomfort_description",
                label="Anong uri ng sakit o discomfort?",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="Ilarawan ang inyong nararamdaman (e.g., pananakit ng ulo, tiyan, etc.).",
                parent_gate_id="discomfort_status",
                gate_trigger_value="meron",
            ),
            Question(
                id="energy_level",
                label="Energy level:",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("high",     "Mataas"),
                    ("moderate", "Katamtaman"),
                    ("low",      "Mababa"),
                ),
            ),
            Question(
                id="mobility_status",
                label="Nakakakilos nang maayos?",
                ui_component="radio",
                is_required=True,
                options=_opts(("yes", "Oo"), ("no", "Hindi")),
            ),
            Question(
                id="emotional_status",
                label="Emotional status:",
                ui_component="chip_selector",
                is_required=True,
                hint_text="Maaaring pumili ng higit sa isa.",
                options=_opts(
                    ("okay",    "Maayos"),
                    ("sad",     "Malungkot"),
                    ("anxious", "Balisa"),
                    ("other",   "Iba pa"),
                ),
            ),
        ],
    )


# ---------------------------------------------------------------------------
# DAILY MONITORING — Illness-Specific Symptom Modules
# ---------------------------------------------------------------------------

def _build_daily_hypertension() -> DailyModule:
    return DailyModule(
        module_id="hypertension",
        title="Pagsubaybay sa Presyon ng Dugo",
        illness_type="hypertension",
        questions=[
            Question(
                id="blood_pressure",
                label="Anong reading ng inyong blood pressure ngayon?",
                ui_component="bp_input",
                is_required=False,
                hint_text="Systolic / Diastolic (mmHg). Laktawan kung hindi nasusukat.",
            ),
            Question(
                id="headache_severity",
                label="Gaano kalala ang sakit ng ulo ngayon?",
                ui_component="slider",
                is_required=False,
                hint_text="1 = Halos di pansin · 10 = Sobrang sakit",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="dizziness_severity",
                label="Gaano kalala ang pagkahilo o pagka-liyo?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="chest_discomfort",
                label="Mayroon bang discomfort o paninikip sa dibdib?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["chest_discomfort_description"]),
            ),
            Question(
                id="chest_discomfort_description",
                label="Ilarawan ang discomfort sa dibdib:",
                ui_component="multi_text_input",
                is_required=False,
                parent_gate_id="chest_discomfort",
                gate_trigger_value="yes",
            ),
            Question(
                id="vision_changes",
                label="Mayroon bang pagbabago sa paningin (malabo, may nakikitang ilaw)?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="medication_adherence_difficulty",
                label="Gaano kahirap sundin ang inyong medication at diet plan?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
        ],
    )


def _build_daily_diabetes() -> DailyModule:
    return DailyModule(
        module_id="diabetes",
        title="Pagsubaybay sa Diabetes",
        illness_type="diabetes",
        questions=[
            Question(
                id="blood_sugar_reading",
                label="Ano po ang blood sugar reading ninyo ngayon?",
                ui_component="number_input",
                is_required=False,
                hint_text="Ilagay ang sukat sa mg/dL. Laktawan kung hindi nasusukat.",
                validation=ValidationRule(min=20.0, max=800.0, step=1.0, unit="mg/dL"),
            ),
            Question(
                id="low_bs_symptoms",
                label="Mga sintomas ng mababang blood sugar:",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("dizzy",      "Pagkahilo"),
                    ("sweating",   "Pagpapawis"),
                    ("trembling",  "Panginginig"),
                    ("confusion",  "Kalituhan"),
                ),
            ),
            Question(
                id="low_bs_severity",
                label="Kung meron, gaano kalala?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="high_bs_symptoms",
                label="Mga sintomas ng mataas na blood sugar:",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("thirsty",            "Matinding uhaw"),
                    ("frequent_urination", "Madalas na pag-ihi"),
                    ("blurred_vision",     "Malabong paningin"),
                    ("fatigue",            "Pagod na pagod"),
                ),
            ),
            Question(
                id="high_bs_severity",
                label="Kung meron, gaano kalala?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="wound_healing_slowness",
                label="Mayroon bang mabagal na paghilom ng sugat?",
                ui_component="radio",
                is_required=False,
                options=YES_NO,
            ),
            Question(
                id="medication_adherence_difficulty",
                label="Gaano kahirap sundin ang inyong diet at medication plan?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
        ],
    )


def _build_daily_heart_disease() -> DailyModule:
    return DailyModule(
        module_id="heart_disease",
        title="Pagsubaybay sa Puso",
        illness_type="heart_disease",
        questions=[
            Question(
                id="blood_pressure",
                label="Anong reading ng inyong blood pressure ngayon?",
                ui_component="bp_input",
                is_required=False,
                hint_text="Laktawan kung hindi nasusukat.",
            ),
            Question(
                id="chest_pain_severity",
                label="Gaano kalala ang pananakit o paninikip sa dibdib?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Wala · 10 = Sobrang sakit. Tumawag agad sa doktor kung 7+.",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="palpitations",
                label="Nakaramdam ba ng kabog ng puso o irregular na tibok?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="shortness_of_breath_severity",
                label="Gaano kalala ang hirap sa paghinga?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="leg_swelling",
                label="Mayroon bang pamamaga sa mga paa o binti?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["leg_swelling_severity"]),
            ),
            Question(
                id="leg_swelling_severity",
                label="Gaano kalala ang pamamaga?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
                parent_gate_id="leg_swelling",
                gate_trigger_value="yes",
            ),
            Question(
                id="fatigue_severity",
                label="Gaano kalala ang pagod o panghihina ngayon?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
        ],
    )


def _build_daily_asthma() -> DailyModule:
    return DailyModule(
        module_id="asthma",
        title="Pagsubaybay sa Hika (Asthma)",
        illness_type="asthma",
        questions=[
            Question(
                id="breathing_difficulty_severity",
                label="Gaano kalala ang hirap sa paghinga ngayon?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Normal na paghinga · 10 = Sobrang hirap huminga",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="wheezing",
                label="Nakaramdam ba ng huni o wheezing sa paghinga?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="cough_severity",
                label="Gaano kalala ang pag-ubo ngayon?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="trigger_exposure",
                label="Nakalantad ba sa mga trigger ngayon?",
                ui_component="chip_selector",
                is_required=False,
                hint_text="Piliin ang lahat ng naaangkop.",
                options=_opts(
                    ("dust",     "Alikabok"),
                    ("smoke",    "Usok"),
                    ("pollen",   "Pollen"),
                    ("cold_air", "Malamig na hangin"),
                    ("exercise", "Ehersisyo"),
                    ("animals",  "Hayop / Alagang hayop"),
                ),
            ),
            Question(
                id="reliever_inhaler_used",
                label="Gumamit ba ng reliever inhaler (e.g., Salbutamol) ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["reliever_puffs"]),
            ),
            Question(
                id="reliever_puffs",
                label="Ilang puff ang ginamit?",
                ui_component="number_input",
                is_required=False,
                validation=ValidationRule(min=1.0, max=20.0, step=1.0, unit="puffs"),
                parent_gate_id="reliever_inhaler_used",
                gate_trigger_value="yes",
            ),
            Question(
                id="nighttime_symptoms",
                label="Nagising ba dahil sa asthma ngayong gabi/kahapon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
        ],
    )


def _build_daily_tuberculosis() -> DailyModule:
    return DailyModule(
        module_id="tuberculosis",
        title="Pagsubaybay sa TB",
        illness_type="tuberculosis",
        questions=[
            Question(
                id="dots_taken",
                label="Nainom na ba ang DOTS medication ngayon?",
                ui_component="radio",
                is_required=True,
                hint_text="DOTS = Directly Observed Treatment, Short-course.",
                options=YES_NO,
            ),
            Question(
                id="cough_severity",
                label="Gaano kalala ang pag-ubo ngayon?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Wala · 10 = Sobrang ubo",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="cough_type",
                label="Uri ng plema o ubo:",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("dry",          "Tuyong ubo"),
                    ("with_phlegm",  "May plema"),
                    ("with_blood",   "May dugo"),
                    ("none",         "Walang ubo"),
                ),
            ),
            Question(
                id="fever_today",
                label="Mayroon bang lagnat ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["fever_temperature"]),
            ),
            Question(
                id="fever_temperature",
                label="Ano ang temperature?",
                ui_component="number_input",
                is_required=False,
                validation=ValidationRule(min=35.0, max=43.0, step=0.1, unit="°C"),
                parent_gate_id="fever_today",
                gate_trigger_value="yes",
            ),
            Question(
                id="night_sweats",
                label="Nagpawis ba nang labis kagabi habang natutulog?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="appetite_change",
                label="Pagbabago sa gana sa pagkain:",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("better", "Mas may gana"),
                    ("same",   "Pareho"),
                    ("worse",  "Mas walang gana"),
                ),
            ),
            Question(
                id="side_effects",
                label="Nakaramdam ba ng side effects ng gamot (paninilaw ng mata/balat, pangangalay)?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["side_effects_description"]),
            ),
            Question(
                id="side_effects_description",
                label="Ilarawan ang side effects:",
                ui_component="multi_text_input",
                is_required=False,
                parent_gate_id="side_effects",
                gate_trigger_value="yes",
            ),
        ],
    )


def _build_daily_cancer() -> DailyModule:
    return DailyModule(
        module_id="cancer",
        title="Sintomas ng Kanser",
        illness_type="cancer",
        questions=[
            Question(
                id="pain_severity",
                label="Gaano kalala ang pananakit ng katawan na inyong nararamdaman?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Halos di pansin · 10 = Sobrang sakit",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="pain_location",
                label="Saan nararamdaman ang pananakit?",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("head",    "Ulo"),
                    ("chest",   "Dibdib"),
                    ("abdomen", "Tiyan"),
                    ("back",    "Likod"),
                    ("limbs",   "Kamay / Paa"),
                    ("other",   "Iba pa"),
                ),
            ),
            Question(
                id="nausea_severity",
                label="Gaano kadalas o kalala ang pagduduwal/pagsusuka?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="fatigue_severity",
                label="Gaano kalala ang panghihina o fatigue?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="breathing_cough_severity",
                label="Gaano kalala ang hirap sa paghinga o ubo?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="appetite_loss_severity",
                label="Gaano kalala ang pagkawala ng gana kumain?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
        ],
    )


def _build_daily_ckd() -> DailyModule:
    return DailyModule(
        module_id="ckd",
        title="Pagsubaybay sa Bato (CKD)",
        illness_type="ckd",
        questions=[
            Question(
                id="urination_change_type",
                label="Uri ng pagbabago sa pag-ihi ngayon:",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("decreased",    "Pagbaba ng dami ng ihi"),
                    ("increased",    "Pagtaas ng dami ng ihi"),
                    ("color_change", "Pagbabago sa kulay ng ihi"),
                    ("foamy",        "Malagkit o mabula"),
                    ("none",         "Walang pagbabago"),
                ),
            ),
            Question(
                id="urination_change_severity",
                label="Kung may pagbabago, gaano kalala?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="edema_location",
                label="Saan may pamamaga?",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("feet",  "Paa"),
                    ("hands", "Kamay"),
                    ("face",  "Mukha"),
                    ("none",  "Wala"),
                ),
            ),
            Question(
                id="edema_severity",
                label="Gaano kalala ang pamamaga?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="itching_severity",
                label="Kung nakakaranas ng pangangati ng balat, gaano ito kalala?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="orthopnea_severity",
                label="Gaano kalala ang hirap sa paghinga lalo na kapag nakahiga?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="diet_adherence_difficulty",
                label="Gaano kahirap sundin ang fluid at diet restriction?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
        ],
    )


def _build_daily_stroke() -> DailyModule:
    return DailyModule(
        module_id="stroke",
        title="Pagsubaybay sa Stroke Recovery",
        illness_type="stroke",
        questions=[
            Question(
                id="weakness_numbness",
                label="Mayroon bang panghihina o pamamanhid sa katawan ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["weakness_location", "weakness_severity"]),
            ),
            Question(
                id="weakness_location",
                label="Saang parte ng katawan?",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("left_arm",  "Kaliwang braso"),
                    ("right_arm", "Kanang braso"),
                    ("left_leg",  "Kaliwang binti"),
                    ("right_leg", "Kanang binti"),
                    ("face",      "Mukha"),
                ),
                parent_gate_id="weakness_numbness",
                gate_trigger_value="yes",
            ),
            Question(
                id="weakness_severity",
                label="Gaano kalala ang panghihina?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
                parent_gate_id="weakness_numbness",
                gate_trigger_value="yes",
            ),
            Question(
                id="speech_difficulty",
                label="Mayroon bang hirap sa pagsasalita o pag-unawa ng sinasabi ng iba?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="balance_difficulty_severity",
                label="Gaano kalala ang kahirapan sa balanse o paglalakad?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Normal · 10 = Hindi makalakad nang walang tulong",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="vision_problems",
                label="Mayroon bang problema sa paningin ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="rehab_exercise_done",
                label="Nagawa ba ang rehabilitation exercises ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="headache_severity",
                label="Gaano kalala ang sakit ng ulo?",
                ui_component="slider",
                is_required=False,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
        ],
    )


def _build_daily_arthritis() -> DailyModule:
    return DailyModule(
        module_id="arthritis",
        title="Pagsubaybay sa Arthritis",
        illness_type="arthritis",
        questions=[
            Question(
                id="joint_pain_locations",
                label="Saang kasukasuan ang pananakit ngayon?",
                ui_component="chip_selector",
                is_required=False,
                hint_text="Piliin ang lahat ng naaangkop.",
                options=_opts(
                    ("hands",     "Mga kamay / daliri"),
                    ("knees",     "Tuhod"),
                    ("hips",      "Balakang"),
                    ("back",      "Likod"),
                    ("shoulders", "Balikat"),
                    ("feet",      "Paa"),
                    ("none",      "Wala"),
                ),
            ),
            Question(
                id="joint_pain_severity",
                label="Gaano kalala ang pananakit ng kasukasuan?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Halos di pansin · 10 = Sobrang sakit",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="morning_stiffness_duration",
                label="Gaano katagal ang stiffness sa umaga bago maging maayos ang galaw?",
                ui_component="number_input",
                is_required=False,
                hint_text="Ilagay ang 0 kung wala.",
                validation=ValidationRule(min=0.0, max=240.0, step=5.0, unit="minuto"),
            ),
            Question(
                id="joint_swelling",
                label="Mayroon bang pamamaga sa mga kasukasuan?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="limited_mobility_severity",
                label="Gaano kalala ang limitasyon sa galaw o paggalaw?",
                ui_component="slider",
                is_required=True,
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="activity_done_today",
                label="Nagawa ba ang pang-araw-araw na gawain nang maayos?",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("fully",       "Oo, buong-buo"),
                    ("partially",   "Bahagi lamang"),
                    ("not_at_all",  "Hindi"),
                ),
            ),
        ],
    )


def _build_daily_mental_health() -> DailyModule:
    return DailyModule(
        module_id="mental_health",
        title="Kalusugan ng Isip",
        illness_type="mental_health",
        questions=[
            Question(
                id="mood_today",
                label="Paano ang inyong mood ngayon?",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("very_good", "Napakaganda"),
                    ("good",      "Maganda"),
                    ("neutral",   "Katamtaman"),
                    ("low",       "Malungkot"),
                    ("very_low",  "Napakababang mood"),
                ),
            ),
            Question(
                id="anxiety_level",
                label="Gaano kalala ang pagkabalisa o anxiety ngayon?",
                ui_component="slider",
                is_required=True,
                hint_text="1 = Walang pagkabalisa · 10 = Sobrang balisa",
                validation=ValidationRule(min=1.0, max=10.0, step=1.0),
            ),
            Question(
                id="sleep_quality",
                label="Paano ang kalidad ng tulog kagabi?",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("good",  "Maayos"),
                    ("fair",  "Katamtaman"),
                    ("poor",  "Masamang tulog"),
                    ("none",  "Hindi natulog"),
                ),
            ),
            Question(
                id="appetite_change",
                label="Pagbabago sa gana sa pagkain:",
                ui_component="radio",
                is_required=True,
                options=_opts(
                    ("better", "Mas may gana"),
                    ("same",   "Pareho"),
                    ("worse",  "Mas walang gana"),
                ),
            ),
            Question(
                id="social_interaction",
                label="Nakipag-usap o nakisalamuha ba sa ibang tao ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
            ),
            Question(
                id="negative_thoughts",
                label="Nakaranas ba ng nakakasamang kaisipan ngayon?",
                ui_component="radio",
                is_required=True,
                options=YES_NO,
                gate=GateConfig(trigger_value="yes", reveals=["negative_thoughts_detail"]),
            ),
            Question(
                id="negative_thoughts_detail",
                label="Nais bang ibahagi ang higit pa? (opsyonal)",
                ui_component="multi_text_input",
                is_required=False,
                hint_text="Ang sagot ay sineserbisyuhan ng iyong healthcare provider.",
                parent_gate_id="negative_thoughts",
                gate_trigger_value="yes",
            ),
            Question(
                id="coping_activity",
                label="Anong ginawa para mapanatag ang isip ngayon?",
                ui_component="chip_selector",
                is_required=False,
                options=_opts(
                    ("prayer",    "Dasal"),
                    ("breathing", "Deep breathing"),
                    ("walk",      "Paglalakad"),
                    ("music",     "Pakikinig ng musika"),
                    ("talk",      "Nakipag-usap sa kamag-anak"),
                    ("other",     "Iba pa"),
                ),
            ),
        ],
    )


# ---------------------------------------------------------------------------
# Medication options per illness
# ---------------------------------------------------------------------------

_MEDS = {
    "hypertension": [
        ("amlodipine",          "Amlodipine"),
        ("losartan",            "Losartan"),
        ("metoprolol",          "Metoprolol"),
        ("hydrochlorothiazide", "Hydrochlorothiazide"),
        ("lisinopril",          "Lisinopril"),
    ],
    "diabetes": [
        ("metformin",    "Metformin"),
        ("insulin",      "Insulin"),
        ("glipizide",    "Glipizide"),
        ("sitagliptin",  "Sitagliptin"),
        ("empagliflozin","Empagliflozin"),
    ],
    "heart_disease": [
        ("aspirin",      "Aspirin"),
        ("atorvastatin", "Atorvastatin"),
        ("bisoprolol",   "Bisoprolol"),
        ("ramipril",     "Ramipril"),
        ("clopidogrel",  "Clopidogrel"),
    ],
    "asthma": [
        ("salbutamol",    "Salbutamol (inhaler)"),
        ("budesonide",    "Budesonide (inhaler)"),
        ("montelukast",   "Montelukast"),
        ("ipratropium",   "Ipratropium"),
        ("prednisolone",  "Prednisolone"),
    ],
    "tuberculosis": [
        ("isoniazid",    "Isoniazid (INH)"),
        ("rifampicin",   "Rifampicin"),
        ("pyrazinamide", "Pyrazinamide"),
        ("ethambutol",   "Ethambutol"),
    ],
    "cancer": [
        ("dexamethasone", "Dexamethasone"),
        ("ondansetron",   "Ondansetron"),
        ("morphine",      "Morphine"),
        ("methotrexate",  "Methotrexate"),
        ("tamoxifen",     "Tamoxifen"),
    ],
    "ckd": [
        ("amlodipine",        "Amlodipine"),
        ("furosemide",        "Furosemide"),
        ("calcium_carbonate", "Calcium Carbonate"),
        ("erythropoietin",    "Erythropoietin"),
        ("sodium_bicarb",     "Sodium Bicarbonate"),
    ],
    "stroke": [
        ("aspirin",      "Aspirin"),
        ("clopidogrel",  "Clopidogrel"),
        ("atorvastatin", "Atorvastatin"),
        ("warfarin",     "Warfarin"),
        ("lisinopril",   "Lisinopril"),
    ],
    "arthritis": [
        ("naproxen",          "Naproxen"),
        ("ibuprofen",         "Ibuprofen"),
        ("methotrexate",      "Methotrexate"),
        ("hydroxychloroquine","Hydroxychloroquine"),
        ("celecoxib",         "Celecoxib"),
    ],
    "mental_health": [
        ("sertraline",    "Sertraline"),
        ("fluoxetine",    "Fluoxetine"),
        ("escitalopram",  "Escitalopram"),
        ("lorazepam",     "Lorazepam"),
        ("risperidone",   "Risperidone"),
    ],
}

_MED_TITLES = {
    "hypertension":  "Pagsubaybay sa Gamot (Hypertension)",
    "diabetes":      "Pagsubaybay sa Gamot (Diabetes)",
    "heart_disease": "Pagsubaybay sa Gamot (Puso)",
    "asthma":        "Pagsubaybay sa Gamot (Asthma)",
    "tuberculosis":  "Pagsubaybay sa Gamot (TB)",
    "cancer":        "Pagsubaybay sa Gamot (Kanser)",
    "ckd":           "Pagsubaybay sa Gamot (CKD)",
    "stroke":        "Pagsubaybay sa Gamot (Stroke)",
    "arthritis":     "Pagsubaybay sa Gamot (Arthritis)",
    "mental_health": "Pagsubaybay sa Gamot (Kalusugan ng Isip)",
}


# ---------------------------------------------------------------------------
# Food options per illness
# ---------------------------------------------------------------------------

_FOODS = {
    "hypertension": [
        ("banana",       "Saging"),
        ("kamote",       "Kamote"),
        ("malunggay",    "Malunggay"),
        ("fish",         "Isda"),
        ("vegetables",   "Gulay"),
        ("brown_rice",   "Brown rice"),
    ],
    "diabetes": [
        ("brown_rice", "Brown rice"),
        ("ampalaya",   "Ampalaya"),
        ("oatmeal",    "Oatmeal"),
        ("tilapia",    "Tilapia"),
        ("kamote",     "Kamote"),
        ("egg",        "Itlog"),
    ],
    "heart_disease": [
        ("oatmeal",    "Oatmeal"),
        ("fish",       "Isda (especially bangus, tuna)"),
        ("vegetables", "Gulay"),
        ("fruits",     "Prutas"),
        ("nuts",       "Mani"),
        ("brown_rice", "Brown rice"),
    ],
    "asthma": [
        ("ginger_tea",  "Salabat (luya)"),
        ("fish",        "Isda"),
        ("apple",       "Mansanas"),
        ("leafy_greens","Dahon-dahonan (spinach, etc.)"),
        ("turmeric",    "Luyang dilaw"),
        ("honey",       "Pulot"),
    ],
    "tuberculosis": [
        ("egg",        "Itlog"),
        ("chicken",    "Manok"),
        ("fish",       "Isda"),
        ("milk",       "Gatas"),
        ("vegetables", "Gulay"),
        ("rice",       "Kanin"),
    ],
    "cancer": [
        ("lugaw",     "Lugaw"),
        ("soup",      "Sabaw"),
        ("banana",    "Saging"),
        ("malunggay", "Malunggay"),
        ("pandesal",  "Pandesal"),
        ("chicken",   "Manok"),
    ],
    "ckd": [
        ("white_rice",  "White rice"),
        ("cabbage",     "Repolyo"),
        ("egg_white",   "Puting itlog"),
        ("apple",       "Mansanas"),
        ("white_bread", "White bread"),
        ("chicken",     "Manok"),
    ],
    "stroke": [
        ("fish",       "Isda"),
        ("vegetables", "Gulay"),
        ("fruits",     "Prutas"),
        ("oatmeal",    "Oatmeal"),
        ("nuts",       "Mani"),
        ("lugaw",      "Lugaw / Mashed na pagkain"),
    ],
    "arthritis": [
        ("fish",        "Isda (omega-3)"),
        ("ginger",      "Luya"),
        ("berries",     "Berry (blueberry, strawberry)"),
        ("vegetables",  "Gulay (lalo ang spinach)"),
        ("turmeric_tea","Salabat na may luyang dilaw"),
        ("nuts",        "Mani"),
    ],
    "mental_health": [
        ("banana",      "Saging"),
        ("egg",         "Itlog"),
        ("fish",        "Isda"),
        ("nuts",        "Mani"),
        ("brown_rice",  "Brown rice"),
        ("vegetables",  "Gulay"),
    ],
}

_FOOD_TITLES = {
    "hypertension":  "Pagkain Monitoring (Hypertension)",
    "diabetes":      "Pagkain Monitoring (Diabetes)",
    "heart_disease": "Pagkain Monitoring (Puso)",
    "asthma":        "Pagkain Monitoring (Asthma)",
    "tuberculosis":  "Pagkain Monitoring (TB)",
    "cancer":        "Pagkain Monitoring (Kanser)",
    "ckd":           "Pagkain Monitoring (CKD)",
    "stroke":        "Pagkain Monitoring (Stroke)",
    "arthritis":     "Pagkain Monitoring (Arthritis)",
    "mental_health": "Pagkain Monitoring (Kalusugan ng Isip)",
}


# ---------------------------------------------------------------------------
# Seeding entry point
# ---------------------------------------------------------------------------

def seed(db) -> None:
    """
    Write all questionnaire documents to Firestore.
    Uses .set() for upsert semantics — safe to re-run after schema updates.
    """
    questionnaires_ref = db.collection("questionnaires")

    illness_types = [
        "hypertension", "diabetes", "heart_disease", "asthma",
        "tuberculosis", "cancer", "ckd", "stroke", "arthritis", "mental_health",
    ]

    symptom_builders = {
        "hypertension":  _build_daily_hypertension,
        "diabetes":      _build_daily_diabetes,
        "heart_disease": _build_daily_heart_disease,
        "asthma":        _build_daily_asthma,
        "tuberculosis":  _build_daily_tuberculosis,
        "cancer":        _build_daily_cancer,
        "ckd":           _build_daily_ckd,
        "stroke":        _build_daily_stroke,
        "arthritis":     _build_daily_arthritis,
        "mental_health": _build_daily_mental_health,
    }

    documents: dict = {
        "intake":          _build_intake(),
        "daily_universal": _build_daily_universal(),
    }

    for illness in illness_types:
        documents[f"daily_{illness}"] = symptom_builders[illness]()
        documents[f"daily_medication_{illness}"] = _medication_module(
            illness, _MED_TITLES[illness], _MEDS[illness]
        )
        documents[f"daily_food_{illness}"] = _food_module(
            illness, _FOOD_TITLES[illness], _FOODS[illness]
        )

    for doc_id, model in documents.items():
        data = model.model_dump(mode="json", exclude_none=False)
        questionnaires_ref.document(doc_id).set(data)
        print(f"  [ok] questionnaires/{doc_id}")

    print(f"\n  Seeded {len(documents)} questionnaire documents successfully.")


if __name__ == "__main__":
    print("Agapay — Questionnaire Seeding Script\n")
    db = get_firestore_client()
    seed(db)

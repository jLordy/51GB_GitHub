"""
Illness-specific symptom classification matrix — the "statistical knowledge base"
for Agapay's NLP Listener Service (Phase 1.2).

Architecture rationale:
  Stored as pure Python data (frozensets) rather than Firestore documents so the
  NLP pipeline remains stateless and avoids cold-start network I/O. If the
  taxonomy needs to be clinician-editable at runtime, migrate to a Firestore
  `symptom_profiles` collection and cache with TTL in a later sprint.

Clinical sources:
  - CKD:      KDIGO Clinical Practice Guidelines (2024)
  - Diabetes: ADA Standards of Medical Care in Diabetes (2024)
  - Oncology: NCCN Supportive Care Guidelines — General Oncology / Chemotherapy
"""

from typing import TypedDict


class ConditionProfile(TypedDict):
    # frozenset for O(1) `in` lookups — this runs on every entity extracted per note.
    expected: frozenset[str]
    atypical: frozenset[str]


# Keys mirror the `illness_type` Literal["ckd", "diabetes", "oncology"] defined in
# NLPNoteSubmission exactly, so profile lookups require no string transformation.
# All terms are lowercase to align with spaCy's LOWER phrase_matcher_attr.
CONDITION_PROFILES: dict[str, ConditionProfile] = {
    "ckd": {
        # Symptoms routinely present in CKD stages 3–5 and managed conservatively.
        "expected": frozenset({
            "fatigue",
            "weakness",
            "edema",
            "swelling",
            "ankle swelling",
            "leg swelling",
            "facial puffiness",
            "decreased urination",
            "oliguria",
            "nausea",
            "loss of appetite",
            "anorexia",
            "pruritus",
            "itching",
            "shortness of breath",
            "dyspnea",
            "hypertension",
            "high blood pressure",
            "pallor",
            "pale skin",
            "anemia",
            "difficulty sleeping",
            "insomnia",
            "muscle cramps",
            "headache",
            "cognitive difficulty",
            "brain fog",
            "foamy urine",
            "proteinuria",
            "lethargy",
            "malaise",
            "decreased urine output",
            "fluid retention",
        }),
        # Symptoms warranting immediate clinical escalation in a CKD patient.
        "atypical": frozenset({
            "chest pain",
            "chest tightness",
            "fever",
            "chills",
            "hematuria",
            "blood in urine",
            "severe vomiting",
            "intractable vomiting",
            "confusion",
            "altered mental status",
            "disorientation",
            "seizures",
            "joint pain",
            "arthralgia",
            "rash",
            "skin rash",
            "dark urine",
            "palpitations",
            "syncope",
            "fainting",
            "sudden weight gain",
            "urinary retention",
            "flank pain",
            "severe back pain",
            "rapid breathing",
            "hypotension",
            "low blood pressure",
        }),
    },

    "diabetes": {
        # Classic hyperglycemic triad + well-known long-term sequelae managed on therapy.
        "expected": frozenset({
            "polyuria",
            "frequent urination",
            "polydipsia",
            "excessive thirst",
            "increased thirst",
            "polyphagia",
            "increased hunger",
            "excessive hunger",
            "fatigue",
            "blurred vision",
            "slow healing",
            "poor wound healing",
            "delayed wound healing",
            "frequent infections",
            "numbness",
            "tingling",
            "peripheral neuropathy",
            "weight gain",
            "dry skin",
            "skin infections",
            "foot pain",
            "neuropathic pain",
            "leg cramps",
            "yeast infections",
            "urinary tract infection",
        }),
        # Symptoms consistent with DKA, HHS, or severe hypoglycemia — require ER triage.
        "atypical": frozenset({
            "sudden weight loss",
            "rapid weight loss",
            "confusion",
            "fruity breath",
            "acetone breath",
            "severe abdominal pain",
            "abdominal pain",
            "fainting",
            "syncope",
            "nausea",
            "vomiting",
            "deep rapid breathing",
            "kussmaul breathing",
            "extreme weakness",
            "flushed skin",
            "chest pain",
            "vision loss",
            "sudden vision change",
            "ketoacidosis",
            "hypoglycemia",
            "seizures",
            "loss of consciousness",
            "fever",
            "severe infection",
            "palpitations",
            "diaphoresis",
            "cold sweats",
        }),
    },

    "oncology": {
        # Common chemotherapy and disease-related symptoms expected during treatment cycles.
        "expected": frozenset({
            "fatigue",
            "nausea",
            "vomiting",
            "hair loss",
            "alopecia",
            "pain",
            "localized pain",
            "loss of appetite",
            "anorexia",
            "weight loss",
            "weakness",
            "mucositis",
            "mouth sores",
            "oral ulcers",
            "peripheral neuropathy",
            "numbness",
            "tingling",
            "diarrhea",
            "constipation",
            "anemia",
            "neutropenia",
            "thrombocytopenia",
            "bruising",
            "dry skin",
            "nail changes",
            "hot flashes",
            "insomnia",
            "difficulty sleeping",
            "cognitive changes",
            "chemo brain",
            "lymphedema",
        }),
        # Red-flag oncology symptoms: neutropenic fever, hemorrhage, neurological emergency.
        "atypical": frozenset({
            "fever",
            "neutropenic fever",
            "high fever",
            "severe bleeding",
            "petechiae",
            "ecchymosis",
            "sudden neurological changes",
            "seizures",
            "paralysis",
            "severe dyspnea",
            "difficulty breathing",
            "jaundice",
            "abnormal bleeding",
            "severe infection",
            "sepsis",
            "confusion",
            "dehydration",
            "severe diarrhea",
            "bowel obstruction",
            "blood clots",
            "deep vein thrombosis",
            "pulmonary embolism",
            "sudden severe pain",
            "spinal cord compression",
            "hemoptysis",
            "coughing blood",
            "bone pain",
            "pathologic fracture",
        }),
    },
}


def get_full_symptom_lexicon() -> list[str]:
    """
    Returns a sorted, deduplicated flat list of all symptom terms across all conditions.

    Used once at pipeline init time to build the EntityRuler pattern set. Sorting
    ensures deterministic pattern ordering — important for reproducible thesis results.
    """
    all_terms: set[str] = set()
    for profile in CONDITION_PROFILES.values():
        all_terms.update(profile["expected"])
        all_terms.update(profile["atypical"])
    return sorted(all_terms)

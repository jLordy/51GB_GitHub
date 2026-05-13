from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class PatientCreate(BaseModel):
    user_uid: str = Field(..., description="Firebase Auth UID of the patient's app account.")
    full_name: str = Field(..., min_length=1, max_length=200)
    date_of_birth: date = Field(..., description="ISO 8601 date (YYYY-MM-DD).")
    illness_type: str
    assigned_doctor_uid: str = Field(..., description="Firebase Auth UID of the responsible doctor.")
    notes: Optional[str] = Field(None, max_length=2000)


class IntakeProfile(BaseModel):
    biological_sex: str
    ethnicity: str

    has_allergies: bool
    allergy_medications: list[str] = []
    allergy_food: list[str] = []
    allergy_environmental: list[str] = []

    tobacco_pack_years: float = Field(ge=0.0, le=200.0)
    alcohol_weekly_frequency: float = Field(ge=0.0, le=100.0)

    living_situation: str
    support_system_strength: str

    has_family_history: bool
    family_history_conditions: list[str] = []


class PatientSelfRegisterPayload(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=200)
    date_of_birth: date = Field(..., description="ISO 8601 date (YYYY-MM-DD).")
    illness_type: list[str] = Field(default_factory=list)
    illness_other: Optional[str] = Field(None, max_length=500)
    notes: Optional[str] = Field(None, max_length=2000)
    intake_profile: Optional[IntakeProfile] = None


class PatientUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=200)
    date_of_birth: Optional[date] = None
    illness_type: Optional[str] = None
    assigned_doctor_uid: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=2000)


class PatientResponse(BaseModel):
    patient_id: str
    user_uid: str
    full_name: str
    date_of_birth: date
    illness_type: list[str] | str
    illness_other: Optional[str] = None
    assigned_doctor_uid: Optional[str] = None
    notes: Optional[str] = None
    intake_profile: Optional[dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

from datetime import date, datetime, timezone
from typing import Any, Literal

from pydantic import BaseModel, Field

AppointmentStatus = Literal["scheduled", "completed", "cancelled", "no_show"]
AppointmentType = Literal["patient", "special"]


class PatientRefOut(BaseModel):
    uid: str
    display_name: str | None = None
    photo_url: str | None = None


class DoctorRefOut(BaseModel):
    uid: str
    display_name: str | None = None
    photo_url: str | None = None
    specialization: str | None = None


class AppointmentCreateRequest(BaseModel):
    patient_uid: str | None = None
    appointment_date: date
    start_time: str = Field(min_length=1, max_length=16)
    end_time: str | None = Field(default=None, max_length=16)
    appointment_type: AppointmentType = "patient"
    clinic_name: str | None = Field(default=None, max_length=200)
    clinic_place: str | None = Field(default=None, max_length=300)
    reason: str | None = Field(default=None, max_length=500)
    notes: str | None = Field(default=None, max_length=2000)


class SecretaryAppointmentCreateRequest(AppointmentCreateRequest):
    doctor_uid: str


class UserRefOut(BaseModel):
    uid: str
    role: str
    display_name: str | None = None
    photo_url: str | None = None


class AppointmentStatusUpdateRequest(BaseModel):
    status: AppointmentStatus


class AppointmentUpdateRequest(BaseModel):
    patient_uid: str | None = None
    appointment_date: date
    start_time: str = Field(min_length=1, max_length=16)
    end_time: str | None = Field(default=None, max_length=16)
    appointment_type: AppointmentType = "patient"
    clinic_name: str | None = Field(default=None, max_length=200)
    clinic_place: str | None = Field(default=None, max_length=300)
    reason: str | None = Field(default=None, max_length=500)
    notes: str | None = Field(default=None, max_length=2000)


class AppointmentOut(BaseModel):
    appointment_id: str
    doctor_uid: str
    patient_uid: str | None = None
    appointment_date: date
    start_time: str
    end_time: str | None = None
    status: AppointmentStatus
    appointment_type: AppointmentType = "patient"
    clinic_name: str | None = None
    clinic_place: str | None = None
    reason: str | None = None
    notes: str | None = None
    doctor: DoctorRefOut | None = None
    patient: PatientRefOut | None = None
    created_at: datetime
    updated_at: datetime


def coerce_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc)

import logging
from datetime import date

from fastapi import APIRouter, Depends, Query, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, require_roles
from src.schemas.calendar_schemas import (
    AppointmentCreateRequest,
    AppointmentOut,
    AppointmentStatusUpdateRequest,
    AppointmentUpdateRequest,
    SecretaryAppointmentCreateRequest,
    UserRefOut,
)
from src.services.calendar_service import (
    create_appointment,
    create_appointment_as_secretary,
    delete_appointment,
    delete_appointment_as_secretary,
    update_appointment,
    update_appointment_as_secretary,
    get_doctors_for_secretary,
    get_patients_for_doctor_as_secretary,
    list_appointments_for_caregiver_by_date,
    list_appointments_for_caregiver_by_range,
    list_appointments_for_doctor_by_date,
    list_appointments_for_doctor_by_range,
    list_appointments_for_patient_by_date,
    list_appointments_for_patient_by_range,
    list_appointments_for_secretary_by_date,
    list_appointments_for_secretary_by_range,
    list_public_clinic_schedule,
    list_public_clinic_schedule_by_range,
    update_appointment_status,
    update_appointment_status_as_secretary,
)

router = APIRouter(prefix="/calendar", tags=["calendar"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


@router.get(
    "/doctor/appointments",
    response_model=list[AppointmentOut],
    summary="List doctor appointments for one date",
)
def get_doctor_appointments_by_date(
    date_value: date = Query(alias="date"),
    current_user: CurrentUser = Depends(require_roles("doctor", "admin")),
) -> list[AppointmentOut]:
    return list_appointments_for_doctor_by_date(
        db,
        doctor_uid=current_user.uid,
        selected_date=date_value,
        logger=logger,
    )


@router.get(
    "/patient/appointments",
    response_model=list[AppointmentOut],
    summary="List patient appointments for one date",
)
def get_patient_appointments_by_date(
    date_value: date = Query(alias="date"),
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> list[AppointmentOut]:
    return list_appointments_for_patient_by_date(
        db,
        patient_uid=current_user.uid,
        selected_date=date_value,
        logger=logger,
    )


@router.get(
    "/caregiver/appointments",
    response_model=list[AppointmentOut],
    summary="List caregiver's connected patients' appointments for one date",
)
def get_caregiver_appointments_by_date(
    date_value: date = Query(alias="date"),
    current_user: CurrentUser = Depends(require_roles("caregiver")),
) -> list[AppointmentOut]:
    return list_appointments_for_caregiver_by_date(
        db,
        caregiver_uid=current_user.uid,
        selected_date=date_value,
        logger=logger,
    )


@router.get(
    "/secretary/appointments",
    response_model=list[AppointmentOut],
    summary="List secretary's connected doctors' appointments for one date",
)
def get_secretary_appointments_by_date(
    date_value: date = Query(alias="date"),
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> list[AppointmentOut]:
    return list_appointments_for_secretary_by_date(
        db,
        secretary_uid=current_user.uid,
        selected_date=date_value,
        logger=logger,
    )


@router.get(
    "/secretary/doctors",
    response_model=list[UserRefOut],
    summary="List doctors connected to this secretary",
)
def get_secretary_doctors(
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> list[UserRefOut]:
    return get_doctors_for_secretary(db, secretary_uid=current_user.uid)


@router.get(
    "/secretary/doctor/{doctor_uid}/patients",
    response_model=list[UserRefOut],
    summary="List patients connected to a specific doctor (secretary access)",
)
def get_doctor_patients_as_secretary(
    doctor_uid: str,
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> list[UserRefOut]:
    return get_patients_for_doctor_as_secretary(
        db,
        secretary_uid=current_user.uid,
        doctor_uid=doctor_uid,
        logger=logger,
    )


@router.post(
    "/secretary/appointments",
    response_model=AppointmentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create an appointment on behalf of a connected doctor",
)
def create_secretary_appointment(
    payload: SecretaryAppointmentCreateRequest,
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> AppointmentOut:
    return create_appointment_as_secretary(
        db,
        secretary_uid=current_user.uid,
        payload=payload,
        logger=logger,
    )


@router.patch(
    "/doctor/appointments/{appointment_id}",
    response_model=AppointmentOut,
    summary="Update a doctor appointment",
)
def patch_doctor_appointment(
    appointment_id: str,
    payload: AppointmentUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "admin")),
) -> AppointmentOut:
    return update_appointment(db, appointment_id=appointment_id, doctor_uid=current_user.uid, payload=payload, logger=logger)


@router.delete(
    "/doctor/appointments/{appointment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a doctor appointment",
)
def delete_doctor_appointment(
    appointment_id: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "admin")),
) -> None:
    delete_appointment(db, appointment_id=appointment_id, doctor_uid=current_user.uid, logger=logger)


@router.patch(
    "/secretary/appointments/{appointment_id}",
    response_model=AppointmentOut,
    summary="Update an appointment on behalf of a connected doctor",
)
def patch_secretary_appointment(
    appointment_id: str,
    payload: AppointmentUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> AppointmentOut:
    return update_appointment_as_secretary(db, secretary_uid=current_user.uid, appointment_id=appointment_id, payload=payload, logger=logger)


@router.delete(
    "/secretary/appointments/{appointment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an appointment on behalf of a connected doctor",
)
def delete_secretary_appointment(
    appointment_id: str,
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> None:
    delete_appointment_as_secretary(db, secretary_uid=current_user.uid, appointment_id=appointment_id, logger=logger)


@router.patch(
    "/secretary/appointments/{appointment_id}/status",
    response_model=AppointmentOut,
    summary="Update appointment status on behalf of a connected doctor",
)
def patch_secretary_appointment_status(
    appointment_id: str,
    payload: AppointmentStatusUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> AppointmentOut:
    return update_appointment_status_as_secretary(
        db,
        secretary_uid=current_user.uid,
        appointment_id=appointment_id,
        status_value=payload.status,
        logger=logger,
    )


@router.get(
    "/doctor/appointments/range",
    response_model=list[AppointmentOut],
    summary="List doctor appointments by date range",
)
def get_doctor_appointments_by_range(
    start_date: date,
    end_date: date,
    current_user: CurrentUser = Depends(require_roles("doctor", "admin")),
) -> list[AppointmentOut]:
    return list_appointments_for_doctor_by_range(
        db,
        doctor_uid=current_user.uid,
        start_date=start_date,
        end_date=end_date,
        logger=logger,
    )


@router.post(
    "/doctor/appointments",
    response_model=AppointmentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a doctor appointment",
)
def create_doctor_appointment(
    payload: AppointmentCreateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "admin")),
) -> AppointmentOut:
    return create_appointment(
        db,
        payload=payload,
        doctor_uid=current_user.uid,
        logger=logger,
    )


@router.patch(
    "/doctor/appointments/{appointment_id}/status",
    response_model=AppointmentOut,
    summary="Update appointment status",
)
def patch_appointment_status(
    appointment_id: str,
    payload: AppointmentStatusUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "admin")),
) -> AppointmentOut:
    return update_appointment_status(
        db,
        appointment_id=appointment_id,
        doctor_uid=current_user.uid,
        status_value=payload.status,
        logger=logger,
    )


@router.get(
    "/public/{doctor_uid}/schedule",
    response_model=list[AppointmentOut],
    summary="View a doctor's public clinic schedule for one date (no patient data)",
)
def get_public_doctor_schedule(
    doctor_uid: str,
    date_value: date = Query(alias="date"),
) -> list[AppointmentOut]:
    return list_public_clinic_schedule(
        db,
        doctor_uid=doctor_uid,
        selected_date=date_value,
        logger=logger,
    )


@router.get(
    "/patient/appointments/range",
    response_model=list[AppointmentOut],
    summary="List patient appointments by date range",
)
def get_patient_appointments_by_range(
    start_date: date,
    end_date: date,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> list[AppointmentOut]:
    return list_appointments_for_patient_by_range(
        db,
        patient_uid=current_user.uid,
        start_date=start_date,
        end_date=end_date,
        logger=logger,
    )


@router.get(
    "/caregiver/appointments/range",
    response_model=list[AppointmentOut],
    summary="List caregiver's connected patients' appointments by date range",
)
def get_caregiver_appointments_by_range(
    start_date: date,
    end_date: date,
    current_user: CurrentUser = Depends(require_roles("caregiver")),
) -> list[AppointmentOut]:
    return list_appointments_for_caregiver_by_range(
        db,
        caregiver_uid=current_user.uid,
        start_date=start_date,
        end_date=end_date,
        logger=logger,
    )


@router.get(
    "/secretary/appointments/range",
    response_model=list[AppointmentOut],
    summary="List secretary's connected doctors' appointments by date range",
)
def get_secretary_appointments_by_range(
    start_date: date,
    end_date: date,
    current_user: CurrentUser = Depends(require_roles("secretary")),
) -> list[AppointmentOut]:
    return list_appointments_for_secretary_by_range(
        db,
        secretary_uid=current_user.uid,
        start_date=start_date,
        end_date=end_date,
        logger=logger,
    )


@router.get(
    "/public/{doctor_uid}/schedule/range",
    response_model=list[AppointmentOut],
    summary="View a doctor's public clinic schedule for a date range (no patient data)",
)
def get_public_doctor_schedule_by_range(
    doctor_uid: str,
    start_date: date,
    end_date: date,
) -> list[AppointmentOut]:
    return list_public_clinic_schedule_by_range(
        db,
        doctor_uid=doctor_uid,
        start_date=start_date,
        end_date=end_date,
        logger=logger,
    )

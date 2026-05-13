import logging
from datetime import date, datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore

from src.schemas.calendar_schemas import (
    AppointmentCreateRequest,
    AppointmentOut,
    DoctorRefOut,
    PatientRefOut,
    SecretaryAppointmentCreateRequest,
    UserRefOut,
    coerce_datetime,
)


def _build_doctor_ref(db, doctor_uid: str) -> DoctorRefOut:
    snapshot = db.collection("users").document(doctor_uid).get()
    data = snapshot.to_dict() or {}
    return DoctorRefOut(
        uid=doctor_uid,
        display_name=data.get("display_name"),
        photo_url=data.get("photo_url"),
    )


def _build_patient_ref(db, patient_uid: str) -> PatientRefOut:
    snapshot = db.collection("users").document(patient_uid).get()
    data = snapshot.to_dict() or {}
    return PatientRefOut(
        uid=patient_uid,
        display_name=data.get("display_name"),
        photo_url=data.get("photo_url"),
    )


def _time_sort_key(raw: str | None) -> tuple[int, int, str]:
    if raw is None:
        return (99, 99, "")

    value = raw.strip()
    if not value:
        return (99, 99, "")

    for fmt in ("%I:%M %p", "%H:%M"):
        try:
            parsed = datetime.strptime(value, fmt)
            return (parsed.hour, parsed.minute, "")
        except ValueError:
            continue

    return (99, 99, value)


def _connected_doctor_uids_for_patient(db, patient_uid: str) -> set[str]:
    seen_connection_ids: set[str] = set()
    other_uids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection("connections")
            .where(filter=firestore.FieldFilter(field, "==", patient_uid))
            .where(filter=firestore.FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_connection_ids:
                continue
            seen_connection_ids.add(doc.id)
            data = doc.to_dict() or {}
            requester_uid = data.get("requester_uid")
            recipient_uid = data.get("recipient_uid")
            other_uid = recipient_uid if requester_uid == patient_uid else requester_uid
            if other_uid and other_uid != patient_uid:
                other_uids.add(str(other_uid))

    doctor_uids: set[str] = set()
    for uid in other_uids:
        user_snapshot = db.collection("users").document(uid).get()
        if not user_snapshot.exists:
            continue
        user_data = user_snapshot.to_dict() or {}
        role = str(user_data.get("role") or "").strip().lower()
        if role == "doctor":
            doctor_uids.add(uid)

    return doctor_uids


def _map_doc_to_out(db, doc_id: str, data: dict[str, Any]) -> AppointmentOut:
    raw_date = data.get("appointment_date")
    if isinstance(raw_date, date):
        appointment_date = raw_date
    elif isinstance(raw_date, str):
        appointment_date = date.fromisoformat(raw_date)
    else:
        raise ValueError("appointment_date is missing or invalid")

    doctor_uid = str(data.get("doctor_uid") or "")
    raw_patient_uid = data.get("patient_uid")
    patient_uid = str(raw_patient_uid) if raw_patient_uid else None
    appointment_type = str(data.get("appointment_type") or "patient")

    return AppointmentOut(
        appointment_id=doc_id,
        doctor_uid=doctor_uid,
        patient_uid=patient_uid,
        appointment_date=appointment_date,
        start_time=str(data.get("start_time") or ""),
        end_time=data.get("end_time"),
        status=str(data.get("status") or "scheduled"),
        appointment_type=appointment_type,
        clinic_name=data.get("clinic_name"),
        clinic_place=data.get("clinic_place"),
        reason=data.get("reason"),
        notes=data.get("notes"),
        doctor=_build_doctor_ref(db, doctor_uid),
        patient=_build_patient_ref(db, patient_uid) if patient_uid else None,
        created_at=coerce_datetime(data.get("created_at")),
        updated_at=coerce_datetime(data.get("updated_at")),
    )


def list_public_clinic_schedule(
    db,
    doctor_uid: str,
    selected_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Return only clinic/special appointments for a doctor on a given date.

    Patient data is stripped — this endpoint is safe to expose publicly because
    it never reveals individual patient information.
    """
    try:
        docs = (
            db.collection("appointments")
            .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
            .where(
                filter=firestore.FieldFilter(
                    "appointment_date", "==", selected_date.isoformat()
                )
            )
            .where(
                filter=firestore.FieldFilter("appointment_type", "==", "special")
            )
            .stream()
        )
    except Exception as exc:
        logger.exception("Failed to query public clinic schedule: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch clinic schedule.",
        )

    results: list[AppointmentOut] = []
    for doc in docs:
        data = doc.to_dict() or {}
        try:
            entry = _map_doc_to_out(db, doc.id, data)
            # Strip any patient reference so no patient data leaks publicly.
            results.append(
                entry.model_copy(update={"patient_uid": None, "patient": None})
            )
        except Exception as exc:
            logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results.sort(key=lambda item: _time_sort_key(item.start_time))
    return results


def create_appointment(
    db,
    payload: AppointmentCreateRequest,
    doctor_uid: str,
    logger: logging.Logger,
) -> AppointmentOut:
    now = datetime.now(timezone.utc)

    if payload.appointment_type == "patient" and not payload.patient_uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="patient_uid is required for patient appointments.",
        )

    doc_data: dict[str, Any] = {
        "doctor_uid": doctor_uid,
        "patient_uid": payload.patient_uid,
        "appointment_date": payload.appointment_date.isoformat(),
        "start_time": payload.start_time,
        "end_time": payload.end_time,
        "status": "scheduled",
        "appointment_type": payload.appointment_type,
        "clinic_name": payload.clinic_name,
        "clinic_place": payload.clinic_place,
        "reason": payload.reason,
        "notes": payload.notes,
        "created_at": firestore.SERVER_TIMESTAMP,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }

    try:
        _, doc_ref = db.collection("appointments").add(doc_data)
        output_data = dict(doc_data)
        output_data["created_at"] = now
        output_data["updated_at"] = now
        return _map_doc_to_out(db, doc_ref.id, output_data)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to create appointment: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create appointment.",
        )


def list_appointments_for_doctor_by_date(
    db,
    doctor_uid: str,
    selected_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    try:
        docs = (
            db.collection("appointments")
            .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
            .where(
                filter=firestore.FieldFilter(
                    "appointment_date", "==", selected_date.isoformat()
                )
            )
            .order_by("start_time", direction=firestore.Query.ASCENDING)
            .stream()
        )
    except Exception as exc:
        logger.exception("Failed to query appointments for date: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch appointments.",
        )

    results: list[AppointmentOut] = []
    for doc in docs:
        data = doc.to_dict() or {}
        try:
            results.append(_map_doc_to_out(db, doc.id, data))
        except Exception as exc:
            logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)
    results.sort(key=lambda item: _time_sort_key(item.start_time))
    return results


def list_appointments_for_doctor_by_range(
    db,
    doctor_uid: str,
    start_date: date,
    end_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    if end_date < start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date.",
        )

    try:
        docs = (
            db.collection("appointments")
            .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
            .where(
                filter=firestore.FieldFilter("appointment_date", ">=", start_date.isoformat())
            )
            .where(
                filter=firestore.FieldFilter("appointment_date", "<=", end_date.isoformat())
            )
            .order_by("appointment_date", direction=firestore.Query.ASCENDING)
            .order_by("start_time", direction=firestore.Query.ASCENDING)
            .stream()
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to query appointments by range: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch appointments.",
        )

    results: list[AppointmentOut] = []
    for doc in docs:
        data = doc.to_dict() or {}
        try:
            results.append(_map_doc_to_out(db, doc.id, data))
        except Exception as exc:
            logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)
    results.sort(
        key=lambda item: (
            item.appointment_date,
            _time_sort_key(item.start_time),
        )
    )
    return results


def list_appointments_for_patient_by_range(
    db,
    patient_uid: str,
    start_date: date,
    end_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Return all appointments for a patient (own + connected doctors' special) in a date range."""
    if end_date < start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date.",
        )
    start_iso = start_date.isoformat()
    end_iso = end_date.isoformat()
    merged: dict[str, AppointmentOut] = {}

    try:
        own_docs = (
            db.collection("appointments")
            .where(filter=firestore.FieldFilter("patient_uid", "==", patient_uid))
            .where(filter=firestore.FieldFilter("appointment_date", ">=", start_iso))
            .where(filter=firestore.FieldFilter("appointment_date", "<=", end_iso))
            .stream()
        )
    except Exception as exc:
        logger.exception("Failed to query patient appointments by range: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch appointments.",
        )

    for doc in own_docs:
        data = doc.to_dict() or {}
        try:
            merged[doc.id] = _map_doc_to_out(db, doc.id, data)
        except Exception as exc:
            logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    connected_doctors = _connected_doctor_uids_for_patient(db, patient_uid)
    for doctor_uid in connected_doctors:
        try:
            docs = (
                db.collection("appointments")
                .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
                .where(filter=firestore.FieldFilter("appointment_date", ">=", start_iso))
                .where(filter=firestore.FieldFilter("appointment_date", "<=", end_iso))
                .stream()
            )
        except Exception as exc:
            logger.exception(
                "Failed to query special appointments for doctor '%s': %s",
                doctor_uid,
                exc,
            )
            continue

        for doc in docs:
            data = doc.to_dict() or {}
            if str(data.get("appointment_type") or "patient") != "special":
                continue
            try:
                merged[doc.id] = _map_doc_to_out(db, doc.id, data)
            except Exception as exc:
                logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results = list(merged.values())
    results.sort(
        key=lambda item: (item.appointment_date, _time_sort_key(item.start_time))
    )
    return results


def list_appointments_for_caregiver_by_range(
    db,
    caregiver_uid: str,
    start_date: date,
    end_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Return all appointments for all patients connected to this caregiver in a date range."""
    if end_date < start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date.",
        )
    start_iso = start_date.isoformat()
    end_iso = end_date.isoformat()
    patient_uids = _connected_patient_uids_for_caregiver(db, caregiver_uid)

    merged: dict[str, AppointmentOut] = {}
    for patient_uid in patient_uids:
        try:
            docs = (
                db.collection("appointments")
                .where(filter=firestore.FieldFilter("patient_uid", "==", patient_uid))
                .where(filter=firestore.FieldFilter("appointment_date", ">=", start_iso))
                .where(filter=firestore.FieldFilter("appointment_date", "<=", end_iso))
                .stream()
            )
        except Exception as exc:
            logger.exception(
                "Failed to query appointments for patient '%s': %s",
                patient_uid,
                exc,
            )
            continue

        for doc in docs:
            data = doc.to_dict() or {}
            try:
                merged[doc.id] = _map_doc_to_out(db, doc.id, data)
            except Exception as exc:
                logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

        connected_doctors = _connected_doctor_uids_for_patient(db, patient_uid)
        for doctor_uid in connected_doctors:
            try:
                special_docs = (
                    db.collection("appointments")
                    .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
                    .where(filter=firestore.FieldFilter("appointment_date", ">=", start_iso))
                    .where(filter=firestore.FieldFilter("appointment_date", "<=", end_iso))
                    .stream()
                )
            except Exception as exc:
                logger.exception(
                    "Failed to query special appointments for doctor '%s': %s",
                    doctor_uid,
                    exc,
                )
                continue
            for doc in special_docs:
                data = doc.to_dict() or {}
                if str(data.get("appointment_type") or "patient") != "special":
                    continue
                try:
                    merged[doc.id] = _map_doc_to_out(db, doc.id, data)
                except Exception as exc:
                    logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results = list(merged.values())
    results.sort(
        key=lambda item: (item.appointment_date, _time_sort_key(item.start_time))
    )
    return results


def list_appointments_for_secretary_by_range(
    db,
    secretary_uid: str,
    start_date: date,
    end_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Return all appointments for all doctors connected to this secretary in a date range."""
    if end_date < start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date.",
        )
    start_iso = start_date.isoformat()
    end_iso = end_date.isoformat()
    doctor_uids = _connected_doctor_uids_for_secretary(db, secretary_uid)

    merged: dict[str, AppointmentOut] = {}
    for doctor_uid in doctor_uids:
        try:
            docs = (
                db.collection("appointments")
                .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
                .where(filter=firestore.FieldFilter("appointment_date", ">=", start_iso))
                .where(filter=firestore.FieldFilter("appointment_date", "<=", end_iso))
                .stream()
            )
        except Exception as exc:
            logger.exception(
                "Failed to query appointments for doctor '%s': %s",
                doctor_uid,
                exc,
            )
            continue

        for doc in docs:
            data = doc.to_dict() or {}
            try:
                merged[doc.id] = _map_doc_to_out(db, doc.id, data)
            except Exception as exc:
                logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results = list(merged.values())
    results.sort(
        key=lambda item: (item.appointment_date, _time_sort_key(item.start_time))
    )
    return results


def list_public_clinic_schedule_by_range(
    db,
    doctor_uid: str,
    start_date: date,
    end_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Return only clinic/special appointments for a doctor in a date range (no patient data)."""
    if end_date < start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date.",
        )
    try:
        docs = (
            db.collection("appointments")
            .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
            .where(filter=firestore.FieldFilter("appointment_date", ">=", start_date.isoformat()))
            .where(filter=firestore.FieldFilter("appointment_date", "<=", end_date.isoformat()))
            .where(filter=firestore.FieldFilter("appointment_type", "==", "special"))
            .stream()
        )
    except Exception as exc:
        logger.exception("Failed to query public clinic schedule by range: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch clinic schedule.",
        )

    results: list[AppointmentOut] = []
    for doc in docs:
        data = doc.to_dict() or {}
        try:
            entry = _map_doc_to_out(db, doc.id, data)
            results.append(
                entry.model_copy(update={"patient_uid": None, "patient": None})
            )
        except Exception as exc:
            logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results.sort(
        key=lambda item: (item.appointment_date, _time_sort_key(item.start_time))
    )
    return results


def list_appointments_for_patient_by_date(
    db,
    patient_uid: str,
    selected_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    date_iso = selected_date.isoformat()
    merged: dict[str, AppointmentOut] = {}

    try:
        own_docs = (
            db.collection("appointments")
            .where(filter=firestore.FieldFilter("patient_uid", "==", patient_uid))
            .where(filter=firestore.FieldFilter("appointment_date", "==", date_iso))
            .stream()
        )
    except Exception as exc:
        logger.exception("Failed to query patient appointments: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch appointments.",
        )

    for doc in own_docs:
        data = doc.to_dict() or {}
        try:
            merged[doc.id] = _map_doc_to_out(db, doc.id, data)
        except Exception as exc:
            logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    connected_doctors = _connected_doctor_uids_for_patient(db, patient_uid)
    for doctor_uid in connected_doctors:
        try:
            docs = (
                db.collection("appointments")
                .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
                .where(filter=firestore.FieldFilter("appointment_date", "==", date_iso))
                .stream()
            )
        except Exception as exc:
            logger.exception(
                "Failed to query special appointments for doctor '%s': %s",
                doctor_uid,
                exc,
            )
            continue

        for doc in docs:
            data = doc.to_dict() or {}
            if str(data.get("appointment_type") or "patient") != "special":
                continue
            try:
                merged[doc.id] = _map_doc_to_out(db, doc.id, data)
            except Exception as exc:
                logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results = list(merged.values())
    results.sort(key=lambda item: _time_sort_key(item.start_time))
    return results


def _connected_patient_uids_for_caregiver(db, caregiver_uid: str) -> set[str]:
    """Return all patient UIDs that have an accepted connection with this caregiver."""
    seen_connection_ids: set[str] = set()
    other_uids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection("connections")
            .where(filter=firestore.FieldFilter(field, "==", caregiver_uid))
            .where(filter=firestore.FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_connection_ids:
                continue
            seen_connection_ids.add(doc.id)
            data = doc.to_dict() or {}
            requester_uid = data.get("requester_uid")
            recipient_uid = data.get("recipient_uid")
            other_uid = recipient_uid if requester_uid == caregiver_uid else requester_uid
            if other_uid and other_uid != caregiver_uid:
                other_uids.add(str(other_uid))

    patient_uids: set[str] = set()
    for uid in other_uids:
        snapshot = db.collection("users").document(uid).get()
        if not snapshot.exists:
            continue
        user_data = snapshot.to_dict() or {}
        role = str(user_data.get("role") or "").strip().lower()
        if role == "patient":
            patient_uids.add(uid)

    return patient_uids


def list_appointments_for_caregiver_by_date(
    db,
    caregiver_uid: str,
    selected_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Aggregate appointments for all patients connected to this caregiver."""
    date_iso = selected_date.isoformat()
    patient_uids = _connected_patient_uids_for_caregiver(db, caregiver_uid)

    merged: dict[str, AppointmentOut] = {}
    for patient_uid in patient_uids:
        try:
            docs = (
                db.collection("appointments")
                .where(filter=firestore.FieldFilter("patient_uid", "==", patient_uid))
                .where(filter=firestore.FieldFilter("appointment_date", "==", date_iso))
                .stream()
            )
        except Exception as exc:
            logger.exception(
                "Failed to query appointments for patient '%s': %s",
                patient_uid,
                exc,
            )
            continue

        for doc in docs:
            data = doc.to_dict() or {}
            try:
                merged[doc.id] = _map_doc_to_out(db, doc.id, data)
            except Exception as exc:
                logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

        connected_doctors = _connected_doctor_uids_for_patient(db, patient_uid)
        for doctor_uid in connected_doctors:
            try:
                special_docs = (
                    db.collection("appointments")
                    .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
                    .where(filter=firestore.FieldFilter("appointment_date", "==", date_iso))
                    .stream()
                )
            except Exception as exc:
                logger.exception(
                    "Failed to query special appointments for doctor '%s': %s",
                    doctor_uid,
                    exc,
                )
                continue
            for doc in special_docs:
                data = doc.to_dict() or {}
                if str(data.get("appointment_type") or "patient") != "special":
                    continue
                try:
                    merged[doc.id] = _map_doc_to_out(db, doc.id, data)
                except Exception as exc:
                    logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results = list(merged.values())
    results.sort(key=lambda item: _time_sort_key(item.start_time))
    return results


def _connected_doctor_uids_for_secretary(db, secretary_uid: str) -> set[str]:
    """Return all doctor UIDs that have an accepted connection with this secretary."""
    seen_connection_ids: set[str] = set()
    other_uids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection("connections")
            .where(filter=firestore.FieldFilter(field, "==", secretary_uid))
            .where(filter=firestore.FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_connection_ids:
                continue
            seen_connection_ids.add(doc.id)
            data = doc.to_dict() or {}
            requester_uid = data.get("requester_uid")
            recipient_uid = data.get("recipient_uid")
            other_uid = recipient_uid if requester_uid == secretary_uid else requester_uid
            if other_uid and other_uid != secretary_uid:
                other_uids.add(str(other_uid))

    doctor_uids: set[str] = set()
    for uid in other_uids:
        snapshot = db.collection("users").document(uid).get()
        if not snapshot.exists:
            continue
        user_data = snapshot.to_dict() or {}
        role = str(user_data.get("role") or "").strip().lower()
        if role == "doctor":
            doctor_uids.add(uid)

    return doctor_uids


def list_appointments_for_secretary_by_date(
    db,
    secretary_uid: str,
    selected_date: date,
    logger: logging.Logger,
) -> list[AppointmentOut]:
    """Aggregate appointments for all doctors connected to this secretary."""
    date_iso = selected_date.isoformat()
    doctor_uids = _connected_doctor_uids_for_secretary(db, secretary_uid)

    merged: dict[str, AppointmentOut] = {}
    for doctor_uid in doctor_uids:
        try:
            docs = (
                db.collection("appointments")
                .where(filter=firestore.FieldFilter("doctor_uid", "==", doctor_uid))
                .where(filter=firestore.FieldFilter("appointment_date", "==", date_iso))
                .stream()
            )
        except Exception as exc:
            logger.exception(
                "Failed to query appointments for doctor '%s': %s",
                doctor_uid,
                exc,
            )
            continue

        for doc in docs:
            data = doc.to_dict() or {}
            try:
                merged[doc.id] = _map_doc_to_out(db, doc.id, data)
            except Exception as exc:
                logger.warning("Skipping malformed appointment '%s': %s", doc.id, exc)

    results = list(merged.values())
    results.sort(key=lambda item: _time_sort_key(item.start_time))
    return results


def get_doctors_for_secretary(db, secretary_uid: str) -> list[UserRefOut]:
    """Return all doctor users connected to this secretary."""
    doctor_uids = _connected_doctor_uids_for_secretary(db, secretary_uid)
    results: list[UserRefOut] = []
    for uid in doctor_uids:
        snapshot = db.collection("users").document(uid).get()
        if not snapshot.exists:
            continue
        data = snapshot.to_dict() or {}
        results.append(
            UserRefOut(
                uid=uid,
                role="doctor",
                display_name=data.get("display_name"),
                photo_url=data.get("photo_url"),
            )
        )
    results.sort(key=lambda u: (u.display_name or "").lower())
    return results


def get_patients_for_doctor_as_secretary(
    db,
    secretary_uid: str,
    doctor_uid: str,
    logger: logging.Logger,
) -> list[UserRefOut]:
    """Return all patients connected to a specific doctor, verified via secretary connection."""
    connected_doctors = _connected_doctor_uids_for_secretary(db, secretary_uid)
    if doctor_uid not in connected_doctors:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not connected to this doctor.",
        )

    seen_ids: set[str] = set()
    other_uids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        docs = (
            db.collection("connections")
            .where(filter=firestore.FieldFilter(field, "==", doctor_uid))
            .where(filter=firestore.FieldFilter("status", "==", "accepted"))
            .stream()
        )
        for doc in docs:
            if doc.id in seen_ids:
                continue
            seen_ids.add(doc.id)
            data = doc.to_dict() or {}
            req = data.get("requester_uid")
            rec = data.get("recipient_uid")
            other = rec if req == doctor_uid else req
            if other and other != doctor_uid:
                other_uids.add(str(other))

    results: list[UserRefOut] = []
    for uid in other_uids:
        snapshot = db.collection("users").document(uid).get()
        if not snapshot.exists:
            continue
        data = snapshot.to_dict() or {}
        role = str(data.get("role") or "").strip().lower()
        if role != "patient":
            continue
        results.append(
            UserRefOut(
                uid=uid,
                role="patient",
                display_name=data.get("display_name"),
                photo_url=data.get("photo_url"),
            )
        )
    results.sort(key=lambda u: (u.display_name or "").lower())
    return results


def create_appointment_as_secretary(
    db,
    secretary_uid: str,
    payload: SecretaryAppointmentCreateRequest,
    logger: logging.Logger,
) -> AppointmentOut:
    """Create an appointment on behalf of a connected doctor."""
    connected_doctors = _connected_doctor_uids_for_secretary(db, secretary_uid)
    if payload.doctor_uid not in connected_doctors:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not connected to this doctor.",
        )
    return create_appointment(
        db,
        payload=payload,
        doctor_uid=payload.doctor_uid,
        logger=logger,
    )


def update_appointment(
    db,
    appointment_id: str,
    doctor_uid: str,
    payload,
    logger: logging.Logger,
):
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail=f"Appointment '{appointment_id}' not found.")
    data = snapshot.to_dict() or {}
    if data.get("doctor_uid") != doctor_uid:
        raise HTTPException(status_code=403, detail="You are not authorized to update this appointment.")
    updates = {
        "patient_uid": payload.patient_uid,
        "appointment_date": payload.appointment_date.isoformat(),
        "start_time": payload.start_time,
        "end_time": payload.end_time,
        "appointment_type": payload.appointment_type,
        "clinic_name": payload.clinic_name,
        "clinic_place": payload.clinic_place,
        "reason": payload.reason,
        "notes": payload.notes,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }
    try:
        doc_ref.update(updates)
        snapshot = doc_ref.get()
        return _map_doc_to_out(db, appointment_id, snapshot.to_dict() or {})
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to update appointment: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update appointment.")


def update_appointment_as_secretary(
    db,
    secretary_uid: str,
    appointment_id: str,
    payload,
    logger: logging.Logger,
):
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail=f"Appointment '{appointment_id}' not found.")
    data = snapshot.to_dict() or {}
    if data.get("doctor_uid") not in _connected_doctor_uids_for_secretary(db, secretary_uid):
        raise HTTPException(status_code=403, detail="You are not authorized to update this appointment.")
    updates = {
        "patient_uid": payload.patient_uid,
        "appointment_date": payload.appointment_date.isoformat(),
        "start_time": payload.start_time,
        "end_time": payload.end_time,
        "appointment_type": payload.appointment_type,
        "clinic_name": payload.clinic_name,
        "clinic_place": payload.clinic_place,
        "reason": payload.reason,
        "notes": payload.notes,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }
    try:
        doc_ref.update(updates)
        snapshot = doc_ref.get()
        return _map_doc_to_out(db, appointment_id, snapshot.to_dict() or {})
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to update appointment: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update appointment.")


def delete_appointment(
    db,
    appointment_id: str,
    doctor_uid: str,
    logger: logging.Logger,
) -> None:
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail=f"Appointment '{appointment_id}' not found.")
    if (snapshot.to_dict() or {}).get("doctor_uid") != doctor_uid:
        raise HTTPException(status_code=403, detail="You are not authorized to delete this appointment.")
    try:
        doc_ref.delete()
    except Exception as exc:
        logger.exception("Failed to delete appointment: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to delete appointment.")


def delete_appointment_as_secretary(
    db,
    secretary_uid: str,
    appointment_id: str,
    logger: logging.Logger,
) -> None:
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail=f"Appointment '{appointment_id}' not found.")
    if (snapshot.to_dict() or {}).get("doctor_uid") not in _connected_doctor_uids_for_secretary(db, secretary_uid):
        raise HTTPException(status_code=403, detail="You are not authorized to delete this appointment.")
    try:
        doc_ref.delete()
    except Exception as exc:
        logger.exception("Failed to delete appointment: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to delete appointment.")


def update_appointment_status_as_secretary(
    db,
    secretary_uid: str,
    appointment_id: str,
    status_value: str,
    logger: logging.Logger,
) -> AppointmentOut:
    """Update appointment status on behalf of a connected doctor."""
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Appointment '{appointment_id}' not found.",
        )

    data = snapshot.to_dict() or {}
    appt_doctor_uid = data.get("doctor_uid")
    connected_doctors = _connected_doctor_uids_for_secretary(db, secretary_uid)
    if appt_doctor_uid not in connected_doctors:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to update this appointment.",
        )

    updates = {
        "status": status_value,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }
    try:
        doc_ref.update(updates)
        snapshot = doc_ref.get()
        updated_data = snapshot.to_dict() or {}
        return _map_doc_to_out(db, appointment_id, updated_data)
    except Exception as exc:
        logger.exception("Failed to update appointment status: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update appointment status.",
        )


def update_appointment_status(
    db,
    appointment_id: str,
    doctor_uid: str,
    status_value: str,
    logger: logging.Logger,
) -> AppointmentOut:
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Appointment '{appointment_id}' not found.",
        )

    data = snapshot.to_dict() or {}
    if data.get("doctor_uid") != doctor_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to update this appointment.",
        )

    updates = {
        "status": status_value,
        "updated_at": firestore.SERVER_TIMESTAMP,
    }

    try:
        doc_ref.update(updates)
        data.update(updates)
        data["updated_at"] = datetime.now(timezone.utc)
        return _map_doc_to_out(db, appointment_id, data)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to update appointment status: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update appointment status.",
        )

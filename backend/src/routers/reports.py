"""
Report Router — Patient Health Diary Summary.

Mounts at /api/reports (registered in api_router.py).

Patient endpoints:
  POST /api/reports/generate                  — generate diary summary (not persisted)
  POST /api/reports                           — save a report
  GET  /api/reports                           — list own reports
  GET  /api/reports/{report_id}               — get single report
  PATCH /api/reports/{report_id}              — edit report content
  DELETE /api/reports/{report_id}             — delete own report

Connection-gated endpoints (doctor / caregiver / secretary):
  POST /api/reports/patients/{patient_uid}/generate  — generate for connected patient
  POST /api/reports/patients/{patient_uid}            — save report for connected patient
  GET  /api/reports/patients/{patient_uid}            — list connected patient's reports
  GET  /api/reports/patients/{patient_uid}/{report_id} — get single report
  PATCH /api/reports/patients/{patient_uid}/{report_id} — edit report
  DELETE /api/reports/patients/{patient_uid}/{report_id} — delete report
"""

import logging

from fastapi import APIRouter, Depends, status
from fastapi.responses import StreamingResponse

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, require_roles

from src.schemas.report_schemas import (
    GeneratedSummaryResponse,
    ReportCreateRequest,
    ReportGenerateRequest,
    ReportListResponse,
    ReportResponse,
    ReportUpdateRequest,
)
from src.services.report_service import (
    _assert_report_access,
    delete_report,
    generate_pdf,
    generate_summary,
    get_report,
    list_reports,
    save_report,
    update_report,
)

router = APIRouter(prefix="/reports", tags=["reports"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Patient — generate (no persist)
# ---------------------------------------------------------------------------

@router.post(
    "/generate",
    response_model=GeneratedSummaryResponse,
    summary="Generate a diary-format summary of own journal entries",
)
def patient_generate(
    req: ReportGenerateRequest,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> GeneratedSummaryResponse:
    return generate_summary(current_user.uid, req.start_date, req.end_date, db, logger)


# ---------------------------------------------------------------------------
# Professional — generate for connected patient (no persist)
# ---------------------------------------------------------------------------

@router.post(
    "/patients/{patient_uid}/generate",
    response_model=GeneratedSummaryResponse,
    summary="Generate a diary-format summary for a connected patient",
)
def professional_generate(
    patient_uid: str,
    req: ReportGenerateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> GeneratedSummaryResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    return generate_summary(patient_uid, req.start_date, req.end_date, db, logger)


# ---------------------------------------------------------------------------
# Patient — generate PDF (no persist)
# ---------------------------------------------------------------------------

@router.post(
    "/generate/pdf",
    summary="Generate a diary-format PDF of own journal entries",
)
def patient_generate_pdf(
    req: ReportGenerateRequest,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> StreamingResponse:
    summary = generate_summary(current_user.uid, req.start_date, req.end_date, db, logger)
    pdf_bytes = generate_pdf(
        current_user.uid, None, req.start_date, req.end_date, db, logger
    )
    try:
        save_report(
            current_user.uid,
            current_user.uid,
            "patient",
            ReportCreateRequest(
                start_date=req.start_date,
                end_date=req.end_date,
                period=req.period,
                content=summary.content,
            ),
            db,
            logger,
        )
    except Exception:
        pass  # Don't fail PDF delivery if save fails
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=health_diary.pdf"},
    )


# ---------------------------------------------------------------------------
# Professional — generate PDF for connected patient (no persist)
# ---------------------------------------------------------------------------

@router.post(
    "/patients/{patient_uid}/generate/pdf",
    summary="Generate a diary-format PDF for a connected patient",
)
def professional_generate_pdf(
    patient_uid: str,
    req: ReportGenerateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> StreamingResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    summary = generate_summary(patient_uid, req.start_date, req.end_date, db, logger)
    pdf_bytes = generate_pdf(
        patient_uid, req.patient_name, req.start_date, req.end_date, db, logger
    )
    try:
        save_report(
            patient_uid,
            current_user.uid,
            current_user.role,
            ReportCreateRequest(
                start_date=req.start_date,
                end_date=req.end_date,
                period=req.period,
                content=summary.content,
            ),
            db,
            logger,
        )
    except Exception:
        pass  # Don't fail PDF delivery if save fails
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=health_diary.pdf"},
    )


# ---------------------------------------------------------------------------
# Patient — save report
# ---------------------------------------------------------------------------

@router.post(
    "",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Save a report for the authenticated patient",
)
def patient_save(
    req: ReportCreateRequest,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> ReportResponse:
    return save_report(current_user.uid, current_user.uid, "patient", req, db, logger)


# ---------------------------------------------------------------------------
# Professional — save report for connected patient
# ---------------------------------------------------------------------------

@router.post(
    "/patients/{patient_uid}",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Save a report for a connected patient",
)
def professional_save(
    patient_uid: str,
    req: ReportCreateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> ReportResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    return save_report(patient_uid, current_user.uid, current_user.role, req, db, logger)


# ---------------------------------------------------------------------------
# Patient — list own reports
# ---------------------------------------------------------------------------

@router.get(
    "",
    response_model=ReportListResponse,
    summary="List all reports for the authenticated patient",
)
def patient_list(
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> ReportListResponse:
    return list_reports(current_user.uid, db, logger)


# ---------------------------------------------------------------------------
# Professional — list connected patient's reports
# ---------------------------------------------------------------------------

@router.get(
    "/patients/{patient_uid}",
    response_model=ReportListResponse,
    summary="List reports for a connected patient",
)
def professional_list(
    patient_uid: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> ReportListResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    return list_reports(patient_uid, db, logger)


# ---------------------------------------------------------------------------
# Patient — get single report
# ---------------------------------------------------------------------------

@router.get(
    "/{report_id}",
    response_model=ReportResponse,
    summary="Get a single report (patient)",
)
def patient_get(
    report_id: str,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> ReportResponse:
    return get_report(report_id, current_user.uid, db, logger)


# ---------------------------------------------------------------------------
# Patient — view saved report as PDF (no new save)
# ---------------------------------------------------------------------------

@router.get(
    "/{report_id}/pdf",
    summary="Render a saved report as PDF (no new save)",
)
def patient_get_pdf(
    report_id: str,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> StreamingResponse:
    report = get_report(report_id, current_user.uid, db, logger)
    pdf_bytes = generate_pdf(
        current_user.uid, None, report.start_date, report.end_date, db, logger
    )
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=report_{report_id}.pdf"},
    )


# ---------------------------------------------------------------------------
# Professional — get single report for connected patient
# ---------------------------------------------------------------------------

@router.get(
    "/patients/{patient_uid}/{report_id}",
    response_model=ReportResponse,
    summary="Get a single report for a connected patient",
)
def professional_get(
    patient_uid: str,
    report_id: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> ReportResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    return get_report(report_id, patient_uid, db, logger)


# ---------------------------------------------------------------------------
# Professional — view saved patient report as PDF (no new save)
# ---------------------------------------------------------------------------

@router.get(
    "/patients/{patient_uid}/{report_id}/pdf",
    summary="Render a saved patient report as PDF (no new save)",
)
def professional_get_pdf(
    patient_uid: str,
    report_id: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> StreamingResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    report = get_report(report_id, patient_uid, db, logger)
    pdf_bytes = generate_pdf(
        patient_uid, None, report.start_date, report.end_date, db, logger
    )
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=report_{report_id}.pdf"},
    )


# ---------------------------------------------------------------------------
# Patient — edit report
# ---------------------------------------------------------------------------

@router.patch(
    "/{report_id}",
    response_model=ReportResponse,
    summary="Edit report content (patient)",
)
def patient_update(
    report_id: str,
    req: ReportUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> ReportResponse:
    return update_report(report_id, current_user.uid, req, db, logger)


# ---------------------------------------------------------------------------
# Professional — edit report for connected patient
# ---------------------------------------------------------------------------

@router.patch(
    "/patients/{patient_uid}/{report_id}",
    response_model=ReportResponse,
    summary="Edit report content for a connected patient",
)
def professional_update(
    patient_uid: str,
    report_id: str,
    req: ReportUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> ReportResponse:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    return update_report(report_id, patient_uid, req, db, logger)


# ---------------------------------------------------------------------------
# Patient — delete report
# ---------------------------------------------------------------------------

@router.delete(
    "/{report_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete own report (patient)",
)
def patient_delete(
    report_id: str,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> None:
    delete_report(report_id, current_user.uid, current_user.uid, db, logger)


# ---------------------------------------------------------------------------
# Professional — delete report for connected patient
# ---------------------------------------------------------------------------

@router.delete(
    "/patients/{patient_uid}/{report_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a connected patient's report",
)
def professional_delete(
    patient_uid: str,
    report_id: str,
    current_user: CurrentUser = Depends(require_roles("doctor", "caregiver", "secretary")),
) -> None:
    _assert_report_access(current_user.uid, patient_uid, db, current_user.role)
    delete_report(report_id, patient_uid, current_user.uid, db, logger)

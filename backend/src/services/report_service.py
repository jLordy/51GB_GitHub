"""
Report Service — Diary-Format Patient Journal Summary.

Fetches all journal entries for a patient within a date range and formats
them as a readable diary, grouped by day.  No AI or NLP — pure data
aggregation and string formatting.

Reports are persisted to Firestore:
  reports/{auto_id}
"""

import io
import logging
import uuid
from datetime import date, datetime, timezone

from fastapi import HTTPException, status
from google.cloud.firestore_v1.base_query import FieldFilter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    HRFlowable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.graphics.shapes import Drawing, String
from reportlab.graphics.charts.linecharts import HorizontalLineChart

from src.schemas.report_schemas import (
    GeneratedSummaryResponse,
    ReportCreateRequest,
    ReportListResponse,
    ReportResponse,
    ReportUpdateRequest,
)

_JOURNAL_ENTRIES_COLLECTION = "journal_entries"
_CONNECTIONS_COLLECTION = "connections"
_REPORTS_COLLECTION = "reports"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _is_directly_connected(uid_a: str, uid_b: str, db) -> bool:
    """Return True if uid_a and uid_b share an accepted connection."""
    for req, rec in ((uid_a, uid_b), (uid_b, uid_a)):
        docs = list(
            db.collection(_CONNECTIONS_COLLECTION)
            .where(filter=FieldFilter("requester_uid", "==", req))
            .where(filter=FieldFilter("recipient_uid", "==", rec))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .limit(1)
            .stream()
        )
        if docs:
            return True
    return False


def _secretary_connected_to_patient(secretary_uid: str, patient_uid: str, db) -> bool:
    """Return True if the secretary is connected to any doctor who is connected to patient_uid."""
    seen: set[str] = set()
    doctor_uids: set[str] = set()

    for field in ("requester_uid", "recipient_uid"):
        for doc in (
            db.collection(_CONNECTIONS_COLLECTION)
            .where(filter=FieldFilter(field, "==", secretary_uid))
            .where(filter=FieldFilter("status", "==", "accepted"))
            .stream()
        ):
            if doc.id in seen:
                continue
            seen.add(doc.id)
            data = doc.to_dict() or {}
            req = data.get("requester_uid")
            rec = data.get("recipient_uid")
            other = rec if req == secretary_uid else req
            if other and other != secretary_uid:
                user_snap = db.collection("users").document(other).get()
                if user_snap.exists:
                    role = str((user_snap.to_dict() or {}).get("role") or "").strip().lower()
                    if role == "doctor":
                        doctor_uids.add(other)

    for doctor_uid in doctor_uids:
        if _is_directly_connected(doctor_uid, patient_uid, db):
            return True
    return False


def _assert_report_access(viewer_uid: str, patient_uid: str, db, viewer_role: str = "") -> None:
    """
    Verify that viewer_uid may access patient_uid's reports.

    - Secretaries: authorised when connected to any doctor who is directly
      connected to the patient (secretary → doctor → patient chain).
    - Doctors / caregivers: require a direct accepted connection.

    Raises HTTP 403 if access is denied.
    """
    if viewer_role.lower() == "secretary":
        if not _secretary_connected_to_patient(viewer_uid, patient_uid, db):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not connected to this patient through a doctor.",
            )
        return

    if not _is_directly_connected(viewer_uid, patient_uid, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not connected to this patient.",
        )


def _humanise(key: str) -> str:
    """Convert snake_case key to a Title Case label, e.g. 'blood_pressure' → 'Blood Pressure'."""
    return " ".join(word.capitalize() for word in key.replace("_", " ").split())


def _format_value(value: object) -> str:
    """Render a journal answer value as a readable string."""
    if value is None:
        return "—"
    if isinstance(value, dict):
        # e.g. {"systolic": 120, "diastolic": 80} → "120 / 80"
        return " / ".join(str(v) for v in value.values())
    if isinstance(value, list):
        return ", ".join(_humanise(str(v)) for v in value) if value else "—"
    raw = str(value).replace("_", " ")
    return raw.capitalize() if raw else "—"


def _entry_to_diary_block(answers: dict) -> str:
    """Render a single journal entry's answers as indented lines."""
    if not answers:
        return "  (No answers recorded)"
    lines = []
    for key, val in answers.items():
        label = _humanise(key)
        formatted = _format_value(val)
        lines.append(f"  {label}: {formatted}")
    return "\n".join(lines)


def _day_heading(dt: datetime) -> str:
    """Format a date as 'Monday, April 6, 2026'."""
    # %-d is Linux-only; strip the leading zero manually for cross-platform support.
    return dt.strftime("%A, %B {day}, %Y").format(day=dt.day)


# ---------------------------------------------------------------------------
# Core: generate diary summary (not persisted)
# ---------------------------------------------------------------------------

def generate_summary(
    patient_uid: str,
    start_date: date,
    end_date: date,
    db,
    logger: logging.Logger,
) -> GeneratedSummaryResponse:
    """
    Fetch all journal entries for patient_uid between start_date and end_date
    (inclusive) and render them as a diary-style plain text string.

    Entries are sorted oldest-first and grouped under day headings.
    """
    start_dt = datetime(start_date.year, start_date.month, start_date.day, 0, 0, 0, tzinfo=timezone.utc)
    end_dt = datetime(end_date.year, end_date.month, end_date.day, 23, 59, 59, tzinfo=timezone.utc)

    docs = list(
        db.collection(_JOURNAL_ENTRIES_COLLECTION)
        .where(filter=FieldFilter("user_uid", "==", patient_uid))
        .where(filter=FieldFilter("submitted_at", ">=", start_dt))
        .where(filter=FieldFilter("submitted_at", "<=", end_dt))
        .order_by("submitted_at")
        .stream()
    )

    if not docs:
        content = (
            f"No journal entries found between "
            f"{start_date.strftime('%B {day}, %Y').format(day=start_date.day)}"
            f" and {end_date.strftime('%B {day}, %Y').format(day=end_date.day)}."
        )
        return GeneratedSummaryResponse(
            content=content,
            entry_count=0,
            start_date=start_date,
            end_date=end_date,
        )

    # Group entries by calendar day (local UTC date key: "YYYY-MM-DD")
    from collections import defaultdict
    day_entries: dict[str, list[dict]] = defaultdict(list)
    for doc in docs:
        data = doc.to_dict() or {}
        submitted_at = data.get("submitted_at")
        if submitted_at is None:
            continue
        # Firestore returns a DatetimeWithNanoseconds — convert to Python datetime
        if hasattr(submitted_at, "tzinfo") and submitted_at.tzinfo is None:
            submitted_at = submitted_at.replace(tzinfo=timezone.utc)
        day_key = submitted_at.strftime("%Y-%m-%d")
        day_entries[day_key].append(data)

    start_label = start_date.strftime("%B {day}, %Y").format(day=start_date.day)
    end_label = end_date.strftime("%B {day}, %Y").format(day=end_date.day)
    lines: list[str] = [
        "Health Diary",
        f"{start_label} — {end_label}",
        "=" * 44,
        "",
    ]

    for day_key in sorted(day_entries.keys()):
        entries_on_day = day_entries[day_key]
        day_dt = datetime.strptime(day_key, "%Y-%m-%d")
        lines.append(f"─── {_day_heading(day_dt)} ───")
        lines.append("")

        for idx, entry in enumerate(entries_on_day, start=1):
            if len(entries_on_day) > 1:
                illness = entry.get("illness_type", "")
                q_type = entry.get("question_set_type", "")
                label = illness.upper() if illness else q_type.replace("_", " ").title()
                lines.append(f"  [{label} — Entry {idx}]")
            answers = entry.get("answers") or {}
            lines.append(_entry_to_diary_block(answers))
            lines.append("")

    content = "\n".join(lines).rstrip()
    logger.info(
        "Generated diary summary for patient=%s: %d entries over %d days",
        patient_uid, len(docs), len(day_entries),
    )
    return GeneratedSummaryResponse(
        content=content,
        entry_count=len(docs),
        start_date=start_date,
        end_date=end_date,
    )


# ---------------------------------------------------------------------------
# Core: generate PDF (not persisted)
# ---------------------------------------------------------------------------

def generate_pdf(
    patient_uid: str,
    patient_name: str | None,
    start_date: date,
    end_date: date,
    db,
    logger: logging.Logger,
) -> bytes:
    """
    Fetch the patient profile and journal entries, then render a formatted
    PDF patient medical health record.  Returns raw PDF bytes.
    """
    from collections import defaultdict
    from xml.sax.saxutils import escape as xml_escape

    # ── Journal entries ──────────────────────────────────────────────────────
    start_dt = datetime(start_date.year, start_date.month, start_date.day, 0, 0, 0, tzinfo=timezone.utc)
    end_dt = datetime(end_date.year, end_date.month, end_date.day, 23, 59, 59, tzinfo=timezone.utc)

    docs = list(
        db.collection(_JOURNAL_ENTRIES_COLLECTION)
        .where(filter=FieldFilter("user_uid", "==", patient_uid))
        .where(filter=FieldFilter("submitted_at", ">=", start_dt))
        .where(filter=FieldFilter("submitted_at", "<=", end_dt))
        .order_by("submitted_at")
        .stream()
    )

    # ── Patient profile ──────────────────────────────────────────────────────
    patient_data: dict = {}
    try:
        p_docs = list(
            db.collection("patients")
            .where(filter=FieldFilter("user_uid", "==", patient_uid))
            .limit(1)
            .stream()
        )
        if p_docs:
            patient_data = p_docs[0].to_dict() or {}
    except Exception:
        pass  # Graceful degradation — still generate PDF without profile

    full_name = patient_data.get("full_name") or patient_name or "\u2014"
    dob_str: str = patient_data.get("date_of_birth") or ""
    intake: dict = patient_data.get("intake_profile") or {}
    illness_list = patient_data.get("illness_type") or []
    if isinstance(illness_list, str):
        illness_list = [illness_list]
    diabetes_type: str | None = patient_data.get("diabetes_type")
    ckd_stage: str | None = patient_data.get("ckd_stage")
    cancer_type: str | None = patient_data.get("cancer_type")

    # Age + date of birth
    dob_display = "\u2014"
    age_display = "\u2014"
    if dob_str:
        try:
            dob_d = date.fromisoformat(dob_str)
            dob_display = dob_d.strftime("%B {d}, %Y").format(d=dob_d.day)
            today = date.today()
            age = (
                today.year
                - dob_d.year
                - ((today.month, today.day) < (dob_d.month, dob_d.day))
            )
            age_display = f"{age} years old"
        except ValueError:
            pass

    # Conditions
    illness_parts: list[str] = []
    for t in illness_list:
        if t == "diabetes":
            lbl = "Diabetes"
            if diabetes_type:
                lbl += " (" + diabetes_type.replace("_", " ").title() + ")"
        elif t == "ckd":
            lbl = "Chronic Kidney Disease"
            if ckd_stage:
                lbl += " (Stage " + ckd_stage.split("_")[-1].upper() + ")"
        elif t == "oncology":
            lbl = "Oncology / Cancer"
            if cancer_type:
                lbl += " \u2013 " + cancer_type
        else:
            lbl = t.replace("_", " ").title()
        illness_parts.append(lbl)
    illness_display = ", ".join(illness_parts) if illness_parts else "\u2014"

    bio_sex = _humanise(intake.get("biological_sex") or "\u2014")
    ethnicity = _humanise(intake.get("ethnicity") or "\u2014")
    living = _humanise(intake.get("living_situation") or "\u2014")

    # Allergies
    has_allergies = intake.get("has_allergies", False)
    if has_allergies:
        all_allergens = (
            list(intake.get("allergy_medications") or [])
            + list(intake.get("allergy_food") or [])
            + list(intake.get("allergy_environmental") or [])
        )
        allergy_display = ", ".join(all_allergens) if all_allergens else "Yes (unspecified)"
    else:
        allergy_display = "None known"

    # Family history
    fam_parts: list[str] = []
    if intake.get("has_family_history"):
        for key, lbl in (
            ("family_history_diabetes", "Diabetes"),
            ("family_history_ckd", "CKD"),
            ("family_history_cancer", "Cancer"),
        ):
            val = (intake.get(key) or "unknown").lower()
            if val in ("yes", "unknown"):
                fam_parts.append(f"{lbl}: {val.title()}")
    fam_display = ", ".join(fam_parts) if fam_parts else "None reported"

    # ── Styles ──────────────────────────────────────────────────────────────
    base = getSampleStyleSheet()
    _GREEN = colors.HexColor("#1B8A5A")
    _DARK = colors.HexColor("#1A1A2E")
    _MUTED = colors.HexColor("#6B7280")
    _BORDER = colors.HexColor("#D1D5DB")
    _PALE = colors.HexColor("#F9FBF9")
    _WHITE = colors.white

    PAGE_W = A4[0] - 4 * cm  # usable width with 2 cm margins each side

    ban_title = ParagraphStyle("BanTitle", fontName="Helvetica-Bold", fontSize=18,
                               textColor=_WHITE, alignment=1, leading=24)
    ban_sub = ParagraphStyle("BanSub", fontName="Helvetica", fontSize=9,
                              textColor=colors.HexColor("#A7D7BB"), alignment=1, leading=13)
    lbl_s = ParagraphStyle("LblS", fontName="Helvetica-Bold", fontSize=8,
                            textColor=_MUTED, leading=11, spaceAfter=1)
    val_s = ParagraphStyle("ValS", fontName="Helvetica-Bold", fontSize=10,
                            textColor=_DARK, leading=14)
    sec_head = ParagraphStyle("SecHead", fontName="Helvetica-Bold", fontSize=11,
                               textColor=_GREEN, spaceBefore=14, spaceAfter=4, leading=14)
    day_head = ParagraphStyle("DayHead", fontName="Helvetica-Bold", fontSize=11,
                               textColor=_DARK, spaceBefore=12, spaceAfter=3, leading=14)
    entry_lbl = ParagraphStyle("EntryLbl", fontName="Helvetica-Bold", fontSize=9,
                                textColor=_GREEN, spaceBefore=4, spaceAfter=1, leading=12)
    fkey = ParagraphStyle("FKey", fontName="Helvetica-Bold", fontSize=9,
                           textColor=_DARK, leftIndent=10, leading=13)
    fval = ParagraphStyle("FVal", fontName="Helvetica", fontSize=9,
                           textColor=_MUTED, leftIndent=10, leading=13, spaceAfter=1)
    empty_s = ParagraphStyle("EmptyS", fontName="Helvetica-Oblique", fontSize=10,
                              textColor=_MUTED, alignment=1, spaceBefore=20)
    period_s = ParagraphStyle("PeriodS", fontName="Helvetica", fontSize=10,
                               textColor=_MUTED, spaceAfter=6, leading=14)

    # ── Date labels ──────────────────────────────────────────────────────────
    start_label = start_date.strftime("%B {d}, %Y").format(d=start_date.day)
    end_label = end_date.strftime("%B {d}, %Y").format(d=end_date.day)
    today_label = date.today().strftime("%B {d}, %Y").format(d=date.today().day)

    # ── Story ────────────────────────────────────────────────────────────────
    story = []

    # 1 — Green banner header
    banner_table = Table(
        [
            [Paragraph("PATIENT HEALTH RECORD", ban_title)],
            [Paragraph(f"Agapay Health  \u00b7  Generated {today_label}", ban_sub)],
        ],
        colWidths=[PAGE_W],
    )
    banner_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), _GREEN),
        ("TOPPADDING", (0, 0), (0, 0), 14),
        ("BOTTOMPADDING", (0, 0), (0, 0), 2),
        ("TOPPADDING", (0, 1), (0, 1), 2),
        ("BOTTOMPADDING", (0, 1), (0, 1), 12),
        ("LEFTPADDING", (0, 0), (-1, -1), 16),
        ("RIGHTPADDING", (0, 0), (-1, -1), 16),
    ]))
    story.append(banner_table)
    story.append(Spacer(1, 10))

    # 2 — Patient information table (label | value | label | value)
    def _lbl(t: str) -> Paragraph:
        return Paragraph(t.upper(), lbl_s)

    def _val(t: str) -> Paragraph:
        return Paragraph(xml_escape(str(t)), val_s)

    LW = PAGE_W * 0.22   # label column
    VW = PAGE_W * 0.28   # value column
    period_val = f"{start_label} \u2014 {end_label}"

    info_table = Table(
        [
            [_lbl("Full Name"),      _val(full_name),       _lbl("Date of Birth"),    _val(dob_display)],
            [_lbl("Age"),            _val(age_display),     _lbl("Biological Sex"),   _val(bio_sex)],
            [_lbl("Ethnicity"),      _val(ethnicity),       _lbl("Living Situation"), _val(living)],
            [_lbl("Condition(s)"),   _val(illness_display), _lbl("Allergies"),        _val(allergy_display)],
            [_lbl("Family History"), _val(fam_display),     _lbl("Report Period"),    _val(period_val)],
        ],
        colWidths=[LW, VW, LW, VW],
    )
    info_table.setStyle(TableStyle([
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [_WHITE, _PALE]),
        ("BOX", (0, 0), (-1, -1), 1, _GREEN),
        ("LINEBELOW", (0, 0), (-1, -2), 0.5, _BORDER),
        ("LINEAFTER", (1, 0), (1, -1), 0.5, _BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 14))

    # 3 — Health diary section heading
    story.append(Paragraph("HEALTH DIARY", sec_head))
    story.append(HRFlowable(width="100%", thickness=1.5, color=_GREEN, spaceAfter=8))
    story.append(Paragraph(f"Period: {start_label} \u2014 {end_label}", period_s))

    # 4 — Journal entries (with entry time, trend charts, compact table layout)
    if not docs:
        story.append(
            Paragraph(
                f"No journal entries found between "
                f"{xml_escape(start_label)} and {xml_escape(end_label)}.",
                empty_s,
            )
        )
    else:
        # ── Collect entries + numeric metrics for trend charts ────────────
        day_entries: dict[str, list[dict]] = defaultdict(list)
        metric_series: dict[str, list[tuple[str, float]]] = defaultdict(list)

        for firestore_doc in docs:
            data = firestore_doc.to_dict() or {}
            submitted_at_raw = data.get("submitted_at")
            if submitted_at_raw is None:
                continue
            submitted_at_ts = submitted_at_raw
            if hasattr(submitted_at_ts, "tzinfo") and submitted_at_ts.tzinfo is None:
                submitted_at_ts = submitted_at_ts.replace(tzinfo=timezone.utc)
            day_key = submitted_at_ts.strftime("%Y-%m-%d")
            # Format entry time in 12-hour clock
            h = submitted_at_ts.hour
            m = submitted_at_ts.minute
            h12 = h % 12 or 12
            ampm = "AM" if h < 12 else "PM"
            data["_entry_time"] = f"{h12}:{m:02d} {ampm}"
            day_entries[day_key].append(data)
            # Collect numeric fields for trend lines
            answers = data.get("answers") or {}
            for ak, av in answers.items():
                if isinstance(av, (int, float)):
                    metric_series[_humanise(ak)].append((day_key, float(av)))
                elif isinstance(av, dict):
                    for sub_k, sub_v in av.items():
                        if isinstance(sub_v, (int, float)):
                            metric_series[
                                f"{_humanise(ak)} \u2013 {_humanise(sub_k)}"
                            ].append((day_key, float(sub_v)))

        # ── Clinical trend charts (metrics with 2+ distinct-day readings) ──
        chartable = {
            name: sorted(pts, key=lambda p: p[0])
            for name, pts in metric_series.items()
            if len({p[0] for p in pts}) >= 2
        }
        if chartable:
            story.append(Paragraph("CLINICAL TRENDS", sec_head))
            story.append(HRFlowable(width="100%", thickness=1, color=_BORDER, spaceAfter=8))

            # Decide layout: ≤ 4 data points → larger 2-per-row; else 3-per-row
            metrics_list = list(chartable.items())
            max_pts = max(len({p[0] for p in pts}) for _, pts in metrics_list)
            cols = 2 if max_pts <= 4 else 3
            CHART_W = float(PAGE_W) / cols - 6
            CHART_H = 120.0

            def _build_chart(metric_name: str, pts: list) -> Drawing:
                day_map: dict[str, float] = {}
                for dk, v in pts:
                    day_map[dk] = v
                sorted_days = sorted(day_map.keys())
                values = [day_map[d] for d in sorted_days]
                n_days = len(sorted_days)
                label_step = max(1, n_days // 6)
                day_labels = []
                for i, dk in enumerate(sorted_days):
                    if i % label_step == 0:
                        dt = datetime.strptime(dk, "%Y-%m-%d")
                        day_labels.append(dt.strftime("%b ") + str(dt.day))
                    else:
                        day_labels.append("")
                d = Drawing(CHART_W, CHART_H)
                lc = HorizontalLineChart()
                lc.x = 38
                lc.y = 32
                lc.width = CHART_W - 46
                lc.height = CHART_H - 52
                lc.data = [values]
                lc.categoryAxis.categoryNames = day_labels
                lc.categoryAxis.labels.fontSize = 6
                lc.categoryAxis.labels.angle = 30
                lc.categoryAxis.labels.boxAnchor = "ne"
                lc.valueAxis.labels.fontSize = 6
                lc.valueAxis.labelTextFormat = "%.1f"
                lc.lines[0].strokeColor = _GREEN
                lc.lines[0].strokeWidth = 1.5
                title_label = String(
                    CHART_W / 2, CHART_H - 8, metric_name,
                    fontSize=7.5, fontName="Helvetica-Bold",
                    fillColor=_DARK, textAnchor="middle",
                )
                d.add(lc)
                d.add(title_label)
                return d

            # Pack drawings into rows of `cols` cells using a Table
            drawings = [_build_chart(name, pts) for name, pts in metrics_list]
            rows = []
            for i in range(0, len(drawings), cols):
                chunk = drawings[i:i + cols]
                # Pad the last row with empty strings so column count is uniform
                while len(chunk) < cols:
                    chunk.append("")
                rows.append(chunk)

            col_w = [PAGE_W / cols] * cols
            chart_table = Table(rows, colWidths=col_w)
            chart_table.setStyle(TableStyle([
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
            ]))
            story.append(chart_table)
            story.append(Spacer(1, 8))

        # ── Cross-tab diary table (rows = fields, columns = entries) ──────
        story.append(Spacer(1, 4))

        # Attach day key back to each entry and build flat chronological list
        all_entries: list[dict] = []
        for dk in sorted(day_entries.keys()):
            for e in day_entries[dk]:
                e["_submitted_day"] = dk
            all_entries.extend(day_entries[dk])

        # Collect all field keys in order of first appearance
        seen_keys: list[str] = []
        seen_keys_set: set[str] = set()
        for entry in all_entries:
            for ak in (entry.get("answers") or {}).keys():
                if ak not in seen_keys_set:
                    seen_keys.append(ak)
                    seen_keys_set.add(ak)

        if not seen_keys:
            story.append(Paragraph("(No answers recorded)", empty_s))
        else:
            LABEL_W = float(PAGE_W) * 0.28
            MAX_COLS = 7  # max entry columns per sub-table

            def _col_hdr_text(e: dict) -> str:
                dk = e.get("_submitted_day", "")
                try:
                    dt = datetime.strptime(dk, "%Y-%m-%d")
                    date_str = f"{dt.month}/{dt.day}"
                except (ValueError, TypeError):
                    date_str = dk
                entry_time = e.get("_entry_time", "")
                return "\n".join(p for p in [date_str, entry_time] if p)

            chunks = [
                all_entries[i:i + MAX_COLS]
                for i in range(0, len(all_entries), MAX_COLS)
            ]

            for chunk_idx, chunk in enumerate(chunks):
                n_cols = len(chunk)
                col_w = (float(PAGE_W) - LABEL_W) / n_cols
                font_sz = (
                    8 if col_w >= 2.2 * cm
                    else (7 if col_w >= 1.6 * cm else 6)
                )

                col_hdr_s = ParagraphStyle(
                    f"ColHdr{chunk_idx}", fontName="Helvetica-Bold",
                    fontSize=font_sz, textColor=_WHITE, alignment=1,
                    leading=font_sz + 2,
                )
                row_lbl_s = ParagraphStyle(
                    f"RowLbl{chunk_idx}", fontName="Helvetica-Bold",
                    fontSize=font_sz, textColor=_DARK, leading=font_sz + 2,
                )
                cell_val_s = ParagraphStyle(
                    f"CellVal{chunk_idx}", fontName="Helvetica",
                    fontSize=font_sz, textColor=_DARK, alignment=1,
                    leading=font_sz + 2,
                )

                hdr_row = [Paragraph("Field", col_hdr_s)] + [
                    Paragraph(xml_escape(_col_hdr_text(e)), col_hdr_s)
                    for e in chunk
                ]
                tbl_rows = [hdr_row]
                for ak in seen_keys:
                    row = [Paragraph(xml_escape(_humanise(ak)), row_lbl_s)]
                    for e in chunk:
                        answers = e.get("answers") or {}
                        val = _format_value(answers.get(ak)) if ak in answers else "\u2014"
                        row.append(Paragraph(xml_escape(val), cell_val_s))
                    tbl_rows.append(row)

                col_widths = [LABEL_W] + [col_w] * n_cols
                cross_tbl = Table(tbl_rows, colWidths=col_widths, repeatRows=1)
                cross_tbl.setStyle(TableStyle([
                    ("ROWBACKGROUNDS", (1, 1), (-1, -1), [_WHITE, _PALE]),
                    ("BOX", (0, 0), (-1, -1), 0.75, _GREEN),
                    ("LINEBELOW", (0, 0), (-1, -1), 0.25, _BORDER),
                    ("LINEAFTER", (0, 0), (-1, -1), 0.25, _BORDER),
                    ("BACKGROUND", (0, 0), (-1, 0), _GREEN),
                    ("BACKGROUND", (0, 1), (0, -1), colors.HexColor("#EAF4ED")),
                    ("LINEAFTER", (0, 0), (0, -1), 0.75, _GREEN),
                    ("TOPPADDING", (0, 0), (-1, -1), 3),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                    ("LEFTPADDING", (0, 0), (-1, -1), 4),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                    ("ALIGN", (1, 0), (-1, -1), "CENTER"),
                ]))
                story.append(cross_tbl)
                if chunk_idx < len(chunks) - 1:
                    story.append(Spacer(1, 14))

    # ── Render to bytes ──────────────────────────────────────────────────────
    buffer = io.BytesIO()
    pdf_doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )
    pdf_doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()

    logger.info(
        "Generated medical PDF for patient=%s: %d entries",
        patient_uid, len(docs),
    )
    return pdf_bytes

def save_report(
    patient_uid: str,
    generated_by_uid: str,
    generated_by_role: str,
    req: ReportCreateRequest,
    db,
    logger: logging.Logger,
) -> ReportResponse:
    """Write a new report document to Firestore."""
    now = datetime.now(tz=timezone.utc)
    report_id = str(uuid.uuid4())
    doc_data = {
        "report_id": report_id,
        "patient_uid": patient_uid,
        "generated_by_uid": generated_by_uid,
        "generated_by_role": generated_by_role,
        "start_date": req.start_date.isoformat(),
        "end_date": req.end_date.isoformat(),
        "period": req.period,
        "content": req.content,
        "created_at": now,
        "updated_at": now,
        "edit_count": 0,
    }
    db.collection(_REPORTS_COLLECTION).document(report_id).set(doc_data)
    logger.info("Saved report report_id=%s for patient=%s", report_id, patient_uid)
    return _doc_to_response(doc_data)


def list_reports(patient_uid: str, db, logger: logging.Logger) -> ReportListResponse:
    """List all reports for a patient, newest first."""
    docs = list(
        db.collection(_REPORTS_COLLECTION)
        .where(filter=FieldFilter("patient_uid", "==", patient_uid))
        .order_by("created_at", direction="DESCENDING")
        .stream()
    )
    reports = [_doc_to_response(d.to_dict()) for d in docs if d.to_dict()]
    return ReportListResponse(reports=reports)


def get_report(report_id: str, patient_uid: str, db, logger: logging.Logger) -> ReportResponse:
    """Fetch a single report, verifying it belongs to patient_uid."""
    doc = db.collection(_REPORTS_COLLECTION).document(report_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found.")
    data = doc.to_dict()
    if data.get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    return _doc_to_response(data)


def update_report(
    report_id: str,
    patient_uid: str,
    req: ReportUpdateRequest,
    db,
    logger: logging.Logger,
) -> ReportResponse:
    """Edit report content; increments edit_count."""
    doc_ref = db.collection(_REPORTS_COLLECTION).document(report_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found.")
    data = doc.to_dict()
    if data.get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")

    now = datetime.now(tz=timezone.utc)
    updates = {
        "content": req.content,
        "updated_at": now,
        "edit_count": data.get("edit_count", 0) + 1,
    }
    doc_ref.update(updates)
    data.update(updates)
    logger.info("Updated report report_id=%s", report_id)
    return _doc_to_response(data)


def delete_report(
    report_id: str,
    patient_uid: str,
    requester_uid: str,
    db,
    logger: logging.Logger,
) -> None:
    """Delete a report. Allowed only by the patient (owner) or the generator."""
    doc = db.collection(_REPORTS_COLLECTION).document(report_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found.")
    data = doc.to_dict()
    if data.get("patient_uid") != patient_uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    if requester_uid != patient_uid and requester_uid != data.get("generated_by_uid"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the patient or the report generator may delete this report.",
        )
    db.collection(_REPORTS_COLLECTION).document(report_id).delete()
    logger.info("Deleted report report_id=%s by requester=%s", report_id, requester_uid)


# ---------------------------------------------------------------------------
# Private helper
# ---------------------------------------------------------------------------

def _doc_to_response(data: dict) -> ReportResponse:
    """Convert a raw Firestore dict to a ReportResponse."""

    def _to_date(val) -> date:
        if isinstance(val, date):
            return val
        return date.fromisoformat(str(val))

    def _to_dt(val) -> datetime:
        if isinstance(val, datetime):
            if val.tzinfo is None:
                return val.replace(tzinfo=timezone.utc)
            return val
        return datetime.fromisoformat(str(val)).replace(tzinfo=timezone.utc)

    return ReportResponse(
        report_id=data["report_id"],
        patient_uid=data["patient_uid"],
        generated_by_uid=data["generated_by_uid"],
        generated_by_role=data["generated_by_role"],
        start_date=_to_date(data["start_date"]),
        end_date=_to_date(data["end_date"]),
        period=data.get("period", "custom"),
        content=data["content"],
        created_at=_to_dt(data["created_at"]),
        updated_at=_to_dt(data["updated_at"]),
        edit_count=data.get("edit_count", 0),
    )

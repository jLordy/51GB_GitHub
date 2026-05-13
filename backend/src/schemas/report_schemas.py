"""Pydantic request/response models for the reports module."""

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class ReportGenerateRequest(BaseModel):
    start_date: date
    end_date: date
    period: str = Field(default="custom", pattern=r"^(week|month|year|custom)$")
    patient_name: Optional[str] = None  # used as PDF heading for professional view


class ReportCreateRequest(BaseModel):
    start_date: date
    end_date: date
    period: str = Field(default="custom", pattern=r"^(week|month|year|custom)$")
    content: str


class ReportUpdateRequest(BaseModel):
    content: str


class ReportResponse(BaseModel):
    report_id: str
    patient_uid: str
    generated_by_uid: str
    generated_by_role: str
    start_date: date
    end_date: date
    period: str
    content: str
    created_at: datetime
    updated_at: datetime
    edit_count: int


class ReportListResponse(BaseModel):
    reports: List[ReportResponse]


class GeneratedSummaryResponse(BaseModel):
    content: str
    entry_count: int
    start_date: date
    end_date: date

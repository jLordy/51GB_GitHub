"""
Companion Router — AI companion endpoints.

Mounts at /api/companion (registered in api_router.py).

Endpoints:
  POST /api/companion         — send a message, receive an AI reply
  GET  /api/companion/health  — Ollama reachability probe (for Flutter session init)
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status

from src.firebase import get_firestore_client
from src.middleware import CurrentUser, require_roles
from src.schemas.companion_schemas import (
    CompanionHealthResponse,
    CompanionRequest,
    CompanionResponse,
)
from src.services.companion_service import check_ollama_health, get_companion_reply

router = APIRouter(prefix="/companion", tags=["companion"])
db = get_firestore_client()
logger = logging.getLogger(__name__)


@router.post(
    "",
    response_model=CompanionResponse,
    summary="Send a message to the AI companion",
    description=(
        "Accepts the user's message, fetches their latest journal entry as context, "
        "and returns an AI response from Ollama (gemma3:4b). "
        "Returns HTTP 503 if Ollama is unreachable — the Flutter client will fall back "
        "to local hardcoded responses silently."
    ),
)
async def chat_with_companion(
    payload: CompanionRequest,
    current_user: CurrentUser = Depends(require_roles("patient")),
) -> CompanionResponse:
    try:
        reply = await get_companion_reply(
            message=payload.message,
            user_uid=current_user.uid,
            db=db,
        )
        return CompanionResponse(reply=reply)
    except RuntimeError as exc:
        # Already logged inside companion_service with full details.
        logger.warning("[COMPANION] Returning 503 to client: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI service unavailable",
        ) from exc


@router.get(
    "/health",
    response_model=CompanionHealthResponse,
    summary="Check Ollama reachability",
    description=(
        "Flutter calls this once at session start. "
        "Returns 200 {'status': 'ok'} if Ollama is running, "
        "503 {'status': 'unavailable'} if not."
    ),
)
async def companion_health() -> CompanionHealthResponse:
    if await check_ollama_health():
        return CompanionHealthResponse(status="ok")
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="AI service unavailable",
    )

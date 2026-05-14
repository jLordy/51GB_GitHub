"""
Companion Service — AI companion logic for AGAPAY.

Responsibilities:
  1. Fetch the authenticated user's most recent journal entry from Firestore.
  2. Build a context-aware system prompt (base prompt + optional journal context).
  3. Call Ollama (gemma3:4b) with the user's message.
  4. Return the AI response text, or raise a RuntimeError on failure so the
     router can return HTTP 503 and the Flutter client can fall back silently.

All Ollama errors are logged explicitly to the terminal for developer visibility.
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any

import httpx
from google.cloud.firestore_v1.base_query import FieldFilter

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration (read from environment — set in src/.env)
# ---------------------------------------------------------------------------

_OLLAMA_URL: str = os.getenv("OLLAMA_URL", "http://localhost:11434")
_OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "gemma3:4b")
_OLLAMA_TIMEOUT: float = 30.0  # seconds — Ollama can be slow on first token

_JOURNAL_ENTRIES_COLLECTION = "journal_entries"

# ---------------------------------------------------------------------------
# Base system prompt (mirrors the Python prototype)
# ---------------------------------------------------------------------------

_BASE_SYSTEM_PROMPT = """You are AGAPAY, a compassionate health companion for a health \
journal and tracking app. Your role is to:
- Provide empathetic support for health-related topics
- Give concise, practical health advice (1-2 sentences maximum)
- Respond in natural sentence form without bullets
- Be a supportive companion, not a doctor
- Keep responses brief and actionable
- STRICTLY If the user uses Tagalog in any word in his sentence, speak in Tagalog too!
- If the user speaks English, respond in English
- Always prioritize user wellbeing and encourage proper medical care when needed
- Stay professional but empathetic in tone
- Address the problem directly. Don't refer to doctors if problem is manageable.
- DO NOT call user "honey", no name-calling.

Keep your responses to 1-2 sentences only. Be straightforward and helpful."""


# ---------------------------------------------------------------------------
# Journal context helpers
# ---------------------------------------------------------------------------

def _fetch_latest_journal_entry(user_uid: str, db: Any) -> dict | None:
    """
    Fetch the single most recent journal entry for the user from Firestore.
    Returns the entry dict, or None if none exists or Firestore fails.
    """
    try:
        docs = list(
            db.collection(_JOURNAL_ENTRIES_COLLECTION)
            .where(filter=FieldFilter("user_uid", "==", user_uid))
            .order_by("submitted_at", direction="DESCENDING")
            .limit(1)
            .stream()
        )
        if not docs:
            return None
        data: dict = docs[0].to_dict() or {}
        return data
    except Exception as exc:
        logger.warning("[COMPANION] Failed to fetch journal entry for uid=%s: %s", user_uid, exc)
        return None


def _format_answers(answers: dict[str, Any]) -> str:
    """
    Serialize the answers dict to a compact, readable string for the prompt.
    Keys are question IDs (e.g. 'q_mood', 'q_bp_systolic') — values can be
    strings, numbers, or lists.
    """
    if not answers:
        return "(no answers recorded)"
    try:
        return json.dumps(answers, ensure_ascii=False, indent=None, separators=(", ", ": "))
    except Exception:
        return str(answers)


def _build_system_prompt(user_uid: str, db: Any) -> str:
    """
    Build the full system prompt, optionally injecting the latest journal entry
    as context. If no entry exists or Firestore fails, returns the base prompt.
    """
    entry = _fetch_latest_journal_entry(user_uid, db)
    if not entry:
        return _BASE_SYSTEM_PROMPT

    answers: dict = entry.get("answers", {})
    submitted_at = entry.get("submitted_at")
    illness_type: str = entry.get("illness_type", "")

    # Format submission date for readability
    date_str = ""
    if isinstance(submitted_at, datetime):
        date_str = submitted_at.astimezone(timezone.utc).strftime("%Y-%m-%d")
    elif submitted_at is not None:
        date_str = str(submitted_at)

    context_parts = []
    if date_str:
        context_parts.append(f"(submitted {date_str})")
    if illness_type:
        context_parts.append(f"Illness type: {illness_type}.")
    context_parts.append(f"Answers: {_format_answers(answers)}")

    journal_context = "\n".join(context_parts)

    return (
        f"{_BASE_SYSTEM_PROMPT}\n\n"
        f"The user's most recent journal entry:\n"
        f"{journal_context}\n\n"
        f"Use this as background context to give more relevant, personalized responses. "
        f"Do not mention the journal entry directly unless the user brings it up."
    )


# ---------------------------------------------------------------------------
# Ollama call
# ---------------------------------------------------------------------------

async def get_companion_reply(message: str, user_uid: str, db: Any) -> str:
    """
    Call Ollama with the user's message and journal context.

    Raises RuntimeError if Ollama is unreachable, times out, or returns an
    invalid response — the router catches this and returns HTTP 503.

    All errors are printed to the terminal for developer visibility.
    """
    system_prompt = _build_system_prompt(user_uid, db)

    payload = {
        "model": _OLLAMA_MODEL,
        "prompt": message,
        "system": system_prompt,
        "stream": False,
        "options": {
            "num_predict": 120,
            "temperature": 0.7,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=_OLLAMA_TIMEOUT) as client:
            response = await client.post(
                f"{_OLLAMA_URL}/api/generate",
                json=payload,
            )
            response.raise_for_status()
            data = response.json()
    except httpx.TimeoutException as exc:
        print(f"[COMPANION] Ollama timeout after {_OLLAMA_TIMEOUT}s: {exc}")
        raise RuntimeError("Ollama request timed out") from exc
    except httpx.ConnectError as exc:
        print(f"[COMPANION] Ollama connection refused at {_OLLAMA_URL}: {exc}")
        raise RuntimeError("Ollama is unreachable") from exc
    except httpx.HTTPStatusError as exc:
        print(f"[COMPANION] Ollama HTTP error {exc.response.status_code}: {exc}")
        raise RuntimeError(f"Ollama returned HTTP {exc.response.status_code}") from exc
    except Exception as exc:
        print(f"[COMPANION] Unexpected error calling Ollama: {exc}")
        raise RuntimeError("Unexpected Ollama error") from exc

    reply: str = data.get("response", "").strip()
    if not reply:
        print(f"[COMPANION] Ollama returned empty response. Full payload: {data}")
        raise RuntimeError("Ollama returned an empty response")

    return reply


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

async def check_ollama_health() -> bool:
    """
    Ping Ollama's /api/tags endpoint to verify it is running.
    Returns True if reachable, False otherwise.
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{_OLLAMA_URL}/api/tags")
            return resp.status_code == 200
    except Exception as exc:
        print(f"[COMPANION] Ollama health check failed: {exc}")
        return False

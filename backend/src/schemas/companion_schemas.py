"""
Companion Schemas — AI Companion endpoint contract.

POST /api/companion  — user sends a message, receives an AI reply.
GET  /api/companion/health — Ollama reachability check.
"""

from pydantic import BaseModel, Field


class CompanionRequest(BaseModel):
    message: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="The user's message to the AI companion.",
    )


class CompanionResponse(BaseModel):
    reply: str = Field(..., description="The AI companion's response text.")


class CompanionHealthResponse(BaseModel):
    status: str = Field(..., description="'ok' if Ollama is reachable, 'unavailable' otherwise.")

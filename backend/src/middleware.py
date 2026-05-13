"""
FastAPI dependency-injection helpers for Firebase token verification.
"""

import logging
from dataclasses import dataclass
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth

from src.firebase import get_firestore_client

logger = logging.getLogger(__name__)

_bearer = HTTPBearer(auto_error=False)


@dataclass
class CurrentUser:
    """Parsed + enriched identity attached to every authenticated request."""
    uid: str
    email: Optional[str]
    role: str    # lowercased Firestore role, e.g. "patient" | "doctor" | "admin"
    status: str  # lowercased Firestore status, e.g. "active" | "onboarding"


def _token_to_current_user(token: str, *, allow_anonymous: bool) -> CurrentUser:
    """Verify a Firebase ID token and load role/status from Firestore."""
    try:
        decoded = firebase_auth.verify_id_token(token, check_revoked=True)
    except firebase_auth.RevokedIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except firebase_auth.UserDisabledError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been disabled.",
        )
    except Exception:
        logger.exception("Token verification failed")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or unverifiable token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not allow_anonymous:
        provider = decoded.get("firebase", {}).get("sign_in_provider", "")
        if provider == "anonymous":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Anonymous sessions cannot access this resource.",
            )

    uid: str = decoded["uid"]
    email: Optional[str] = decoded.get("email")

    db = get_firestore_client()
    doc = db.collection("users").document(uid).get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    user_data: dict = doc.to_dict() or {}
    return CurrentUser(
        uid=uid,
        email=email,
        role=user_data.get("role", "").lower(),
        status=user_data.get("status", "").lower(),
    )


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> Optional[CurrentUser]:
    """Return CurrentUser if a valid Bearer token is present, else None."""
    if not credentials or not credentials.credentials:
        return None
    try:
        return _token_to_current_user(credentials.credentials, allow_anonymous=True)
    except HTTPException:
        return None


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> CurrentUser:
    """Require a valid Bearer token; raise 401 if missing or invalid."""
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _token_to_current_user(credentials.credentials, allow_anonymous=True)


async def get_authenticated_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> CurrentUser:
    """Require a valid, non-anonymous Bearer token; raise 401/403 otherwise."""
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _token_to_current_user(credentials.credentials, allow_anonymous=False)


def require_roles(*roles: str):
    """Dependency factory that restricts an endpoint to the given roles.

    Usage:
        current_user: CurrentUser = Depends(require_roles("admin"))
    """
    role_set = {r.lower() for r in roles}

    async def _check(
        current_user: CurrentUser = Depends(get_authenticated_user),
    ) -> CurrentUser:
        if current_user.role.lower() not in role_set:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions.",
            )
        return current_user

    return _check

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import auth as firebase_auth
from google.cloud.firestore_v1 import Client

from src.firebase import get_firestore_client

logger = logging.getLogger(__name__)


def register_user_profile(
    db: Client,
    payload: dict[str, Any],
    log: logging.Logger,
) -> tuple[str, dict[str, Any]]:
    """Create a Firebase Auth account and a matching Firestore user document."""
    email: str = str(payload["email"]).strip().lower()
    password: str = str(payload["password"])
    display_name: str = str(payload.get("display_name", "")).strip()

    try:
        firebase_user = firebase_auth.create_user(
            email=email,
            password=password,
            display_name=display_name or None,
        )
    except firebase_auth.EmailAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This email is already registered.",
        ) from exc
    except Exception as exc:
        log.exception("Firebase user creation failed for %s: %s", email, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to create user account.",
        ) from exc

    uid = firebase_user.uid
    user_doc: dict[str, Any] = {
        "uid": uid,
        "email": email,
        "role": "pending",
        "status": "pending",
        "display_name": display_name or None,
        "photo_url": None,
        "bio": None,
        "date_of_birth": None,
        "is_private": False,
        "notifications_enabled": True,
        "created_at": datetime.now(timezone.utc),
    }

    try:
        db.collection("users").document(uid).set(user_doc)
    except Exception as exc:
        log.exception("Firestore write failed for uid=%s: %s", uid, exc)
        # Roll back the Firebase Auth account so the user can retry cleanly.
        try:
            firebase_auth.delete_user(uid)
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to save user profile.",
        ) from exc

    log.info("Registered new user uid=%s email=%s", uid, email)
    return uid, user_doc


def purge_user_data(db: Client, uid: str, log: logging.Logger) -> None:
    """Delete all Firestore data owned by uid."""
    for collection in ("posts", "journal_entries", "messages"):
        docs = db.collection(collection).where("uid", "==", uid).stream()
        batch = db.batch()
        count = 0
        for doc in docs:
            batch.delete(doc.reference)
            count += 1
            if count == 500:
                batch.commit()
                batch = db.batch()
                count = 0
        if count > 0:
            batch.commit()

    db.collection("users").document(uid).delete()
    log.info("Purged Firestore data for uid=%s", uid)


def list_all_users() -> list[dict[str, str | None]]:
    """Return every user document from Firestore."""
    db = get_firestore_client()
    return [doc.to_dict() or {} for doc in db.collection("users").stream()]


def browse_users(query: str) -> list[dict[str, str | None]]:
    """Search users by display_name or email (case-insensitive prefix, admin use)."""
    db = get_firestore_client()
    q = query.strip().lower()
    results: list[dict] = []
    seen: set[str] = set()
    for doc in db.collection("users").stream():
        data = doc.to_dict() or {}
        uid = data.get("uid", doc.id)
        if uid in seen:
            continue
        name = (data.get("display_name") or "").lower()
        email = (data.get("email") or "").lower()
        if q in name or q in email:
            results.append(data)
            seen.add(uid)
    return results


def update_user_role(uid: str, role: str) -> dict[str, str | None]:
    """Set a new role for uid and return the updated user dict."""
    db = get_firestore_client()
    normalized = role.strip().lower()
    db.collection("users").document(uid).update({"role": normalized})
    doc = db.collection("users").document(uid).get()
    return doc.to_dict() or {}


def toggle_user_status(uid: str, disabled: bool) -> dict[str, str | None]:
    """Enable or disable uid in Firebase Auth + Firestore."""
    firebase_auth.update_user(uid, disabled=disabled)
    db = get_firestore_client()
    new_status = "disabled" if disabled else "active"
    db.collection("users").document(uid).update({"status": new_status})
    doc = db.collection("users").document(uid).get()
    return doc.to_dict() or {}


def delete_user_record(uid: str) -> None:
    """Remove uid from Firebase Auth and Firestore."""
    db = get_firestore_client()
    db.collection("users").document(uid).delete()
    try:
        firebase_auth.delete_user(uid)
    except firebase_auth.UserNotFoundError:
        pass

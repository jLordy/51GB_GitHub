import json
import logging
import os
import secrets
import resend
from google.cloud.firestore_v1.base_query import FieldFilter
from datetime import datetime, timedelta, timezone
from urllib import error as urllib_error
from urllib import request as urllib_request

from fastapi import APIRouter, Body, Depends, HTTPException, status
from firebase_admin import auth

from src.auth import (
    delete_user_record,
    list_all_users,
    purge_user_data,
    register_user_profile,
    toggle_user_status,
    update_user_role,
)
from src.firebase import get_firestore_client
from src.middleware import (
    CurrentUser,
    get_authenticated_user,
    get_current_user,
    require_roles,
)
from src.schemas.register_request_examples import REGISTER_REQUEST_EXAMPLES
from src.schemas.auth_schemas import (
    AnyRegistration,
    ChangePasswordRequest,
    ForgotPasswordRequest,
    RegisterEmailOtpRequest,
    RegistrationResponse,
    ResetPasswordRequest,
    RoleUpdateRequest,
    UserProfileResponse,
    VerifyRegisterEmailOtpRequest,
    VerifyOtpRequest,
)
from src.schemas.patient_schemas import PatientSelfRegisterPayload, PatientResponse
from src.routers.journal import router as journal_router
from src.routers.reports import router as reports_router
from src.routers.calendar import router as calendar_router
from src.routers.call import router as call_router
from src.routers.chat import router as chat_router
from src.routers.connections import router as connections_router
from src.routers.files import router as files_router

router = APIRouter(prefix="/api", tags=["api"])
router.include_router(journal_router)
router.include_router(reports_router)
router.include_router(calendar_router)
router.include_router(call_router)
router.include_router(chat_router)
router.include_router(connections_router)
router.include_router(files_router)

db = get_firestore_client()
logger = logging.getLogger(__name__)


def _verify_current_password(email: str, password: str) -> None:
    api_key = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password change is not configured on the server.",
        )

    payload = json.dumps(
        {
            "email": email,
            "password": password,
            "returnSecureToken": False,
        }
    ).encode("utf-8")
    req = urllib_request.Request(
        url=f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib_request.urlopen(req, timeout=15):
            return
    except urllib_error.HTTPError as exc:
        detail = "Current password is incorrect."
        try:
            body = json.loads(exc.read().decode("utf-8"))
            message = str(body.get("error", {}).get("message", "")).upper()
            if message == "TOO_MANY_ATTEMPTS_TRY_LATER":
                detail = "Too many failed attempts. Please try again later."
            elif message == "PASSWORD_LOGIN_DISABLED":
                detail = "Password sign-in is not enabled for this account."
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        ) from exc
    except Exception as exc:
        logger.exception("Password verification failed for email=%s: %s", email, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to verify current password.",
        ) from exc


# ─────────────────────────────── OTP helpers ──────────────────────────────────

_OTP_COLLECTION = "password_reset_otps"
_OTP_TTL_MINUTES = 10
_OTP_MAX_ATTEMPTS = 5
_REGISTER_OTP_COLLECTION = "registration_email_otps"
_DEBUG_EMAIL_ERRORS = os.getenv("DEBUG_EMAIL_ERRORS", "false").strip().lower() == "true"


def _send_otp_email(
    recipient_email: str,
    otp: str,
    *,
    purpose: str,
) -> None:
    """Send a 6-digit OTP via Resend only, with purpose-specific content."""
    sender_name = os.getenv("RESEND_SENDER_NAME", "AGAPAY Support").strip()
    resend_key = os.getenv("RESEND_API_KEY", "").strip()
    resend_from = os.getenv("RESEND_FROM_EMAIL", "onboarding@resend.dev").strip()

    if not resend_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="RESEND_API_KEY is missing. Configure Resend first.",
        )

    if purpose == "registration":
        subject = "AGAPAY Email Verification Code"
        heading = "AGAPAY Email Verification"
        action_line = "Use the code below to verify your email and continue registration."
        ignore_line = "If you did not try to create an AGAPAY account, please ignore this email."
    else:
        subject = "AGAPAY Password Reset Code"
        heading = "AGAPAY Password Reset"
        action_line = "Use the code below to reset your password."
        ignore_line = "If you did not request a password reset, please ignore this email."

    plain = (
        f"Your AGAPAY code is: {otp}\n\n"
        f"{action_line}\n"
        f"This code expires in {_OTP_TTL_MINUTES} minutes.\n"
        f"{ignore_line}"
    )
    html = f"""
    <html><body style="font-family:sans-serif;color:#222;">
      <h2 style="color:#359361;">{heading}</h2>
      <p>{action_line} It expires in <strong>{_OTP_TTL_MINUTES} minutes</strong>.</p>
      <div style="font-size:32px;font-weight:bold;letter-spacing:8px;
                  padding:16px 24px;background:#f0f6fa;
                  border-radius:8px;display:inline-block;margin:12px 0;">
        {otp}
      </div>
      <p style="color:#999;font-size:13px;">
        {ignore_line}
      </p>
    </body></html>
    """
    resend.api_key = resend_key
    try:
        resend.Emails.send(
            {
                "from": f"{sender_name} <{resend_from}>",
                "to": [recipient_email],
                "subject": subject,
                "html": html,
                "text": plain,
            }
        )
    except Exception as exc:
        logger.exception("Resend email send failed for %s: %s", recipient_email, exc)
        detail = "Resend failed to send OTP email."
        if _DEBUG_EMAIL_ERRORS:
            detail = f"Resend failed to send OTP email: {exc}"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=detail,
        ) from exc


def _get_otp_doc(email: str) -> dict | None:
    snapshot = db.collection(_OTP_COLLECTION).document(email).get()
    return snapshot.to_dict() if snapshot.exists else None


def _validate_otp(email: str, otp: str) -> None:
    """Raise HTTPException if the OTP is missing, expired, or incorrect."""
    doc = _get_otp_doc(email)
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No password reset was requested for this email.",
        )

    expires_at = doc.get("expires_at")
    if expires_at is None or datetime.now(timezone.utc) > expires_at:
        db.collection(_OTP_COLLECTION).document(email).delete()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired. Please request a new one.",
        )

    attempts: int = doc.get("attempts", 0)
    if attempts >= _OTP_MAX_ATTEMPTS:
        db.collection(_OTP_COLLECTION).document(email).delete()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many incorrect attempts. Please request a new OTP.",
        )

    if doc.get("otp") != otp.strip():
        db.collection(_OTP_COLLECTION).document(email).update({"attempts": attempts + 1})
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect OTP. Please try again.",
        )


def _validate_registration_otp(email: str, otp: str) -> None:
    doc_ref = db.collection(_REGISTER_OTP_COLLECTION).document(email)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No email verification was requested for this address.",
        )

    doc = snapshot.to_dict() or {}
    expires_at = doc.get("expires_at")
    if expires_at is None or datetime.now(timezone.utc) > expires_at:
        doc_ref.delete()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification code expired. Please request a new one.",
        )

    attempts: int = doc.get("attempts", 0)
    if attempts >= _OTP_MAX_ATTEMPTS:
        doc_ref.delete()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many incorrect attempts. Please request a new code.",
        )

    if doc.get("otp") != otp.strip():
        doc_ref.update({"attempts": attempts + 1})
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect verification code.",
        )


def _ensure_registration_email_verified(email: str) -> None:
    doc_ref = db.collection(_REGISTER_OTP_COLLECTION).document(email)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please verify your email before creating an account.",
        )

    doc = snapshot.to_dict() or {}
    expires_at = doc.get("expires_at")
    if expires_at is None or datetime.now(timezone.utc) > expires_at:
        doc_ref.delete()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email verification expired. Please verify your email again.",
        )

    if doc.get("verified") is not True:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please verify your email before creating an account.",
        )


# ─────────────────────────── Registration OTP endpoints ───────────────────────

@router.post("/auth/register/send-otp", status_code=status.HTTP_200_OK)
def send_register_email_otp(payload: RegisterEmailOtpRequest) -> dict:
    email = payload.email.lower().strip()

    try:
        auth.get_user_by_email(email)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This email is already registered. Try signing in instead.",
        )
    except HTTPException:
        raise
    except Exception:
        pass

    otp = f"{secrets.randbelow(1_000_000):06d}"
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)
    db.collection(_REGISTER_OTP_COLLECTION).document(email).set(
        {
            "otp": otp,
            "expires_at": expiry,
            "attempts": 0,
            "verified": False,
        }
    )
    _send_otp_email(email, otp, purpose="registration")
    return {"message": "Verification code sent."}


@router.post("/auth/register/verify-otp", status_code=status.HTTP_200_OK)
def verify_register_email_otp(payload: VerifyRegisterEmailOtpRequest) -> dict:
    email = payload.email.lower().strip()
    _validate_registration_otp(email, payload.otp)
    db.collection(_REGISTER_OTP_COLLECTION).document(email).update(
        {
            "verified": True,
            "verified_at": datetime.now(timezone.utc),
        }
    )
    return {"message": "Email verified."}


# ─────────────────────────────── Password-reset OTP endpoints ─────────────────

@router.post("/auth/forgot-password", status_code=status.HTTP_200_OK)
def forgot_password(payload: ForgotPasswordRequest) -> dict:
    """Send a 6-digit OTP to the user's email address."""
    email = payload.email.lower().strip()

    try:
        auth.get_user_by_email(email)
    except Exception:
        logger.info("forgot_password: Firebase user not found for email=%s", email)
        return {"message": "If an account with that email exists, a reset code has been sent."}

    logger.info("forgot_password: Firebase user found for email=%s", email)

    otp = f"{secrets.randbelow(1_000_000):06d}"
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)

    db.collection(_OTP_COLLECTION).document(email).set({
        "otp": otp,
        "expires_at": expiry,
        "attempts": 0,
    })

    _send_otp_email(email, otp, purpose="password_reset")
    logger.info("forgot_password: OTP email dispatch attempted for email=%s", email)
    return {"message": "If an account with that email exists, a reset code has been sent."}


@router.post("/auth/verify-otp", status_code=status.HTTP_200_OK)
def verify_otp(payload: VerifyOtpRequest) -> dict:
    """Verify the OTP without resetting the password (pre-flight for step 3 UI)."""
    email = payload.email.lower().strip()
    _validate_otp(email, payload.otp)
    return {"message": "OTP verified."}


@router.post("/auth/reset-password", status_code=status.HTTP_200_OK)
def reset_password(payload: ResetPasswordRequest) -> dict:
    """Verify the OTP then set a new password via Firebase Admin SDK."""
    email = payload.email.lower().strip()
    new_password = payload.new_password.strip()

    if len(new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Password must be at least 8 characters.",
        )

    _validate_otp(email, payload.otp)

    try:
        user = auth.get_user_by_email(email)
        auth.update_user(user.uid, password=new_password)
    except Exception as exc:
        logger.exception("Failed to reset password for %s: %s", email, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to reset password. Please try again.",
        ) from exc

    db.collection(_OTP_COLLECTION).document(email).delete()
    return {"message": "Password has been reset successfully."}


# ─────────────────────────────── Registration ─────────────────────────────────

@router.post("/register", response_model=RegistrationResponse, status_code=status.HTTP_201_CREATED)
def register_user(
    payload: AnyRegistration = Body(..., openapi_examples=REGISTER_REQUEST_EXAMPLES),
) -> RegistrationResponse:
    normalized_email = str(payload.email).strip().lower()
    _ensure_registration_email_verified(normalized_email)
    auth_uid, user_doc = register_user_profile(db, payload.model_dump(mode="json"), logger)
    db.collection(_REGISTER_OTP_COLLECTION).document(normalized_email).delete()
    return RegistrationResponse(
        user_id=auth_uid,
        user=UserProfileResponse(**user_doc),
    )


# ─────────────────────────────── Current-user endpoints ───────────────────────

@router.get("/print")
def read_root() -> dict[str, str]:
    return {"Hello": "Welcome to Python World"}


@router.get("/me", response_model=UserProfileResponse)
def read_current_user(
    current_user: CurrentUser = Depends(get_authenticated_user),
) -> UserProfileResponse:
    """
    Returns the authenticated user's full profile.
    Response shape matches UserModel.fromJson() in the Flutter frontend.
    """
    doc = db.collection("users").document(current_user.uid).get()
    extra: dict = doc.to_dict() or {} if doc.exists else {}
    return UserProfileResponse(
        uid=current_user.uid,
        email=current_user.email,
        role=current_user.role,
        status=current_user.status,
        display_name=extra.get("display_name"),
        photo_url=extra.get("photo_url"),
        bio=extra.get("bio"),
        date_of_birth=extra.get("date_of_birth"),
        is_private=extra.get("is_private", False),
        notifications_enabled=extra.get("notifications_enabled", True),
    )


@router.post("/me/password", status_code=status.HTTP_204_NO_CONTENT)
def change_my_password(
    payload: ChangePasswordRequest,
    current_user: CurrentUser = Depends(get_authenticated_user),
) -> None:
    from firebase_admin import auth as fb_auth

    current_password = payload.current_password.strip()
    new_password = payload.new_password.strip()

    if not current_user.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password change requires an email-based account.",
        )
    if len(new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 8 characters.",
        )
    if current_password == new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from the current password.",
        )

    _verify_current_password(current_user.email, current_password)

    try:
        fb_auth.update_user(current_user.uid, password=new_password)
    except Exception as exc:
        logger.exception("Password update failed for uid=%s: %s", current_user.uid, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to update password.",
        ) from exc


@router.post("/me/role", response_model=UserProfileResponse)
def self_select_role(
    payload: RoleUpdateRequest,
    current_user: CurrentUser = Depends(get_authenticated_user),
) -> UserProfileResponse:
    """
    Lets a freshly-registered user choose their own role.
    Only callable while role == "pending"; blocked afterwards.
    Returns the full profile so the Flutter frontend can update currentUserProvider
    without a separate GET /api/me call (avoids null-wiping optional fields).
    """
    if current_user.role.lower() != "pending":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Role is already assigned. Contact an admin to change it.",
        )

    allowed_self_select = {"caregiver", "doctor", "patient", "secretary"}
    normalized = payload.role.strip().lower()
    if normalized not in allowed_self_select:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Role must be one of: {', '.join(sorted(allowed_self_select))}.",
        )

    update_fields: dict = {"role": normalized}
    # Patients complete health-profile onboarding before full access.
    update_fields["status"] = "onboarding" if normalized == "patient" else "active"

    db.collection("users").document(current_user.uid).update(update_fields)

    # Re-fetch from Firestore so all profile fields are returned, not just role/status.
    # This prevents Flutter's currentUserProvider from null-wiping display_name etc.
    doc = db.collection("users").document(current_user.uid).get()
    extra: dict = doc.to_dict() or {} if doc.exists else {}
    return UserProfileResponse(
        uid=current_user.uid,
        email=current_user.email,
        role=normalized,
        status=update_fields["status"],
        display_name=extra.get("display_name"),
        photo_url=extra.get("photo_url"),
        bio=extra.get("bio"),
        date_of_birth=extra.get("date_of_birth"),
        is_private=extra.get("is_private", False),
        notifications_enabled=extra.get("notifications_enabled", True),
    )


# ─────────────────────────────── Patient self-registration ────────────────────

@router.post("/patients/self-register", response_model=PatientResponse, status_code=status.HTTP_201_CREATED)
def patient_self_register(
    payload: PatientSelfRegisterPayload,
    current_user: CurrentUser = Depends(get_authenticated_user),
) -> PatientResponse:
    """
    Called at the end of the patient onboarding wizard.
    Creates the patient record in Firestore and marks the user as active.
    Only callable when role == "patient" and status == "onboarding".
    """
    if current_user.role.lower() != "patient":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only patients can call this endpoint.",
        )
    if current_user.status.lower() != "onboarding":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Patient profile already set up.",
        )

    existing = (
        db.collection("patients")
        .where(filter=FieldFilter("user_uid", "==", current_user.uid))
        .limit(1)
        .get()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Patient record already exists.",
        )

    now = datetime.now(timezone.utc)
    doc_data = {
        "user_uid": current_user.uid,
        "full_name": payload.full_name,
        "date_of_birth": payload.date_of_birth.isoformat(),
        "illness_type": payload.illness_type,
        "illness_other": payload.illness_other,
        "notes": payload.notes,
        "assigned_doctor_uid": None,
        "intake_profile": payload.intake_profile.model_dump() if payload.intake_profile else None,
        "created_at": now,
        "updated_at": now,
    }

    _, doc_ref = db.collection("patients").add(doc_data)
    db.collection("users").document(current_user.uid).update({"status": "active"})

    return PatientResponse(
        patient_id=doc_ref.id,
        user_uid=current_user.uid,
        full_name=payload.full_name,
        date_of_birth=payload.date_of_birth,
        illness_type=payload.illness_type,
        illness_other=payload.illness_other,
        assigned_doctor_uid=None,
        notes=payload.notes,
        intake_profile=doc_data["intake_profile"],
        created_at=now,
        updated_at=now,
    )


# ─────────────────────────────── Profile update ───────────────────────────────

@router.patch("/users/me")
def update_my_profile(
    payload: dict = Body(...),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, object]:
    """Update the authenticated user's own editable profile fields.

    Accepted fields (all optional):
      display_name, photo_url, bio, date_of_birth, is_private, notifications_enabled
    """
    from firebase_admin import auth as fb_auth

    allowed = {"display_name", "photo_url", "bio", "date_of_birth", "is_private", "notifications_enabled"}
    updates: dict[str, object] = {
        k: v for k, v in payload.items() if k in allowed and v is not None
    }
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No updatable fields provided.",
        )

    db.collection("users").document(current_user.uid).update(updates)

    auth_updates: dict[str, str] = {}
    if "display_name" in updates:
        auth_updates["display_name"] = str(updates["display_name"])
    if "photo_url" in updates:
        auth_updates["photo_url"] = str(updates["photo_url"])
    if auth_updates:
        fb_auth.update_user(current_user.uid, **auth_updates)

    post_updates: dict[str, str] = {}
    if "display_name" in updates:
        post_updates["author_name"] = str(updates["display_name"])
    if "photo_url" in updates:
        post_updates["profile_pic"] = str(updates["photo_url"])
    if post_updates:
        posts_query = db.collection("posts").where(
            filter=FieldFilter("author_id", "==", current_user.uid)
        )
        batch = db.batch()
        count = 0
        for doc in posts_query.stream():
            batch.update(doc.reference, post_updates)
            count += 1
            if count == 500:
                batch.commit()
                batch = db.batch()
                count = 0
        if count > 0:
            batch.commit()

    return {"status": "updated", "uid": current_user.uid, **updates}


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_own_account(
    current_user: CurrentUser = Depends(get_current_user),
) -> None:
    """Permanently delete the authenticated user's Firestore data.

    Firebase Auth deletion is handled client-side after this returns 204.
    """
    user_ref = db.collection("users").document(current_user.uid)
    if not user_ref.get().exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    purge_user_data(db, current_user.uid, logger)


# ─────────────────────────────── Admin endpoints ──────────────────────────────

@router.get("/users")
def list_users(
    _: CurrentUser = Depends(require_roles("admin")),
) -> list[dict[str, str | None]]:
    return list_all_users()


@router.patch("/users/{uid}/status", status_code=status.HTTP_200_OK)
def set_user_status(
    uid: str,
    body: dict = Body(...),
    current_user: CurrentUser = Depends(require_roles("admin")),
) -> dict[str, str | None]:
    if current_user.uid == uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot disable your own account",
        )
    disabled = bool(body.get("disabled", False))
    return toggle_user_status(uid, disabled)


@router.put("/users/{uid}/role")
def change_user_role(
    uid: str,
    payload: RoleUpdateRequest,
    current_user: CurrentUser = Depends(require_roles("admin")),
) -> dict[str, str | None]:
    if current_user.uid == uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot change your own role",
        )
    return update_user_role(uid, payload.role)


@router.delete("/users/{uid}")
def delete_user(
    uid: str,
    current_user: CurrentUser = Depends(require_roles("admin")),
) -> dict[str, str]:
    if current_user.uid == uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own account",
        )
    delete_user_record(uid)
    return {"status": "deleted", "uid": uid}

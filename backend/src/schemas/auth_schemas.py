"""
Pydantic models for all API request/response bodies.

Schema parity with Flutter frontend (frontend/lib/features/auth/):
  - All JSON keys are snake_case — frontend reads them as-is via UserModel.fromJson().
  - No camelCase aliases needed; the Flutter side does NOT use json_serializable
    with a camelCase convention — it manually reads 'display_name', 'photo_url', etc.
  - Optional frontend fields map to Optional[str] = None here.
  - bool defaults (is_private=False, notifications_enabled=True) match Flutter defaults.
"""

from typing import Optional
from pydantic import BaseModel, EmailStr


# ──────────────────────────────── Registration OTP ────────────────────────────

class RegisterEmailOtpRequest(BaseModel):
    """POST /api/auth/register/send-otp  — frontend sends {'email': email}"""
    email: EmailStr


class VerifyRegisterEmailOtpRequest(BaseModel):
    """POST /api/auth/register/verify-otp — frontend sends {'email': email, 'otp': otp}"""
    email: EmailStr
    otp: str


# ──────────────────────────────── Registration ────────────────────────────────

class RegistrationRequest(BaseModel):
    """
    POST /api/register — matches RegisterRequest.toJson() in the Flutter frontend:
        {'email': ..., 'password': ..., 'display_name': ...}
    Role is NOT included here; it is chosen separately via POST /api/me/role.
    """
    email: EmailStr
    password: str
    display_name: str  # snake_case matches frontend key 'display_name'


# Alias used in api_router.py for backwards-compatibility with the Union-style name.
AnyRegistration = RegistrationRequest


# ──────────────────────────────── Password reset OTP ─────────────────────────

class ForgotPasswordRequest(BaseModel):
    """POST /api/auth/forgot-password — frontend sends {'email': email}"""
    email: EmailStr


class VerifyOtpRequest(BaseModel):
    """POST /api/auth/verify-otp — frontend sends {'email': email, 'otp': otp}"""
    email: EmailStr
    otp: str


class ResetPasswordRequest(BaseModel):
    """
    POST /api/auth/reset-password
    Frontend sends: {'email': email, 'otp': otp, 'new_password': newPassword}
    """
    email: EmailStr
    otp: str
    new_password: str  # snake_case matches frontend key 'new_password'


# ──────────────────────────────── Authenticated user actions ──────────────────

class ChangePasswordRequest(BaseModel):
    """
    POST /api/me/password
    Frontend sends: {'current_password': currentPassword, 'new_password': newPassword}
    """
    current_password: str
    new_password: str


class RoleUpdateRequest(BaseModel):
    """
    POST /api/me/role  (self-select, pending users only)
    PUT  /api/users/{uid}/role  (admin re-assign)
    Frontend sends: {'role': role}
    """
    role: str


# ──────────────────────────────── Response models ─────────────────────────────

class UserProfileResponse(BaseModel):
    """
    Canonical user profile shape returned by GET /api/me and POST /api/me/role.

    Parity with UserModel.fromJson() in frontend/lib/features/auth/model/user_model.dart:
      uid                  → json['uid'] as String           (required)
      email                → json['email'] as String?        (optional)
      role                 → json['role'] as String          (required)
      status               → json['status'] as String?       (required, defaults to '')
      display_name         → json['display_name'] as String? (optional)
      photo_url            → json['photo_url'] as String?    (optional)
      bio                  → json['bio'] as String?          (optional)
      date_of_birth        → json['date_of_birth'] as String? then DateTime.tryParse
      is_private           → json['is_private'] as bool?     (defaults false)
      notifications_enabled→ json['notifications_enabled'] as bool? (defaults true)
    """
    uid: str
    email: Optional[str] = None
    role: str
    status: str
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    bio: Optional[str] = None
    date_of_birth: Optional[str] = None  # ISO date string, e.g. "1990-06-15"
    is_private: bool = False
    notifications_enabled: bool = True


class RegistrationResponse(BaseModel):
    """POST /api/register — 201 Created. Frontend only checks the status code."""
    user_id: str
    user: UserProfileResponse

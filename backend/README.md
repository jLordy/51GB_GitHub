# Agapay backend — LLM / agent reference

**One-liner:** FastAPI app (`main.py`) titled *Agapay API*; Firebase Admin verifies ID tokens; **Firestore** is system of record; **Azure Blob Storage** backs binary file uploads (`file_service.py`); **Resend** sends registration/password OTP email. CORS from `CORS_ORIGINS` (default `*`). Health: `GET /` → `{"status":"ok"}`. Product API: **`/api/*`** only (plus `/docs` OpenAPI).

**Sibling:** HTTP client + contracts live in repo `frontend/` (see `frontend/README.md`). Flutter `UserModel.fromJson` is explicitly aligned with `GET /api/me` (`UserProfileResponse` in `src/schemas/auth_schemas.py`).

---

## Run / import contract (do not violate)

- **Working directory:** project-relative **`backend/`** when launching or tooling, because imports are `from src....` (no installed package).
- **Process:** `uvicorn main:app --reload --host 0.0.0.0 --port 8000` (typical local port **8000**; Flutter debug defaults to `localhost:8000` / Android emulator `10.0.2.2:8000`).
- **Secrets file:** `load_dotenv` in `src/firebase.py` loads **`src/.env`** (not repo root). `FIREBASE_CREDENTIALS` must be set (JSON file path or raw JSON string).
- **Lifespan:** `get_firebase_app()` runs on startup (`main.py`).

---

## Authentication & identity (`src/middleware.py`)

| Dependency | Bearer required | Anonymous Firebase user |
|------------|-----------------|-------------------------|
| `get_current_user_optional` | no → `None` if missing | allowed if token decodes |
| `get_current_user` | yes | **allowed** |
| `get_authenticated_user` | yes | **403** (`sign_in_provider == anonymous`) |
| `require_roles("admin", ...)` | uses `get_authenticated_user` | blocked with anon |

Flow: decode JWT with `firebase_admin.auth.verify_id_token` (`check_revoked=True`, `clock_skew_seconds=10`) → read **`users/{uid}`** in Firestore → build `CurrentUser(uid, email, role, status)` with **lowercased** `role` and `status`. Missing user doc → **404** “User profile not found.” Revoked/expired/disabled tokens map to **401** / **403** as implemented.

**RBAC:** Endpoints that need non-anon callers use `get_authenticated_user`. Admin routes use `Depends(require_roles("admin"))` — role compared **case-insensitively** to Firestore `users.{uid}.role`.

---

## HTTP surface (routers)

All mounted under `APIRouter(prefix="/api")` in `src/routers/api_router.py` unless noted.

| Mount file | URL prefix | Notes |
|------------|------------|--------|
| `api_router.py` | `/api` | Registration (`POST /api/register`), email OTP (`/api/auth/register/send-otp`, `verify-otp`), password OTP (`/api/auth/forgot-password`, `verify-otp`, `reset-password`), `POST /api/me/password`, `GET/PATCH` profile-ish routes (`/api/me`, `PATCH /api/users/me`, `POST /api/me/role`, `DELETE /api/me`), `POST /api/patients/self-register`, admin `/api/users*`, debug `GET /api/print` |
| `journal.py` | `/api/journal` | Entries, questions, patient-scoped journal access |
| `reports.py` | `/api/reports` | Diary text + PDF; patient/doctor flows |
| `calendar.py` | `/api/calendar` | Appointments; doctor/patient/caregiver/secretary/public schedule variants |
| `call.py` | `/api/call` | Notify callee (`users` read/write) |
| `chat.py` | `/api/chat` | Conversations + messages + `GET /api/chat/key` (needs `CHAT_ENCRYPTION_KEY`) |
| `connections.py` | `/api/connections` | Connection CRUD + secretary/doctor listing helpers |
| `files.py` | `/api/files` | Folders/documents + storage summary |

**Drift / not in `src/routers` today (grep before assuming):** The Flutter client also calls **`/api/notifications`** and **`/api/upload/image`**, **`/api/upload/video`**. Those string paths do **not** appear under `backend/src/routers/` in this tree—either implemented elsewhere, proxied, or client-ahead-of-server. Fix by adding routers or removing client calls.

---

## Firestore topology (high-signal collections)

Use this when reasoning about queries, security rules, or migrations.

| Collection / path | Used for (indicative) |
|-------------------|------------------------|
| `users/{uid}` | Profile, **`role`**, **`status`**, display fields; created at registration with `role: pending`, `status: pending` |
| `patients` | Patient clinical record; `user_uid` links to auth user; onboarding completion writes here (`api_router` patient self-register) |
| `password_reset_otps` | Doc id = email; OTP for forgot-password (`_OTP_COLLECTION` in `api_router.py`) |
| `registration_email_otps` | Doc id = email; registration email OTP (`_REGISTER_OTP_COLLECTION` in `api_router.py`) |
| `connections` | Health-circle connection documents (`connection_service.py`) |
| `conversations` / `conversations/{id}/messages/{msgId}` | DM threads (`chat_service.py`) |
| `journal_entries` | Persisted journal sessions (`journal_service.py`); optional subcollection `edit_history` per service |
| `questionnaires/*` | Seeded by `seed_questionnaire.py` (e.g. `daily_universal`, illness-specific dailies, intake) |
| `reports` | Saved generated reports (`report_service.py`) |
| `file_folders`, `file_documents`, `file_storage_summary` | Metadata + per-patient byte accounting (`file_service.py` docstring lists schema) |
| `appointments` | Calendar (`calendar_service.py`) |
| `posts` | Social-style posts; `PATCH /api/users/me` batch-updates posts where `author_id == uid` |
| `users/{uid}/notifications/{notifId}` | Per-user inbox; `fetch_notifications` orders by `createdAt` DESC (`notification_service.py`). Types include social: `post_reply`, `post_heart`, `comment_heart` (payload may carry `postId` → join `posts/{postId}`). |

`auth.purge_user_data` deletes by top-level queries on `posts`, `journal_entries`, `messages` with field **`uid`**—may not match all subcollection-heavy schemas; reconcile before relying on account deletion completeness.

---

## Services ↔ storage (where logic lives)

| Service | Primary concern |
|---------|-----------------|
| `journal_service.py` | Questionnaire assembly from `questionnaires/*`, CRUD `journal_entries`, connection checks vs `connections` |
| `report_service.py` | Aggregates `journal_entries` + `connections` + `patients`; writes `reports`; PDF via ReportLab |
| `file_service.py` | Firestore folder/doc metadata + **Azure** blob upload path `documents/{patient_uid}/{folder_id}/{uuid}.{ext}`; 500 MB cap |
| `chat_service.py` | `conversations` + subcollection `messages`; no WebSocket in this API—clients use Firestore/SDK for live DM if applicable |
| `connection_service.py` | `connections` + `notification_service` fan-out on accept/request |
| `calendar_service.py` | `appointments`, `users`, `connections` |
| `notification_service.py` | Writes/reads `users/{uid}/notifications/*`; **no** dedicated router in `src/routers/` for `GET /api/notifications` in this tree—see HTTP drift section |

---

## Environment variables (complete list from codebase scan)

`FIREBASE_CREDENTIALS` (**required**); `CORS_ORIGINS`; `FIREBASE_WEB_API_KEY` (password verify for `POST /api/me/password`); `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `RESEND_SENDER_NAME`; `DEBUG_EMAIL_ERRORS`; `CHAT_ENCRYPTION_KEY` (also read in `src/core/encryption.py`); `AZURE_STORAGE_CONNECTION_STRING`, `AZURE_STORAGE_CONTAINER_NAME`.

---

## File map (where to edit)

| Concern | Path |
|---------|------|
| App, CORS, lifespan | `main.py` |
| Mount sub-routers, most auth/user routes | `src/routers/api_router.py` |
| Per-domain HTTP | `src/routers/{journal,reports,calendar,call,chat,connections,files}.py` |
| Pydantic IO | `src/schemas/*_schemas.py` |
| Firebase init | `src/firebase.py` |
| Register/purge/list users | `src/auth.py` |
| Token deps | `src/middleware.py` |
| Questionnaire seed | `seed_questionnaire.py` (supports `FIRESTORE_EMULATOR_HOST`) |

**Conventions:** Keep routers thin; put Firestore transaction/batch logic in `src/services/`. Match existing `HTTPException` status patterns (404 vs 403) in `connection_service` docstring (anti-enumeration).

---

## Minimal human commands

```bash
cd backend && pip install -r requirements.txt
# set src/.env with FIREBASE_CREDENTIALS at minimum
uvicorn main:app --reload --host 0.0.0.0 --port 8000
python seed_questionnaire.py   # optional: populate questionnaires/*
```

Never commit credentials, `*.json` service accounts, or `.env`.

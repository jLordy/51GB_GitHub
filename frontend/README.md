# Agapay frontend — LLM / agent reference

**One-liner:** Flutter app **package name `frontend`** (all imports `package:frontend/...`). **Firebase:** Auth (email + Google), Firestore streams where used, FCM hooks in `main.dart`. **State:** Riverpod 3.x. **Navigation:** `go_router` with redirects from **Firebase `User`** + backend **`UserModel`** (`role`, `status`). **HTTP:** single `Dio` wrapper `ApiClient` attaches **`Authorization: Bearer <Firebase idToken>`** and optional **`x-functions-key`**.

**Sibling:** REST API implementation in repo `../backend/` (`backend/README.md`). Paths are always **`/api/...`** relative to configurable base URL.

---

## Base URL & build-time defines (`lib/features/auth/controller/auth_provider.dart`)

| Build | `backendBaseUrlProvider` resolution |
|-------|-------------------------------------|
| Any | If `String.fromEnvironment('API_BASE_URL')` non-empty → use it (trim not shown; treat as authoritative when set). |
| **Debug**, non-Android | `http://localhost:8000` |
| **Debug**, Android | `http://10.0.2.2:8000` |
| **Release** (else) | `https://agapayapp.online/` |

`backendFunctionKeyProvider`: `String.fromEnvironment('AZURE_FUNCTIONS_KEY')` → empty → `null` else trimmed string. When non-null, `ApiClient` adds header **`x-functions-key`**.

**Typical invoke:** `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`

---

## `ApiClient` contract (`lib/core/network/api_client.dart`)

- **Base:** `Dio(BaseOptions(baseUrl: baseUrl, contentType: json, connectTimeout 15s, receiveTimeout 30s))`.
- **Per request:** `extra['requiresAuth']` defaults **true**; when true and no Firebase user / token → throws `FirebaseAuthException(unauthenticated)`.
- **Headers:** JSON content-type; if `functionKey` set → `x-functions-key`; if authenticated → `Authorization: Bearer <idToken>` (`getIdToken(true)`).
- **Methods:** `get`, `post`, `put`, `patch`, `delete` (JSON), `postBytes`, `getBytes`, `postMultipart` (multipart for uploads).

---

## Global providers (edit these when wiring cross-cutting behavior)

| Provider | File | Role |
|----------|------|------|
| `firebaseAuthProvider` | `auth_provider.dart` | `FirebaseAuth.instance` |
| `authRepositoryProvider` | `auth_provider.dart` | Sign-in/register/OTP against backend + GoogleSignIn |
| `authStateProvider` | `auth_provider.dart` | `StreamProvider<User?>` from Firebase auth |
| `backendBaseUrlProvider` | `auth_provider.dart` | API origin |
| `backendFunctionKeyProvider` | `auth_provider.dart` | Azure Functions key header |
| `apiClientProvider` | `auth_provider.dart` | `ApiClient` singleton for app |
| `backendSessionRepositoryProvider` | `auth_provider.dart` | `UserProfileRepository` (admin/me/users) |
| `currentUserProvider` | `auth_provider.dart` | `StateProvider<UserModel?>` — filled after session sync from **`GET /api/me`** |
| `authSessionSyncProvider` | `auth_provider.dart` | **`Provider<void>`** — `ref.listen` on `authStateProvider` to sync profile; **must stay watched** (`MyApp` watches it) |
| `routerProvider` | `app_router.dart` | `GoRouter` |
| `appNavigatorKey` | `app_router.dart` | `GlobalKey<NavigatorState>` |

---

## Routing & guards (`lib/core/router/app_router.dart`)

- **Initial location:** `/login`.
- **Refresh:** `ValueNotifier` incremented when `authStateProvider` signed-in flag changes OR `currentUserProvider` `role`/`status` changes (re-runs redirect).
- **Redirect summary:**
  - Not authenticated → only `/login`, `/register`, `/email-verification`, `/forgot-password`, `/role-selection` allowed; else → `/login`.
  - Authenticated + `role == pending` (case-insensitive) → forced **`/role-selection`** except when already there.
  - After role resolved: **doctor** or **secretary** → default home **`/doctor-dashboard`**; others → **`/home`**.
  - Authenticated on auth pages → redirect to default home.
  - **Guards:** doctor/secretary cannot stay on `/home`; patients/caregivers cannot stay on `/doctor-dashboard` (race while profile loads).

When adding routes: extend `GoRoute` list, respect role/status, avoid redirect loops with `isAuthPage` / `isRoleSelectionPage` patterns.

---

## Roles & lifecycle (strings are lowercased in many comparisons)

**Roles** seen in backend + router: `pending`, `patient`, `caregiver`, `doctor`, `secretary`, `admin`.

**Status:** e.g. `pending` (initial), `onboarding` (patient after role select until `POST /api/patients/self-register`), `active`. Backend `POST /api/me/role` sets `onboarding` for patient and `active` for other roles.

---

## Feature → data layer map (first file to open for API paths)

| Feature dir | Repository / stream entry | Backend prefix (typical) |
|-------------|---------------------------|--------------------------|
| `auth/data/auth_repository.dart` | register, OTP, password reset | `/api/register`, `/api/auth/...` |
| `auth/data/user_profile_repository.dart` | me, users admin, profile patch | `/api/me`, `/api/users`, `/api/users/me` |
| `onboarding/data/onboarding_repository.dart` | patient wizard completion | `POST /api/patients/self-register` |
| `journal/data/journal_repository.dart` | entries, questions | `/api/journal/...` |
| `report/data/report_repository.dart` | reports + PDF bytes | `/api/reports/...` |
| `calendar/data/calendar_repository.dart` | appointments | `/api/calendar/...` |
| `connections/data/connection_repository.dart` | browse, connections, patients by uid | `/api/users/browse*`, `/api/connections`, `/api/patients/...` |
| `chat/data/chat_repository.dart` | conversations, messages, multipart | `/api/chat/...`, **`/api/upload/image`**, **`/api/upload/video`** |
| `chat/data/chat_stream_repository.dart` | Firestore real-time (DM delivery) | client SDK, not REST |
| `file/data/file_repository.dart` | folders/documents | `/api/files/...` |
| `notifications/data/notification_repository.dart` | list/mark/delete/patch | **`/api/notifications/...`** |
| `call/controller/call_controller.dart` | notify | `/api/call/notify` (confirm in file) |

**Drift:** `notification_repository` and `chat_repository` upload methods hit paths that may **not** exist on the FastAPI router set in `backend/src/routers/`—check `backend/README.md` “HTTP drift” before debugging 404.

---

## Directory convention (`lib/features/<feature>/`)

Common layout: `presentation/` (screens, widgets), `data/` (repositories), `controller/` or `*_provider.dart`, `model/`. **Chat encryption:** `encryption_provider.dart` + `core/utils/message_crypto.dart` — server key from **`GET /api/chat/key`**.

**Report / PDF:** `features/report/utils/` uses conditional imports: `*_io.dart`, `*_web.dart`, `*_stub.dart` — copy pattern when adding platforms.

---

## Firebase / app entry (`lib/main.dart`)

- `WidgetsFlutterBinding.ensureInitialized()`
- `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
- `GoogleSignIn.instance.initialize(...)` with **webClientId** constant in file (OAuth client)
- `runApp(ProviderScope(child: MyApp()))`
- `MyApp`: `ConsumerWidget`, watches **`authSessionSyncProvider`**, **`routerProvider`**, **`themeNotifierProvider`**, `MaterialApp.router(debugShowCheckedModeBanner: false, title: 'Agapay', ...)`

**Theme:** `lib/theme/palette.dart` + `themeNotifierProvider` (not re-exported here—grep if theming task).

---

## Assets (`pubspec.yaml`)

`assets/images/`; font **TanSongbird** → `assets/fonts/TANSONGBIRD.otf`.

---

## Dependencies worth remembering (`pubspec.yaml`)

`dio`, `flutter_riverpod`, `go_router`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `google_sign_in`, `flutter_webrtc`, `encrypt`, `file_picker`, `image_picker`, `flutter_pdfview`, `table_calendar`, etc.

---

## Minimal human commands

```bash
cd frontend && flutter pub get && flutter run
# optional:
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Regenerate `lib/firebase_options.dart` with FlutterFire when changing Firebase apps. Do not embed private backend secrets in source; use `--dart-define` or CI secrets.

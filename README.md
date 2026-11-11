# ShiftSure

ShiftSure is a parametric income protection platform for quick-commerce delivery workers, offering weekly coverage, rider-filed claims, AI-assisted claim verification, and automated payout management.


## Overview

Riders on quick-commerce platforms (for example Zepto, Blinkit, or Instamart) earn in short, hyperlocal windows. Heavy rain, flooding, dark-store outages, zone closures, extreme heat, or hazardous air quality can sharply cut weekly earnings. ShiftSure plans to cover that **income loss only**. It is not health, accident, life, or vehicle insurance.


### Planned product flow

1. A rider buys weekly coverage.
2. The rider declares working shifts.
3. A disruption occurs (weather, outage, closure, etc.).
4. The rider files a claim.
5. The system verifies the claim against external signals and fraud checks.
6. The claim is approved or rejected; approved claims are paid out to the rider's wallet.

Disruption events act as evidence for verification. They do not pay out on their own.

## Planned technology stack

| Area | Planned technology | Status |
|---|---|---|
| Rider app | Flutter (Android, iOS) | Scaffold **Implemented** (PR #6); sign-in **Implemented** (PR #7); worker profile setup/view/edit **In progress** (PR #10); other rider features **Planned** |
| Admin dashboard | Flutter Web | Planned |
| Backend API | Node.js + Express | Scaffold **Implemented** (PR #3); token auth and role middleware **Implemented** (PR #4); worker profile API and rider-role onboarding **In progress** (PR #10); other features **Planned** |
| Auth and database | Firebase Auth + Cloud Firestore | Deny-all Firestore client rules and emulator tests **Implemented** (PR #5); `workers` collection **In progress** (PR #10); other data models **Planned** |
| AI service (pricing, risk scoring) | Python + FastAPI | Planned |
| Fraud / graph analysis | Neo4j | Planned |


## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): proposed high-level architecture
- [docs/ROADMAP.md](docs/ROADMAP.md): planned phases and small-PR sequence
- [CLAUDE.md](CLAUDE.md): conventions for AI-assisted development

## Development

Only the backend and the rider app scaffold exist so far (see [Backend](#backend-scaffold-implemented-pr-3-and-auth-middleware-implemented-pr-4) and [Rider app](#rider-app-scaffold-implemented-pr-6-sign-in-implemented-pr-7)). Setup instructions for other components will be added as each is introduced.

### Tooling baseline (Implemented)

- **CI:** a GitHub Actions workflow runs repository-hygiene checks (whitespace, forbidden credential files, JSON validity, relative Markdown links) and, since PR #3, the backend tests (`backend-tests` job). PR #5 added the `firestore-rules-tests` job (Firestore emulator, Java 21). PR #6 adds the `mobile-tests` job (format check, `flutter analyze`, `flutter test`, Flutter 3.47.9). No other component has build or test jobs yet.
- **Firebase emulators (config only, not yet tested):** `firebase.json` configures the Auth (`127.0.0.1:9099`) and Firestore (`127.0.0.1:8080`) emulators with the Emulator UI disabled. `.firebaserc` uses the emulator-only demo project `demo-shiftsure`; no real Firebase project is configured. Once Firebase CLI is installed, the intended command is `firebase emulators:start --project demo-shiftsure`. Emulator startup has **not** been tested.
- **Firestore rules (Implemented, PR #5):** `firestore.rules` denies all client SDK access; `firebase.json` loads it. The backend (Admin SDK, which bypasses rules) is the only intended data path. No collection-specific rules exist yet. Emulator tests live in `backend/test-rules/` and run with `cd backend && npm run test:rules` (needs Java 21+; uses demo project `demo-shiftsure`, never a real project). They are separate from the hermetic `npm test`.

### Backend scaffold (Implemented, PR #3) and auth middleware (Implemented, PR #4)

A minimal Node.js + Express app in `backend/` (plain JavaScript, ESM). It serves the public `GET /health` and, since PR #10 (**In progress**), the authenticated worker profile API under `/api/workers/me` (see [Worker profiles](#worker-profiles-in-progress-pr-10)). PR #4 added Firebase Admin initialization and authentication/authorization middleware (**Implemented**). All other feature routes are **Planned** and do not exist yet.

**Prerequisites:** Node.js 26 (Active LTS; see `backend/.nvmrc`) and npm.

```bash
cd backend
npm ci                 # install exact locked dependencies
cp .env.example .env   # optional; defaults work without it
npm run dev            # start with auto-restart on file changes (node --watch)
npm start              # start without watch
curl localhost:3000/health
# {"status":"ok","service":"shiftsure-backend","uptimeSeconds":3}
npm test               # run tests (node:test)
```

**Configuration.** `backend/.env` is optional and is always read from the `backend/` directory regardless of where the command is run. Variables already set in the shell take precedence over the file. Invalid values stop startup with a message listing every problem.

| Variable | Default | Description |
|---|---|---|
| `NODE_ENV` | `development` | `development`, `test`, or `production` |
| `PORT` | `3000` | HTTP port, integer 0-65535 (`0` picks a free port) |
| `SERVICE_NAME` | `shiftsure-backend` | Name reported by `GET /health` |
| `FIREBASE_PROJECT_ID` | `demo-shiftsure` | Project used to verify ID tokens. Required in production, where `demo-*` ids are rejected |
| `FIREBASE_AUTH_EMULATOR_HOST` | unset | Local Auth emulator, e.g. `127.0.0.1:9099`. Read by the Firebase Admin SDK; startup fails if set in production |
| `FIRESTORE_EMULATOR_HOST` | unset | Local Firestore emulator, e.g. `127.0.0.1:8080`. Read by the Firebase Admin SDK; startup fails if set in production |

Against a real (development) project, Firestore access and custom-claim writes need Application Default Credentials on the dev machine (for example `gcloud auth application-default login`); verifying ID tokens needs only the project id. No key files are committed. Against the emulators no credentials are needed.

**Authentication and roles (Implemented, PR #4).** `authenticate` (`backend/src/middleware/auth.js`) verifies a Firebase ID token from `Authorization: Bearer <token>` and sets `req.user = { uid, role }`; `requireRole('admin')` etc. restricts a route. Failures return `401 {"error":"unauthenticated"}` or `403 {"error":"forbidden"}` with no further detail.

- **Roles come only from Firebase custom claims.** The verified token's `role` claim must be `rider` or `admin`; anything else means no role (403 on role-guarded routes). Nothing the client sends (headers, body, query) is used for authorization. The old repo read the role from a Firestore `workers` document on every request and defaulted to `rider`; that is intentionally not carried over.
- **Implications:** claims are refreshed only when the client's ID token refreshes (up to about an hour), so role changes lag. Immediate revocation needs `verifyIdToken(token, true)` (checks revocation) *in addition to* `revokeRefreshTokens`; `revokeRefreshTokens` alone does not invalidate existing ID tokens until they expire. Claims must be set by trusted server code or scripts via the Admin SDK (`setCustomUserClaims`). The rider role is assigned during profile creation (PR #10, **In progress**; see [Worker profiles](#worker-profiles-in-progress-pr-10)); admin bootstrap and Firestore-rule use of `request.auth.token.role` are **Planned**.
- **Emulator coverage (PR #10):** `npm run test:emulator` (Java 21+, demo project `demo-shiftsure` only) verifies real Auth-emulator ID tokens, rider-claim assignment, and token refresh end to end. The hermetic `npm test` still injects a fake verifier.

**Tests:** `npm test` is hermetic: it needs no `.env`, Firebase emulators, network access, or credentials. HTTP tests bind to an ephemeral port on `127.0.0.1`. `npm run test:rules` and `npm run test:emulator` start local emulators (demo project only) and run in CI's `firestore-rules-tests` job.

### Rider app (scaffold Implemented, PR #6; sign-in Implemented, PR #7)

A Flutter app in `mobile/` (Android and iOS) with Material 3 theming (light and dark, following the system), bottom navigation between Home, Policy, Claims and Wallet, and a small HTTP client. Home shows the rider's profile summary (PR #10, **In progress**). **Everything else is Planned:** Policy, Claims and Wallet are labelled placeholders. Home also has a **development diagnostic** card that calls `GET /health` once on load (and on Retry); it is not a rider feature.

**Prerequisites (toolchain upgraded in the `chore/upgrade-mobile-toolchain` PR #8, **Implemented**):** Flutter 3.47.9 (stable; Dart 3.13.7), JDK 17+, and the Android SDK with platform 36, build-tools 36.0.0 and NDK 28.2.13676358 (Gradle can download the NDK; accept licenses with `flutter doctor --android-licenses`). Android `minSdk` is 24 (Android 7.0+), up from 23. The iOS deployment target is 15.0 (raised from 12.0); iOS builds need macOS and Xcode and have **not** been verified.

Android build config: Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin Gradle Plugin 2.4.0, Java 17 source/target, `compileSdk`/`targetSdk` 36 (Flutter defaults). Verified with `flutter build apk --debug`, and manually on a physical Android device (Samsung SM S921B, reported by the maintainer) against the `shiftsure-dev` project: registration, login, logout, session persistence, auth-gated navigation and the Home `/health` card. **Known limitation:** `android.builtInKotlin=false` and `android.newDsl=false` (written by Flutter's own migrator, same as its 3.47 template) because Flutter's Gradle plugin does not yet support AGP 9's new DSL and `firebase_core`/`firebase_auth` still apply the Kotlin Gradle plugin, so Flutter prints a build warning about future Built-in Kotlin. Remove the flags when Flutter and FlutterFire support it.

```bash
cd mobile
flutter pub get
flutter analyze && flutter test        # hermetic: no backend or network needed
cp config.example.json config.local.json   # optional; git-ignored
flutter run --dart-define-from-file=config.local.json
```

**Backend URL.** `API_BASE_URL` is a build-time setting (default `http://localhost:3000`). Start the backend with `cd backend && npm run dev` first.

| Target | `API_BASE_URL` |
|---|---|
| iOS simulator | `http://localhost:3000` (default) |
| Android emulator | `http://10.0.2.2:3000`, or keep the default and run `adb reverse tcp:3000 tcp:3000` |
| Physical device | `http://<your-computer-LAN-IP>:3000` (the backend must listen on that interface) |

Plain HTTP is allowed only in Android **debug** builds (`android/app/src/debug/AndroidManifest.xml`); release builds are HTTPS-only. `ApiClient` (`mobile/lib/api/api_client.dart`) attaches the Firebase ID token (`Authorization: Bearer`) through `tokenProvider`, wired to Firebase Auth in PR #7.


**Sign-in (Implemented, PR #7).** Email/password registration, login and logout, with the session persisted by Firebase and the app gated on auth state (signed out: login/registration; signed in: the rider app). Covered by unit/widget tests using a fake auth service; manually verified end to end on a physical Android device against `shiftsure-dev` after the toolchain upgrade (maintainer-reported; not automated). Password reset and social/phone sign-in are **not included**. A new rider has no backend role until profile setup (PR #10) assigns one.

- Firebase client config is in `mobile/lib/firebase_options.dart` (**tracked**: public client config for the `shiftsure-dev` project only, no admin credentials) and was generated with `flutterfire configure`; `mobile/firebase.json` records that setup. The Google Services Gradle plugin is not used (Firebase is initialised explicitly from `firebase_options.dart`), so Android builds need no `google-services.json`; it stays git-ignored. FlutterFire is `firebase_core` 5.1.x / `firebase_auth` 7.0.x (Flutter 3.47.9); Android `minSdk` is 24. `GoogleService-Info.plist` (iOS) is not set up.
- Default: the Firebase development project (`shiftsure-dev`); Email/Password must be enabled in its Console. The backend needs `FIREBASE_PROJECT_ID=shiftsure-dev` in `backend/.env`, **no** `*_EMULATOR_HOST` variables, and (for worker profiles) Application Default Credentials.
- Emulator (optional, `USE_AUTH_EMULATOR=true`): the app, `firebase` CLI and backend all use the isolated project **`demo-shiftsure`**, never `shiftsure-dev`. Host defaults to `10.0.2.2` on Android and `127.0.0.1` otherwise (`AUTH_EMULATOR_HOST`/`AUTH_EMULATOR_PORT` override). The app refuses this mode in release builds. Not yet tested here.

```bash
# development project (backend: cd backend && npm run dev)
cd mobile && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# local emulator (three terminals)
firebase emulators:start --only auth,firestore --project demo-shiftsure   # repo root
cd backend && FIREBASE_PROJECT_ID=demo-shiftsure FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run dev
cd mobile && flutter run --dart-define=USE_AUTH_EMULATOR=true --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

On a **physical Android device**, forward both ports over adb and point the app at `127.0.0.1` (the app passes the host to Firebase as given; FlutterFire's automatic `127.0.0.1` to `10.0.2.2` rewrite is disabled):

```bash
adb reverse tcp:9099 tcp:9099 && adb reverse tcp:3000 tcp:3000
cd mobile && flutter run --dart-define=USE_AUTH_EMULATOR=true --dart-define=AUTH_EMULATOR_HOST=127.0.0.1 --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

### Worker profiles (In progress, PR #10)

Each rider has one profile at Firestore `workers/{firebaseUid}`, written only by the backend (Admin SDK). The app never reads Firestore directly; `firestore.rules` stays deny-all.

| Field | Rules |
|---|---|
| `name` | 2-80 characters: letters, spaces, `.` `'` `-` (whitespace trimmed and collapsed) |
| `phone` | 10-digit Indian mobile number (`6`-`9` first); `+91`, spaces and hyphens are accepted and stripped |
| `city` | 2-60 characters, same character rules as `name`. Free text for now (see the roadmap note on the dark-store catalog) |
| `platform` | `zepto`, `blinkit`, `swiggy_instamart`, or `other` |
| `created_at`, `updated_at` | Server timestamps, set by the backend only |

API (all require `Authorization: Bearer <Firebase ID token>`; the uid always comes from the verified token, and there is no route that takes another worker's uid):

| Request | Who | Result |
|---|---|---|
| `GET /api/workers/me` | no role yet, or `rider` | `200 {profile, token_refresh_required}` or `404 profile_not_found` |
| `POST /api/workers/me` | no role yet, or `rider` | `201 {profile, token_refresh_required}`; `409 profile_exists`; `400 validation_failed` |
| `PATCH /api/workers/me` | `rider` | `200 {profile}` with only the sent fields changed; `404`; `400` |

Unknown fields (including `uid`, `role`, timestamps, `dark_store_id`, `zone_id`) are rejected with `400`. Admin accounts get `403`: they are not worker accounts.

**Rider-role onboarding.** On `POST`, after validating the body, the backend reads the user's current custom claims from Firebase Auth. If there is no role it sets `role: 'rider'` (merging any other claims), then creates the profile. An existing `admin` (or any other non-rider) role is never overwritten: the request gets `403` and nothing is written. The client cannot choose the role. Custom claims only appear in a newly minted ID token, so when `token_refresh_required` is true the app calls `getIdToken(forceRefresh: true)`.

**Interrupted onboarding** recovers automatically. If the claim was set but the profile write failed, `GET` returns `404`, the app shows setup again, and the retried `POST` creates the profile without reassigning the role. If the app closed before refreshing its token, the next `GET` reports `token_refresh_required` (and re-checks the claim), and a `PATCH` rejected with `403` refreshes the token and retries once.

**App.** After sign-in the app asks the backend for the profile. It shows a setup form if there is none, or the app shell if there is one (with retry and sign-out on load errors). The profile can be viewed from Home (**View profile** or the person icon) and edited; edits send only changed fields. No location permission is used.

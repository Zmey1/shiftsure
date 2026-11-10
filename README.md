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
| Rider app | Flutter (Android, iOS) | Scaffold **In progress** (PR #6); rider features **Planned** |
| Admin dashboard | Flutter Web | Planned |
| Backend API | Node.js + Express | Scaffold **Implemented** (PR #3); token auth and role middleware **Implemented** (PR #4, no protected routes yet); features **Planned** |
| Auth and database | Firebase Auth + Cloud Firestore | Deny-all Firestore client rules and emulator tests **Implemented** (PR #5); data models **Planned** |
| AI service (pricing, risk scoring) | Python + FastAPI | Planned |
| Fraud / graph analysis | Neo4j | Planned |


## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): proposed high-level architecture
- [docs/ROADMAP.md](docs/ROADMAP.md): planned phases and small-PR sequence
- [CLAUDE.md](CLAUDE.md): conventions for AI-assisted development

## Development

Only the backend and the rider app scaffold exist so far (see [Backend](#backend-scaffold-implemented-pr-3-and-auth-middleware-implemented-pr-4) and [Rider app](#rider-app-scaffold-implemented-pr-6-sign-in-in-progress-pr-7)). Setup instructions for other components will be added as each is introduced.

### Tooling baseline (Implemented)

- **CI:** a GitHub Actions workflow runs repository-hygiene checks (whitespace, forbidden credential files, JSON validity, relative Markdown links) and, since PR #3, the backend tests (`backend-tests` job). PR #5 added the `firestore-rules-tests` job (Firestore emulator, Java 21). PR #6 adds the `mobile-tests` job (format check, `flutter analyze`, `flutter test`, Flutter 3.47.9). No other component has build or test jobs yet.
- **Firebase emulators (config only, not yet tested):** `firebase.json` configures the Auth (`127.0.0.1:9099`) and Firestore (`127.0.0.1:8080`) emulators with the Emulator UI disabled. `.firebaserc` uses the emulator-only demo project `demo-shiftsure`; no real Firebase project is configured. Once Firebase CLI is installed, the intended command is `firebase emulators:start --project demo-shiftsure`. Emulator startup has **not** been tested.
- **Firestore rules (Implemented, PR #5):** `firestore.rules` denies all client SDK access; `firebase.json` loads it. The backend (Admin SDK, which bypasses rules) is the only intended data path. No collection-specific rules exist yet. Emulator tests live in `backend/test-rules/` and run with `cd backend && npm run test:rules` (needs Java 21+; uses demo project `demo-shiftsure`, never a real project). They are separate from the hermetic `npm test`.

### Backend scaffold (Implemented, PR #3) and auth middleware (Implemented, PR #4)

A minimal Node.js + Express app in `backend/` (plain JavaScript, ESM). It currently serves only the public `GET /health`. PR #4 added Firebase Admin initialization and authentication/authorization middleware (**Implemented**), but no route uses them yet. Firestore and all feature routes are **Planned** and do not exist yet.

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

**Authentication and roles (Implemented, PR #4).** `authenticate` (`backend/src/middleware/auth.js`) verifies a Firebase ID token from `Authorization: Bearer <token>` and sets `req.user = { uid, role }`; `requireRole('admin')` etc. restricts a route. Failures return `401 {"error":"unauthenticated"}` or `403 {"error":"forbidden"}` with no further detail.

- **Roles come only from Firebase custom claims.** The verified token's `role` claim must be `rider` or `admin`; anything else means no role (403 on role-guarded routes). Nothing the client sends (headers, body, query) is used for authorization. The old repo read the role from a Firestore `workers` document on every request and defaulted to `rider`; that is intentionally not carried over.
- **Implications:** claims are refreshed only when the client's ID token refreshes (up to about an hour), so role changes lag. Immediate revocation needs `verifyIdToken(token, true)` (checks revocation) *in addition to* `revokeRefreshTokens`; `revokeRefreshTokens` alone does not invalidate existing ID tokens until they expire. Claims must be set by trusted server code or scripts via the Admin SDK (`setCustomUserClaims`); that registration/bootstrap step is **Planned** for later PRs, as is Firestore-rule use of `request.auth.token.role`.
- **Not yet verified against the emulator:** tests inject a fake verifier. No credentials are used; only the project id is needed to verify tokens.

**Tests** are hermetic: they need no `.env`, Firebase emulators, network access, or credentials. HTTP tests bind to an ephemeral port on `127.0.0.1`.

### Rider app (scaffold Implemented, PR #6; sign-in In progress, PR #7)

A Flutter app in `mobile/` (Android and iOS) with Material 3 theming (light and dark, following the system), bottom navigation between Home, Policy, Claims and Wallet, and a small HTTP client. **Everything else is Planned:** Policy, Claims and Wallet are labelled placeholders, and there is no business data yet. The one working screen element is a **development diagnostic** card on Home that calls `GET /health` once on load (and on Retry); it is not a rider feature.

**Prerequisites (toolchain upgraded in the `chore/upgrade-mobile-toolchain` maintenance PR, **In progress**):** Flutter 3.47.9 (stable; Dart 3.13.7), JDK 17+, and the Android SDK with platform 36, build-tools 36.0.0 and NDK 28.2.13676358 (Gradle can download the NDK; accept licenses with `flutter doctor --android-licenses`). Android `minSdk` is 24 (Android 7.0+), up from 23. The iOS deployment target is 15.0 (raised from 12.0); iOS builds need macOS and Xcode and have **not** been verified.

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


**Sign-in (In progress, PR #7).** Email/password registration, login and logout, with the session persisted by Firebase and the app gated on auth state (signed out: login/registration; signed in: the rider app). Covered by unit/widget tests using a fake auth service; manually verified end to end on a physical Android device against `shiftsure-dev` after the toolchain upgrade (maintainer-reported; not automated). Worker profiles, role assignment, password reset and social/phone sign-in are **Planned/not included**: a new rider has no backend role.

- Firebase client config is in `mobile/lib/firebase_options.dart` (**tracked**: public client config for the `shiftsure-dev` project only, no admin credentials) and was generated with `flutterfire configure`; `mobile/firebase.json` records that setup. The Google Services Gradle plugin is not used (Firebase is initialised explicitly from `firebase_options.dart`), so Android builds need no `google-services.json`; it stays git-ignored. FlutterFire is `firebase_core` 5.1.x / `firebase_auth` 7.0.x (Flutter 3.47.9); Android `minSdk` is 24. `GoogleService-Info.plist` (iOS) is not set up.
- Default: the Firebase development project (`shiftsure-dev`); Email/Password must be enabled in its Console. The backend needs `FIREBASE_PROJECT_ID=shiftsure-dev` in `backend/.env` and **no** `FIREBASE_AUTH_EMULATOR_HOST`.
- Emulator (optional, `USE_AUTH_EMULATOR=true`): the app, `firebase` CLI and backend all use the isolated project **`demo-shiftsure`**, never `shiftsure-dev`. Host defaults to `10.0.2.2` on Android and `127.0.0.1` otherwise (`AUTH_EMULATOR_HOST`/`AUTH_EMULATOR_PORT` override). The app refuses this mode in release builds. Not yet tested here.

```bash
# development project (backend: cd backend && npm run dev)
cd mobile && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# local emulator (three terminals)
firebase emulators:start --only auth --project demo-shiftsure   # repo root
cd backend && FIREBASE_PROJECT_ID=demo-shiftsure FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 npm run dev
cd mobile && flutter run --dart-define=USE_AUTH_EMULATOR=true --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

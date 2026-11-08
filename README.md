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
| Rider app | Flutter (Android, iOS) | Planned |
| Admin dashboard | Flutter Web | Planned |
| Backend API | Node.js + Express | Scaffold **Implemented** (PR #3); token auth and role middleware **Implemented** (PR #4, no protected routes yet); features **Planned** |
| Auth and database | Firebase Auth + Cloud Firestore | Deny-all Firestore client rules and emulator tests **In progress** (PR #5); data models **Planned** |
| AI service (pricing, risk scoring) | Python + FastAPI | Planned |
| Fraud / graph analysis | Neo4j | Planned |


## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): proposed high-level architecture
- [docs/ROADMAP.md](docs/ROADMAP.md): planned phases and small-PR sequence
- [CLAUDE.md](CLAUDE.md): conventions for AI-assisted development

## Development

Only the backend scaffold exists so far (see [Backend](#backend-scaffold-implemented-pr-3-in-review)). Setup instructions for other components will be added as each is introduced.

### Tooling baseline (Implemented)

- **CI:** a GitHub Actions workflow runs repository-hygiene checks (whitespace, forbidden credential files, JSON validity, relative Markdown links) and, since PR #3, the backend tests (`backend-tests` job). PR #5 adds the `firestore-rules-tests` job (Firestore emulator, Java 21). No other component has build or test jobs yet.
- **Firebase emulators (config only, not yet tested):** `firebase.json` configures the Auth (`127.0.0.1:9099`) and Firestore (`127.0.0.1:8080`) emulators with the Emulator UI disabled. `.firebaserc` uses the emulator-only demo project `demo-shiftsure`; no real Firebase project is configured. Once Firebase CLI is installed, the intended command is `firebase emulators:start --project demo-shiftsure`. Emulator startup has **not** been tested.
- **Firestore rules (In progress, PR #5):** `firestore.rules` denies all client SDK access; `firebase.json` loads it. The backend (Admin SDK, which bypasses rules) is the only intended data path. No collection-specific rules exist yet. Emulator tests live in `backend/test-rules/` and run with `cd backend && npm run test:rules` (needs Java 21+; uses demo project `demo-shiftsure`, never a real project). They are separate from the hermetic `npm test`.

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

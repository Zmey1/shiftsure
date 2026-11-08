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
| Backend API | Node.js + Express | Scaffold **Implemented** (PR #3); auth and features **Planned** |
| Auth and database | Firebase Auth + Cloud Firestore | Planned |
| AI service (pricing, risk scoring) | Python + FastAPI | Planned |
| Fraud / graph analysis | Neo4j | Planned |


## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): proposed high-level architecture
- [docs/ROADMAP.md](docs/ROADMAP.md): planned phases and small-PR sequence
- [CLAUDE.md](CLAUDE.md): conventions for AI-assisted development

## Development

Only the backend scaffold exists so far (see [Backend](#backend-scaffold-implemented-pr-3-in-review)). Setup instructions for other components will be added as each is introduced.

### Tooling baseline (Implemented)

- **CI:** a GitHub Actions workflow runs repository-hygiene checks (whitespace, forbidden credential files, JSON validity, relative Markdown links) and, since PR #3, the backend tests (`backend-tests` job). No other component has build or test jobs yet.
- **Firebase emulators (config only, not yet tested):** `firebase.json` configures the Auth (`127.0.0.1:9099`) and Firestore (`127.0.0.1:8080`) emulators with the Emulator UI disabled. `.firebaserc` uses the emulator-only demo project `demo-shiftsure`; no real Firebase project is configured. Once Firebase CLI is installed, the intended command is `firebase emulators:start --project demo-shiftsure`. Emulator startup has **not** been tested.
- **Open Firestore rules:** no `firestore.rules` file exists yet, so the Firestore emulator allows all reads and writes. This is for local development only; security rules are planned for PR #5.

### Backend scaffold (Implemented, PR #3 in review)

A minimal Node.js + Express app in `backend/` (plain JavaScript, ESM). It currently serves only `GET /health`. Firebase Admin, authentication, Firestore, and all feature routes are **Planned** (PR #4 onward) and do not exist yet.

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

**Tests** are hermetic: they need no `.env`, Firebase emulators, network access, or credentials. HTTP tests bind to an ephemeral port on `127.0.0.1`.

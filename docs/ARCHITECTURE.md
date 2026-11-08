# ShiftSure: Proposed Architecture

> **Status: proposal only.** Nothing described here is implemented. This document is a design to be reviewed and refined as components are built. Every component below is **Planned**.

## 1. Goals

- Weekly parametric income protection for quick-commerce delivery riders.
- Rider-filed claims, verified asynchronously using external evidence and fraud checks.
- Income-loss coverage only. No health, accident, life, or vehicle cover.
- Safe by default: simulated payouts, server-side authorization, emulator-based testing.

## 2. Components

| Component | Technology | Responsibility | Status |
|---|---|---|---|
| Rider app | Flutter (Android, iOS) | Registration, login, buy coverage, declare shifts, file and track claims, wallet | Planned |
| Admin dashboard | Flutter Web | Monitor zones, claims, pools, loss ratio; simulate disruptions | Planned |
| Backend API | Node.js + Express | Auth verification, business logic, claim orchestration, wallet and payouts | Scaffold **Implemented** (Express app, config, `GET /health`); auth and business logic **Planned** |
| Auth / database | Firebase Auth + Cloud Firestore | Identity, persistent data | Planned |
| AI service | Python + FastAPI | Risk scoring, premium calculation, verification inputs | Planned |
| Fraud / graph layer | Neo4j | Detect coordinated abuse and claim-event mismatches | Planned |

```
Rider app ──┐
            ├─► Backend API ──► Firestore / Firebase Auth
Admin web ──┘        │
                     ├─► AI service (FastAPI) ──► Neo4j
                     └─► External signals (weather, AQI; mocked at first)
```

The AI service and Neo4j links are added in later roadmap phases; they are not part of the initial build.

## 3. Proposed claim flow

1. Rider has active weekly coverage and declared shifts.
2. A disruption occurs. It is detected from external signals or created by an admin as a *disruption event*.
3. Rider files a claim; the backend validates it and stores it as `pending`.
4. The backend verifies it using its own rules: disruption evidence, shift overlap, and duplicate-claim checks.
5. The claim is marked `approved` or `rejected`.
6. If approved, the wallet is credited (simulated payout mode by default) and the rider is notified.

Disruption events are evidence only. They never approve claims or trigger payouts directly.

**Initial verification is backend rules only.** The AI service (risk scoring, premium calculation) and Neo4j fraud/graph checks will be integrated later, following the roadmap (Phases 5 and 6). Until then they are not part of the verification path.

## 4. Design principles

- **Backend is the single integration point.** Clients never talk to the AI service or Neo4j directly.
- **Server-side authorization.** Roles (rider, admin) are checked on the backend using verified Firebase tokens.
- **Service-to-service auth.** The backend authenticates to the AI service with a shared secret or equivalent.
- **Idempotent payouts.** A claim can be paid at most once.
- **Fail safe.** If fraud or verification services are unavailable, claims stay pending rather than auto-approving.
- **Simulated payouts by default.** A real payment provider is out of scope until explicitly decided.

## 5. Proposed data model (sketch)

Firestore collections, subject to change: `workers`, `policies`, `shifts`, `claims`, `disruption_events`, `wallets`/transactions, `zones`. Schemas, indexes, and security rules will be designed in their own PRs.

## 6. Environments and testing

- Local development uses the Firebase Emulator Suite and a local Neo4j instance.
- Tests never touch production Firebase or production databases.
- Unit tests are hermetic; integration and E2E tests run against emulators only.
- Each component keeps its own `.env.example`; real `.env` files and keys are never committed.

## 7. Open questions

- AI pricing approach and the data used to train or warm up the model.
- Neo4j hosting and scope versus a simpler first fraud-check version.
- Source of real disruption signals (weather and AQI providers) versus mocks.
- Deployment target (for example Cloud Run + Firebase Hosting).
- Payout provider, if real payouts are ever added.

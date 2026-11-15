# ShiftSure: Proposed Architecture

> **Status: proposal, partly built.** This is a design to be reviewed and refined as components are built. The status column below says what exists; anything not marked **Implemented** or **In progress** is **Planned**.

## 1. Goals

- Weekly parametric income protection for quick-commerce delivery riders.
- Rider-filed claims, verified asynchronously using external evidence and fraud checks.
- Income-loss coverage only. No health, accident, life, or vehicle cover.
- Safe by default: simulated payouts, server-side authorization, emulator-based testing.

## 2. Components

| Component | Technology | Responsibility | Status |
|---|---|---|---|
| Rider app | Flutter (Android, iOS) | Registration, login, buy coverage, declare shifts, file and track claims, wallet | Scaffold **Implemented** (PR #6). Email/password registration, login, logout and auth-gated navigation **Implemented** (PR #7). Worker profile setup, view and edit **Implemented** (PR #10). Dark-store selection **In progress** (PR #11). All other rider features **Planned** |
| Admin dashboard | Flutter Web | Monitor zones, claims, pools, loss ratio; simulate disruptions | Planned |
| Backend API | Node.js + Express | Auth verification, business logic, claim orchestration, wallet and payouts | Scaffold **Implemented** (Express app, config, `GET /health`); token auth and role middleware **Implemented** (PR #4); worker profile API (`/api/workers/me`) and rider-role onboarding **Implemented** (PR #10); dark-store catalog and assignment **In progress** (PR #11); other business logic **Planned** |
| Auth / database | Firebase Auth + Cloud Firestore | Identity, persistent data | Deny-all Firestore client rules **Implemented** (PR #5); `workers` collection **Implemented** (PR #10), with dark-store assignment fields **In progress** (PR #11); other data models **Planned** |
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
- **Server-side authorization.** Roles (rider, admin) are checked on the backend using verified Firebase ID tokens. **Decision (PR #4, implemented):** the role is read only from the token's signed `role` custom claim, not from a Firestore document. This avoids a database read per request and keeps authorization independent of Firestore rules; a missing or unknown claim means no role (denied). Consequences: claims change only on token refresh; they must be set server-side with the Admin SDK (rider onboarding: see below; admin bootstrap is **Planned**); Firestore rules can read `request.auth.token.role`; any `role` field in Firestore is not authoritative.
- **Rider app sign-in (PR #7, Implemented).** The app signs riders in with Firebase Auth email/password and sends the Firebase ID token to the backend through `ApiClient.tokenProvider`. By default it uses the Firebase *development* project; `USE_AUTH_EMULATOR=true` switches to the local Auth emulator under the isolated `demo-shiftsure` project (matching the Firebase CLI and backend settings) and is refused in release builds. `firebase_options.dart` (public client config for the dev project) is tracked. The client never sets roles or claims; a newly registered rider has **no role** until profile setup (below).
- **Rider-role onboarding (PR #10, Implemented).** `POST /api/workers/me` is the only code path that grants a role. After validating the body it reads the user's *current* claims from Firebase Auth (not the possibly stale token). If there is no role it sets `role: 'rider'`, merging other claims; any existing role, including `admin`, is left untouched and the request is refused (403). The claim is set *before* the profile is written, so a failed write is fixed by retrying. Because claims only reach the app in a new ID token, the API returns `token_refresh_required` and the app force-refreshes its token; `GET` re-checks the claim and the app retries a 403 `PATCH` once after refreshing, covering an app closed mid-onboarding. `GET`/`POST` accept a token with no role (onboarding) or `rider`; `PATCH` requires `rider`; admins are not worker accounts. Known limitation: the claim read-then-write is not atomic; the future admin-bootstrap PR must not race with it.
- **Service-to-service auth.** The backend authenticates to the AI service with a shared secret or equivalent.
- **Idempotent payouts.** A claim can be paid at most once.
- **Fail safe.** If fraud or verification services are unavailable, claims stay pending rather than auto-approving.
- **Simulated payouts by default.** A real payment provider is out of scope until explicitly decided.

## 5. Proposed data model (sketch)

Firestore collections, subject to change: `workers`, `policies`, `shifts`, `claims`, `disruption_events`, `wallets`/transactions, `zones`, `dark_stores`. Schemas and indexes will be designed in their own PRs.

**`workers/{firebaseUid}` (PR #10, Implemented; assignment fields PR #11, In progress).** `name`, `phone` (10-digit Indian mobile, normalized), `city` (validated free text), `platform` (`zepto` | `blinkit` | `swiggy_instamart` | `other`), server-set `created_at`/`updated_at`, and the optional, server-set `dark_store_id` and `zone_id` (absent until a store is chosen; removed when cleared). The document ID is the verified uid; there is no stored `uid` or `role`. Only the four profile fields are client-writable through `POST`/`PATCH`; the store is chosen through its own endpoint and `zone_id` is never client-supplied.

**Dark stores and zones (PR #11, In progress).** A *dark store* is a rider's weekly insurance pool membership (pools: PR #12, **Planned**); a *zone* is the geographic area used for exposure and disruption coverage. Several dark stores may belong to one zone and still keep separate weekly pools.

- **Catalog.** A small, **fictional demonstration dataset** in backend code (`backend/src/catalog/demo-catalog.js`) of cities, zones and stores, behind `createCatalog` (`backend/src/catalog/catalog.js`). Startup fails if the data is inconsistent: duplicate ids or city names, a zone in an unknown city, a store in an unknown zone or city or in a different city from its zone, an unsupported platform, or a non-boolean `active`. It is not stored in Firestore yet, so there is no seeding and `firestore.rules` is unchanged; moving it to `zones`/`dark_stores` collections (for admin management, PR #25) only replaces the catalog implementation.
- **Manual assignment (no GPS).** `GET /api/dark-stores` lists the active stores matching the rider's *stored* platform and city (request parameters are ignored). `PUT /api/workers/me/dark-store` takes only a `dark_store_id`; in a Firestore transaction the backend reads the profile, checks that the store exists, is active, and matches that platform and city, then writes `dark_store_id` and the store's `zone_id`. There is no default or fallback zone.
- **Re-validation.** A `PATCH` that changes `platform` or `city` re-checks the assignment inside the same transaction as the update and removes `dark_store_id`/`zone_id` if the store no longer fits. Because both writes are transactional, a concurrent edit and assignment cannot leave an incompatible store (verified on the emulator).
- **City matching.** The free-text `city` from PR #10 matches a catalog city when equal after trimming, whitespace collapsing and case-folding. No aliases (for example "Bangalore") yet.
- Policy purchase (PR #13) must require, and re-check, a valid assignment.

**Firestore client access (PR #5, implemented).** `firestore.rules` denies all client SDK reads and writes (unauthenticated, rider, and admin alike). Clients reach data only through the backend, which uses the Firebase Admin SDK; the Admin SDK bypasses security rules, so backend authorization is the only gate for application data. Collection-specific rules are deliberately deferred until real data models and access requirements exist. Emulator-based tests (`backend/test-rules/`) verify the denial.

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

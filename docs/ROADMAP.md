# ShiftSure: Roadmap

> **Status: early setup.** PR #1 is **Completed** (merged). PR #2 is **Completed** (merged). PR #3 is **Completed** (merged). PR #4 is **Completed** (merged). PR #5 is **Completed** (merged). PR #6 is **Completed** (merged). PR #7 is **Completed** (merged). PR #8 is **Completed** (merged). PR #9 is **In progress**. All other items are **Not started**. Scope and ordering may change after review.

Work ships as small, reviewable PRs: one concern each, docs updated alongside, tests included where code exists.
Larger tasks may split into smaller PRs during implementation.

## Phase 0: Repository setup
- **PR #1:** Repository initialization (README, `.gitignore`, `CLAUDE.md`, architecture and roadmap docs). *Completed (merged, #1).*
- **PR #2:** Tooling baseline (editorconfig, CI skeleton, PR template, Firebase emulator config). *Completed (merged, #2).*

## Phase 1: Backend foundation
- **PR #3:** Backend scaffold (Express, config loading, health endpoint, test setup). *Completed (merged, #3).*
- **PR #4:** Firebase Admin integration and auth middleware (token verification, role checks via custom claims). *Completed (merged, #4).*
- **PR #5:** Firestore security rules and emulator-based tests (deny-all for client SDK access). *Completed (merged, #5).*

## Phase 2: Rider app foundation
- **PR #6:** Flutter rider app scaffold (navigation, theming, API client). *Completed (merged, #6).*
- **PR #7:** Registration and login (Firebase Auth email/password; dev project by default, emulator optional). *Completed (merged, #7).*
- **PR #8:** Mobile toolchain upgrade (Flutter 3.47.9, Firebase core 5.x / auth 7.x, AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, minSdk 24, iOS 15.0). *Completed (merged, #8).*
- **PR #9:** Docs: align PR references and roadmap numbering with GitHub PR numbers. *In progress.*
- PR #10: Worker profile API and screens.

## Phase 3: Coverage and shifts
- PR #11: Weekly policy model, API, and purchase flow (fixed pricing first).
- PR #12: Shift declaration API and UI.

## Phase 4: Disruptions and claims
- PR #13: Disruption events (mock feeds, admin-created events).
- PR #14: Claim filing API and UI (`pending` state).
- PR #15: Claim verification pipeline (rules-based first; fail-safe to pending).
- PR #16: Wallet and simulated, idempotent payouts.

## Phase 5: AI service
- PR #17: FastAPI scaffold, service-to-service auth.
- PR #18: Risk scoring and premium calculation.
- PR #19: Backend integration with the AI service.

## Phase 6: Fraud layer
- PR #20: Neo4j local setup and graph model.
- PR #21: Fraud checks integrated into verification.

## Phase 7: Admin dashboard
- PR #22: Flutter Web admin scaffold and admin auth.
- PR #23: Claims, zones, and metrics views.
- PR #24: Disruption simulation controls.

## Phase 8: Hardening and release
- PR #25: End-to-end tests on emulators.
- PR #26: Security review and dependency audit.
- PR #27: Deployment configuration and docs.

## Ground rules
- Each PR should contain one focused, reviewable change. A feature may span multiple components when necessary.
- Reuse of old-repo code is reviewed and intentional, never bulk-copied.
- Tests never run against production Firebase or databases.

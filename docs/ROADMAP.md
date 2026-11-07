# ShiftSure: Roadmap

> **Status: early setup.** PR #1 is **Completed** (merged). PR #2 is **In progress**. All other items are **Not started**. Scope and ordering may change after review.

Work ships as small, reviewable PRs: one concern each, docs updated alongside, tests included where code exists.
Larger tasks may split into smaller PRs during implementation.

## Phase 0: Repository setup
- **PR #1:** Repository initialization (README, `.gitignore`, `CLAUDE.md`, architecture and roadmap docs). *Completed (merged, #1).*
- **PR #2:** Tooling baseline (editorconfig, CI skeleton, PR template, Firebase emulator config). *In progress.*

## Phase 1: Backend foundation
- PR #3: Backend scaffold (Express, config loading, health endpoint, test setup).
- PR #4: Firebase Admin integration and auth middleware (token verification, role checks).
- PR #5: Firestore security rules and emulator-based tests.

## Phase 2: Rider app foundation
- PR #6: Flutter rider app scaffold (navigation, theming, API client).
- PR #7: Registration and login against the Firebase emulator.
- PR #8: Worker profile API and screens.

## Phase 3: Coverage and shifts
- PR #9: Weekly policy model, API, and purchase flow (fixed pricing first).
- PR #10: Shift declaration API and UI.

## Phase 4: Disruptions and claims
- PR #11: Disruption events (mock feeds, admin-created events).
- PR #12: Claim filing API and UI (`pending` state).
- PR #13: Claim verification pipeline (rules-based first; fail-safe to pending).
- PR #14: Wallet and simulated, idempotent payouts.

## Phase 5: AI service
- PR #15: FastAPI scaffold, service-to-service auth.
- PR #16: Risk scoring and premium calculation.
- PR #17: Backend integration with the AI service.

## Phase 6: Fraud layer
- PR #18: Neo4j local setup and graph model.
- PR #19: Fraud checks integrated into verification.

## Phase 7: Admin dashboard
- PR #20: Flutter Web admin scaffold and admin auth.
- PR #21: Claims, zones, and metrics views.
- PR #22: Disruption simulation controls.

## Phase 8: Hardening and release
- PR #23: End-to-end tests on emulators.
- PR #24: Security review and dependency audit.
- PR #25: Deployment configuration and docs.

## Ground rules
- Each PR should contain one focused, reviewable change. A feature may span multiple components when necessary.
- Reuse of old-repo code is reviewed and intentional, never bulk-copied.
- Tests never run against production Firebase or databases.

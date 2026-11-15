# ShiftSure: Roadmap

> **Status: early setup.** PRs #1 to #10 are **Completed** (merged). PR #11 is **In progress**. All other items are **Not started**. Scope and ordering may change after review.

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
- **PR #9:** Docs: align PR references and roadmap numbering with GitHub PR numbers. *Completed (merged, #9).*
- **PR #10:** Worker profile API and screens (name, phone, city, delivery platform; backend-assigned rider role during onboarding). *Completed (merged, #10).* Does **not** include dark stores, zones, insurance pools, or policies.

## Phase 3: Coverage and shifts
The original "weekly policy" item was split into three PRs (catalog and assignment, pools, policy purchase), because buying a policy needs a validated dark-store and zone assignment first. Later items were renumbered to match.

- **PR #11:** Dark-store catalog and manual store assignment. *In progress.*
  - A backend-managed **dark-store catalog** linked to **zones**: dark store = weekly insurance pool membership; zone = geographic exposure and disruption coverage; several dark stores may share one zone while keeping separate pools. The prototype uses a small, **fictional demonstration dataset** in backend code (no real store locations; publicly sourced locations must not be treated as delivery boundaries or reused without permission).
  - **Manual store assignment** (no GPS, so the prototype works from any city): the backend lists stores matching the rider's saved platform and city, the rider selects one, and the backend validates its existence, availability, and platform/city compatibility, then resolves `zone_id`. There is no default or fallback zone. Changing a profile's platform or city re-validates the assignment and clears it if it no longer fits. The free-text `city` from PR #10 is matched to catalog cities case-insensitively.
  - Does **not** include pools, policies, pricing, GPS, or admin catalog management.
- PR #12: Weekly insurance pools, one per dark store per week.
- PR #13: Weekly policy model, API, and purchase flow (fixed pricing first; requires a valid store assignment).
- PR #14: Shift declaration API and UI.

## Phase 4: Disruptions and claims
- PR #15: Disruption events (mock feeds, admin-created events).
- PR #16: Claim filing API and UI (`pending` state).
- PR #17: Claim verification pipeline (rules-based first; fail-safe to pending).
- PR #18: Wallet and simulated, idempotent payouts.

## Phase 5: AI service
- PR #19: FastAPI scaffold, service-to-service auth.
- PR #20: Risk scoring and premium calculation.
- PR #21: Backend integration with the AI service.

## Phase 6: Fraud layer
- PR #22: Neo4j local setup and graph model.
- PR #23: Fraud checks integrated into verification.

## Phase 7: Admin dashboard
- PR #24: Flutter Web admin scaffold and admin auth.
- PR #25: Claims, zones, and metrics views.
- PR #26: Disruption simulation controls.

## Phase 8: Hardening and release
- PR #27: End-to-end tests on emulators.
- PR #28: Security review and dependency audit.
- PR #29: Deployment configuration and docs.

## Ground rules
- Each PR should contain one focused, reviewable change. A feature may span multiple components when necessary.
- Reuse of old-repo code is reviewed and intentional, never bulk-copied.
- Tests never run against production Firebase or databases.

# ShiftSure: Development Rules

ShiftSure is a **fresh rebuild**. Nothing is implemented yet; docs describe plans unless explicitly marked otherwise. See `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`.

## Workflow
- Work in small, reviewable PRs, following `docs/ROADMAP.md`. One concern per PR.
- Inspect first, then propose a short plan and wait for approval before creating or editing files.
- Never commit, push, or open a PR without explicit permission. The user reviews every change first.
- Do not install dependencies or scaffold apps unless the current PR's scope says so.

## Docs honesty
- Always label things **Planned**, **In progress**, or **Implemented**. Never describe planned features as working.
- Update docs in the same PR that changes behavior.

## Old repository
- The old repo (`~/VSCODE_FILES/guidewire_meow_company/`) is reference material only. Do not modify it.
- No bulk copying. Reuse of any code must be reviewed, intentional, and called out in the PR description.

## Security
- Never commit secrets: `.env`, service-account keys, keystores, `google-services.json`, Neo4j credentials. Commit only `.env.example` templates with placeholder values.
- Never run tests, seeds, or scripts against production Firebase or production databases. Use local emulators (Firebase Emulator Suite, local Neo4j) for integration and E2E tests.
- Payouts stay in simulated mode unless the user explicitly says otherwise.
- Backend must verify auth and enforce authorization server-side; never trust client-supplied roles or IDs.

## Conventions
- Planned layout: `mobile/` (rider app), `admin/` (Flutter Web), `backend/` (Node/Express), `ai/` (FastAPI), `docs/`.
- Each component owns its own tests and `.env.example`; keep tests hermetic by default.
- Commit messages: short imperative subject, optionally prefixed (`docs:`, `chore:`, `feat:`, `fix:`, `test:`).
- Run `git diff --check` and the relevant tests/linters before asking for review.


# Clario — Engineering Instructions

## Project
Clario is a native iOS productivity app using SwiftUI, SwiftData, Observation, Swift Concurrency, and AI-assisted thought organization.

The development branch is `dev`. Do not use `main` as the implementation baseline unless explicitly instructed.

## Current Objective
Prepare Clario for a future production release and credible portfolio demonstration.

Do not publish, deploy, submit to App Store Connect, or introduce unnecessary features.

## Engineering Principles
- Prefer simple, maintainable Swift code.
- Follow existing patterns unless there is a demonstrated problem.
- Keep views focused on presentation.
- Keep business logic independently testable.
- Use dependency injection for external services.
- Handle async cancellation and stale results correctly.
- Never silently lose user data.
- Propagate meaningful errors and provide recovery paths.
- Preserve SwiftData persistence compatibility.
- Avoid unnecessary third-party dependencies and abstractions.

## Security
- Never commit API keys, credentials, or private configuration.
- Never print secret values in reports or logs.
- Do not embed developer-owned API credentials in distributed builds.
- Do not assume that .gitignore protects already tracked files.
- No automatic Git history rewrites or force pushes.

## Development Workflow
1. Inspect relevant code before editing.
2. Identify the problem and minimal fix.
3. Work in small, focused changes.
4. Add regression tests for important behavior.
5. Run relevant tests and builds when available.
6. Review the diff for unrelated changes.
7. Commit changes with meaningful messages.
8. Report the verification results and remaining risks.

## Git Rules
- Preserve uncommitted user changes.
- Create feature branches from `dev`.
- Do not merge to `main` automatically.
- Do not reset, force-push, delete branches, or rewrite history without approval.
- Never commit failing work as completed.

## Verification
Use existing Xcode schemes and available simulator destinations.
Prefer Swift Testing or XCTest for automated tests.
Use in-memory SwiftData containers and mocked AI services for deterministic tests.
Record exact build commands and results.
Never claim tests passed unless executed.

## Scope
Prioritize correctness, security, testing, and release readiness over new functionality.

Do not make unrelated UI redesigns or architectural rewrites.

## Completion Report
Always report:
- Completed changes
- Files changed
- Tests and builds executed
- Commit SHAs
- Remaining issues
- Next recommended action

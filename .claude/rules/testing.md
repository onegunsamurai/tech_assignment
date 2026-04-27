# Testing Rules

## Philosophy

- **Test real behavior, not implementation details.** Assert on observable
  outcomes (return values, side effects on collaborators, emitted events)
  — not on which internal helper was called.
- **Mock only at service/API boundaries** — database, HTTP clients to
  third-party services, filesystem, clock, random. Never mock internal
  functions for convenience; if you need that, refactor.
- **Every bug fix must include a regression test** — the test must fail
  before the fix and pass after.
- **Test edge cases:** empty inputs, null/optional fields, boundary values,
  unexpected types, concurrent operations, retries, timeouts.
- **Test error paths:** network failures, invalid data, unauthorized access,
  malformed input, dependency outages.
- **Prefer integration-style tests over isolated unit tests** when they add
  more confidence for the same effort. Isolated unit tests are right when a
  pure function has non-trivial logic.
- **If a test needs more than 3 mocks, the code under test may need
  refactoring** — the class or function probably has too many
  collaborators.

## Coverage targets

- ≥80% coverage per module
- ≥70% overall
- 100% on critical paths (auth, payments, data integrity, access control)
- Coverage is a floor, not a goal — high coverage with weak assertions is
  worse than lower coverage with strong ones.

## What each kind of test covers

- **Unit tests** — one function or class with its direct dependencies mocked
  where appropriate. Fast, many, deterministic.
- **Integration tests** — a slice of the system with real collaborators
  (real DB, real queue, real HTTP server). Use test containers or fixtures
  rather than mocks.
- **Contract tests** — for every API endpoint. Verify request shape, response
  shape, status codes, and error format against the declared contract.
- **End-to-end tests** — one test per acceptance criterion on the user
  story. Browser or API-level depending on the feature. Keep them few and
  stable.

## Test discipline

- Co-locate tests with source when the language ecosystem supports it
  (Rust, Go, Vitest). Otherwise use a sibling `tests/` tree mirroring the
  source layout.
- Test names read as sentences: `returns_404_when_user_missing`,
  `rejects_login_after_five_failed_attempts`.
- Arrange / Act / Assert structure inside each test.
- One logical assertion per test; helper matchers may make multiple
  technical assertions.
- Clean up all shared state between tests (DB rows, in-memory caches,
  global stores, filesystem).
- Seed randomness and clocks so tests are deterministic.
- Flaky tests are bugs — fix or delete them; never retry-until-green.

## What the project chooses (fill in)

Add a `## Tooling` section to this file once you've picked your stack's
test runner, mocking library, coverage tool, and how to run them in CI.
The principles above are stable; the tools are not.

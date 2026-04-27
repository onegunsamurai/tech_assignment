---
name: test-audit
description: Audit test coverage and quality across the codebase
---

# Test Coverage & Quality Audit

Analyze the test suite for coverage gaps, weak assertions, and missing
edge cases. Language-agnostic — walk whichever source tree the project
has.

## Steps

### 1. Map source → test files

For each source file with non-trivial logic, find the corresponding
test file. Common test file conventions:

- **Co-located:** `foo.ts` + `foo.test.ts`, `foo.rs` + `foo_test.rs`,
  `foo.go` + `foo_test.go`
- **Sibling tree:** `src/foo.py` + `tests/test_foo.py`
- **Unit-mirror:** `lib/foo.kt` + `test/lib/FooTest.kt`

Flag any non-trivial source file with no corresponding test file.

### 2. Assess test quality

For each test file, check:

- **Assertion strength:** Tests that only check `toBeTruthy()`, status
  codes, or "it doesn't throw" without verifying response bodies or
  state are weak.
- **Over-mocking:** Tests with more than 3 `mock` / `vi.mock` / `patch`
  calls may be testing mocks, not code. Consider whether the code
  under test has too many collaborators.
- **Edge cases:** Look for missing tests around empty inputs, error
  responses, boundary values, concurrent operations, retries.
- **Error paths:** Verify tests exist for exception / error branches,
  not just happy paths.
- **Async handling:** Async tests should properly await the operations
  they're asserting on.
- **Flaky / skipped tests:** List any `xit`, `@pytest.mark.skip`,
  `#[ignore]`, `@Disabled`, or commented-out tests.

### 3. Run test suites

Use the project's configured test command (from `/check` discovery —
`CHECK_CMD` env var, `make test`, `npm test`, `cargo test`, etc.).

Report pass / fail counts and any failures.

### 4. Coverage

If the project has a coverage tool configured (coverage.py / c8 /
cargo-llvm-cov / jacoco), run it and surface:

- Overall coverage % vs the project's target (default: ≥80% per module,
  ≥70% overall)
- Worst-covered modules
- Files with <50% coverage and non-trivial logic

## Output Format

| Source file | Test file | Status | Issues |
|-------------|-----------|--------|--------|
| `path/to/file.py` | `tests/test_file.py` | Covered | Weak assertions on line 42 |
| `path/to/other.py` | — | **Missing** | No test file exists |

Then provide prioritized recommendations:

1. **Critical:** Untested files with complex logic (esp. auth, billing,
   data integrity)
2. **High:** Tests with weak assertions or excessive mocking
3. **Medium:** Missing edge-case coverage

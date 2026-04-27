Run the project's full check suite and summarize results.

## Instructions

1. Determine the project's check command by probing in this order:

   1. `CHECK_CMD` env var from `.claude/settings.local.json`
   2. `make check` if a `Makefile` with a `check` target exists
   3. `npm run check` if `package.json` has a `scripts.check` entry
   4. `just check` if a `justfile` with a `check` recipe exists
   5. Otherwise, run the project's individual gates in sequence
      (lint + typecheck + test + build) based on what's configured:
      - Python: `ruff check .`, `ruff format --check .`, `mypy`, `pytest`
      - TypeScript: `eslint .`, `tsc --noEmit`, the configured test runner
      - Go: `go vet ./...`, `go build ./...`, `go test ./...`
      - Rust: `cargo clippy`, `cargo fmt --check`, `cargo test`
      - Pick up whatever the repo actually has configured; do not invent
        commands it does not support.

2. Capture the full output. Do not truncate errors.

3. Parse and summarize pass/fail by category (lint, typecheck, test, build,
   other). For each category the project runs, report PASS, FAIL, or SKIP
   with the command that was executed.

4. For any failures:
   - Extract the specific error messages
   - Include `file:line` references when the tool provides them
   - Suggest a fix for each failure

5. End with a clear verdict: all checks pass, or a punch list of what needs
   fixing before commit.

## Notes

- Do not skip a failing gate silently.
- If a gate is misconfigured (e.g., command not found), report it as a
  config problem rather than a test failure.
- Never use `--no-verify` or similar bypass flags to make things pass.

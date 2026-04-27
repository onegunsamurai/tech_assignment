---
name: code-review
description: Pre-commit code review with structured findings
---

# Code Review

Review staged or recent changes for correctness, security, performance,
and style compliance.

## Steps

### 1. Gather changes

```bash
# Staged changes (pre-commit)
git diff --cached --name-only
git diff --cached

# Or recent changes on branch (resolve default branch first)
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@origin/@@' || echo main)
git diff "$DEFAULT"...HEAD --name-only
git diff "$DEFAULT"...HEAD
```

Categorize files by area — infer from the repo layout (server, client,
database, infra, docs, tests).

### 2. Review checklist

**Correctness:**
- Logic errors, off-by-one, null/undefined handling
- Missing `await` / unhandled promise rejections in async code
- Incorrect type annotations or missing narrowing
- Wrong assumptions about collection ordering or length

**Security:**
- SQL/command/template injection vectors
- Secrets or credentials in code
- Missing input validation at API boundaries
- Unsafe deserialization, path traversal, SSRF

**Performance:**
- N+1 queries or unnecessary database calls
- Large objects held in memory unnecessarily
- Missing pagination on list endpoints
- Quadratic loops on user-controlled input sizes

**Error handling:**
- Uncaught exceptions in async code
- Missing error responses for failure paths
- Swallowed errors (empty `except:` / `.catch(() => {})`)
- Retry storms without backoff

**Style compliance:**
- Follow the conventions declared in `.claude/rules/code-style.md`
- Naming consistent with the surrounding module
- DRY violations, dead code, unclear naming

**Tests:**
- Do behavioral changes have corresponding test updates?
- Are new edge cases covered?
- Regression test for any bug being fixed?

### 3. Verify

Run the project's check command (see `.claude/commands/check.md`).
Report any lint, typecheck, or test failures.

## Output Format

For each finding:

- **Severity:** Critical / High / Medium / Low
- **File:Line:** exact location
- **Problem:** what's wrong
- **Fix:** suggested correction
- **Impact:** what could go wrong if not fixed

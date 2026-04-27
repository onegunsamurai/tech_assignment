---
name: e2e-test-feature
description: E2E test the current feature/fix using Playwright MCP browser automation
---

# Feature-Focused E2E Testing

Test the feature or fix on the current branch using Playwright MCP
browser automation. Gathers context from git and issues, plans which
pages / flows to test, executes interactively, and reports results.

This skill is stack-agnostic — it figures out what to test from the
diff and the project's own routing / page layout.

## Prerequisites

- A locally running dev server. The base URL is taken from the
  `APP_BASE_URL` env var in `.claude/settings.local.json`, defaulting
  to `http://localhost:3000`.
- Optional auth — if `E2E_TEST_EMAIL` / `E2E_TEST_PASSWORD` are set,
  the skill will log in before testing auth-protected pages.

## Steps

### 1. Gather context

```bash
git branch --show-current
git log --oneline -10
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@origin/@@' || echo main)
git diff "$DEFAULT"...HEAD --name-only
```

- Parse the branch name for feature context (e.g., `fix/login-redirect`).
- Read recent commits to understand what changed.
- Extract any issue numbers from branch name or commit messages
  (`#123`). If found: `gh issue view <number>`.

If there are no changes vs the default branch, ask the user what
specific flow to test before proceeding.

### 2. Plan test flow

Map changed files to URLs to test. The specific mapping depends on the
project's framework and routing convention — infer it from the repo:

- Next.js app router: `src/app/foo/page.tsx` → `/foo`
- Next.js pages router: `pages/foo.tsx` → `/foo`
- Django / Rails / Laravel: check the project's routes file
- SPA with a router file: grep for route definitions and map to URLs
- API-only projects: test via HTTP calls with `mcp__playwright__browser_evaluate`

List the pages that need testing and whether each requires auth.

### 3. Pre-flight check

1. `mcp__playwright__browser_navigate` to `$APP_BASE_URL`. If it fails,
   tell the user to start the dev server and stop.
2. If the feature involves an API, health-check the API base URL.
3. If any auth-protected pages are in scope and credentials are
   configured, log in:
   - Navigate to the login page (project-specific path)
   - `mcp__playwright__browser_snapshot` to find the form
   - Fill the credentials via `mcp__playwright__browser_fill_form`
   - Submit and wait for redirect via `mcp__playwright__browser_wait_for`

### 4. Execute tests

For each page in the plan:

1. **Navigate:** `mcp__playwright__browser_navigate`
2. **Wait:** `mcp__playwright__browser_wait_for` for the page's key
   elements
3. **Snapshot:** `mcp__playwright__browser_snapshot` — verify expected
   elements are present in the accessibility tree
4. **Console check:** `mcp__playwright__browser_console_messages` —
   flag any `error` level messages
5. **Network check:** `mcp__playwright__browser_network_requests` —
   flag any 4xx / 5xx responses that are not expected
6. **Screenshot:** `mcp__playwright__browser_take_screenshot` — save
   to `e2e-screenshots/feat-NN-<page-name>.png`
7. **Feature interactions:** Based on the feature context, interact
   with the specific elements that changed
   (`mcp__playwright__browser_click`, `mcp__playwright__browser_fill_form`,
   `mcp__playwright__browser_type`, `mcp__playwright__browser_press_key`)
8. **Post-interaction verify:** Take another snapshot and screenshot
   to confirm the expected state change occurred

### 5. Close browser

`mcp__playwright__browser_close`.

## Output Format

```
## E2E Test Results: <branch-name>

### Context
- Branch: <branch-name>
- Feature: <description from issue or commits>
- Related issue: <#number and title, or "none">
- Pages tested: <comma-separated list>

### Results
| # | Page | Test | Status | Details |
|---|------|------|--------|---------|

### Console Errors
| Page | Level | Message |
|------|-------|---------|

### Network Errors
| Page | URL | Status | Method |
|------|-----|--------|--------|

### Screenshots
1. `e2e-screenshots/feat-01-<name>.png` — description

### Recommended Next Steps
- <actionable fix with file:line reference where possible>
```

Omit sections that have no entries.

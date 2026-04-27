---
name: e2e-test-general
description: Exploratory QA testing across the app — finds bugs and optionally files GitHub issues
---

# Exploratory E2E Testing

Act as a human QA tester. Walk through every user-facing page of the
application, testing common functionality and interactions. Collect all
bugs found, present them to the user, and file GitHub issues only if
the user confirms.

Stack-agnostic — the specific pages to test are inferred from the
project's routing / page layout at runtime.

## Configuration

The base URL is read from the `APP_BASE_URL` env var
(`.claude/settings.local.json`), defaulting to `http://localhost:3000`.
A sibling `APP_API_URL` can be set for the API health check; otherwise
the API base is inferred from the app's network requests.

If login-protected pages are in scope, set `E2E_TEST_EMAIL` and
`E2E_TEST_PASSWORD` so the skill can authenticate.

## Steps

### 1. Pre-flight check

1. `mcp__playwright__browser_navigate` to `$APP_BASE_URL`. If it fails,
   tell the user to start the dev server and stop.
2. If the app has a known `/health` / `/api/health` endpoint, check it
   via `mcp__playwright__browser_evaluate`. If not healthy, tell the
   user the backend is down and stop.

### 2. Discover pages to test

Enumerate the app's public and auth-protected pages. Options, in order
of preference:

- Read the project's route file (Next.js `app/` directory, Django
  `urls.py`, Rails `routes.rb`, etc.) and list URLs.
- Use the landing page's navigation links to discover pages.
- Ask the user for the list of pages to cover.

Classify each as **public** or **auth required**.

### 3. Walk public pages

For each public page, run this sequence:

1. `mcp__playwright__browser_navigate` to the URL
2. `mcp__playwright__browser_snapshot` — note visible headings,
   forms, buttons
3. `mcp__playwright__browser_take_screenshot` →
   `e2e-screenshots/gen-NN-<page>.png`
4. Exercise a representative interaction (click a primary button, open
   a tab, submit a search form)
5. `mcp__playwright__browser_console_messages` — flag errors
6. `mcp__playwright__browser_network_requests` — flag 4xx / 5xx

### 4. Log in (if credentials are configured)

Navigate to the login URL, fill `$E2E_TEST_EMAIL` / `$E2E_TEST_PASSWORD`,
submit, and wait for the expected redirect. If login fails, report and
skip the authenticated section.

### 5. Walk authenticated pages

Same as Step 3, for each auth-protected page.

### 6. Cross-cutting checks

- **Console errors:** Compile all errors across all pages into a
  deduplicated list (group by message, note which pages).
- **Network failures:** Compile all 4xx / 5xx requests across all
  pages.
- **Missing elements:** Note any pages where expected key elements were
  not found.
- **Unresolved loading states:** Note any pages that show spinners or
  empty states that never resolve.

### 7. Close browser

`mcp__playwright__browser_close`.

### 8. Present findings

Classify bugs by severity:

- **Critical:** Page crash, JS error blocking interaction, broken auth
- **High:** Missing functionality, broken navigation, API errors
- **Medium:** UI glitches, minor broken flows
- **Low:** Console warnings, cosmetic issues

Ask: **"I found N bugs. Would you like me to file these as GitHub
issues?"** Only proceed to step 9 if the user confirms.

### 9. File GitHub issues (if the user confirms)

Check for existing open bug issues first:

```bash
gh issue list --label bug --state open --limit 50
```

Skip any duplicates. For distinct bugs:

```bash
gh issue create \
  --title "[Bug] <concise description>" \
  --label "bug" \
  --body "## Description
<clear description>

## Steps to Reproduce
1. Navigate to <URL>
2. <action>
3. <observation>

## Expected Behavior
<what should happen>

## Actual Behavior
<what happened — include error messages>

## Environment
- Browser: Chromium (Playwright)
- App: $APP_BASE_URL
- Branch: <current branch>

## Additional Context
- Console errors: <if any>
- Screenshot: <path>
- Found by: /e2e-test-general exploratory run"
```

## Output Format

```
## Exploratory E2E Test Report

### Summary
- Pages tested: N
- Bugs found: N (N critical, N high, N medium, N low)
- Issues created: N (or "pending user confirmation")
- Console errors: N unique across N pages
- Network errors: N failed requests

### Page Results
| # | Page | Status | Issues Found |
|---|------|--------|--------------|

### Bugs Found
| # | Title | Severity | Page | Details |
|---|-------|----------|------|---------|

### Bugs Filed (after confirmation)
| # | Issue | Title | Severity |
|---|-------|-------|----------|

### Console Errors (deduplicated)
| Message | Pages | Count |
|---------|-------|-------|

### Screenshots
1. `e2e-screenshots/gen-01-<name>.png`
```

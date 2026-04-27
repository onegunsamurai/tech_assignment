---
name: auto-fix
description: >
  Automated end-to-end bug-fix pipeline. Trigger when the user says `/auto-fix`,
  `/auto-fix #N`, "fix a bug end-to-end", "find and fix an open issue",
  "auto-fix the highest priority bug", or requests an automated PR workflow
  for a GitHub issue. Also trigger on "run the fix pipeline" or
  "pick up a bug and open a PR". Do NOT trigger for manual code edits,
  one-off test runs, or partial workflows (e.g., "just open a PR").
---

# Auto-Fix Pipeline

Full automated pipeline: GitHub issue → code fix → validation → E2E →
commit (with approval) → PR → CI → Copilot review → implement fixes.

Stack-agnostic. Relies on the project's configured check command
(`CHECK_CMD` in `.claude/settings.local.json`), the worktree scripts
(if installed), and `.claude/rules/` for review criteria.

**Usage:**

- `/auto-fix` — picks highest-priority open bug
- `/auto-fix #N` — targets specific issue

---

## Common commands

| Label | Command |
|-------|---------|
| `DIFF_FILES` | `git diff "$DEFAULT"...HEAD --name-only` |
| `DIFF_FULL`  | `git diff "$DEFAULT"...HEAD` |
| `BRANCH_NAME`| `git branch --show-current` |
| `DEFAULT`    | `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \| sed 's@origin/@@' \|\| echo main` |

---

## Pipeline rules

1. **No stage may be skipped.** Work through every stage in sequence.
2. After each stage, output a checkpoint:
   ```
   ✓ Stage N complete: <one-line summary>
   → Next: Stage N+1 — <stage name>
   ```
3. If a stage HALTs, follow the **Halt Cleanup** procedure at the end.

---

## Stage 1 — Discover bug

**If a specific issue number `#N` was given:**
```bash
gh issue view N --json number,title,body,labels,comments
```

**Otherwise, find the highest-priority open bug:**
```bash
gh issue list --label bug --state open \
  --json number,title,body,labels \
  --limit 20
```

Pick the issue with the highest priority label: **P0 > P1 > P2 >
unlabeled**. If tied, pick the oldest (lowest number). If the project
uses different priority labels, adapt accordingly.

Display: `→ Targeting issue #N: <title>`. Read all comments for extra
context.

---

## Stage 2 — Create worktree

**Guard: clean working tree**
```bash
git status --porcelain
```
If non-empty → **HALT**: "Working tree is dirty. Commit or stash your
changes before running /auto-fix."

**Create an isolated worktree** (only if the worktree scripts are
installed in this repo — check `scripts/worktree-create.sh`):
```bash
bash scripts/worktree-create.sh N
```

If the worktree scripts are not installed, skip worktree creation and
operate on a fresh branch from `$DEFAULT`:
```bash
git switch -c fix/issue-N-<slug> "$DEFAULT"
```

Either way, subsequent stages run in the branch/worktree.

---

## Stage 3 — Analyze & fix

**Max 3 search-and-read cycles.** If no clear root cause after 3
cycles, **HALT** with a summary of what was examined and what
hypotheses were considered.

1. Cross-reference the issue with the codebase to identify affected
   files:
   - Search for function / class / route names mentioned in the issue
   - Check recent commits: `git log --oneline -20 -- <path>`
   - Read the affected files fully before editing

2. Implement the fix:
   - Fix the root cause, not just the symptom
   - Follow `.claude/rules/code-style.md` for the project's linter,
     formatter, and naming conventions
   - Follow `.claude/rules/security.md` for validation, parameterized
     queries, secret handling

3. Add or update tests:
   - Every bug fix must include a regression test (see
     `.claude/rules/testing.md`)
   - Test the failure case described in the issue, not just the happy
     path

---

## Stage 4 — Validation loop

Repeat until all checks pass, **max 3 attempts**. After 3 failures →
**HALT** with full diagnostic output.

### 4a. Project check

Run the project's check command (discovered per
`.claude/commands/check.md`):

```bash
${CHECK_CMD:-make check}
```

If failing: read the exact error, fix it, retry. Do not retry without
understanding the cause.

### 4b. Code review

Run `DIFF_FILES` and `DIFF_FULL`. Review for:

- **Correctness:** logic errors, missing async awaits, incorrect types,
  null handling
- **Security:** injection, secrets in code, missing input validation
- **Performance:** N+1 queries, missing pagination, large in-memory
  objects
- **Error handling:** uncaught exceptions, swallowed errors
- **Style:** per `.claude/rules/code-style.md`
- **Tests:** behavioral changes covered, edge cases present

Auto-fix any findings before continuing.

### 4c. Contract sync

If the diff touches API routes, schemas, or generated-client source-of-
truth files (see `.claude/rules/api-design.md` and
`.claude/hooks/protected-paths.conf`), run the project's regeneration
command and verify generated artifacts compile / typecheck.

### 4d. Doc sync

If the diff touches code areas that have a code→docs mapping (per
`.claude/agents/doc-writer.md`), update the corresponding docs and
verify the docs build succeeds.

---

## Stage 5 — E2E test loop (optional)

**Max 3 iterations.** Only run if the project has a dev server and the
feature is user-facing. Use the `e2e-test-feature` skill to exercise
the changed pages / flows. If E2E is not applicable, skip to Stage 6.

---

## Stage 6 — Commit (with approval)

1. Show the user the diff and propose a conventional-commit message
   (`fix:`, `feat:`, `docs:`, etc. — see `.claude/rules/git-workflow.md`).
2. Wait for user approval.
3. Commit with the approved message.

Never use `--no-verify` — the enforcement hooks will catch it.

---

## Stage 7 — Open pull request

```bash
git push -u origin HEAD
gh pr create \
  --title "<commit subject>" \
  --body "Closes #N

## Summary
<1-3 bullet points>

## Test plan
- [ ] <checklist from the issue>
"
```

---

## Stage 8 — CI watch + review response

1. Poll `gh pr checks` until all required checks complete.
2. If any check fails, loop back to Stage 4 with the failure output.
3. If automated reviewers (Copilot, CodeRabbit, etc.) post comments,
   triage them and implement actionable feedback. Ignore purely
   stylistic nits unless they align with `.claude/rules/code-style.md`.
4. Re-push and wait for checks again.

---

## Halt cleanup

When a stage HALTs:

1. Print a clear diagnostic of what was tried and why it failed.
2. Leave the worktree / branch in place so the user can pick up where
   you stopped.
3. Do not force-push, do not delete branches, do not revert commits
   without asking.

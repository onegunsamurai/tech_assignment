---
name: git-workflow
description: Branch naming, commit message conventions, and pre-commit workflow
globs: []
---

# Git Workflow

## Branch Naming
- `feat/` — New features (e.g., `feat/user-authentication`)
- `fix/` — Bug fixes (e.g., `fix/timeout-on-upload`)
- `docs/` — Documentation changes (e.g., `docs/contributing-guide`)
- `chore/` — Maintenance, refactors, build config
- `kb/` — Knowledge-base / internal notes (optional)

The worktree scripts (if installed) derive the prefix from the issue's
GitHub labels: `bug` → `fix/`, `documentation` → `docs/`, otherwise
`feat/`.

## Commit Messages
Use conventional format. Core prefixes:
- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation
- `refactor:` — Code change that neither fixes a bug nor adds a feature
- `test:` — Tests only
- `chore:` — Build, tooling, deps

Write messages that explain *why*, not just *what*:
- Good: `feat: add GitHub OAuth login flow`
- Good: `fix: handle third-party API timeout during assessment`
- Bad: `update files`
- Bad: `fix bug`

## Before Committing
- Run the project's check command (see `.claude/commands/check.md` —
  by default it discovers `CHECK_CMD`, `make check`, `npm run check`,
  or the configured lint / typecheck / test / build sequence).
- Never use `--no-verify` to bypass pre-commit hooks — fix the
  underlying issue instead. The `block-no-verify.sh` hook enforces
  this.
- Stage specific files rather than `git add -A` to avoid committing
  secrets or build artifacts.

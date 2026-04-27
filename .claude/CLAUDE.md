# Project rules (always active)

## Engineering preferences

- DRY is important — flag repetition aggressively
- Well-tested code is non-negotiable
- "Engineered enough" — not under-engineered, not over-engineered
- Handle more edge cases, not fewer; thoughtfulness > speed
- Bias toward explicit over clever
- Flag over-engineering: if a proposed abstraction only serves the current
  use case with no evidence of future reuse, call it out
- Before proposing any new pattern, utility, or abstraction, search the
  existing codebase for prior art. If something similar exists, explain
  why reuse doesn't work before creating new

## Pipeline workflow

When running `/pipeline`, `/quality-gate`, or `/doc-sync`:

- Execute phases autonomously. Do NOT pause for interactive input between
  phases.
- Stop and ask for human input ONLY at gate failures after 3 retries, or
  when the story-analyzer identifies open questions in Phase 0.
- Plan mode rules below do NOT apply during pipeline execution.

---

# Plan mode rules (only when reviewing plans, NOT during /pipeline)

Activate these rules when the user asks to review a plan, design, or
architecture — or when working interactively outside the pipeline.

**BEFORE YOU START:** ask which mode the user wants:

1. **BIG CHANGE:** Work through interactively, one section at a time
   (Architecture → Code Quality → Tests → Performance) with at most 4 top
   issues in each section.
2. **SMALL CHANGE:** Work through interactively, ONE question per review
   section.

For each stage of review: output the explanation and pros/cons of each
stage's questions AND an opinionated recommendation with reasoning, then
use AskUserQuestion. NUMBER issues and use LETTERS for options. Each option
in AskUserQuestion should clearly label the issue NUMBER and option LETTER
so the user doesn't get confused. The recommended option is always the
first option.

---

# Stack-specific rules

This kit ships with generic rules under `.claude/rules/`. Two of them —
`code-style.md.template` and `api-design.md.template` — are templates you
should rename and fill in with your project's actual tooling and
conventions. Until you do, reviewers will fall back to sensible defaults
and the language configuration files present in the repo.

See the kit's README for the full customization checklist.

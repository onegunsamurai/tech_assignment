---
name: doc-sync
description: Verify documentation accuracy against the current codebase
---

# Documentation Sync Verification

Audit project documentation to ensure it accurately reflects the current
codebase.

## Detect the docs system

Before auditing, identify the docs system in use (MkDocs, Docusaurus,
Sphinx, VitePress, mdBook, or plain markdown) by scanning for config
files and respect its conventions.

## Build or infer the code-to-docs mapping

If the project has declared a mapping in `.claude/agents/doc-writer.md`
or similar, use it. Otherwise infer from the repo layout:

| Code area | Typical doc location |
|-----------|---------------------|
| API routes / controllers | `docs/api/` or `docs/reference/api.md` |
| Data models / schemas | `docs/architecture/data-models.md` |
| Core services / domain logic | `docs/architecture/` |
| Build scripts / Makefile / CI | `docs/development/` |
| Frontend / UI | `docs/guides/` |

## Steps

1. **Inventory API surface:** List all route definitions (search for
   the project's routing DSL — `@router`, `app.get`, `router.post`,
   `@GetMapping`, `Route::`, `mux.HandleFunc`, etc.) and compare
   against the API reference doc. Flag missing or outdated entries.

2. **Inventory data models:** List public model / schema definitions
   and compare field names / types against the data-models doc.

3. **Check commands:** Verify any `make` targets, npm scripts, cargo
   tasks, or shell commands referenced in docs actually exist and have
   correct syntax.

4. **Check code examples:** For any code snippets in docs, verify they
   reference symbols that still exist in the codebase.

5. **Validate build:** Run the project's docs build command to catch
   broken links and missing pages. Examples:
   - MkDocs: `mkdocs build --strict`
   - Docusaurus: `npm run build` in the docs dir
   - Sphinx: `sphinx-build -W docs docs/_build`
   - mdBook: `mdbook build`
   - Plain markdown: the project's markdown linter, if any

## Output Format

For each discrepancy found:

- **File:** doc file path and line number
- **Issue:** what's wrong (missing / outdated / incorrect)
- **Fix:** suggested correction with code reference

End with a clear SYNC STATUS: IN SYNC / OUT OF SYNC (N issues).

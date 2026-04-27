# /doc-sync — Verify documentation is in sync with code

Checks that all documentation accurately reflects the current codebase.
Run periodically or before any release.

## Usage

```
/doc-sync
/doc-sync --fix    # auto-fix stale docs
```

## Execution

### Step 1: Detect documentation files

```bash
find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" \
  -not -path "*/vendor/*" -not -path "*/target/*" -not -path "*/dist/*" \
  -not -path "*/build/*" | head -50
find . -name "codemap*" -o -name "CODEMAP*" | head -20
```

Also detect the docs system in use (MkDocs / Docusaurus / Sphinx / VitePress
/ mdBook / plain markdown) by scanning for config files, and respect its
conventions.

### Step 2: Cross-reference checks

For each documentation file, verify:

**API documentation vs actual routes:**
- Grep for route definitions in whatever framework the project uses
  (`app.get`, `router.post`, `@Get`, `@Post`, `@app.route`, `mux.HandleFunc`,
  `Route::get`, etc.)
- Compare against documented endpoints
- Flag: documented endpoint that doesn't exist, existing endpoint not
  documented

**README vs actual setup:**
- Verify install commands actually work for the project's package manager
- Verify env var names match `.env.example` (if present)
- Verify file paths mentioned actually exist

**Architecture docs vs actual structure:**
- Verify component names mentioned in ADRs exist
- Verify directory structure matches documented structure
- Check that dependency relationships described are still accurate

**Codemap vs actual code:**
- If codemap files exist, verify listed files still exist
- Verify exports listed in codemap match actual exports
- Flag files that exist but aren't in any codemap

### Step 3: Report

```
## Documentation sync report

### Stale docs (code changed, docs didn't)
- docs/api.md: endpoint POST /api/v2/users not documented
- README.md: references src/old-module.ts which was renamed to
  src/new-module.ts

### Orphan docs (docs reference things that don't exist)
- docs/architecture.md: references PaymentGateway service (file deleted in
  commit abc123)

### Missing docs (code exists, no documentation)
- src/services/notification.ts: new service, no API doc entry

SYNC STATUS: IN SYNC / OUT OF SYNC (X issues)
```

If `--fix` flag is set, delegate to the doc-writer agent to fix each issue,
respecting the project's docs system conventions.

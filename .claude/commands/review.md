Review staged or branch changes for issues.

## Instructions

1. Determine what to review:
   - If there are staged changes: `git diff --cached`
   - Otherwise: `git diff <default-branch>...HEAD` (all branch changes)
     — detect the default branch from
     `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null`
     or fall back to `main` / `master`.
   - If neither has changes, tell the user and stop.

2. Categorize changes by area — infer from the repo's directory
   structure. Typical groups:
   - Server / API code
   - Client / UI code
   - Database / migrations
   - Infrastructure / CI
   - Docs and tests

3. Review against project standards declared in:
   - `.claude/rules/code-style.md` (linting, formatting, naming)
   - `.claude/rules/api-design.md` (API contracts, error shape)
   - `.claude/rules/security.md` (secrets, injection, auth patterns)
   - `.claude/rules/testing.md` (coverage, edge cases, mock discipline)
   - Plus: DRY violations and unnecessary complexity

4. Output findings in structured format:

   ```
   [SEVERITY] file_path:line_number
   Problem: <description>
   Fix: <suggested change>
   Impact: <what could go wrong>
   ```

5. Summarize: total findings by severity, and whether the changes are
   ready to commit.

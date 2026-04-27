#!/usr/bin/env bash
# push-reminder.sh — Gentle reminder to run checks before pushing.
# Called as a PreToolUse hook for Bash. Reads tool input JSON from stdin.
# Exit 0 = allow (never blocks).
#
# The reminder text is taken from the CHECK_CMD env var when set; otherwise
# it falls back to a generic message. Configure CHECK_CMD in
# .claude/settings.local.json under the env key, e.g.:
#
#   "env": { "CHECK_CMD": "make check" }

set -euo pipefail

# Read stdin (tool input JSON)
input=$(cat)

# Extract command from JSON — prefer jq, fall back to python3
if command -v jq >/dev/null 2>&1; then
  command_str=$(echo "$input" | jq -r '.command // empty' 2>/dev/null || true)
else
  command_str=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || true)
fi

# If we couldn't extract a command, allow
if [ -z "$command_str" ]; then
  exit 0
fi

# Print reminder for git push commands
if echo "$command_str" | grep -qE 'git\s+push'; then
  if [ -n "${CHECK_CMD:-}" ]; then
    echo "Reminder: run \`${CHECK_CMD}\` before pushing." >&2
  else
    echo "Reminder: run your project's lint + test command before pushing." >&2
  fi
fi

exit 0

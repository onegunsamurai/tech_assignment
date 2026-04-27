#!/usr/bin/env bash
# protect-files.sh — Guard secrets, auto-generated code, and other protected
# files from edits. Called as a PreToolUse hook for Edit|Write. Reads tool
# input JSON from stdin. Exit 0 = allow, Exit 2 = block.
#
# Protected patterns are loaded from .claude/hooks/protected-paths.conf
# (one glob per line, `#` for comments). A sensible default set is shipped
# with the kit; extend for your project's generated or sensitive paths.

set -euo pipefail

# Locate the config file relative to this script
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${HOOK_DIR}/protected-paths.conf"

# Read stdin (tool input JSON)
input=$(cat)

# Extract file_path from JSON — prefer jq, fall back to python3
if command -v jq >/dev/null 2>&1; then
  file_path=$(echo "$input" | jq -r '.file_path // empty' 2>/dev/null || true)
else
  file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null || true)
fi

# If we couldn't extract a file path, allow (fail open)
if [ -z "$file_path" ]; then
  exit 0
fi

filename=$(basename "$file_path")

# If no config file, fall back to a minimal hard-coded set so the hook is
# never a no-op after a botched install
if [ ! -f "$CONFIG_FILE" ]; then
  case "$filename" in
    .env|.env.*|*.pem|*.key|*.p12|id_rsa*|credentials.json)
      echo "BLOCKED: $filename is a secrets file. Do not read or modify it directly." >&2
      exit 2
      ;;
  esac
  exit 0
fi

# Read protected patterns from config (skip blank lines and comments)
while IFS= read -r pattern || [ -n "$pattern" ]; do
  # Trim surrounding whitespace
  pattern="${pattern#"${pattern%%[![:space:]]*}"}"
  pattern="${pattern%"${pattern##*[![:space:]]}"}"
  # Skip empty lines and comments
  [ -z "$pattern" ] && continue
  case "$pattern" in \#*) continue ;; esac

  # Match against filename (basename) — catches simple patterns like .env.*
  case "$filename" in
    $pattern)
      echo "BLOCKED: $file_path matches protected pattern '$pattern'." >&2
      echo "If this is auto-generated, regenerate it via the project's build command." >&2
      echo "If this is a secrets file, update it outside of Claude." >&2
      exit 2
      ;;
  esac

  # Match against full path — catches patterns with slashes
  # (use case-pattern matching with the full glob)
  case "$file_path" in
    $pattern|*/$pattern)
      echo "BLOCKED: $file_path matches protected pattern '$pattern'." >&2
      echo "If this is auto-generated, regenerate it via the project's build command." >&2
      echo "If this is a secrets file, update it outside of Claude." >&2
      exit 2
      ;;
  esac
done < "$CONFIG_FILE"

# File is not protected — allow
exit 0

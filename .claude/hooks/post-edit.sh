#!/bin/bash
set -euo pipefail

# Reads PostToolUse JSON payload on stdin. Extracts edited file path(s),
# runs tools/Invoke-Check.ps1, and writes any failures to stderr so Claude
# reads them and reacts. Strict mode for src/**, lenient elsewhere — the
# check script itself decides based on path prefix.

payload="$(cat)"

# Use jq if available; otherwise a tolerant grep-based extraction.
extract_path() {
  if command -v jq >/dev/null 2>&1; then
    echo "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null
  else
    echo "$payload" | grep -oE '"file_path"\s*:\s*"[^"]+"' | head -n1 | sed -E 's/.*"file_path"\s*:\s*"([^"]+)".*/\1/'
  fi
}

file_path="$(extract_path)"

if [ -z "${file_path:-}" ]; then
  exit 0
fi

# Only check .ps1 and .md files we care about.
case "$file_path" in
  *.ps1) ;;
  *.md)
    case "$file_path" in
      *custom_batch_actions/*) ;;
      src/custom_batch_actions/*) ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac

if ! command -v pwsh >/dev/null 2>&1; then
  # No pwsh — can't lint. Don't block the edit.
  exit 0
fi

repo_root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
check="$repo_root/tools/Invoke-Check.ps1"

if [ ! -f "$check" ]; then
  exit 0
fi

set +e
output="$(pwsh -NoProfile -File "$check" -Path "$file_path" 2>&1)"
status=$?
set -e

if [ $status -eq 0 ]; then
  # Surface info-level output (legacy nudge etc.) but don't block.
  echo "$output"
  exit 0
fi

echo "$output" >&2
exit 2

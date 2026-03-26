#!/bin/bash
# ============================================================================
# gl_mark_done.sh — Mark a GitLab todo as "Done"
# ============================================================================
#
# PURPOSE:
#   Marks a GitLab todo as done via the API and logs the action to an audit
#   file for error recovery.
#
# USAGE:
#   ./gl_mark_done.sh TODO_ID PROJECT TYPE TITLE URL
#
# ARGUMENTS:
#   TODO_ID    — GitLab todo ID (numeric, from gl_notifications.sh output)
#   PROJECT    — project path (e.g. group/project)
#   TYPE       — MergeRequest or Issue
#   TITLE      — todo subject title
#   URL        — web URL to the MR/issue
#
# DEPENDENCIES:
#   - glab (GitLab CLI, authenticated)
#
# EXIT CODES:
#   0 — success
#   1 — invalid arguments or API failure
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source config for audit log path
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

AUDIT_LOG="${MARKED_DONE_AUDIT_LOG:-$HOME/.local/share/gl-onmyplate/marked-done.tsv}"

# ---- Validate arguments -----------------------------------------------------

if [ $# -lt 5 ]; then
  echo "Usage: gl_mark_done.sh TODO_ID PROJECT TYPE TITLE URL" >&2
  exit 1
fi

TODO_ID="$1"
PROJECT="$2"
TYPE="$3"
TITLE="$4"
URL="$5"

# ---- Ensure audit log directory exists ---------------------------------------

AUDIT_DIR="$(dirname "$AUDIT_LOG")"
mkdir -p "$AUDIT_DIR"

# ---- Log the action ----------------------------------------------------------

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$TIMESTAMP" "$TODO_ID" "$PROJECT" "$TYPE" "$TITLE" "$URL" >> "$AUDIT_LOG"

# ---- Mark as done via API ----------------------------------------------------

glab api --method POST "/todos/${TODO_ID}/mark_as_done" --silent 2>/dev/null || {
  echo "ERROR: Failed to mark todo $TODO_ID as done" >&2
  echo "  Project: $PROJECT" >&2
  echo "  Title: $TITLE" >&2
  exit 1
}

echo "Marked done: $PROJECT — $TITLE"

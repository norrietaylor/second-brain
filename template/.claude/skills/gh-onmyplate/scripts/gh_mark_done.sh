#!/bin/bash
# ============================================================================
# gh_mark_done.sh — Mark a GitHub notification thread as "Done"
# ============================================================================
#
# PURPOSE:
#   Marks a notification thread as done via the GitHub API and logs the action
#   to an audit file for error recovery.
#
# USAGE:
#   ./gh_mark_done.sh THREAD_ID REPO TYPE TITLE URL
#
# ARGUMENTS:
#   THREAD_ID  — GitHub notification thread ID (numeric)
#   REPO       — owner/repo (e.g. elastic/beats)
#   TYPE       — PullRequest or Issue
#   TITLE      — notification subject title
#   URL        — web URL to the issue/PR
#
# DEPENDENCIES:
#   - gh (GitHub CLI, authenticated with 'notifications' scope)
#
# EXIT CODES:
#   0 — success
#   1 — invalid arguments or API failure
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source config for audit log path
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

AUDIT_LOG="${MARKED_DONE_AUDIT_LOG:-$HOME/.local/share/gh-onmyplate/marked-done.tsv}"

# ---- Validate arguments -----------------------------------------------------

if [ $# -lt 5 ]; then
  echo "Usage: gh_mark_done.sh THREAD_ID REPO TYPE TITLE URL" >&2
  exit 1
fi

THREAD_ID="$1"
REPO="$2"
TYPE="$3"
TITLE="$4"
URL="$5"

# ---- Ensure audit log directory exists ---------------------------------------

AUDIT_DIR="$(dirname "$AUDIT_LOG")"
mkdir -p "$AUDIT_DIR"

# ---- Log the action ----------------------------------------------------------

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$TIMESTAMP" "$THREAD_ID" "$REPO" "$TYPE" "$TITLE" "$URL" >> "$AUDIT_LOG"

# ---- Mark as done via API ----------------------------------------------------

HTTP_STATUS=$(gh api -X PATCH "/notifications/threads/$THREAD_ID" --silent 2>&1) || {
  echo "ERROR: Failed to mark thread $THREAD_ID as done" >&2
  echo "  Repo: $REPO" >&2
  echo "  Title: $TITLE" >&2
  exit 1
}

echo "Marked done: $REPO — $TITLE"

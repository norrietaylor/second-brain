#!/bin/bash
# ============================================================================
# gl_my_mrs.sh — List your open MRs with last post summary
# ============================================================================
#
# PURPOSE:
#   Lists all open Merge Requests authored by the current user, along with
#   the last note on each. Catches MRs that may be stale, waiting for
#   review, or have pipeline failures.
#
# WHAT IT SHOWS (per MR):
#   - Project, MR number, title, URL
#   - Created date and last updated date
#   - Pipeline status
#   - The last non-system note: who posted it, when, and the body text
#
# USAGE:
#   ./gl_my_mrs.sh              # default: MRs created within last 1 year
#   ./gl_my_mrs.sh 6m           # MRs created within last 6 months
#   ./gl_my_mrs.sh 1y           # MRs created within last 1 year
#   ./gl_my_mrs.sh --compact    # compact TSV output
#
# DEPENDENCIES:
#   - glab (GitLab CLI, authenticated)
#   - jq
#   - macOS date command (uses -v flag for date arithmetic)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Source config -----------------------------------------------------------

GL_HOST=""

# shellcheck source=config.sh
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

# shellcheck source=_filter_helpers.sh
source "$SCRIPT_DIR/_filter_helpers.sh"

_resolve_gitlab_host

# ---- Resolve current GitLab username -----------------------------------------

GL_USER=$(glab api /user 2>/dev/null | jq -r '.username')
if [ -z "$GL_USER" ]; then
  echo "ERROR: Could not determine GitLab username. Is 'glab' authenticated?" >&2
  exit 1
fi

# ---- Parse arguments ---------------------------------------------------------

COMPACT=false
TIMESPAN="1y"

for arg in "$@"; do
  case "$arg" in
    --compact) COMPACT=true ;;
    *d|*w|*m|*y) TIMESPAN="$arg" ;;
    *)
      echo "ERROR: Invalid argument '$arg'. Use format: Nd, Nw, Nm, or Ny (e.g. 7d, 2w, 6m, 1y) and/or --compact" >&2
      exit 1
      ;;
  esac
done

case "$TIMESPAN" in
  *d) DATE_OFFSET="-v-${TIMESPAN%d}d" ;;
  *w) DATE_OFFSET="-v-${TIMESPAN%w}w" ;;
  *m) DATE_OFFSET="-v-${TIMESPAN%m}m" ;;
  *y) DATE_OFFSET="-v-${TIMESPAN%y}y" ;;
esac

SINCE_DATE=$(date "$DATE_OFFSET" -u +%Y-%m-%dT%H:%M:%SZ)

# ---- Find open MRs -----------------------------------------------------------

echo "# Open MRs authored by ${GL_USER} (created since ${SINCE_DATE%T*})"
echo ""

MRS=$(glab api "/merge_requests?scope=created_by_me&state=opened&created_after=${SINCE_DATE}&per_page=100" \
  --paginate 2>/dev/null \
  | jq -s '
    flatten | .[]
    | {
        project: (.references.full | gsub("![0-9]+$"; "") | ltrimstr("/") | rtrimstr("/")),
        iid: (.iid | tostring),
        title: .title,
        created: .created_at[0:10],
        updated: .updated_at[0:10],
        url: .web_url,
        pipeline_status: (.head_pipeline.status // "none")
      }
  ')

if [ -z "$MRS" ]; then
  echo "(no open MRs found)"
  exit 0
fi

COUNT=$(echo "$MRS" | jq -s 'length')
echo "Found ${COUNT} open MR(s). Fetching last note for each..."
echo ""

# ---- For each MR, get the last note ------------------------------------------

echo "$MRS" | jq -c '.' | while read -r MR; do
  PROJECT=$(echo "$MR" | jq -r '.project')
  IID=$(echo "$MR" | jq -r '.iid')
  TITLE=$(echo "$MR" | jq -r '.title')
  CREATED=$(echo "$MR" | jq -r '.created')
  UPDATED=$(echo "$MR" | jq -r '.updated')
  URL=$(echo "$MR" | jq -r '.url')
  PIPELINE=$(echo "$MR" | jq -r '.pipeline_status')

  ENCODED_PROJECT=$(echo "$PROJECT" | sed 's|/|%2F|g')

  LAST_NOTE=$(glab api "/projects/${ENCODED_PROJECT}/merge_requests/${IID}/notes?sort=desc&order_by=created_at&per_page=10" \
    2>/dev/null \
    | jq '[.[] | select(.system == false)] | first // empty | {
        author: .author.username,
        date: .created_at[0:10],
        body: .body
      }' 2>/dev/null || echo "")

  if [ -n "$LAST_NOTE" ] && [ "$LAST_NOTE" != "null" ]; then
    LAST_AUTHOR=$(echo "$LAST_NOTE" | jq -r '.author')
    LAST_DATE=$(echo "$LAST_NOTE" | jq -r '.date')
    LAST_BODY=$(echo "$LAST_NOTE" | jq -r '.body')
  else
    LAST_AUTHOR=""
    LAST_DATE=""
    LAST_BODY=""
  fi

  if [ "$COMPACT" = true ]; then
    if [ -n "$LAST_AUTHOR" ]; then
      SUMMARY="${LAST_AUTHOR} (${LAST_DATE}) | pipeline: ${PIPELINE}"
    else
      SUMMARY="no notes | pipeline: ${PIPELINE}"
    fi
    printf '%s!%s\t%s\t%s\t%s\n' "$PROJECT" "$IID" "$CREATED" "$TITLE" "$SUMMARY"
  else
    echo "=== MR: ${PROJECT}!${IID} ==="
    echo "TITLE: ${TITLE}"
    echo "CREATED: ${CREATED}  UPDATED: ${UPDATED}"
    echo "PIPELINE: ${PIPELINE}"
    echo "URL: ${URL}"

    if [ -n "$LAST_AUTHOR" ]; then
      echo "LAST_NOTE_BY: ${LAST_AUTHOR} (${LAST_DATE})"
      echo "LAST_NOTE_BODY:"
      echo "$LAST_BODY"
    else
      echo "LAST_NOTE_BY: (no notes found — only the opening description exists)"
    fi

    echo "---"
    echo ""
  fi
done

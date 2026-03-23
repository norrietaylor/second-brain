#!/bin/bash
# ============================================================================
# gl_involved.sh — GitLab Involvement Search
# ============================================================================
#
# PURPOSE:
#   Searches GitLab for all open MRs and issues where you're involved and
#   that had recent activity. Does NOT depend on the todo inbox — queries
#   MR and issue data directly across multiple involvement dimensions.
#
# WHAT IT SHOWS:
#   - Open MRs where you are the author, assignee, or reviewer
#   - Open issues where you are the author or assignee
#   - Filtered to items with activity within the specified timespan
#   - Filters out MRs where your only involvement is via an ignored group
#
# STRENGTHS:
#   - Always works regardless of todo inbox state
#   - Immune to "Done" clearing — queries source of truth directly
#
# LIMITATIONS:
#   - No read/unread distinction — shows everything with recent activity
#   - Only shows OPEN items
#   - @mention involvement not captured (use gl_notifications.sh for that)
#
# OUTPUT COLUMNS:
#   PROJECT     — project path (group/project)
#   TYPE        — MR or Issue
#   UPDATED     — date of last activity (YYYY-MM-DD)
#   TITLE       — MR/issue title
#   URL         — clickable web URL
#
# USAGE:
#   ./gl_involved.sh                   # default: last 7 days
#   ./gl_involved.sh 3d                # last 3 days
#   ./gl_involved.sh 2w                # last 2 weeks
#   ./gl_involved.sh 1m                # last 1 month
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Source config and helpers -----------------------------------------------

IGNORE_REVIEW_GROUPS=()
FILTER_MERGED_REVIEWED=true
GL_HOST=""

# shellcheck source=config.sh
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"
# shellcheck source=_filter_helpers.sh
source "$SCRIPT_DIR/_filter_helpers.sh"

_resolve_gitlab_host

# ---- Resolve current GitLab user ---------------------------------------------

GL_USER=$(glab api /user 2>/dev/null | jq -r '.username')
if [ -z "$GL_USER" ]; then
  echo "ERROR: Could not determine GitLab username. Is 'glab' authenticated?" >&2
  exit 1
fi

GL_USER_ID=$(glab api /user 2>/dev/null | jq -r '.id')

# ---- Parse arguments ---------------------------------------------------------

COMPACT=false
TIMESPAN="7d"

for arg in "$@"; do
  case "$arg" in
    --compact) COMPACT=true ;;
    *d|*w|*m) TIMESPAN="$arg" ;;
    *)
      echo "ERROR: Invalid argument '$arg'. Use format: Nd, Nw, or Nm (e.g. 7d, 2w, 1m) and/or --compact" >&2
      exit 1
      ;;
  esac
done

case "$TIMESPAN" in
  *d) DATE_OFFSET="-v-${TIMESPAN%d}d" ;;
  *w) DATE_OFFSET="-v-${TIMESPAN%w}w" ;;
  *m) DATE_OFFSET="-v-${TIMESPAN%m}m" ;;
esac

SINCE_DATE=$(date "$DATE_OFFSET" -u +%Y-%m-%dT%H:%M:%SZ)
SINCE_DATE_SHORT="${SINCE_DATE%T*}"

echo "# Open MRs & issues involving ${GL_USER} updated since ${SINCE_DATE_SHORT} (${TIMESPAN})"
echo ""

# ---- Fetch results from multiple endpoints -----------------------------------

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# MRs: authored by me
glab api "/merge_requests?scope=created_by_me&state=opened&updated_after=${SINCE_DATE}&per_page=100" \
  --paginate 2>/dev/null \
  | jq -s '
    flatten | .[]
    | {
        project: (.references.full | gsub("![0-9]+$"; "") | ltrimstr("/") | rtrimstr("/")),
        type: "MR",
        is_mr: true,
        iid: (.iid | tostring),
        author: .author.username,
        assignees: [.assignees[]?.username],
        updated: .updated_at[0:10],
        title: .title,
        url: .web_url
      }
  ' >> "$TMPFILE" 2>/dev/null || true

# MRs: assigned to me
glab api "/merge_requests?scope=assigned_to_me&state=opened&updated_after=${SINCE_DATE}&per_page=100" \
  --paginate 2>/dev/null \
  | jq -s '
    flatten | .[]
    | {
        project: (.references.full | gsub("![0-9]+$"; "") | ltrimstr("/") | rtrimstr("/")),
        type: "MR",
        is_mr: true,
        iid: (.iid | tostring),
        author: .author.username,
        assignees: [.assignees[]?.username],
        updated: .updated_at[0:10],
        title: .title,
        url: .web_url
      }
  ' >> "$TMPFILE" 2>/dev/null || true

# MRs: I'm a reviewer
glab api "/merge_requests?reviewer_id=${GL_USER_ID}&state=opened&updated_after=${SINCE_DATE}&per_page=100" \
  --paginate 2>/dev/null \
  | jq -s '
    flatten | .[]
    | {
        project: (.references.full | gsub("![0-9]+$"; "") | ltrimstr("/") | rtrimstr("/")),
        type: "MR",
        is_mr: true,
        iid: (.iid | tostring),
        author: .author.username,
        assignees: [.assignees[]?.username],
        updated: .updated_at[0:10],
        title: .title,
        url: .web_url
      }
  ' >> "$TMPFILE" 2>/dev/null || true

# Issues: authored by me
glab api "/issues?scope=created_by_me&state=opened&updated_after=${SINCE_DATE}&per_page=100" \
  --paginate 2>/dev/null \
  | jq -s '
    flatten | .[]
    | {
        project: (.references.full | gsub("#[0-9]+$"; "") | ltrimstr("/") | rtrimstr("/")),
        type: "Issue",
        is_mr: false,
        iid: (.iid | tostring),
        author: .author.username,
        assignees: [.assignees[]?.username],
        updated: .updated_at[0:10],
        title: .title,
        url: .web_url
      }
  ' >> "$TMPFILE" 2>/dev/null || true

# Issues: assigned to me
glab api "/issues?scope=assigned_to_me&state=opened&updated_after=${SINCE_DATE}&per_page=100" \
  --paginate 2>/dev/null \
  | jq -s '
    flatten | .[]
    | {
        project: (.references.full | gsub("#[0-9]+$"; "") | ltrimstr("/") | rtrimstr("/")),
        type: "Issue",
        is_mr: false,
        iid: (.iid | tostring),
        author: .author.username,
        assignees: [.assignees[]?.username],
        updated: .updated_at[0:10],
        title: .title,
        url: .web_url
      }
  ' >> "$TMPFILE" 2>/dev/null || true

if [ ! -s "$TMPFILE" ]; then
  echo "(no open MRs or issues found for this period)"
  exit 0
fi

# ---- Deduplicate by URL ------------------------------------------------------

RAW_RESULTS=$(jq -sc 'unique_by(.url) | .[]' "$TMPFILE")
rm -f "$TMPFILE"

if [ -z "$RAW_RESULTS" ]; then
  echo "(no open MRs or issues found for this period)"
  exit 0
fi

# ---- Filter results ----------------------------------------------------------

HAS_GROUPS_TO_IGNORE=false
if [ ${#IGNORE_REVIEW_GROUPS[@]} -gt 0 ]; then
  HAS_GROUPS_TO_IGNORE=true
fi

FILTERED_COUNT=0
KEPT_RESULTS=""

while IFS= read -r item; do
  IS_MR=$(echo "$item" | jq -r '.is_mr')

  if [ "$IS_MR" = "true" ] && [ "$HAS_GROUPS_TO_IGNORE" = true ]; then
    AUTHOR=$(echo "$item" | jq -r '.author')
    PROJECT=$(echo "$item" | jq -r '.project')
    IID=$(echo "$item" | jq -r '.iid')

    AUTHOR_LOWER=$(echo "$AUTHOR" | tr '[:upper:]' '[:lower:]')
    USER_LOWER=$(echo "$GL_USER" | tr '[:upper:]' '[:lower:]')

    if [ "$AUTHOR_LOWER" != "$USER_LOWER" ]; then
      IS_ASSIGNEE=$(echo "$item" | jq -r --arg user "$GL_USER" '
        .assignees | map(ascii_downcase) | any(. == ($user | ascii_downcase))
      ')

      if [ "$IS_ASSIGNEE" != "true" ]; then
        MR_JSON=$(fetch_mr_json "$PROJECT" "$IID" 2>/dev/null || echo "")

        if [ -n "$MR_JSON" ] && is_group_only_involvement "$MR_JSON"; then
          FILTERED_COUNT=$((FILTERED_COUNT + 1))
          continue
        fi
      fi
    fi
  fi

  if [ "$COMPACT" = true ]; then
    TSV_LINE=$(echo "$item" | jq -r '[(.project + (if .is_mr then "!" else "#" end) + .iid), .type, .title] | @tsv')
  else
    TSV_LINE=$(echo "$item" | jq -r '[.project, .type, .updated, .title, .url] | @tsv')
  fi
  if [ -z "$KEPT_RESULTS" ]; then
    KEPT_RESULTS="$TSV_LINE"
  else
    KEPT_RESULTS="${KEPT_RESULTS}
${TSV_LINE}"
  fi

done < <(echo "$RAW_RESULTS" | jq -c '.')

# ---- Output ------------------------------------------------------------------

if [ -z "$KEPT_RESULTS" ]; then
  echo "(no open MRs or issues remaining after filtering)"
  if [ "$FILTERED_COUNT" -gt 0 ]; then
    echo "(${FILTERED_COUNT} item(s) filtered: group-only involvement)"
  fi
else
  COUNT=$(echo "$KEPT_RESULTS" | wc -l | tr -d ' ')
  echo "$KEPT_RESULTS" | column -t -s $'\t'
  echo ""
  echo "($COUNT items)"
  if [ "$FILTERED_COUNT" -gt 0 ]; then
    echo "(${FILTERED_COUNT} item(s) filtered: group-only involvement)"
  fi
fi

_filter_cleanup_cache

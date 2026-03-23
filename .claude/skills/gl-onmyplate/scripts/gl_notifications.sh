#!/bin/bash
# ============================================================================
# gl_notifications.sh — GitLab Todos (Notification Inbox) Query
# ============================================================================
#
# PURPOSE:
#   Queries the GitLab Todos API to show pending action items. Todos are
#   GitLab's equivalent of GitHub's notification inbox — they represent
#   things that need your attention.
#
# WHAT IT SHOWS:
#   - Pending todos where you were mentioned, assigned, review-requested, etc.
#   - Filters out build-failure todos and other automated noise
#   - Filters out MRs where your only involvement is via an ignored group
#     (configurable in config.sh)
#   - Filters out merged MRs unless you were @mentioned post-merge
#
# STRENGTHS:
#   - Directly reflects GitLab's "pending" todo state
#   - Catches @mentions, assignments, approval requests, review requests
#   - Covers both MRs and Issues
#
# LIMITATIONS:
#   - Todos marked "done" in the GitLab UI are gone from the API
#   - Only shows pending todos (everything pending is "new")
#   - Group/namespace filtering adds ~1 API call per MR todo that is not
#     clearly authored by or assigned to the user
#
# OUTPUT COLUMNS (default):
#   TODO_ID     — todo ID (for gl_mark_done.sh)
#   PROJECT     — project path (group/project)
#   TYPE        — MergeRequest or Issue
#   ACTION      — why the todo was created:
#                    assigned             = you were assigned
#                    mentioned            = you were @mentioned
#                    directly_addressed   = message opened with @you
#                    review_requested     = someone wants your review
#                    approval_required    = your approval is needed
#                    review_submitted     = someone reviewed your MR
#   UPDATED     — date of last activity (YYYY-MM-DD)
#   TITLE       — MR/issue title
#   URL         — clickable web URL
#
# OUTPUT COLUMNS (--compact):
#   TODO_ID     — todo ID
#   REF         — project path + MR/issue ref (e.g. group/project!123)
#   ACTION      — why you were notified
#   TITLE       — MR/issue title
#
# USAGE:
#   ./gl_notifications.sh              # all pending todos
#   ./gl_notifications.sh 3d           # todos updated in last 3 days
#   ./gl_notifications.sh 2w           # last 2 weeks
#   ./gl_notifications.sh 7d --compact # compact output with todo IDs
#
# DEPENDENCIES:
#   - glab (GitLab CLI, authenticated)
#   - jq
#   - macOS date command (uses -v flag for date arithmetic)
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

# ---- Resolve current GitLab username -----------------------------------------

GL_USER=$(glab api /user 2>/dev/null | jq -r '.username')
if [ -z "$GL_USER" ]; then
  echo "ERROR: Could not determine GitLab username. Is 'glab' authenticated?" >&2
  exit 1
fi

# ---- Parse arguments ---------------------------------------------------------

COMPACT=false
TIMESPAN=""

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

SINCE_DATE=""
if [ -n "$TIMESPAN" ]; then
  case "$TIMESPAN" in
    *d) DATE_OFFSET="-v-${TIMESPAN%d}d" ;;
    *w) DATE_OFFSET="-v-${TIMESPAN%w}w" ;;
    *m) DATE_OFFSET="-v-${TIMESPAN%m}m" ;;
  esac
  SINCE_DATE=$(date "$DATE_OFFSET" -u +%Y-%m-%dT%H:%M:%SZ)
fi

# ---- Fetch pending todos -----------------------------------------------------

if [ -n "$SINCE_DATE" ]; then
  echo "# Pending GitLab todos updated since ${SINCE_DATE%T*} (${TIMESPAN})"
else
  echo "# All pending GitLab todos"
fi
echo ""

NOISE_ACTIONS='["build_failed","oci_package_published","merge_train_removed","unmergeable"]'

RAW_TODOS=$(glab api "/todos?state=pending&per_page=100" --paginate 2>/dev/null \
  | jq -s --argjson noise "$NOISE_ACTIONS" '
    flatten
    | .[]
    | select(
        .target_type == "MergeRequest" or .target_type == "Issue"
      )
    | select(.action_name as $a | $noise | any(. == $a) | not)
    | {
        todo_id: (.id | tostring),
        project: .project.path_with_namespace,
        type: .target_type,
        iid: (.target.iid | tostring),
        action: .action_name,
        updated: .updated_at[0:10],
        title: .target.title,
        url: .target_url,
        ref: (.project.path_with_namespace + (if .target_type == "MergeRequest" then "!" else "#" end) + (.target.iid | tostring))
      }
  ')

# Apply timespan filter if provided
if [ -n "$SINCE_DATE" ] && [ -n "$RAW_TODOS" ]; then
  RAW_TODOS=$(echo "$RAW_TODOS" | jq -c --arg since "${SINCE_DATE%T*}" 'select(.updated >= $since)')
fi

if [ -z "$RAW_TODOS" ]; then
  echo "(no pending todos found)"
  exit 0
fi

# ---- Filter todos ------------------------------------------------------------

FILTERED_GROUP=""
FILTERED_MERGED=""
KEPT_RESULTS=""

while IFS= read -r todo; do
  TYPE=$(echo "$todo" | jq -r '.type')
  PROJECT=$(echo "$todo" | jq -r '.project')
  IID=$(echo "$todo" | jq -r '.iid')
  ACTION=$(echo "$todo" | jq -r '.action')

  if [ "$TYPE" = "MergeRequest" ]; then
    MR_JSON=$(fetch_mr_json "$PROJECT" "$IID" 2>/dev/null || echo "")

    if [ -n "$MR_JSON" ]; then
      if [ "$ACTION" = "review_requested" ]; then
        if is_group_only_involvement "$MR_JSON"; then
          FILTER_LINE=$(echo "$todo" | jq -r '[.project, .type, .action, .updated, .title] | join("  ")')
          FILTERED_GROUP="${FILTERED_GROUP:+${FILTERED_GROUP}
}  ${FILTER_LINE}"
          continue
        fi
      fi

      if is_merged_mr "$MR_JSON"; then
        FILTER_LINE=$(echo "$todo" | jq -r '[.project, .type, .action, .updated, .title] | join("  ")')
        FILTERED_MERGED="${FILTERED_MERGED:+${FILTERED_MERGED}
}  ${FILTER_LINE}"
        continue
      fi
    fi
  fi

  if [ "$COMPACT" = true ]; then
    TSV_LINE=$(echo "$todo" | jq -r '[.todo_id, .ref, .action, .title] | @tsv')
  else
    TSV_LINE=$(echo "$todo" | jq -r '[.todo_id, .project, .type, .action, .updated, .title, .url] | @tsv')
  fi
  if [ -z "$KEPT_RESULTS" ]; then
    KEPT_RESULTS="$TSV_LINE"
  else
    KEPT_RESULTS="${KEPT_RESULTS}
${TSV_LINE}"
  fi

done < <(echo "$RAW_TODOS" | jq -c '.')

# ---- Output ------------------------------------------------------------------

if [ -z "$KEPT_RESULTS" ]; then
  echo "(no todos remaining after filtering)"
else
  echo "$KEPT_RESULTS" | column -t -s $'\t'
fi

if [ -n "$FILTERED_GROUP" ]; then
  GROUP_COUNT=$(echo "$FILTERED_GROUP" | wc -l | tr -d ' ')
  echo ""
  echo "# Filtered: group-only involvement (${GROUP_COUNT}):"
  echo "$FILTERED_GROUP"
fi

if [ -n "$FILTERED_MERGED" ]; then
  MERGED_COUNT=$(echo "$FILTERED_MERGED" | wc -l | tr -d ' ')
  echo ""
  echo "# Filtered: merged MRs (${MERGED_COUNT}):"
  echo "$FILTERED_MERGED"
fi

_filter_cleanup_cache

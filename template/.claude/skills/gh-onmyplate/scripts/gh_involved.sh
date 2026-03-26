#!/bin/bash
# ============================================================================
# gh_involved.sh — GitHub Involvement Search
# ============================================================================
#
# PURPOSE:
#   Searches GitHub for all open issues and PRs where you're involved and
#   that had recent activity. This does NOT depend on the notification inbox
#   — it queries actual issue/PR data directly.
#
# WHAT IT SHOWS:
#   - Open issues and PRs where you authored, commented, were mentioned,
#     were assigned, or were requested for review
#   - Filtered to items with activity within the specified timespan
#   - Filters out PRs where your only involvement is via an ignored team
#     (configurable in config.sh)
#
# STRENGTHS:
#   - Always works regardless of notification inbox state or settings
#   - Immune to "Done" clearing — queries the source of truth directly
#   - Shows everything you're involved in, not just what GitHub decided
#     to notify you about
#
# LIMITATIONS:
#   - Does NOT tell you if there's new activity since you last looked
#     (no read/unread distinction)
#   - Only shows OPEN items (closed/merged issues and PRs are excluded
#     to reduce noise — you probably don't need to reply to those)
#   - GitHub search API has a 1000-result limit
#   - Cannot distinguish "new comment I haven't seen" from "I already
#     replied to the latest comment"
#   - Team filtering adds ~1 API call per PR result that is not authored
#     by or assigned to the user
#
# OUTPUT COLUMNS:
#   REPO        — repository (owner/name)
#   TYPE        — PR or Issue
#   UPDATED     — date of last activity (YYYY-MM-DD)
#   TITLE       — issue/PR title
#   URL         — clickable web URL
#
# USAGE:
#   ./gh_involved.sh                   # default: last 7 days
#   ./gh_involved.sh 3d                # last 3 days
#   ./gh_involved.sh 2w                # last 2 weeks
#   ./gh_involved.sh 1m                # last 1 month
#
# DEPENDENCIES:
#   - gh (GitHub CLI, authenticated with 'repo' scope)
#   - jq
#   - macOS date command (uses -v flag for date arithmetic)
#
# EXIT CODES:
#   0 — success (even if no results)
#   1 — invalid arguments or missing dependencies
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Source config and helpers -----------------------------------------------

# Safe defaults if config is missing
IGNORE_REVIEW_TEAMS=()
FILTER_MERGED_REVIEWED=true

# shellcheck source=config.sh
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"
# shellcheck source=_filter_helpers.sh
source "$SCRIPT_DIR/_filter_helpers.sh"

# ---- Resolve current GitHub username ----------------------------------------

GH_USER=$(gh api /user --jq '.login' 2>/dev/null)
if [ -z "$GH_USER" ]; then
  echo "ERROR: Could not determine GitHub username. Is 'gh' authenticated?" >&2
  exit 1
fi

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

# Convert shorthand to macOS date -v format
case "$TIMESPAN" in
  *d) DATE_OFFSET="-v-${TIMESPAN%d}d" ;;
  *w) DATE_OFFSET="-v-${TIMESPAN%w}w" ;;
  *m) DATE_OFFSET="-v-${TIMESPAN%m}m" ;;
esac

SINCE_DATE=$(date "$DATE_OFFSET" -u +%Y-%m-%d)

# ---- Fetch search results as JSON lines --------------------------------------

echo "# Open issues & PRs involving ${GH_USER} updated since ${SINCE_DATE} (${TIMESPAN})"
echo ""

RAW_RESULTS=$(gh api -X GET search/issues \
  -f q="involves:${GH_USER} updated:>=${SINCE_DATE} is:open" \
  -F per_page=100 \
  --jq '
    .items[]
    | {
        repo: (.repository_url | gsub("https://api.github.com/repos/"; "")),
        type: (if .pull_request then "PR" else "Issue" end),
        is_pr: (if .pull_request then true else false end),
        author: .user.login,
        assignees: [.assignees[]?.login],
        number: .number,
        updated: .updated_at[0:10],
        title: .title,
        url: .html_url
      }
  ')

if [ -z "$RAW_RESULTS" ]; then
  echo "(no open issues or PRs found for this period)"
  exit 0
fi

# ---- Filter results ----------------------------------------------------------

HAS_TEAMS_TO_IGNORE=false
if [ ${#IGNORE_REVIEW_TEAMS[@]} -gt 0 ]; then
  HAS_TEAMS_TO_IGNORE=true
fi

FILTERED_COUNT=0
KEPT_RESULTS=""

while IFS= read -r item; do
  IS_PR=$(echo "$item" | jq -r '.is_pr')

  # Only apply team filtering to PRs, and only if there are teams to ignore
  if [ "$IS_PR" = "true" ] && [ "$HAS_TEAMS_TO_IGNORE" = true ]; then
    AUTHOR=$(echo "$item" | jq -r '.author')
    REPO=$(echo "$item" | jq -r '.repo')
    NUMBER=$(echo "$item" | jq -r '.number')

    # Quick check: if user is the author, keep immediately (no API call)
    AUTHOR_LOWER=$(echo "$AUTHOR" | tr '[:upper:]' '[:lower:]')
    USER_LOWER=$(echo "$GH_USER" | tr '[:upper:]' '[:lower:]')

    if [ "$AUTHOR_LOWER" != "$USER_LOWER" ]; then
      # Check assignees from search result (also free, no API call)
      IS_ASSIGNEE=$(echo "$item" | jq -r --arg user "$GH_USER" '
        .assignees | map(ascii_downcase) | any(. == ($user | ascii_downcase))
      ')

      if [ "$IS_ASSIGNEE" != "true" ]; then
        # Need to fetch PR details to check requested_teams
        PR_JSON=$(fetch_pr_json "$REPO" "$NUMBER" 2>/dev/null || echo "")

        if [ -n "$PR_JSON" ] && is_team_only_involvement "$PR_JSON"; then
          FILTERED_COUNT=$((FILTERED_COUNT + 1))
          continue
        fi
      fi
    fi
  fi

  # Format as TSV line and accumulate
  if [ "$COMPACT" = true ]; then
    TSV_LINE=$(echo "$item" | jq -r '[(.repo + "#" + (.number | tostring)), .type, .title] | @tsv')
  else
    TSV_LINE=$(echo "$item" | jq -r '[.repo, .type, .updated, .title, .url] | @tsv')
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
  echo "(no open issues or PRs remaining after filtering)"
  if [ "$FILTERED_COUNT" -gt 0 ]; then
    echo "(${FILTERED_COUNT} item(s) filtered: team-only involvement)"
  fi
else
  COUNT=$(echo "$KEPT_RESULTS" | wc -l | tr -d ' ')
  echo "$KEPT_RESULTS" | column -t -s $'\t'
  echo ""
  echo "($COUNT items)"
  if [ "$FILTERED_COUNT" -gt 0 ]; then
    echo "(${FILTERED_COUNT} item(s) filtered: team-only involvement)"
  fi
fi

# ---- Cleanup -----------------------------------------------------------------

_filter_cleanup_cache

#!/bin/bash
# ============================================================================
# gh_notifications.sh — GitHub Notifications Inbox Query
# ============================================================================
#
# PURPOSE:
#   Queries the GitHub Notifications API to show threads with NEW activity
#   since you last looked. This is the "bell icon" inbox — it tells you
#   what's happened that you haven't dealt with yet.
#
# WHAT IT SHOWS:
#   - Threads where you're directly participating (commented, authored,
#     mentioned, assigned, review requested, etc.)
#   - Both read and unread notifications
#   - Filters out noise: repo-wide subscriptions, CI activity, security alerts
#   - Filters out team-only PR involvement (configurable in config.sh)
#   - Filters out merged PRs unless you were @mentioned by name
#
# STRENGTHS:
#   - Tells you about genuinely NEW activity (new comments, new reviews)
#   - Distinguishes "NEW" (unread) vs "read" so you know what you've seen
#   - Catches @mentions even if you haven't participated in the thread before
#
# LIMITATIONS:
#   - Notifications marked "Done" in the GitHub UI are permanently deleted
#     from the API — they cannot be retrieved
#   - Requires "Web" notifications to be enabled in GitHub Settings >
#     Notifications > Subscriptions (not just Email)
#   - If you historically had Web notifications off, only activity AFTER
#     enabling them will appear
#   - Team/merged filtering adds ~1 API call per PullRequest notification
#     that matches team_mention or review_requested reasons
#
# OUTPUT COLUMNS (default):
#   THREAD_ID   — notification thread ID (for mark-done API)
#   REPO        — repository (owner/name)
#   TYPE        — Issue or PullRequest
#   REASON      — why you were notified:
#                    author           = you created the thread
#                    comment          = you commented previously
#                    mention          = you were @mentioned
#                    review_requested = someone wants your review
#                    assign           = you were assigned
#                    team_mention     = your team was @mentioned
#                    state_change     = thread was opened/closed/merged
#   STATUS      — NEW (unread) or read
#   UPDATED     — date of last activity (YYYY-MM-DD)
#   TITLE       — issue/PR title
#   URL         — clickable web URL
#
# OUTPUT COLUMNS (--compact):
#   THREAD_ID   — notification thread ID
#   REPO#N      — repository#number (e.g. elastic/beats#123)
#   REASON      — why you were notified
#   STATUS      — NEW or read
#   TITLE       — issue/PR title
#
# USAGE:
#   ./gh_notifications.sh              # default: last 7 days
#   ./gh_notifications.sh 3d           # last 3 days
#   ./gh_notifications.sh 2w           # last 2 weeks
#   ./gh_notifications.sh 1m           # last 1 month
#   ./gh_notifications.sh 7d --compact # compact output with thread IDs
#
# DEPENDENCIES:
#   - gh (GitHub CLI, authenticated with 'notifications' scope)
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

SINCE_DATE=$(date "$DATE_OFFSET" -u +%Y-%m-%dT%H:%M:%SZ)

# ---- Fetch notifications as JSON lines ---------------------------------------

echo "# Notifications (participating) since ${SINCE_DATE%T*} (${TIMESPAN})"
echo ""

RAW_NOTIFICATIONS=$(gh api -X GET /notifications \
  -F all=true \
  -F participating=true \
  -F since="$SINCE_DATE" \
  -F per_page=100 \
  --paginate \
  --jq '
    .[]
    | select(.reason != "subscribed" and .reason != "ci_activity" and .reason != "security_alert")
    | {
        thread_id: (.id | tostring),
        repo: .repository.full_name,
        type: .subject.type,
        number: ((.subject.url // "") | split("/") | last),
        reason: .reason,
        status: (if .unread then "NEW" else "read" end),
        updated: .updated_at[0:10],
        title: .subject.title,
        api_url: (.subject.url // ""),
        web_url: ((.subject.url // "")
          | gsub("https://api.github.com/repos/"; "https://github.com/")
          | gsub("/pulls/"; "/pull/"))
      }
  ')

if [ -z "$RAW_NOTIFICATIONS" ]; then
  echo "(no participating notifications found for this period)"
  echo ""
  echo "Tip: if this is always empty, check GitHub Settings > Notifications >"
  echo "Subscriptions and ensure 'On GitHub' is enabled (not just Email)."
  exit 0
fi

# ---- Filter notifications ----------------------------------------------------

FILTERED_TEAM=""
FILTERED_MERGED=""
KEPT_RESULTS=""

while IFS= read -r notif; do
  TYPE=$(echo "$notif" | jq -r '.type')
  REASON=$(echo "$notif" | jq -r '.reason')
  API_URL=$(echo "$notif" | jq -r '.api_url')

  # Only apply PR-specific filters to PullRequest notifications
  if [ "$TYPE" = "PullRequest" ] && [ -n "$API_URL" ]; then

    # If user authored the PR, always keep — no API call needed
    if [ "$REASON" = "author" ]; then
      : # fall through to keep
    else
      # Fetch PR details (cached — one API call per unique PR)
      PR_JSON=$(fetch_pr_json_from_api_url "$API_URL" 2>/dev/null || echo "")

      if [ -n "$PR_JSON" ]; then
        # Check 1: team-only involvement (only for team_mention/review_requested)
        if [ "$REASON" = "team_mention" ] || [ "$REASON" = "review_requested" ]; then
          if is_team_only_involvement "$PR_JSON"; then
            FILTER_LINE=$(echo "$notif" | jq -r '[.repo, .type, .reason, .updated, .title] | join("  ")')
            FILTERED_TEAM="${FILTERED_TEAM:+${FILTERED_TEAM}
}  ${FILTER_LINE}"
            continue
          fi
        fi

        # Check 2: merged PR where user is not author
        if is_merged_pr "$PR_JSON"; then
          FILTER_LINE=$(echo "$notif" | jq -r '[.repo, .type, .reason, .updated, .title] | join("  ")')
          FILTERED_MERGED="${FILTERED_MERGED:+${FILTERED_MERGED}
}  ${FILTER_LINE}"
          continue
        fi
      fi
    fi
  fi

  # Format as TSV line and accumulate
  if [ "$COMPACT" = true ]; then
    TSV_LINE=$(echo "$notif" | jq -r '[.thread_id, (.repo + "#" + .number), .reason, .status, .title] | @tsv')
  else
    TSV_LINE=$(echo "$notif" | jq -r '[.thread_id, .repo, .type, .reason, .status, .updated, .title, .web_url] | @tsv')
  fi
  if [ -z "$KEPT_RESULTS" ]; then
    KEPT_RESULTS="$TSV_LINE"
  else
    KEPT_RESULTS="${KEPT_RESULTS}
${TSV_LINE}"
  fi

done < <(echo "$RAW_NOTIFICATIONS" | jq -c '.')

# ---- Output ------------------------------------------------------------------

if [ -z "$KEPT_RESULTS" ]; then
  echo "(no notifications remaining after filtering)"
else
  echo "$KEPT_RESULTS" | column -t -s $'\t'
fi

# Show filtered items for transparency
if [ -n "$FILTERED_TEAM" ]; then
  TEAM_COUNT=$(echo "$FILTERED_TEAM" | wc -l | tr -d ' ')
  echo ""
  echo "# Filtered: team-only involvement (${TEAM_COUNT}):"
  echo "$FILTERED_TEAM"
fi

if [ -n "$FILTERED_MERGED" ]; then
  MERGED_COUNT=$(echo "$FILTERED_MERGED" | wc -l | tr -d ' ')
  echo ""
  echo "# Filtered: merged PRs (${MERGED_COUNT}):"
  echo "$FILTERED_MERGED"
fi

# ---- Cleanup -----------------------------------------------------------------

_filter_cleanup_cache

#!/bin/bash
# ============================================================================
# gh_my_prs.sh — List your open PRs with last post summary
# ============================================================================
#
# PURPOSE:
#   Lists all open PRs authored by the current user, along with the last
#   comment/review on each. This catches PRs that may be stale, waiting
#   for review, or have CI failures — things that need the user's attention
#   even if no one has pinged them.
#
# WHAT IT SHOWS (per PR):
#   - Repo, PR number, title, URL
#   - Created date and last updated date
#   - The last post: who posted it, when, what type (comment/review/
#     review_comment), and the body text
#   - If the last post is from a CI bot, the agent can infer build status
#
# USAGE:
#   ./gh_my_prs.sh              # default: PRs created within last 1 year
#   ./gh_my_prs.sh 6m           # PRs created within last 6 months
#   ./gh_my_prs.sh 1y           # PRs created within last 1 year
#
# DEPENDENCIES:
#   - gh (GitHub CLI, authenticated)
#   - jq
#   - macOS date command (uses -v flag for date arithmetic)
#
# EXIT CODES:
#   0 — success (even if no results)
#   1 — invalid arguments or missing dependencies
# ============================================================================

set -euo pipefail

# ---- Resolve current GitHub username ----------------------------------------

GH_USER=$(gh api /user --jq '.login' 2>/dev/null)
if [ -z "$GH_USER" ]; then
  echo "ERROR: Could not determine GitHub username. Is 'gh' authenticated?" >&2
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

SINCE_DATE=$(date "$DATE_OFFSET" -u +%Y-%m-%d)

# ---- Find open PRs ----------------------------------------------------------

echo "# Open PRs authored by ${GH_USER} (created since ${SINCE_DATE})"
echo ""

PRS=$(gh api -X GET search/issues \
  -f q="author:${GH_USER} is:pr is:open created:>=${SINCE_DATE}" \
  -F per_page=100 \
  --jq '.items[] | {
    repo: (.repository_url | gsub("https://api.github.com/repos/"; "")),
    number: .number,
    title: .title,
    created: .created_at[0:10],
    updated: .updated_at[0:10],
    url: .html_url
  }')

if [ -z "$PRS" ]; then
  echo "(no open PRs found)"
  exit 0
fi

COUNT=$(echo "$PRS" | jq -s 'length')
echo "Found ${COUNT} open PR(s). Fetching last post for each..."
echo ""

# ---- For each PR, get the last post -----------------------------------------

echo "$PRS" | jq -c '.' | while read -r PR; do
  REPO=$(echo "$PR" | jq -r '.repo')
  NUMBER=$(echo "$PR" | jq -r '.number')
  TITLE=$(echo "$PR" | jq -r '.title')
  CREATED=$(echo "$PR" | jq -r '.created')
  UPDATED=$(echo "$PR" | jq -r '.updated')
  URL=$(echo "$PR" | jq -r '.url')

  # Collect last posts from each source in parallel
  TMPFILE=$(mktemp)
  trap "rm -f $TMPFILE" EXIT

  # Issue comments (last one)
  gh api "/repos/$REPO/issues/$NUMBER/comments" \
    -F per_page=1 -f direction=desc \
    --jq '.[] | {author: .user.login, date: .created_at[0:10], body: .body, src: "comment"}' \
    >> "$TMPFILE" 2>/dev/null || true

  # Reviews (last one with a body)
  gh api "/repos/$REPO/pulls/$NUMBER/reviews" \
    --paginate \
    --jq '[.[] | select((.body // "") != "")] | last | {author: .user.login, date: .submitted_at[0:10], body: ((.state // "REVIEW") + ": " + .body), src: "review"}' \
    >> "$TMPFILE" 2>/dev/null || true

  # Review comments (last one)
  gh api "/repos/$REPO/pulls/$NUMBER/comments" \
    -F per_page=1 -f direction=desc \
    --jq '.[] | {author: .user.login, date: .created_at[0:10], body: ("(on " + (.path // "file") + ") " + .body), src: "review_comment"}' \
    >> "$TMPFILE" 2>/dev/null || true

  # Pick the most recent post across all sources
  LAST_POST=$(jq -s 'map(select(.date != null)) | sort_by(.date) | last // empty' "$TMPFILE" 2>/dev/null)
  rm -f "$TMPFILE"

  if [ -n "$LAST_POST" ]; then
    LAST_AUTHOR=$(echo "$LAST_POST" | jq -r '.author')
    LAST_DATE=$(echo "$LAST_POST" | jq -r '.date')
    LAST_SRC=$(echo "$LAST_POST" | jq -r '.src')
    LAST_BODY=$(echo "$LAST_POST" | jq -r '.body')
  else
    LAST_AUTHOR=""
    LAST_DATE=""
    LAST_SRC=""
    LAST_BODY=""
  fi

  if [ "$COMPACT" = true ]; then
    # Compact: REPO#N  CREATED  TITLE  LAST_POST_SUMMARY
    if [ -n "$LAST_AUTHOR" ]; then
      SUMMARY="${LAST_AUTHOR} (${LAST_SRC}, ${LAST_DATE})"
    else
      SUMMARY="no comments"
    fi
    printf '%s#%s\t%s\t%s\t%s\n' "$REPO" "$NUMBER" "$CREATED" "$TITLE" "$SUMMARY"
  else
    echo "=== PR: ${REPO}#${NUMBER} ==="
    echo "TITLE: ${TITLE}"
    echo "CREATED: ${CREATED}  UPDATED: ${UPDATED}"
    echo "URL: ${URL}"

    if [ -n "$LAST_AUTHOR" ]; then
      echo "LAST_POST_BY: ${LAST_AUTHOR} (${LAST_SRC} on ${LAST_DATE})"
      echo "LAST_POST_BODY:"
      echo "$LAST_BODY"
    else
      echo "LAST_POST_BY: (no comments found — only the opening post exists)"
    fi

    echo "---"
    echo ""
  fi
done

#!/bin/bash
# ============================================================================
# gh_thread_context.sh — Extract relevant discussion tail from a GitHub thread
# ============================================================================
#
# PURPOSE:
#   Given a GitHub issue or PR URL, fetches all comments and returns only the
#   tail of the conversation starting from the user's last involvement. This
#   avoids loading the entire (often very long) discussion into an AI agent's
#   context window.
#
# HOW IT FINDS THE ANCHOR POINT:
#   Scans all posts chronologically and finds the LATEST one where either:
#     - The current authenticated user is the author, OR
#     - The post body contains @username (a mention)
#   Then returns everything from that point to the end of the thread.
#   If no anchor is found, returns the entire thread.
#
# WHAT IT FETCHES (merged chronologically):
#   - The opening post (issue/PR body)
#   - Issue comments (main conversation — works for both issues and PRs)
#   - PR reviews (review summaries with APPROVED/CHANGES_REQUESTED/etc.)
#   - PR review comments (inline code discussion)
#
# OUTPUT FORMAT:
#   Structured text (not JSON) designed for AI agent consumption:
#     - Header with metadata (repo, title, state, counts, action hint)
#     - Posts from anchor point onward with author, date, and body
#
# USAGE:
#   ./gh_thread_context.sh <github-url>
#   ./gh_thread_context.sh https://github.com/owner/repo/issues/123
#   ./gh_thread_context.sh https://github.com/owner/repo/pull/456
#
# DEPENDENCIES:
#   - gh (GitHub CLI, authenticated)
#   - jq
#
# EXIT CODES:
#   0 — success
#   1 — invalid arguments, parse error, or API failure
# ============================================================================

set -euo pipefail

# ---- Usage -------------------------------------------------------------------

if [ $# -lt 1 ]; then
  echo "Usage: $0 <github-issue-or-pr-url>" >&2
  echo "Example: $0 https://github.com/owner/repo/pull/123" >&2
  exit 1
fi

URL="${1%/}"

# ---- Parse URL ---------------------------------------------------------------

if [[ "$URL" =~ github\.com/([^/]+/[^/]+)/(issues|pull)/([0-9]+) ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}"
  URL_TYPE="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
  IS_PR=$( [ "$URL_TYPE" = "pull" ] && echo true || echo false )
else
  echo "ERROR: Could not parse URL: $URL" >&2
  echo "Expected: https://github.com/owner/repo/issues/N or .../pull/N" >&2
  exit 1
fi

# ---- Get current user --------------------------------------------------------

GH_USER=$(gh api /user --jq '.login' 2>/dev/null)
if [ -z "$GH_USER" ]; then
  echo "ERROR: Could not determine GitHub username. Is 'gh' authenticated?" >&2
  exit 1
fi

# ---- Fetch data --------------------------------------------------------------

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# Issue/PR metadata + opening post (single API call)
ISSUE_JSON=$(gh api "/repos/$OWNER_REPO/issues/$NUMBER")
TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
STATE=$(echo "$ISSUE_JSON" | jq -r '.state')
echo "$ISSUE_JSON" | jq '{author: .user.login, date: .created_at, body: (.body // ""), src: "post"}' >> "$TMPFILE"

# Issue comments (works for both issues and PRs)
gh api "/repos/$OWNER_REPO/issues/$NUMBER/comments" \
  --paginate \
  --jq '.[] | {author: .user.login, date: .created_at, body: (.body // ""), src: "comment"}' \
  >> "$TMPFILE" 2>/dev/null || true

# PR-specific: reviews and inline review comments
if [ "$IS_PR" = true ]; then
  gh api "/repos/$OWNER_REPO/pulls/$NUMBER/reviews" \
    --paginate \
    --jq '.[] | select((.body // "") != "") | {author: .user.login, date: .submitted_at, body: ((.state // "REVIEW") + ": " + .body), src: "review"}' \
    >> "$TMPFILE" 2>/dev/null || true

  gh api "/repos/$OWNER_REPO/pulls/$NUMBER/comments" \
    --paginate \
    --jq '.[] | {author: .user.login, date: .created_at, body: ("(on " + (.path // "file") + ")\n" + (.body // "")), src: "review_comment"}' \
    >> "$TMPFILE" 2>/dev/null || true
fi

# ---- Process and output ------------------------------------------------------

jq -rs --arg user "$GH_USER" --arg title "$TITLE" --arg state "$STATE" \
  --arg repo "$OWNER_REPO" --arg number "$NUMBER" --arg is_pr "$IS_PR" '

  sort_by(.date) as $timeline |
  ($timeline | length) as $total |

  # Find anchor: last index where author==user or body mentions @user
  [$timeline | to_entries[] | select(
    .value.author == $user or
    (.value.body | ascii_downcase | contains("@" + ($user | ascii_downcase)))
  ) | .key] as $matches |

  (if ($matches | length) == 0 then 0 else ($matches | last) end) as $anchor |
  $timeline[$anchor:] as $tail |
  (($timeline | last).author == $user) as $user_is_last |

  # Anchor description
  (if ($matches | length) == 0 then
    "beginning — you were not found in thread"
  elif $timeline[$anchor].author == $user then
    "your last post"
  else
    "last post mentioning you"
  end) as $anchor_desc |

  # Header
  "THREAD: \($repo)#\($number) — \($title)\n" +
  "TYPE: \(if $is_pr == "true" then "Pull Request" else "Issue" end)\n" +
  "STATE: \($state)\n" +
  "USER: \($user)\n" +
  "TOTAL_POSTS: \($total)\n" +
  "SHOWING: posts \($anchor + 1) through \($total) of \($total) (from \($anchor_desc))\n" +
  "LAST_POST_BY: \(($timeline | last).author)\n" +
  "ACTION_HINT: \(
    if $user_is_last then
      "Last post is yours — likely no action needed"
    else
      "Last post is by someone else — may need your response"
    end
  )\n" +
  "===\n" +

  # Posts
  ($tail | to_entries | map(
    "\n[\($anchor + .key + 1)/\($total)] \(.value.src) by @\(.value.author) on \(.value.date[0:10]):\n\(.value.body)\n---"
  ) | join(""))

' "$TMPFILE"

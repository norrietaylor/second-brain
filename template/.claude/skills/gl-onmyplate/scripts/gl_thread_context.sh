#!/bin/bash
# ============================================================================
# gl_thread_context.sh — Extract relevant discussion tail from a GitLab thread
# ============================================================================
#
# PURPOSE:
#   Given a GitLab MR or issue URL, fetches all notes and returns only the
#   tail of the conversation starting from the user's last involvement.
#
# HOW IT FINDS THE ANCHOR POINT:
#   Scans all non-system notes chronologically and finds the LATEST one where:
#     - The current authenticated user is the author, OR
#     - The note body contains @username (a mention)
#   Then returns everything from that point to the end of the thread.
#   If no anchor is found, returns the entire thread.
#
# USAGE:
#   ./gl_thread_context.sh <gitlab-url>
#   ./gl_thread_context.sh https://gitlab.example.com/group/project/-/issues/123
#   ./gl_thread_context.sh https://gitlab.example.com/group/project/-/merge_requests/456
#
# DEPENDENCIES:
#   - glab (GitLab CLI, authenticated)
#   - jq
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

# ---- Usage -------------------------------------------------------------------

if [ $# -lt 1 ]; then
  echo "Usage: $0 <gitlab-mr-or-issue-url>" >&2
  echo "Example: $0 https://gitlab.example.com/group/project/-/merge_requests/123" >&2
  exit 1
fi

URL="${1%/}"

# ---- Parse URL ---------------------------------------------------------------
# Supports any hostname: gitlab.com, self-hosted, subgroups

# Strip protocol + hostname to get the path portion (pure bash, no sed)
NOPROTOCOL="${URL#*://}"
URL_PATH="${NOPROTOCOL#*/}"

if [[ "$URL_PATH" =~ ^([^/]+(/[^/]+)*)/-/(merge_requests|issues)/([0-9]+) ]]; then
  PROJECT_PATH="${BASH_REMATCH[1]}"
  URL_TYPE="${BASH_REMATCH[3]}"
  IID="${BASH_REMATCH[4]}"
  IS_MR=$( [ "$URL_TYPE" = "merge_requests" ] && echo true || echo false )
else
  echo "ERROR: Could not parse URL: $URL" >&2
  echo "Expected: https://gitlab.example.com/group/project/-/merge_requests/N or .../issues/N" >&2
  exit 1
fi

ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's|/|%2F|g')

# ---- Get current user --------------------------------------------------------

GL_USER=$(glab api /user 2>/dev/null | jq -r '.username')
if [ -z "$GL_USER" ]; then
  echo "ERROR: Could not determine GitLab username. Is 'glab' authenticated?" >&2
  exit 1
fi

# ---- Fetch data --------------------------------------------------------------

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

if [ "$IS_MR" = true ]; then
  ITEM_JSON=$(glab api "/projects/${ENCODED_PATH}/merge_requests/${IID}")
  ITEM_TYPE="Merge Request"
  NOTES_ENDPOINT="/projects/${ENCODED_PATH}/merge_requests/${IID}/notes?sort=asc&order_by=created_at&per_page=100"
else
  ITEM_JSON=$(glab api "/projects/${ENCODED_PATH}/issues/${IID}")
  ITEM_TYPE="Issue"
  NOTES_ENDPOINT="/projects/${ENCODED_PATH}/issues/${IID}/notes?sort=asc&order_by=created_at&per_page=100"
fi

TITLE=$(echo "$ITEM_JSON" | jq -r '.title')
STATE=$(echo "$ITEM_JSON" | jq -r '.state')
DESCRIPTION=$(echo "$ITEM_JSON" | jq -r '.description // ""')
AUTHOR=$(echo "$ITEM_JSON" | jq -r '.author.username')
CREATED_AT=$(echo "$ITEM_JSON" | jq -r '.created_at')

# Opening post
jq -n \
  --arg author "$AUTHOR" \
  --arg date "$CREATED_AT" \
  --arg body "$DESCRIPTION" \
  '{author: $author, date: $date, body: $body, src: "description"}' \
  >> "$TMPFILE"

# All non-system notes
glab api "$NOTES_ENDPOINT" --paginate 2>/dev/null \
  | jq -s 'flatten | .[] | select(.system == false) | {author: .author.username, date: .created_at, body: (.body // ""), src: "note"}' \
  >> "$TMPFILE" 2>/dev/null || true

# ---- Process and output ------------------------------------------------------

jq -rs --arg user "$GL_USER" --arg title "$TITLE" --arg state "$STATE" \
  --arg project "$PROJECT_PATH" --arg iid "$IID" --arg is_mr "$IS_MR" \
  --arg item_type "$ITEM_TYPE" '

  sort_by(.date) as $timeline |
  ($timeline | length) as $total |

  [$timeline | to_entries[] | select(
    .value.author == $user or
    (.value.body | ascii_downcase | contains("@" + ($user | ascii_downcase)))
  ) | .key] as $matches |

  (if ($matches | length) == 0 then 0 else ($matches | last) end) as $anchor |
  $timeline[$anchor:] as $tail |
  (($timeline | last).author == $user) as $user_is_last |

  (if ($matches | length) == 0 then
    "beginning — you were not found in thread"
  elif $timeline[$anchor].author == $user then
    "your last post"
  else
    "last post mentioning you"
  end) as $anchor_desc |

  "THREAD: \($project)\(if $is_mr == "true" then "!" else "#" end)\($iid) — \($title)\n" +
  "TYPE: \($item_type)\n" +
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

  ($tail | to_entries | map(
    "\n[\($anchor + .key + 1)/\($total)] \(.value.src) by @\(.value.author) on \(.value.date[0:10]):\n\(.value.body)\n---"
  ) | join(""))

' "$TMPFILE"

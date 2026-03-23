#!/bin/bash
# ============================================================================
# _filter_helpers.sh — Shared filtering functions for gh-onmyplate scripts
# ============================================================================
#
# Sourced (not executed) by gh_notifications.sh and gh_involved.sh.
# Provides functions to check whether a PR should be filtered out based on
# team-only involvement or merged status.
#
# REQUIRES:
#   - config.sh sourced first (for IGNORE_REVIEW_TEAMS, FILTER_MERGED_REVIEWED)
#   - GH_USER set to the authenticated GitHub username
#   - gh CLI authenticated
#   - jq installed
# ============================================================================

# ---- PR JSON cache ----------------------------------------------------------
# Cache directory for PR JSON, so multiple checks on the same PR don't re-fetch.

_FILTER_CACHE_DIR=""

_filter_init_cache() {
  if [ -z "$_FILTER_CACHE_DIR" ]; then
    _FILTER_CACHE_DIR=$(mktemp -d)
  fi
}

_filter_cleanup_cache() {
  if [ -n "$_FILTER_CACHE_DIR" ] && [ -d "$_FILTER_CACHE_DIR" ]; then
    rm -rf "$_FILTER_CACHE_DIR"
  fi
}

# ---- fetch_pr_json ----------------------------------------------------------
# Fetches PR details from the API (or returns cached result).
#
# Usage: fetch_pr_json OWNER_REPO NUMBER
# Output: PR JSON on stdout
# Returns: 0 on success, 1 on API failure
#
# The single GET /repos/{owner}/{repo}/pulls/{number} call returns:
#   .merged, .state, .user.login (author), .assignees[].login,
#   .requested_reviewers[].login, .requested_teams[].slug

fetch_pr_json() {
  local owner_repo="$1"
  local number="$2"
  local cache_key="${owner_repo//\//__}__${number}"

  _filter_init_cache

  local cache_file="${_FILTER_CACHE_DIR}/${cache_key}.json"

  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi

  local pr_json
  pr_json=$(gh api "/repos/${owner_repo}/pulls/${number}" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$pr_json" ]; then
    return 1
  fi

  echo "$pr_json" > "$cache_file"
  echo "$pr_json"
  return 0
}

# ---- fetch_pr_json_from_api_url --------------------------------------------
# Like fetch_pr_json but takes a full GitHub API URL (e.g. from notification
# subject.url). Extracts owner/repo and number, then delegates to fetch_pr_json.
#
# Usage: fetch_pr_json_from_api_url API_URL
# Output: PR JSON on stdout

fetch_pr_json_from_api_url() {
  local api_url="$1"

  # Convert issues URL to pulls URL if needed
  # Notifications may use /repos/owner/repo/issues/N even for PRs
  local pulls_url="${api_url/\/issues\//\/pulls\/}"

  # Extract owner/repo and number from API URL
  # Format: https://api.github.com/repos/OWNER/REPO/pulls/NUMBER
  local path="${pulls_url#https://api.github.com/repos/}"
  local owner_repo="${path%/pulls/*}"
  local number="${path##*/}"

  if [ -z "$owner_repo" ] || [ -z "$number" ]; then
    return 1
  fi

  fetch_pr_json "$owner_repo" "$number"
}

# ---- is_team_only_involvement -----------------------------------------------
# Checks if the user's only involvement in a PR is via an ignored team.
#
# Usage: is_team_only_involvement PR_JSON
#   PR_JSON: JSON string from fetch_pr_json
#   Uses global: GH_USER, IGNORE_REVIEW_TEAMS
#
# Returns: 0 if team-only (should filter), 1 if personally involved (keep)

is_team_only_involvement() {
  local pr_json="$1"

  # If no teams configured to ignore, never filter
  if [ ${#IGNORE_REVIEW_TEAMS[@]} -eq 0 ]; then
    return 1
  fi

  # Build a jq filter for the ignored teams
  local teams_json
  teams_json=$(printf '%s\n' "${IGNORE_REVIEW_TEAMS[@]}" | jq -R . | jq -s .)

  # Single jq call: check all conditions
  # Returns "filter" if team-only, "keep" if personally involved
  local result
  result=$(echo "$pr_json" | jq -r --arg user "$GH_USER" --argjson ignore_teams "$teams_json" '
    # Extract relevant fields
    (.user.login | ascii_downcase) as $author |
    ([.assignees[]?.login | ascii_downcase]) as $assignees |
    ([.requested_reviewers[]?.login | ascii_downcase]) as $reviewers |
    ([.requested_teams[]?.slug]) as $teams |
    ($user | ascii_downcase) as $me |

    # Check personal involvement
    ($author == $me) as $is_author |
    ($assignees | any(. == $me)) as $is_assignee |
    ($reviewers | any(. == $me)) as $is_individual_reviewer |

    # Check if any requested team matches ignore list
    # ignore_teams entries are "org/slug" — compare against just the slug portion
    ($ignore_teams | map(split("/") | last)) as $ignore_slugs |
    ($teams | any(. as $t | $ignore_slugs | any(. == $t))) as $has_ignored_team |

    if $is_author or $is_assignee or $is_individual_reviewer then
      "keep"
    elif $has_ignored_team then
      "filter"
    else
      "keep"
    end
  ')

  if [ "$result" = "filter" ]; then
    return 0
  fi
  return 1
}

# ---- is_merged_pr ------------------------------------------------------------
# Checks if a PR is merged and the user doesn't need to act on it.
#
# Once a PR is merged, it's done — notifications for it are historical noise.
# Exceptions (keep the PR):
#   - User authored the PR (may care about post-merge activity)
#   - Someone @mentioned the user in a comment AFTER the merge date
#
# Usage: is_merged_pr PR_JSON
#   PR_JSON: JSON string from fetch_pr_json
#   Uses global: GH_USER
#
# Returns: 0 if merged+no-action-needed (should filter), 1 otherwise (keep)

is_merged_pr() {
  local pr_json="$1"

  # If FILTER_MERGED_REVIEWED is disabled, never filter
  if [ "${FILTER_MERGED_REVIEWED:-true}" != "true" ]; then
    return 1
  fi

  # Check merged state and authorship in one jq call
  local check
  check=$(echo "$pr_json" | jq -r --arg user "$GH_USER" '
    if .merged != true then "not_merged"
    elif (.user.login | ascii_downcase) == ($user | ascii_downcase) then "is_author"
    else .merged_at
    end
  ')

  case "$check" in
    not_merged) return 1 ;;  # Not merged — keep
    is_author)  return 1 ;;  # User authored it — keep
  esac

  # $check is now the merged_at timestamp — check for post-merge @mentions
  local owner_repo number
  owner_repo=$(echo "$pr_json" | jq -r '.base.repo.full_name')
  number=$(echo "$pr_json" | jq -r '.number')

  local post_merge_mention
  post_merge_mention=$(gh api "/repos/${owner_repo}/issues/${number}/comments" \
    -f since="$check" \
    --jq --arg user "$GH_USER" '
      [.[] | select(.body | ascii_downcase | contains("@" + ($user | ascii_downcase)))]
      | length
    ' 2>/dev/null || echo "0")

  if [ "$post_merge_mention" != "0" ] && [ -n "$post_merge_mention" ]; then
    return 1  # Post-merge mention found — keep
  fi

  return 0  # Merged, not author, no post-merge mention — filter
}

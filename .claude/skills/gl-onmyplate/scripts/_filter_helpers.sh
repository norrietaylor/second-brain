#!/bin/bash
# ============================================================================
# _filter_helpers.sh — Shared filtering functions for gl-onmyplate scripts
# ============================================================================
#
# Sourced (not executed) by gl_notifications.sh and gl_involved.sh.
# Provides functions to check whether an MR should be filtered out based on
# group-only involvement or merged status.
#
# REQUIRES:
#   - config.sh sourced first (for IGNORE_REVIEW_GROUPS, FILTER_MERGED_REVIEWED, GL_HOST)
#   - GL_USER set to the authenticated GitLab username
#   - GITLAB_HOST exported (set from GL_HOST or glab default)
#   - glab CLI authenticated
#   - jq installed
# ============================================================================

# ---- _resolve_gitlab_host ---------------------------------------------------
# Detects the authenticated GitLab host in order of preference:
#   1. GL_HOST set in config.sh
#   2. GITLAB_HOST already exported in environment
#   3. First host with a 'user:' entry in the glab config file (self-hosted)
#   4. glab config get host (falls back to gitlab.com)
#
# Exports GITLAB_HOST so all subsequent glab api calls use the right instance.

_resolve_gitlab_host() {
  # 1. Explicit config
  if [ -n "${GL_HOST:-}" ]; then
    export GITLAB_HOST="$GL_HOST"
    return
  fi

  # 2. Already set in environment
  if [ -n "${GITLAB_HOST:-}" ]; then
    return
  fi

  # 3. Parse glab config file for first authenticated (non-gitlab.com) host
  local config_file
  config_file="$HOME/Library/Application Support/glab-cli/config.yml"
  [ -f "$config_file" ] || config_file="$HOME/.config/glab-cli/config.yml"

  if [ -f "$config_file" ]; then
    local detected
    detected=$(python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
in_hosts = False
current = None
for line in content.splitlines():
    if line == 'hosts:':
        in_hosts = True; continue
    if in_hosts:
        m = re.match(r'^    ([^: ]+):\$', line)
        if m: current = m.group(1); continue
        if re.match(r'^        user: \S', line) and current and current != 'gitlab.com':
            print(current); break
" "$config_file" 2>/dev/null || echo "")
    if [ -n "$detected" ]; then
      export GITLAB_HOST="$detected"
      return
    fi
  fi

  # 4. Fallback to glab default
  export GITLAB_HOST
  GITLAB_HOST=$(glab config get host 2>/dev/null || echo "gitlab.com")
}

# ---- MR JSON cache ----------------------------------------------------------

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

# ---- url_encode_path --------------------------------------------------------
# URL-encodes a project path (replaces / with %2F) for GitLab API URLs.

url_encode_path() {
  echo "$1" | sed 's|/|%2F|g'
}

# ---- fetch_mr_json ----------------------------------------------------------
# Fetches MR details from the API (or returns cached result).
#
# Usage: fetch_mr_json PROJECT_PATH IID

fetch_mr_json() {
  local project_path="$1"
  local iid="$2"
  local encoded_path
  encoded_path=$(url_encode_path "$project_path")
  local cache_key="${project_path//\//__}__${iid}"

  _filter_init_cache

  local cache_file="${_FILTER_CACHE_DIR}/${cache_key}.json"

  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi

  local mr_json
  mr_json=$(glab api "/projects/${encoded_path}/merge_requests/${iid}" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$mr_json" ]; then
    return 1
  fi

  echo "$mr_json" > "$cache_file"
  echo "$mr_json"
  return 0
}

# ---- is_group_only_involvement ----------------------------------------------
# Returns 0 if user's only involvement is as a reviewer on a project under
# an ignored namespace (should filter), 1 if personally involved (keep).

is_group_only_involvement() {
  local mr_json="$1"

  if [ ${#IGNORE_REVIEW_GROUPS[@]} -eq 0 ]; then
    return 1
  fi

  local groups_json
  groups_json=$(printf '%s\n' "${IGNORE_REVIEW_GROUPS[@]}" | jq -R . | jq -s .)

  local result
  result=$(echo "$mr_json" | jq -r --arg user "$GL_USER" --argjson ignore_groups "$groups_json" '
    (.author.username | ascii_downcase) as $author |
    ([.assignees[]?.username | ascii_downcase]) as $assignees |
    ([.reviewers[]?.username | ascii_downcase]) as $reviewers |
    ($user | ascii_downcase) as $me |
    (.namespace.full_path // "") as $namespace |

    ($ignore_groups | any(. as $g | $namespace | startswith($g))) as $in_ignored_ns |

    if ($author == $me) or ($assignees | any(. == $me)) then
      "keep"
    elif $in_ignored_ns and ($reviewers | any(. == $me)) then
      "filter"
    else
      "keep"
    end
  ')

  [ "$result" = "filter" ] && return 0 || return 1
}

# ---- is_merged_mr -----------------------------------------------------------
# Returns 0 if MR is merged and user does not need to act (should filter),
# 1 otherwise (keep).

is_merged_mr() {
  local mr_json="$1"

  if [ "${FILTER_MERGED_REVIEWED:-true}" != "true" ]; then
    return 1
  fi

  local check
  check=$(echo "$mr_json" | jq -r --arg user "$GL_USER" '
    if .state != "merged" then "not_merged"
    elif (.author.username | ascii_downcase) == ($user | ascii_downcase) then "is_author"
    else .merged_at
    end
  ')

  case "$check" in
    not_merged) return 1 ;;
    is_author)  return 1 ;;
  esac

  # $check is merged_at — look for post-merge @mentions
  local project_path iid encoded_path
  project_path=$(echo "$mr_json" | jq -r '.path_with_namespace // (.namespace.full_path + "/" + .path)')
  iid=$(echo "$mr_json" | jq -r '.iid')
  encoded_path=$(url_encode_path "$project_path")

  local post_merge_mention
  post_merge_mention=$(glab api "/projects/${encoded_path}/merge_requests/${iid}/notes?sort=asc&order_by=created_at&per_page=100" \
    --paginate 2>/dev/null \
    | jq -s --arg user "$GL_USER" --arg since "$check" '
        flatten
        | [.[] | select(
            .system == false and
            .created_at >= $since and
            (.body | ascii_downcase | contains("@" + ($user | ascii_downcase)))
          )] | length
      ' 2>/dev/null || echo "0")

  if [ "$post_merge_mention" != "0" ] && [ -n "$post_merge_mention" ]; then
    return 1
  fi

  return 0
}

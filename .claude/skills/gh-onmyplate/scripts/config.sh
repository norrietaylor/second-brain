#!/bin/bash
# ============================================================================
# config.sh — Configuration for gh-onmyplate scripts
# ============================================================================
#
# This file is sourced by gh_notifications.sh and gh_involved.sh to control
# filtering behavior. Edit the arrays below to match your preferences.
#
# If this file is missing or cannot be sourced, scripts fall back to safe
# defaults (no filtering).
# ============================================================================

# ---- Teams to ignore for review requests ------------------------------------
#
# If your ONLY involvement in a PR is via one of these teams (team review
# request or team @mention), the PR will be filtered out of your results.
#
# Format: "org/team-slug" — must match the GitHub team slug exactly.
# Find your team slugs: gh api /orgs/YOUR_ORG/teams --jq '.[].slug'
#
# Examples:
#   "elastic/beats-tech-leads"
#   "myorg/platform-reviewers"

IGNORE_REVIEW_TEAMS=(
  "elastic/beats-tech-leads"
)

# ---- Merged PR filtering ----------------------------------------------------
#
# When true, merged PRs are filtered out of notifications UNLESS you were
# @mentioned by name (notification reason = "mention"). This removes noise
# from PRs you reviewed/approved that have since been merged.
#
# Set to "false" to disable this filter.

FILTER_MERGED_REVIEWED=true

#!/bin/bash
# ============================================================================
# config.sh — Configuration for gl-onmyplate scripts
# ============================================================================
#
# This file is sourced by gl_notifications.sh and gl_involved.sh to control
# filtering behavior. Edit the arrays below to match your preferences.
#
# If this file is missing or cannot be sourced, scripts fall back to safe
# defaults (no filtering).
# ============================================================================

# ---- GitLab hostname ---------------------------------------------------------
#
# Set this to your self-hosted GitLab hostname. Leave blank and the scripts
# will auto-detect the first authenticated host from the glab config file.
#
# Example: GL_HOST="git.example.com"

GL_HOST=""

# ---- Namespaces to ignore for review requests --------------------------------
#
# If your ONLY involvement in an MR is as a reviewer on a project under one
# of these namespace paths (group or group/subgroup), the MR will be filtered
# out of your results.
#
# Format: "group" or "group/subgroup" — must match the GitLab namespace path
# exactly. Find your group paths: glab api /groups | jq '.[].full_path'
#
# Examples:
#   "myorg/platform"
#   "elastic/ingest"

IGNORE_REVIEW_GROUPS=(
  # "myorg/platform"
)

# ---- Merged MR filtering -----------------------------------------------------
#
# When true, merged MRs are filtered out of notifications UNLESS you were
# @mentioned by name after the merge. This removes noise from MRs you
# reviewed/approved that have since been merged.
#
# Set to "false" to disable this filter.

FILTER_MERGED_REVIEWED=true

# ---- Audit log location (for gl_mark_done.sh) --------------------------------

# MARKED_DONE_AUDIT_LOG="$HOME/.local/share/gl-onmyplate/marked-done.tsv"

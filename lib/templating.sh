#!/usr/bin/env bash
# templating.sh — file copying with placeholder substitution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ── Template variables ───────────────────────────────────────────────
# These are set by the installer before calling copy functions.
# Exported so they're available to subshells.
export TPL_VAULT_NAME="${TPL_VAULT_NAME:-second-brain}"
export TPL_USER_NAME="${TPL_USER_NAME:-}"
export TPL_USER_FIRST_NAME="${TPL_USER_FIRST_NAME:-}"
export TPL_USER_ROLE="${TPL_USER_ROLE:-}"
export TPL_USER_EMAIL="${TPL_USER_EMAIL:-}"

# ── Substitution ─────────────────────────────────────────────────────

# Replace all {{PLACEHOLDER}} tokens in a string
apply_template() {
  local content="$1"
  content="${content//\{\{VAULT_NAME\}\}/${TPL_VAULT_NAME}}"
  content="${content//\{\{USER_NAME\}\}/${TPL_USER_NAME}}"
  content="${content//\{\{USER_FIRST_NAME\}\}/${TPL_USER_FIRST_NAME}}"
  content="${content//\{\{USER_ROLE\}\}/${TPL_USER_ROLE}}"
  content="${content//\{\{USER_EMAIL\}\}/${TPL_USER_EMAIL}}"
  echo "$content"
}

# Apply template substitution to a file using sed (handles large files)
apply_template_file() {
  local src="$1"
  local dst="$2"

  sed \
    -e "s|{{VAULT_NAME}}|${TPL_VAULT_NAME}|g" \
    -e "s|{{USER_NAME}}|${TPL_USER_NAME}|g" \
    -e "s|{{USER_FIRST_NAME}}|${TPL_USER_FIRST_NAME}|g" \
    -e "s|{{USER_ROLE}}|${TPL_USER_ROLE}|g" \
    -e "s|{{USER_EMAIL}}|${TPL_USER_EMAIL}|g" \
    "$src" > "$dst"
}

# ── File copying ─────────────────────────────────────────────────────

# Copy a single file from template/ to vault, applying templating.
# If the source filename ends in .tmpl, the .tmpl suffix is stripped.
# Preserves execute permissions.
copy_template_file() {
  local src="$1"
  local dst="$2"

  # Strip .tmpl suffix from destination
  dst="${dst%.tmpl}"

  mkdir -p "$(dirname "$dst")"

  if file_needs_templating "$src"; then
    apply_template_file "$src" "$dst"
  else
    cp "$src" "$dst"
  fi

  # Preserve executable bit
  if [[ -x "$src" ]]; then
    chmod +x "$dst"
  fi
}

# Check if a file contains template placeholders
file_needs_templating() {
  local f="$1"
  # Binary files should not be templated
  if file "$f" | grep -q "text"; then
    grep -q '{{[A-Z_]*}}' "$f" 2>/dev/null
  else
    return 1
  fi
}

# ── Bulk copy ────────────────────────────────────────────────────────

# Copy all files from template/ to vault, respecting integration selections.
# Arguments:
#   $1 — installer template dir (e.g., /path/to/installer/template)
#   $2 — vault target dir
#   $3 — comma-separated integrations list
copy_template_tree() {
  local template_dir="$1"
  local vault_dir="$2"
  local integrations="$3"
  local copied=0
  local skipped=0

  # Build list of exclusion patterns based on disabled integrations
  local -a excludes=()

  if ! echo "$integrations" | grep -q "GitHub"; then
    excludes+=("*gh-onmyplate*" "*gh-fetch*" "*gh-import*" "*GitHub.base" "*sb-github-sync*" "*github.claude.md")
  fi
  if ! echo "$integrations" | grep -q "GitLab"; then
    excludes+=("*gl-onmyplate*")
  fi
  if ! echo "$integrations" | grep -q "Slack"; then
    excludes+=("*slack-my-activity*" "*slack-activity.claude.md" "*my-activity.md")
  fi
  if ! echo "$integrations" | grep -q "Granola"; then
    excludes+=("*granola*" "*Granola*")
  fi

  # Walk the template tree
  while IFS= read -r -d '' src; do
    local rel="${src#"${template_dir}/"}"
    local dst="${vault_dir}/${rel}"
    local skip=false

    # Check exclusion patterns
    for pattern in "${excludes[@]}"; do
      # shellcheck disable=SC2254
      if [[ "$rel" == $pattern ]]; then
        skip=true
        break
      fi
    done

    if [[ "$skip" == true ]]; then
      ((skipped++))
      continue
    fi

    copy_template_file "$src" "$dst"
    ((copied++))
  done < <(find "$template_dir" -type f -print0)

  log_success "Copied ${copied} files (${skipped} skipped for disabled integrations)"
}

# ── Scaffold copy ────────────────────────────────────────────────────

# Copy scaffold files (user-owned, never overwritten on update).
# Arguments:
#   $1 — installer scaffold dir
#   $2 — vault target dir
#   $3 — associative array of extra template vars (PRIORITY_1, etc.)
copy_scaffold_files() {
  local scaffold_dir="$1"
  local vault_dir="$2"

  local context_dir="${vault_dir}/05 Meta/context"
  local claude_dir="${vault_dir}/.claude"

  # Work profile
  local wp_dst="${context_dir}/work-profile.md"
  if [[ ! -f "$wp_dst" ]]; then
    apply_template_file "${scaffold_dir}/context/work-profile.md.tmpl" "$wp_dst"
    log_success "Created work-profile.md"
  else
    log_info "work-profile.md already exists — skipped"
  fi

  # Current priorities
  local cp_dst="${context_dir}/current-priorities.md"
  if [[ ! -f "$cp_dst" ]]; then
    apply_template_file "${scaffold_dir}/context/current-priorities.md.tmpl" "$cp_dst"
    log_success "Created current-priorities.md"
  else
    log_info "current-priorities.md already exists — skipped"
  fi

  # Settings local
  local sl_dst="${claude_dir}/settings.local.json"
  if [[ ! -f "$sl_dst" ]]; then
    cp "${scaffold_dir}/settings.local.json" "$sl_dst"
    log_success "Created settings.local.json"
  else
    log_info "settings.local.json already exists — skipped"
  fi

  # Inbox log
  local log_dst="${vault_dir}/05 Meta/logs/inbox-log.md"
  if [[ ! -f "$log_dst" ]]; then
    touch "$log_dst"
    log_success "Created inbox-log.md"
  else
    log_info "inbox-log.md already exists — skipped"
  fi
}

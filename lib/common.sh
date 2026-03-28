#!/usr/bin/env bash
# common.sh — shared utilities for the Second Brain installer

set -euo pipefail

# ── Colors (fallback if gum unavailable) ─────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}ℹ${RESET}  $*"; }
log_success() { echo -e "${GREEN}✓${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}⚠${RESET}  $*"; }
log_error()   { echo -e "${RED}✗${RESET}  $*"; }
log_step()    { echo -e "\n${BOLD}$*${RESET}"; }

# ── Gum wrappers ────────────────────────────────────────────────────
# These provide a consistent interface and fall back to basic prompts
# if gum is somehow unavailable (shouldn't happen — installer checks).

ensure_gum() {
  if command -v gum &>/dev/null; then
    return 0
  fi

  log_warn "gum not found. Attempting to install via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install gum
    if command -v gum &>/dev/null; then
      log_success "gum installed successfully"
      return 0
    fi
  fi

  log_error "Could not install gum. Please install it manually: brew install gum"
  exit 1
}

# Styled header banner
show_banner() {
  gum style \
    --border double \
    --border-foreground 212 \
    --padding "1 3" \
    --margin "1 0" \
    --align center \
    --bold \
    "$@"
}

# Prompt for text input
# Usage: result=$(prompt_input "Header" "Prompt text" "default value")
prompt_input() {
  local header="$1"
  local prompt="$2"
  local default="${3:-}"

  echo -e "${DIM}${header}${RESET}" >&2
  if [[ -n "$default" ]]; then
    gum input --placeholder "$prompt" --value "$default"
  else
    gum input --placeholder "$prompt"
  fi
}

# Prompt for confirmation
# Usage: if prompt_confirm "Do the thing?"; then ...
prompt_confirm() {
  gum confirm "$1"
}

# Multi-select from options
# Usage: selected=$(prompt_multi_select "Choose integrations:" "GitHub sync" "GitLab sync" "Slack" "Granola" "Git-backed vault")
prompt_multi_select() {
  local header="$1"
  shift
  echo -e "${DIM}${header}${RESET}" >&2
  gum choose --no-limit "$@"
}

# Single select from options
# Usage: selected=$(prompt_select "Pick one:" "Option A" "Option B")
prompt_select() {
  local header="$1"
  shift
  echo -e "${DIM}${header}${RESET}" >&2
  gum choose "$@"
}

# Show a spinner while running a command
# Usage: run_with_spinner "Installing..." some_command arg1 arg2
run_with_spinner() {
  local title="$1"
  shift
  gum spin --spinner dot --title "$title" -- "$@"
}

# ── Installer metadata ──────────────────────────────────────────────
INSTALLER_VERSION="1.0.0"

# Get the directory where the installer repo lives
installer_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# Read .sb-installer.json from a vault
read_installer_meta() {
  local vault_path="$1"
  local meta_file="${vault_path}/.sb-installer.json"
  if [[ -f "$meta_file" ]]; then
    cat "$meta_file"
  else
    echo "{}"
  fi
}

# Write .sb-installer.json to a vault
write_installer_meta() {
  local vault_path="$1"
  local vault_name="$2"
  local integrations="$3"

  cat > "${vault_path}/.sb-installer.json" <<EOF
{
  "installer_repo": "$(installer_dir)",
  "version": "${INSTALLER_VERSION}",
  "vault_name": "${vault_name}",
  "integrations": "${integrations}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

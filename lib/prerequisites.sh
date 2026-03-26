#!/usr/bin/env bash
# prerequisites.sh — dependency checking and installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ── Prerequisite checks ─────────────────────────────────────────────
# Each check function returns 0 if the tool is available, 1 if not.
# They print status as a side effect.

check_obsidian_cli() {
  if command -v obsidian &>/dev/null; then
    local version
    version=$(obsidian --version 2>/dev/null || echo "unknown")
    log_success "Obsidian CLI: ${version}"
    return 0
  else
    log_error "Obsidian CLI: not found"
    return 1
  fi
}

check_gh_cli() {
  if command -v gh &>/dev/null; then
    local version
    version=$(gh --version 2>/dev/null | head -1 || echo "unknown")
    log_success "GitHub CLI: ${version}"
    return 0
  else
    log_error "GitHub CLI: not found"
    return 1
  fi
}

check_glab_cli() {
  if command -v glab &>/dev/null; then
    local version
    version=$(glab --version 2>/dev/null | head -1 || echo "unknown")
    log_success "GitLab CLI: ${version}"
    return 0
  else
    log_error "GitLab CLI: not found"
    return 1
  fi
}

check_jq() {
  if command -v jq &>/dev/null; then
    local version
    version=$(jq --version 2>/dev/null || echo "unknown")
    log_success "jq: ${version}"
    return 0
  else
    log_error "jq: not found"
    return 1
  fi
}

check_python3() {
  if command -v python3 &>/dev/null; then
    local version
    version=$(python3 --version 2>/dev/null || echo "unknown")
    log_success "Python: ${version}"
    return 0
  else
    log_error "Python 3: not found"
    return 1
  fi
}

check_git() {
  if command -v git &>/dev/null; then
    local version
    version=$(git --version 2>/dev/null || echo "unknown")
    log_success "Git: ${version}"
    return 0
  else
    log_error "Git: not found"
    return 1
  fi
}

check_claude_code() {
  if command -v claude &>/dev/null; then
    log_success "Claude Code: installed"
    return 0
  else
    log_error "Claude Code: not found"
    return 1
  fi
}

# ── Brew install helper ──────────────────────────────────────────────
offer_brew_install() {
  local tool="$1"
  local formula="$2"
  local cask="${3:-false}"

  if ! command -v brew &>/dev/null; then
    log_warn "Homebrew not found — install ${tool} manually"
    return 1
  fi

  if prompt_confirm "Install ${tool} via Homebrew?"; then
    if [[ "$cask" == "true" ]]; then
      run_with_spinner "Installing ${tool}..." brew install --cask "$formula"
    else
      run_with_spinner "Installing ${tool}..." brew install "$formula"
    fi
    log_success "${tool} installed"
    return 0
  else
    log_warn "Skipped ${tool} installation"
    return 1
  fi
}

# ── Run all prerequisite checks ──────────────────────────────────────
# Arguments: space-separated list of integrations
# Returns: number of failures
check_all_prerequisites() {
  local integrations="$1"
  local failures=0

  log_step "Checking prerequisites..."

  # Always required
  check_jq      || { offer_brew_install "jq" "jq"           && check_jq;      } || ((failures++))
  check_python3  || ((failures++))  # Ships with macOS, can't easily brew-fix

  # Required for vault operation
  check_obsidian_cli || {
    log_info "Install Obsidian CLI: https://obsidian.md/cli"
    ((failures++))
  }
  check_claude_code || {
    log_info "Install: npm install -g @anthropic-ai/claude-code"
    ((failures++))
  }

  # Integration-specific
  if echo "$integrations" | grep -q "GitHub"; then
    check_gh_cli || { offer_brew_install "GitHub CLI" "gh" && check_gh_cli; } || ((failures++))
  fi

  if echo "$integrations" | grep -q "GitLab"; then
    check_glab_cli || { offer_brew_install "GitLab CLI" "glab" && check_glab_cli; } || ((failures++))
  fi

  if echo "$integrations" | grep -q "Git-backed"; then
    check_git || ((failures++))
  fi

  return $failures
}

# ── Auth validation ──────────────────────────────────────────────────
validate_gh_auth() {
  log_step "Validating GitHub authentication..."
  if gh auth status &>/dev/null; then
    log_success "GitHub CLI authenticated"
    return 0
  else
    log_warn "GitHub CLI not authenticated"
    log_info "Run: gh auth login"
    return 1
  fi
}

validate_glab_auth() {
  log_step "Validating GitLab authentication..."
  if glab auth status &>/dev/null; then
    log_success "GitLab CLI authenticated"
    return 0
  else
    log_warn "GitLab CLI not authenticated"
    log_info "Run: glab auth login"
    return 1
  fi
}

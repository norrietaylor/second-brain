#!/usr/bin/env bash
# install.sh — Second Brain installer and updater
#
# Usage:
#   ./install.sh              # fresh install (interactive)
#   ./install.sh --update     # update an existing vault
#   ./install.sh --update /path/to/vault

set -euo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${INSTALLER_DIR}/lib/common.sh"
source "${INSTALLER_DIR}/lib/prerequisites.sh"
source "${INSTALLER_DIR}/lib/templating.sh"
source "${INSTALLER_DIR}/lib/integrations.sh"

# ── Argument parsing ─────────────────────────────────────────────────
UPDATE_MODE=false
UPDATE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      UPDATE_MODE=true
      if [[ "${2:-}" != "" && "${2:-}" != --* ]]; then
        UPDATE_PATH="$2"
        shift
      fi
      shift
      ;;
    --help|-h)
      echo "Usage: ./install.sh [--update [/path/to/vault]]"
      echo ""
      echo "Options:"
      echo "  --update        Update an existing vault installation"
      echo "  --update PATH   Update the vault at PATH"
      echo "  --help          Show this help"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Ensure gum is available ──────────────────────────────────────────
ensure_gum

# ══════════════════════════════════════════════════════════════════════
# UPDATE MODE
# ══════════════════════════════════════════════════════════════════════
if [[ "$UPDATE_MODE" == true ]]; then
  show_banner "Second Brain" "Update"

  # Find the vault
  if [[ -z "$UPDATE_PATH" ]]; then
    # Try to find vaults with .sb-installer.json
    local_vaults=()
    while IFS= read -r f; do
      local_vaults+=("$(dirname "$f")")
    done < <(find "$HOME" -maxdepth 5 -name ".sb-installer.json" -type f 2>/dev/null | head -5)

    if [[ ${#local_vaults[@]} -eq 0 ]]; then
      UPDATE_PATH=$(prompt_input "Vault path" "Enter the path to your vault" "")
    elif [[ ${#local_vaults[@]} -eq 1 ]]; then
      UPDATE_PATH="${local_vaults[0]}"
      log_info "Found vault: ${UPDATE_PATH}"
      prompt_confirm "Update this vault?" || exit 0
    else
      UPDATE_PATH=$(prompt_select "Select vault to update:" "${local_vaults[@]}")
    fi
  fi

  if [[ ! -f "${UPDATE_PATH}/.sb-installer.json" ]]; then
    log_error "No .sb-installer.json found at ${UPDATE_PATH}"
    log_info "This doesn't appear to be a Second Brain vault installed by this tool."
    exit 1
  fi

  # Read current metadata
  meta=$(cat "${UPDATE_PATH}/.sb-installer.json")
  vault_name=$(echo "$meta" | python3 -c "import sys,json; print(json.load(sys.stdin).get('vault_name','second-brain'))")
  integrations=$(echo "$meta" | python3 -c "import sys,json; print(json.load(sys.stdin).get('integrations',''))")
  old_version=$(echo "$meta" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','0.0.0'))")

  log_info "Vault: ${vault_name} (v${old_version} → v${INSTALLER_VERSION})"
  log_info "Path: ${UPDATE_PATH}"

  # If integrations field is empty, prompt the user to select
  if [[ -z "$integrations" ]]; then
    log_warn "No integrations recorded — please select which are enabled:"
    integrations_raw=$(prompt_multi_select \
      "Which integrations are enabled in this vault?" \
      "GitHub sync (gh CLI)" \
      "GitLab sync (glab CLI)" \
      "Slack activity tracking" \
      "Granola meeting sync" \
      "Git-backed vault")
    integrations=$(echo "$integrations_raw" | tr '\n' ',' | sed 's/,$//')
  fi

  log_info "Integrations: ${integrations}"

  # Set template variables
  export TPL_VAULT_NAME="$vault_name"
  export TPL_VAULT_PATH="$UPDATE_PATH"
  # Read user name from existing config
  if [[ -f "${UPDATE_PATH}/05 Meta/config.yaml" ]]; then
    existing_name=$(grep 'self_name:' "${UPDATE_PATH}/05 Meta/config.yaml" 2>/dev/null | sed 's/.*self_name: *"\(.*\)"/\1/' || echo "")
    export TPL_USER_NAME="${existing_name}"
    export TPL_USER_FIRST_NAME="${existing_name%% *}"
  fi

  # Check for git-backed vault
  if [[ -d "${UPDATE_PATH}/.git" ]]; then
    log_step "Updating via git merge..."

    (
      cd "$UPDATE_PATH"

      # Ensure working tree is clean
      if ! git diff --quiet || ! git diff --cached --quiet; then
        log_warn "Vault has uncommitted changes. Stashing..."
        git stash push -m "sb: pre-update stash"
      fi

      # Update the upstream branch
      git checkout sb/upstream 2>/dev/null || git checkout -b sb/upstream

      # Copy new template files
      copy_template_tree "${INSTALLER_DIR}/template" "$UPDATE_PATH" "$integrations"

      git add -A
      if git diff --cached --quiet; then
        log_info "No changes to template files"
        git checkout main
      else
        git commit -m "sb: update to v${INSTALLER_VERSION}"
        git checkout main

        if git merge sb/upstream -m "sb: merge upstream v${INSTALLER_VERSION}"; then
          log_success "Merged successfully"
        else
          log_warn "Merge conflicts detected — resolve them and commit"
          log_info "Conflicting files:"
          git diff --name-only --diff-filter=U
        fi
      fi

      # Restore stash if we stashed
      if git stash list | grep -q "sb: pre-update stash"; then
        git stash pop || log_warn "Could not auto-apply stash — run 'git stash pop' manually"
      fi
    )
  else
    # Non-git vault: overwrite template files directly
    log_step "Copying updated template files..."
    copy_template_tree "${INSTALLER_DIR}/template" "$UPDATE_PATH" "$integrations"
  fi

  # Regenerate sandbox + permissions for current integrations
  configure_settings "$UPDATE_PATH" "$integrations" "$vault_name"

  # Update metadata
  write_installer_meta "$UPDATE_PATH" "$vault_name" "$integrations"
  log_success "Updated .sb-installer.json to v${INSTALLER_VERSION}"

  # Make scripts executable
  find "${UPDATE_PATH}/.claude/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
  find "${UPDATE_PATH}/.claude/skills" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

  show_banner "Update complete!" "v${old_version} → v${INSTALLER_VERSION}"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════════
# FRESH INSTALL
# ══════════════════════════════════════════════════════════════════════

show_banner "Second Brain" "Installer v${INSTALLER_VERSION}"

echo ""
log_info "This will set up a new Second Brain vault powered by Obsidian + Claude Code."
echo ""

# ── Step 1: Vault name ───────────────────────────────────────────────
log_step "Step 1: Vault configuration"

vault_name=$(prompt_input "Vault name" "Name for your vault (used in Obsidian and CLI)" "second-brain")

default_path="${HOME}/Documents/obsidian/${vault_name}"
vault_path=$(prompt_input "Vault location" "Where to create the vault" "$default_path")

# Expand ~ if present
vault_path="${vault_path/#\~/$HOME}"

# Check if path exists
if [[ -d "$vault_path" ]]; then
  if [[ -f "${vault_path}/.sb-installer.json" ]]; then
    log_warn "This path already has a Second Brain installation."
    if prompt_confirm "Switch to update mode?"; then
      exec "$0" --update "$vault_path"
    fi
    exit 0
  elif [[ -d "${vault_path}/.obsidian" ]]; then
    log_warn "An Obsidian vault already exists at this path."
    prompt_confirm "Install Second Brain into this existing vault?" || exit 0
  else
    log_warn "Directory already exists: ${vault_path}"
    prompt_confirm "Install into this directory?" || exit 0
  fi
fi

# ── Step 2: Integration selection ────────────────────────────────────
log_step "Step 2: Select integrations"

echo ""
integrations_raw=$(prompt_multi_select \
  "Which integrations do you want? (space to select, enter to confirm)" \
  "GitHub sync (gh CLI)" \
  "GitLab sync (glab CLI)" \
  "Slack activity tracking" \
  "Granola meeting sync" \
  "Git-backed vault")

# Normalize to comma-separated
integrations=$(echo "$integrations_raw" | tr '\n' ',' | sed 's/,$//')

echo ""
log_info "Selected: ${integrations}"

# ── Step 3: Prerequisites ────────────────────────────────────────────
log_step "Step 3: Prerequisites"

prereq_failures=0
check_all_prerequisites "$integrations" || prereq_failures=$?

if [[ $prereq_failures -gt 0 ]]; then
  echo ""
  log_warn "${prereq_failures} prerequisite(s) not met"
  prompt_confirm "Continue anyway? (some features may not work)" || exit 1
fi

# ── Step 4: User profile ─────────────────────────────────────────────
log_step "Step 4: Your profile"

user_name=$(prompt_input "Full name" "Your full name" "")
user_role=$(prompt_input "Role" "Your role or title" "")
user_email=$(prompt_input "Email" "Your email (optional)" "")

# Extract first name
user_first_name="${user_name%% *}"

# Set template variables
export TPL_VAULT_NAME="$vault_name"
export TPL_VAULT_PATH="$vault_path"
export TPL_USER_NAME="$user_name"
export TPL_USER_FIRST_NAME="$user_first_name"
export TPL_USER_ROLE="$user_role"
export TPL_USER_EMAIL="$user_email"

# ── Step 5: Create vault ─────────────────────────────────────────────
log_step "Step 5: Creating vault"

# Create directory structure
mkdir -p "$vault_path"
mkdir -p "${vault_path}/04 Data"
mkdir -p "${vault_path}/05 Meta/context"
mkdir -p "${vault_path}/05 Meta/context/team"
mkdir -p "${vault_path}/05 Meta/logs"
mkdir -p "${vault_path}/03 Resources"
mkdir -p "${HOME}/${vault_name}-inbox"

log_success "Created vault directories"

# Copy template files
copy_template_tree "${INSTALLER_DIR}/template" "$vault_path" "$integrations"

# Make scripts executable
find "${vault_path}/.claude/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
find "${vault_path}/.claude/skills" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
# Make skill entry-point scripts executable
find "${vault_path}/.claude/skills" -maxdepth 2 -type f ! -name "*.md" -exec chmod +x {} \; 2>/dev/null || true

# ── Step 6: Scaffold user files ──────────────────────────────────────
log_step "Step 6: User configuration"

# Handle priorities for scaffold
export TPL_PRIORITY_1="${TPL_PRIORITY_1:-Define priorities in 05 Meta/context/current-priorities.md}"
export TPL_PRIORITY_2="${TPL_PRIORITY_2:-}"
export TPL_PRIORITY_3="${TPL_PRIORITY_3:-}"

# Temporarily add priority vars to the sed in apply_template_file
# We do this by extending the function for scaffold files
scaffold_apply() {
  local src="$1"
  local dst="$2"
  sed \
    -e "s|{{VAULT_NAME}}|${TPL_VAULT_NAME}|g" \
    -e "s|{{VAULT_PATH}}|${TPL_VAULT_PATH}|g" \
    -e "s|{{USER_NAME}}|${TPL_USER_NAME}|g" \
    -e "s|{{USER_FIRST_NAME}}|${TPL_USER_FIRST_NAME}|g" \
    -e "s|{{USER_ROLE}}|${TPL_USER_ROLE}|g" \
    -e "s|{{USER_EMAIL}}|${TPL_USER_EMAIL}|g" \
    -e "s|{{PRIORITY_1}}|${TPL_PRIORITY_1}|g" \
    -e "s|{{PRIORITY_2}}|${TPL_PRIORITY_2}|g" \
    -e "s|{{PRIORITY_3}}|${TPL_PRIORITY_3}|g" \
    "$src" > "$dst"
}

# Copy scaffold files (only if they don't exist)
ctx_dir="${vault_path}/05 Meta/context"
if [[ ! -f "${ctx_dir}/work-profile.md" ]]; then
  scaffold_apply "${INSTALLER_DIR}/scaffold/context/work-profile.md.tmpl" "${ctx_dir}/work-profile.md"
  log_success "Created work-profile.md"
fi

if [[ ! -f "${ctx_dir}/current-priorities.md" ]]; then
  scaffold_apply "${INSTALLER_DIR}/scaffold/context/current-priorities.md.tmpl" "${ctx_dir}/current-priorities.md"
  log_success "Created current-priorities.md"
fi

if [[ ! -f "${vault_path}/.claude/settings.local.json" ]]; then
  cp "${INSTALLER_DIR}/scaffold/settings.local.json" "${vault_path}/.claude/settings.local.json"
  log_success "Created settings.local.json"
fi

if [[ ! -f "${vault_path}/05 Meta/logs/inbox-log.md" ]]; then
  touch "${vault_path}/05 Meta/logs/inbox-log.md"
  log_success "Created inbox-log.md"
fi

# ── Step 7: Integration setup ────────────────────────────────────────
log_step "Step 7: Integration setup"

run_integration_setup "$vault_path" "$integrations" "$user_name"

# ── Step 8: Write installer metadata ─────────────────────────────────
write_installer_meta "$vault_path" "$vault_name" "$integrations"

# ── Step 9: Summary ──────────────────────────────────────────────────
echo ""
show_banner "Installation complete!"

echo ""
echo "  Vault:          ${vault_path}"
echo "  Vault name:     ${vault_name}"
echo "  Integrations:   ${integrations}"
echo "  Inbox folder:   ${HOME}/${vault_name}-inbox"
echo ""

log_step "Next steps"
echo ""
echo "  1. Open the vault in Obsidian:"
echo "     - Open Obsidian → Open folder as vault → select: ${vault_path}"
echo ""
echo "  2. Install required Obsidian plugins:"
echo "     - Bases (enable in Core Plugins)"
echo "     - Templater by SilentVoid (set template folder: 05 Meta/templates)"
echo "     - Update frontmatter modified date by Alan Grainger"
echo "       (format: YYYY-MM-DD HH:mm, exclude: 05 Meta)"
if echo "$integrations" | grep -q "Granola"; then
echo "     - Granola Sync by philfreo"
fi
echo ""
echo "  3. Start Claude Code in the vault directory:"
echo "     cd \"${vault_path}\" && claude"
echo ""
echo "  4. Run the setup verification:"
echo "     /verify"
echo ""
echo "  5. Start your first day:"
echo "     /today"
echo ""

if echo "$integrations" | grep -q "Git-backed"; then
  echo ""
  log_info "To update later: ./install.sh --update \"${vault_path}\""
fi

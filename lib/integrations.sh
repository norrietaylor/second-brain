#!/usr/bin/env bash
# integrations.sh — per-integration setup and validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ── Integration setup ────────────────────────────────────────────────
# Each function handles post-copy setup for its integration.
# Called after template files have been copied to the vault.

setup_github() {
  local vault_dir="$1"

  log_step "GitHub integration setup"

  # Validate auth
  if gh auth status &>/dev/null; then
    log_success "GitHub CLI authenticated"
  else
    log_warn "GitHub CLI not authenticated"
    log_info "You can authenticate later with: gh auth login"
  fi
}

setup_gitlab() {
  local vault_dir="$1"

  log_step "GitLab integration setup"

  # Validate auth
  if glab auth status &>/dev/null; then
    log_success "GitLab CLI authenticated"
  else
    log_warn "GitLab CLI not authenticated"
    log_info "You can authenticate later with: glab auth login"
  fi

  # Check for custom host
  local gl_host
  gl_host=$(prompt_input "GitLab host" "gitlab.example.com (leave empty for gitlab.com)" "")
  if [[ -n "$gl_host" ]]; then
    local config_script="${vault_dir}/.claude/skills/gl-onmyplate/scripts/config.sh"
    if [[ -f "$config_script" ]]; then
      python3 - "$config_script" "$gl_host" <<'PYEOF'
import sys
path, host = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = content.replace('GL_HOST=""', f'GL_HOST="{host}"', 1)
with open(path, 'w') as f:
    f.write(content)
PYEOF
      log_success "GitLab host set to ${gl_host}"
    fi
  fi
}

setup_slack() {
  local vault_dir="$1"

  log_step "Slack integration setup"

  if [[ -n "${SLACK_USER_TOKEN:-}" ]]; then
    log_success "SLACK_USER_TOKEN detected in environment"
  else
    log_info "Slack can work in two modes:"
    echo "  1. Direct API (faster, reactions, DM names) — needs SLACK_USER_TOKEN"
    echo "  2. MCP fallback (no setup needed, but slower)"
    echo ""

    local mode
    mode=$(prompt_select "Slack mode:" "MCP fallback (no setup needed)" "Direct API (set up token now)")

    if [[ "$mode" == *"Direct API"* ]]; then
      log_info "Create a Slack app at https://api.slack.com/apps"
      log_info "Scopes needed: search:read, reactions:read, users:read"
      log_info "After installing to your workspace, add to ~/.zshrc:"
      echo ""
      echo "  export SLACK_USER_TOKEN=\"xoxp-your-token-here\""
      echo ""
    else
      log_success "MCP fallback mode — no additional setup needed"
    fi
  fi
}

setup_notion() {
  local vault_dir="$1"

  log_step "Notion integration setup"

  log_info "Notion uses the Notion MCP already configured in Claude (no CLI needed)."
  echo ""

  local db_ids
  db_ids=$(prompt_input "Task database IDs" \
    "Comma-separated Notion database IDs that contain tasks (leave empty to configure later)" \
    "")

  export TPL_NOTION_TASK_DATABASES="$db_ids"

  if [[ -n "$db_ids" ]]; then
    log_success "Notion task databases: ${db_ids}"
  else
    log_info "No databases configured — edit 05 Meta/config.yaml later to add them"
  fi
}

setup_granola() {
  local vault_dir="$1"
  local user_name="$2"

  log_step "Granola meeting sync setup"

  log_info "Granola requires manual Obsidian plugin setup:"
  echo "  1. Install the Granola Sync plugin in Obsidian"
  echo "     https://github.com/philfreo/obsidian-granola-plugin"
  echo "  2. Open Obsidian Settings → Granola Sync → Connect to Granola"
  echo "  3. Configure plugin settings:"
  echo "     - Template path: 05 Meta/templates/Granola.md"
  echo "     - Folder path: Granola"
  echo "     - Filename pattern: {date} {title}"
  echo "     - Match attendees by email: enabled"
  echo ""

  # Create staging folder
  local staging="${vault_dir}/Granola"
  mkdir -p "$staging"
  log_success "Created Granola staging folder: ${staging}"
}

setup_git() {
  local vault_dir="$1"
  local vault_name="$2"

  log_step "Git setup"

  if [[ -d "${vault_dir}/.git" ]]; then
    log_info "Git repository already exists at ${vault_dir}"
    return 0
  fi

  (
    cd "$vault_dir"
    git init -b sb/upstream
    git add -A
    git commit -m "sb: initial install (v${INSTALLER_VERSION})"

    # Create main branch from upstream
    git checkout -b main
  )

  log_success "Initialized git repo with sb/upstream tracking branch"
}

# ── Config generation ────────────────────────────────────────────────
# Build config.yaml sections based on selected integrations

generate_config() {
  local vault_dir="$1"
  local integrations="$2"
  local config_file="${vault_dir}/05 Meta/config.yaml"

  # Append-mode: file already populated — only add sections for integrations
  # whose block is missing (e.g. integration added via `--update`).
  if [[ -f "$config_file" ]] && ! grep -q '{{' "$config_file"; then
    local appended=false
    if echo "$integrations" | grep -q "Slack" && ! grep -q '^slack:' "$config_file"; then
      cat >> "$config_file" <<'EOF'

slack:
  denylist:
    - random
    - social
    - watercooler
  activity:
    session_gap_minutes: 15
    single_msg_minutes: 10
    reaction_msg_minutes: 5
    session_buffer_minutes: 5
    round_to_minutes: 15
    timezone_offset_hours: -7
EOF
      appended=true
    fi

    if echo "$integrations" | grep -q "Granola" && ! grep -q '^granola:' "$config_file"; then
      cat >> "$config_file" <<EOF

granola:
  self_name: "${TPL_USER_NAME}"
  self_aliases:
    - "${TPL_USER_FIRST_NAME}"
  staging_folder: "Granola"
  series_overrides: {}
EOF
      appended=true
    fi

    if echo "$integrations" | grep -q "Notion" && ! grep -q '^notion:' "$config_file"; then
      local notion_dbs_yaml
      notion_dbs_yaml=$(_notion_databases_yaml "${TPL_NOTION_TASK_DATABASES:-}")
      cat >> "$config_file" <<EOF

notion:
  self_name: "${TPL_USER_NAME}"
  task_databases:${notion_dbs_yaml}
  mention_lookback_days: 7
  follow_up_wait_days: 3
EOF
      appended=true
    fi

    if [[ "$appended" == true ]]; then
      log_success "Appended new integration sections to config.yaml"
    else
      log_info "config.yaml already configured — skipped"
    fi
    return 0
  fi

  # Start with classification (always present)
  cat > "$config_file" <<'EOF'
classification:
  confidence_threshold: 0.6
EOF

  # Slack section
  if echo "$integrations" | grep -q "Slack"; then
    cat >> "$config_file" <<'EOF'

slack:
  denylist:
    - random
    - social
    - watercooler
  activity:
    session_gap_minutes: 15
    single_msg_minutes: 10
    reaction_msg_minutes: 5
    session_buffer_minutes: 5
    round_to_minutes: 15
    timezone_offset_hours: -7
EOF
  fi

  # Granola section
  if echo "$integrations" | grep -q "Granola"; then
    cat >> "$config_file" <<EOF

granola:
  self_name: "${TPL_USER_NAME}"
  self_aliases:
    - "${TPL_USER_FIRST_NAME}"
  staging_folder: "Granola"
  series_overrides: {}
EOF
  fi

  # Notion section
  if echo "$integrations" | grep -q "Notion"; then
    local notion_dbs_yaml
    notion_dbs_yaml=$(_notion_databases_yaml "${TPL_NOTION_TASK_DATABASES:-}")
    cat >> "$config_file" <<EOF

notion:
  self_name: "${TPL_USER_NAME}"
  task_databases:${notion_dbs_yaml}
  mention_lookback_days: 7
  follow_up_wait_days: 3
EOF
  fi

  log_success "Generated config.yaml"
}

# Render the task_databases YAML value.
# Empty input -> " []" (inline empty list).
# Non-empty -> newline-separated list items.
_notion_databases_yaml() {
  local csv="$1"
  if [[ -z "$csv" ]]; then
    echo " []"
    return
  fi
  local out=""
  local IFS=','
  for id in $csv; do
    id="${id## }"
    id="${id%% }"
    [[ -z "$id" ]] && continue
    out="${out}
    - \"${id}\""
  done
  echo "$out"
}

# ── Settings configuration ────────────────────────────────────────────
# Tailor permissions in settings.json based on selected integrations.

configure_settings() {
  local vault_dir="$1"
  local integrations="$2"
  local vault_name="$3"
  local settings_file="${vault_dir}/.claude/settings.json"

  # Build permission allow list (only include integration-specific entries)
  local -a allow_perms=(
    '"Bash(obsidian *)"'
    '"Bash(git add *)"'
    '"Bash(git commit *)"'
    '"Bash(git status*)"'
    '"Bash(git diff*)"'
    '"Bash(git log*)"'
    '"Bash(python3 *.claude/scripts/*)"'
    '"Bash(*.claude/scripts/sb*)"'
    '"Bash(*.claude/scripts/vault-cleanup*)"'
  )

  if echo "$integrations" | grep -q "GitHub"; then
    allow_perms+=(
      '"Bash(*.claude/scripts/gh-fetch*)"'
      '"Bash(*gh-onmyplate/scripts/*)"'
    )
  fi
  if echo "$integrations" | grep -q "GitLab"; then
    allow_perms+=('"Bash(*gl-onmyplate/scripts/*)"')
  fi
  if echo "$integrations" | grep -q "Granola"; then
    allow_perms+=(
      '"Bash(*.claude/scripts/granola-ingest*)"'
      '"Bash(*.claude/scripts/granola-initial-sync*)"'
    )
  fi
  if echo "$integrations" | grep -q "Slack"; then
    allow_perms+=('"Bash(*.claude/scripts/slack-my-activity*)"')
  fi
  allow_perms+=('"Bash(*.claude/scripts/sync-memory.sh*)"')

  # Utility commands (read-only / safe)
  allow_perms+=(
    '"Bash(ls *)"'
    '"Bash(cat *)"'
    '"Bash(mkdir -p *)"'
    '"Bash(chmod +x *)"'
    '"Bash(command -v *)"'
    '"Bash(jq *)"'
  )
  if echo "$integrations" | grep -q "GitHub"; then
    allow_perms+=('"Bash(gh *)"')
  fi
  if echo "$integrations" | grep -q "GitLab"; then
    allow_perms+=('"Bash(glab *)"')
  fi

  # Join allow_perms with newlines
  local allow_json=""
  for i in "${!allow_perms[@]}"; do
    allow_json="${allow_json}      ${allow_perms[$i]}"
    if [[ $i -lt $((${#allow_perms[@]} - 1)) ]]; then
      allow_json="${allow_json},"
    fi
    allow_json="${allow_json}
"
  done

  cat > "$settings_file" <<EOF
{
  "permissions": {
    "allow": [
${allow_json}    ],
    "deny": [
      "Bash(git push*)",
      "Bash(git reset*)",
      "Bash(rm -rf*)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 '.claude/scripts/calculate_dates.py'"
          }
        ]
      }
    ]
  }
}
EOF

  log_success "Configured permissions for selected integrations"
}

# ── Run all selected integration setups ──────────────────────────────
run_integration_setup() {
  local vault_dir="$1"
  local integrations="$2"
  local user_name="$3"

  if echo "$integrations" | grep -q "GitHub"; then
    setup_github "$vault_dir"
  fi

  if echo "$integrations" | grep -q "GitLab"; then
    setup_gitlab "$vault_dir"
  fi

  if echo "$integrations" | grep -q "Slack"; then
    setup_slack "$vault_dir"
  fi

  if echo "$integrations" | grep -q "Notion"; then
    setup_notion "$vault_dir"
  fi

  if echo "$integrations" | grep -q "Granola"; then
    setup_granola "$vault_dir" "$user_name"
  fi

  # Generate config.yaml based on selections
  generate_config "$vault_dir" "$integrations"

  # Tailor sandbox + permissions to selected integrations
  configure_settings "$vault_dir" "$integrations" "$TPL_VAULT_NAME"

  # Git must be last (it commits the initial state)
  if echo "$integrations" | grep -q "Git-backed"; then
    setup_git "$vault_dir" ""
  fi
}

# Run per-integration setup for only the newly-added integrations during update.
# Does NOT regenerate settings.json or config.yaml — the caller handles those.
run_new_integrations_setup() {
  local vault_dir="$1"
  local newly_added="$2"
  local user_name="$3"

  if echo "$newly_added" | grep -q "GitHub"; then
    setup_github "$vault_dir"
  fi
  if echo "$newly_added" | grep -q "GitLab"; then
    setup_gitlab "$vault_dir"
  fi
  if echo "$newly_added" | grep -q "Slack"; then
    setup_slack "$vault_dir"
  fi
  if echo "$newly_added" | grep -q "Notion"; then
    setup_notion "$vault_dir"
  fi
  if echo "$newly_added" | grep -q "Granola"; then
    setup_granola "$vault_dir" "$user_name"
  fi
  # Git last (it commits initial state when initializing a previously-non-git vault)
  if echo "$newly_added" | grep -q "Git-backed"; then
    setup_git "$vault_dir" ""
  fi
}

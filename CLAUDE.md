# CLAUDE.md — Second Brain Installer

This file provides guidance to Claude Code when working on the **installer** repo (not the installed vault).

## What This Is

An installer that provisions Obsidian vaults as personal knowledge management systems. The installer copies template files into a user-chosen location, applies variable substitution, and sets up integrations.

## Repo Structure

```
second-brain/                        ← this repo (installer)
├── install.sh                       ← main entry point (install + update)
├── README.md                        ← user-facing docs
├── CLAUDE.md                        ← this file (developer docs)
├── lib/                             ← installer helper scripts
│   ├── common.sh                    ← gum wrappers, logging, metadata
│   ├── prerequisites.sh             ← dependency checks + brew install
│   ├── integrations.sh              ← per-integration setup logic
│   └── templating.sh                ← file copy with placeholder substitution
├── template/                        ← vault source files (copied to target)
│   ├── CLAUDE.md                    ← vault's CLAUDE.md (has {{VAULT_NAME}} placeholders)
│   ├── README.md                    ← vault's README
│   ├── .claude/                     ← commands, skills, agents, settings
│   ├── .gitignore                   ← vault's gitignore
│   ├── .mcp.json
│   ├── 01 Projects/                 ← project base view
│   ├── 02 Areas/                    ← browsing base views
│   └── 05 Meta/                     ← schemas, scripts, templates, config, bases
├── scaffold/                        ← user-owned files (created once, never overwritten)
│   ├── context/work-profile.md.tmpl
│   ├── context/current-priorities.md.tmpl
│   └── settings.local.json
└── docs/                            ← development specs and proofs
```

## Template System

### Placeholders

Files in `template/` and `scaffold/` use `{{PLACEHOLDER}}` syntax:

| Placeholder | Source | Example |
|---|---|---|
| `{{VAULT_NAME}}` | User input during install | `second-brain` |
| `{{USER_NAME}}` | User input during install | `Jane Smith` |
| `{{USER_FIRST_NAME}}` | Derived from USER_NAME | `Jane` |
| `{{USER_ROLE}}` | User input during install | `Staff Engineer` |
| `{{USER_EMAIL}}` | User input during install | `jane@company.com` |
| `{{PRIORITY_1..3}}` | Scaffold-only, user fills in | — |

### How it works

1. `lib/templating.sh` walks the `template/` tree
2. For each file, checks if it contains `{{...}}` patterns
3. If yes, runs sed substitution; if no, plain copy
4. `.tmpl` suffix is stripped from destination filenames

### Adding a new template variable

1. Add the placeholder to relevant files: `{{NEW_VAR}}`
2. Add the sed line in `apply_template_file()` in `lib/templating.sh`
3. Export `TPL_NEW_VAR` in `install.sh` before calling copy functions

## Integration System

Each integration is a named feature the user selects during install:

| Integration | Controls |
|---|---|
| `GitHub sync` | gh-onmyplate skill, gh-fetch script, gh-import command, GitHub.base |
| `GitLab sync` | gl-onmyplate skill |
| `Slack activity tracking` | slack-my-activity script, slack command |
| `Granola meeting sync` | granola scripts, Granola.md template |
| `Git-backed vault` | .gitignore, git init, sb/upstream branch |

Disabled integrations exclude files via glob patterns in `copy_template_tree()`.

### Adding a new integration

1. Add option to the `gum choose` list in `install.sh` Step 2
2. Add exclusion patterns in `copy_template_tree()` in `lib/templating.sh`
3. Add setup function in `lib/integrations.sh`
4. Add config section in `generate_config()` in `lib/integrations.sh`

## Git-Based Update Strategy

Installed vaults with git use a tracking branch:

- `sb/upstream` — contains only installer-managed files, committed by installer
- `main` — user's working branch

On update:
1. `sb/upstream` gets new template files committed
2. `main` merges `sb/upstream`
3. User resolves any conflicts

## Key Conventions

- **Shell style**: bash, `set -euo pipefail`, functions over scripts
- **Commit prefix**: `sb:` for vault commits
- **gum dependency**: auto-installed via brew if missing
- **macOS assumed**: uses `sed -i ''` (BSD sed), `brew`, etc.

## Testing

Manual testing workflow:
```bash
# Fresh install to a temp directory
./install.sh
# Choose /tmp/test-vault as location

# Verify vault
ls /tmp/test-vault/.claude/commands/
grep -r 'vault=second-brain' /tmp/test-vault/ || echo "No hardcoded vault names"
obsidian vault=test-vault search query="type" path="05 Meta/claude" format=json | cat

# Update test
# Edit a template file, then:
./install.sh --update /tmp/test-vault
```

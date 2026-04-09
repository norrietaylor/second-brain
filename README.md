# Second Brain Installer

An installer for provisioning [Obsidian](https://obsidian.md) vaults as personal knowledge management systems, powered by [Claude Code](https://claude.ai/code) automation.

## What It Does

This repo is **not** the vault itself — it's the installer. Running `install.sh` creates a fully configured Second Brain vault at a location of your choosing, with:

- **Type-dispatched notes** — every note has a `type` frontmatter field (person, project, task, meeting, etc.) with enforced schemas
- **Live database views** — Obsidian Bases files that query notes by frontmatter properties
- **AI-powered daily workflows** — Claude Code slash commands for morning briefings (`/today`), end-of-day processing (`/eod`), meeting capture (`/meeting`), and more
- **Configurable integrations** — GitHub, GitLab, Slack, and Granola meeting sync

## Prerequisites

| Tool | Required | Install |
|---|---|---|
| [Homebrew](https://brew.sh) | Yes | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| [Obsidian](https://obsidian.md) | Yes | `brew install --cask obsidian` |
| [Obsidian CLI](https://obsidian.md/cli) | Yes (v1.12+) | See Obsidian docs |
| [Claude Code](https://claude.ai/code) | Yes | `npm install -g @anthropic-ai/claude-code` |
| [jq](https://jqlang.github.io/jq/) | Yes | `brew install jq` |
| [Python 3](https://www.python.org) | Yes | Ships with macOS |
| [gum](https://github.com/charmbracelet/gum) | Auto-installed | `brew install gum` |

The installer will check for these and offer to install missing tools via Homebrew.

### Optional (based on integrations)

| Tool | For | Install |
|---|---|---|
| [GitHub CLI](https://cli.github.com) (`gh`) | GitHub sync | `brew install gh` |
| [GitLab CLI](https://gitlab.com/gitlab-org/cli) (`glab`) | GitLab sync | `brew install glab` |

## Install

```bash
git clone https://github.com/norrietaylor/second-brain.git
cd second-brain
./install.sh
```

The interactive installer will prompt for:

1. **Vault name** — used in Obsidian and CLI commands (default: `second-brain`)
2. **Vault location** — where to create the vault (default: `~/Documents/obsidian/<name>`)
3. **Integrations** — which features to enable:
   - GitHub sync (issue/PR tracking, notifications)
   - GitLab sync (MR/issue tracking, todos)
   - Slack activity tracking (time estimates for Harvest)
   - Granola meeting sync (transcription)
   - Git-backed vault (version control with update support)
4. **Your profile** — name, role, email (used in meeting notes and config)

## Update

If you installed with "Git-backed vault" enabled:

```bash
cd /path/to/this/installer-repo
git pull
./install.sh --update
```

The updater:
1. Finds your vault (or prompts for the path)
2. Updates the `sb/upstream` tracking branch with new template files
3. Merges into your `main` branch
4. You resolve any conflicts in files you've customized

For non-git vaults, `--update` overwrites installer-managed files directly.

## What Gets Installed

### Installer-managed files (updated on `--update`)

- `.claude/commands/` — slash commands (`/today`, `/eod`, `/meeting`, etc.)
- `.claude/skills/` — Claude Code skills (classify, obsidian-cli, gh-onmyplate, etc.)
- `.claude/agents/` — automation agents
- `.claude/settings.json` — permissions and hooks
- `05 Meta/claude/` — type schemas (`*.claude.md`)
- `.claude/scripts/` — shell scripts (gh-fetch, sb-ingest, granola-ingest, etc.)
- `05 Meta/templates/` — Templater templates
- `05 Meta/bases/` — system base views
- `02 Areas/*.base` — browsing views
- `01 Projects/*.base` — project tracking
- `CLAUDE.md` — vault documentation for Claude Code

### User-owned files (created once, never overwritten)

- `05 Meta/config.yaml` — classification, Slack, and Granola settings
- `05 Meta/context/` — work profile, priorities
- `05 Meta/logs/` — classification audit trail
- `04 Data/` — all your notes
- `.claude/settings.local.json` — your local Claude Code settings

## Vault Architecture

See the installed vault's `CLAUDE.md` for full documentation on:
- Type dispatch system and note schemas
- File naming conventions
- Obsidian CLI usage
- Classification pipeline
- GitHub/GitLab sync architecture
- Granola meeting sync
- Slack activity tracking

## Development

This repo uses the following structure:

```
├── install.sh          ← main installer + updater
├── lib/                ← installer helper scripts
├── template/           ← vault source files (copied to target)
├── scaffold/           ← user-owned files (created once)
└── docs/               ← development specs and proofs
```

To work on the installer:
```bash
cd /path/to/second-brain   # this repo
claude                      # uses root CLAUDE.md for context
```

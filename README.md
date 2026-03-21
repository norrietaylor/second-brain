# Second Brain

An Obsidian vault structured as a personal knowledge management system, powered by Claude Code automation. Notes are organized by type (not folder) using frontmatter-driven Bases views, with CLI commands for daily workflows.

## Prerequisites

| Dependency | Purpose | Install |
|---|---|---|
| [Obsidian](https://obsidian.md) | Vault host | `brew install --cask obsidian` |
| [Obsidian CLI](https://obsidian.md/cli) (v1.12+) | Vault operations from terminal | See Obsidian docs |
| [Claude Code](https://claude.ai/code) | AI-powered commands (`/today`, `/eod`, etc.) | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com) (`gh`) | GitHub sync | `brew install gh` |
| [jq](https://jqlang.github.io/jq/) | JSON processing in scripts | `brew install jq` |
| [Python 3](https://www.python.org) | Date calculation script | Ships with macOS |
| [Docker](https://www.docker.com) | Slack MCP server (optional) | `brew install --cask docker` |

### Obsidian Plugins

Install via Obsidian Settings > Community Plugins:

- **Bases** (core, enable in Core Plugins)
- **Templater** by SilentVoid
- **Update frontmatter modified date** by Alan Grainger

## Setup

### 1. Clone and open the vault

```bash
git clone <repo-url> ~/Documents/obsidian/second-brain
```

Open the folder as a vault in Obsidian.

### 2. Run the setup command

With the vault open in Obsidian, start Claude Code in the vault directory and run:

```
/setup
```

This interactive command will:
- Create all gitignored directories (`04 Data/`, `05 Meta/context/`, `05 Meta/logs/`, `03 Resources/`, `~/second-brain-inbox/`)
- Scaffold personal context files (work profile, priorities) with your input
- Validate all prerequisites (Obsidian CLI, GitHub CLI, jq, Python 3)
- Check GitHub authentication
- Verify Obsidian vault access and script permissions
- Remind you to configure required Obsidian plugins
- Create `.claude/settings.local.json` if missing

### 3. Manual steps after `/setup`

The command will flag anything it can't automate. Common manual steps:

- **Obsidian plugins** — install via Settings > Community Plugins:
  - **Templater**: set template folder to `05 Meta/templates`
  - **Update frontmatter modified date**: set format to `YYYY-MM-DD HH:mm`, add `05 Meta` to excluded folders
- **GitHub auth** — if not authenticated, run `gh auth login`
- **Slack MCP** (optional) — `cp .env.example .env`, fill in tokens, run `./run-mcp.sh`

## Preflight Check

Run these to verify everything is wired up:

```bash
# Core tools
obsidian --version                    # v1.12+ required
gh --version                          # GitHub CLI
jq --version                          # JSON processor
python3 --version                     # Python 3

# Obsidian vault access
obsidian vault=second-brain search query="type" path="05 Meta/claude" format=json | cat

# Bases views respond
obsidian vault=second-brain base:query path="02 Areas/Tasks.base" format=json | cat

# GitHub CLI authenticated
gh auth status

# Scripts are executable
ls -la 05\ Meta/scripts/gh-fetch 05\ Meta/scripts/sb-ingest

# Inbox drop folder exists
ls -d ~/second-brain-inbox

# Claude Code session hook works
python3 '05 Meta/scripts/calculate_dates.py'
```

All commands should exit 0. If Obsidian CLI commands fail, make sure Obsidian is running with the vault open.

## Architecture

See [CLAUDE.md](CLAUDE.md) for full system documentation: type dispatch, file naming, wiki-link conventions, classification pipeline, and GitHub sync architecture.

### Key Concepts

- **Type dispatch**: every note has a `type` frontmatter field; schemas live in `05 Meta/claude/<type>.claude.md`
- **Single data lake**: all notes in `04 Data/YYYY/MM/` regardless of type
- **Virtual folders**: `02 Areas/*.base` files are live database views, not storage
- **Classification pipeline**: new captures arrive as `type: inbox` → `/eod` classifies them → low confidence items get flagged for review

### Commands

| Command | When to use |
|---|---|
| `/setup` | First-time vault initialization after cloning |
| `/today` | Start of day — briefing, daily note, GitHub sync |
| `/eod` | End of day — classify inbox, detect dirty notes, generate digest |
| `/meeting` | Create a meeting note from natural language |
| `/learned` | Capture context at end of a work session |
| `/gh-import` | Import or update a specific GitHub issue/PR |
| `/generate-digests` | Backfill missing weekly/monthly digests |

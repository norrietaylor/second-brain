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
- **Google Calendar** (optional, for calendar blocks in daily notes)
- **Tasks** by Martin Schenck

## Setup

### 1. Clone and open the vault

```bash
git clone <repo-url> ~/Documents/obsidian/second-brain
```

Open the folder as a vault in Obsidian.

### 2. Install Obsidian plugins

Open Settings > Community Plugins, install the plugins listed above, then:

- **Templater**: set template folder to `05 Meta/templates`
- **Update frontmatter modified date**: set format to `YYYY-MM-DD HH:mm`, add `05 Meta` to excluded folders
- **Google Calendar**: configure with your Google account (optional)

### 3. Create personal context files

These are gitignored — create them locally:

```bash
mkdir -p "05 Meta/context" "05 Meta/logs"

cat > "05 Meta/context/work-profile.md" << 'EOF'
---
type: context
---
# Work Profile

- **Name:** Your Name
- **Role:** Your Role
- **Email:** you@example.com
EOF

cat > "05 Meta/context/current-priorities.md" << 'EOF'
---
type: context
---
# Current Priorities

1. ...
2. ...
3. ...
EOF

touch "05 Meta/logs/inbox-log.md"
```

The tag taxonomy (`05 Meta/context/tags.md`) is committed and shared.

### 4. Configure environment

```bash
# GitHub CLI auth
gh auth login

# Optional: Slack MCP server
cp .env.example .env   # fill in your Slack tokens
./run-mcp.sh
```

### 5. Create the inbox drop folder

```bash
mkdir -p ~/second-brain-inbox
```

Other projects can drop markdown files here. `sb-ingest` moves them into the vault.

### 6. Set up Claude Code local settings

Create `.claude/settings.local.json` for user-specific MCP servers and permissions (gitignored):

```json
{
  "permissions": {
    "allow": []
  }
}
```

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
| `/today` | Start of day — briefing, daily note, GitHub sync |
| `/eod` | End of day — classify inbox, detect dirty notes, generate digest |
| `/meeting` | Create a meeting note from natural language |
| `/learned` | Capture context at end of a work session |
| `/gh-import` | Import or update a specific GitHub issue/PR |
| `/generate-digests` | Backfill missing weekly/monthly digests |

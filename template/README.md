---
modified: 2026-03-23T21:00:00-07:00
---
# Second Brain

An Obsidian vault structured as a personal knowledge management system, powered by Claude Code automation. Notes are organized by type (not folder) using frontmatter-driven Bases views, with CLI commands for daily workflows.

## Prerequisites

| Dependency | Purpose | Install |
|---|---|---|
| [Obsidian](https://obsidian.md) | Vault host | `brew install --cask obsidian` |
| [Obsidian CLI](https://obsidian.md/cli) (v1.12+) | Vault operations from terminal | See Obsidian docs |
| [Claude Code](https://claude.ai/code) | AI-powered commands (`/today`, `/eod`, etc.) | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com) (`gh`) | GitHub sync | `brew install gh` |
| [GitLab CLI](https://gitlab.com/gitlab-org/cli) (`glab`) | GitLab sync (optional) | `brew install glab` |
| [jq](https://jqlang.github.io/jq/) | JSON processing in scripts | `brew install jq` |
| [Python 3](https://www.python.org) | Date calculation, Slack activity script | Ships with macOS |

### Obsidian Plugins

Install via Obsidian Settings > Community Plugins:

- **Bases** (core, enable in Core Plugins)
- **Templater** by SilentVoid
- **Update frontmatter modified date** by Alan Grainger
- **Granola Sync** by philfreo — syncs Granola meeting transcripts to a staging folder

### Optional Integrations

| Integration | Purpose | Setup |
|---|---|---|
| Slack MCP plugin | Channel summaries in `/eod`, MCP fallback for `/slack:my-activity` | Enable in Claude Code MCP settings |
| Slack API token | Direct API for `/slack:my-activity` (faster, includes reactions + DM names) | [Setup instructions](#slack-activity--time-estimates) |
| [Granola](https://granola.ai) | Meeting transcription and notes | [Setup instructions](#granola-meeting-sync) |
| Harvest MCP server | Time entry (future `/slack:harvest-entry`) | Configured in Claude Desktop |

## Setup

This vault was provisioned by the Second Brain installer. Most setup is already done.

### 1. Open the vault in Obsidian

Open Obsidian → Open folder as vault → select this directory.

### 2. Run the health check

With the vault open in Obsidian, start Claude Code in the vault directory and run:

```
/verify
```

This checks that the vault is correctly configured:
- Obsidian CLI can reach the vault
- Bases views respond
- Prerequisites and authentication are valid
- Scripts are executable

### 3. Manual steps after `/verify`

The command will flag anything that needs attention. Common manual steps:

- **Obsidian plugins** — install via Settings > Community Plugins:
  - **Templater**: set template folder to `05 Meta/templates`
  - **Update frontmatter modified date**: set format to `YYYY-MM-DD HH:mm`, add `05 Meta` to excluded folders
  - **Granola Sync**: see [Granola Meeting Sync](#granola-meeting-sync)
- **GitHub auth** — if not authenticated, run `gh auth login`
- **Slack** — see [Slack Activity & Time Estimates](#slack-activity--time-estimates) for optional setup

## Preflight Check

Run these to verify everything is wired up:

```bash
# Core tools
obsidian --version                    # v1.12+ required
gh --version                          # GitHub CLI
jq --version                          # JSON processor
python3 --version                     # Python 3

# Obsidian vault access
obsidian vault={{VAULT_NAME}} search query="type" path="05 Meta/claude" format=json | cat

# Bases views respond
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Tasks.base" format=json | cat

# GitHub CLI authenticated
gh auth status

# Scripts are executable
ls -la 05\ Meta/scripts/gh-fetch 05\ Meta/scripts/sb-ingest 05\ Meta/scripts/slack-my-activity

# Inbox drop folder exists
ls -d ~/{{VAULT_NAME}}-inbox

# Claude Code session hook works
python3 '.claude/scripts/calculate_dates.py'

# Slack API (optional — only if token configured)
echo $SLACK_USER_TOKEN | head -c 10   # should show "xoxp-..."
```

All commands should exit 0. If Obsidian CLI commands fail, make sure Obsidian is running with the vault open.

## Architecture

See [CLAUDE.md](CLAUDE.md) for full system documentation: type dispatch, file naming, wiki-link conventions, classification pipeline, GitHub sync, and Slack activity architecture.

### Key Concepts

- **Type dispatch**: every note has a `type` frontmatter field; schemas live in `05 Meta/claude/<type>.claude.md`
- **Single data lake**: all notes in `04 Data/YYYY/MM/` regardless of type
- **Virtual folders**: `02 Areas/*.base` files are live database views, not storage
- **Classification pipeline**: new captures arrive as `type: inbox` → `/eod` classifies them → low confidence items get flagged for review

### Commands

| Command | When to use |
|---|---|
| `/verify` | Post-install health check — validates vault access, prerequisites, auth |
| `/today` | Start of day — briefing, daily note, GitHub sync |
| `/eod` | End of day — classify inbox, detect dirty notes, Slack activity + time estimates, generate digest |
| `/meeting` | Create a meeting note from natural language |
| `/learned` | Capture context at end of a work session |
| `/gh-import` | Import or update a specific GitHub issue/PR |
| `/generate-digests` | Backfill missing weekly/monthly digests |
| `/slack:my-activity` | Slack activity report with time estimates per channel (for Harvest) |
| `/gh-onmyplate` | GitHub plate check — notifications, open threads, your PRs |
| `/gl-onmyplate` | GitLab plate check — todos, open threads, your MRs |
| `/session-log` | Capture session context for Second Brain ingestion |

### Scripts

| Script | Purpose | Usage |
|---|---|---|
| `.claude/scripts/gh-fetch` | Fetch GitHub issue/PR data as JSON | `gh-fetch <url> [--since <ISO-date>]` |
| `.claude/scripts/sb-ingest` | Import files from `~/{{VAULT_NAME}}-inbox/` drop folder | `sb-ingest [--dry-run]` |
| `.claude/scripts/calculate_dates.py` | Date utility (runs on session start via hook) | Auto-invoked |
| `.claude/scripts/granola-ingest` | Transform staged Granola notes into meeting notes | `granola-ingest [--dry-run]` |
| `.claude/scripts/slack-my-activity` | Slack activity with session-based time estimates | `slack-my-activity [YYYY-MM-DD] [--json]` |
| `.claude/scripts/sync-memory.sh` | Sync Claude memory files | Manual |

### Configuration

Central configuration lives in `05 Meta/config.yaml`:

```yaml
classification:
  confidence_threshold: 0.6        # below this → needs_review

slack:
  denylist:                        # channels excluded from /eod summaries
    - random
    - social
    - watercooler
  activity:                        # session clustering for time estimates
    session_gap_minutes: 15        # gap to split sessions
    single_msg_minutes: 10         # lone authored message duration
    reaction_msg_minutes: 5        # lone reaction-only duration
    session_buffer_minutes: 5      # buffer on each end of multi-message sessions
    round_to_minutes: 15           # Harvest-friendly rounding
    timezone_offset_hours: -7      # PDT (-7) or PST (-8)

granola:
  self_name: "Your Name"           # excluded from attendee counts
  self_aliases: ["Your First Name"]
  staging_folder: "Granola"        # must match plugin folder path
  series_overrides: {}             # "Meeting Title": "forced-meeting-name"
```

## Slack Activity & Time Estimates

Tracks your personal Slack activity (messages sent, reactions placed) for a given day, groups by channel, clusters into sessions, and estimates time spent. Designed for Harvest time entry.

Full technical documentation: `05 Meta/claude/slack-activity.claude.md`

### How it works

1. Fetches all messages you sent on the target date
2. Optionally fetches messages you reacted to (Direct API only)
3. Groups by channel, clusters messages into sessions (15-min gap = new session)
4. Estimates duration per session: single message = 10min, multi-message = span + 10min buffer
5. Rounds per-channel totals to 15 minutes (Harvest-friendly)

### Usage

```bash
# Standalone
/slack:my-activity              # today
/slack:my-activity 2026-03-23   # specific date

# Automatic — runs as part of /eod Step 5.5
# Output appears in daily note as a collapsible time estimate table
```

### Data sources (graceful degradation)

| Source | Requires | Messages | Reactions | DM Names | Speed |
|---|---|---|---|---|---|
| Direct API | `SLACK_USER_TOKEN` env var | 100/page | Yes | Yes | 1-2 API calls |
| MCP fallback | Slack MCP plugin enabled | 20/page | No | Yes | 3+ MCP calls |
| Neither | — | Skipped | Skipped | — | — |

### Setup (optional — MCP fallback works without this)

Create a Slack app for Direct API mode:

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From Scratch**
2. **OAuth & Permissions** → **User Token Scopes** → add: `search:read`, `reactions:read`, `users:read`
3. **Install to Workspace** → approve → copy **User OAuth Token** (`xoxp-...`)
4. Add to shell profile:
   ```bash
   # ~/.zshrc
   export SLACK_USER_TOKEN="xoxp-your-token-here"
   ```

### EOD integration

`/eod` Step 5.5 automatically generates channel summaries and time estimates. The time report appears in the daily note as a collapsed callout:

```markdown
### Slack Activity
- **#channel-1** — topic summary
- **#channel-2** — topic summary

> [!note]- Time Estimates (13 channels, 6h 30m)
> | Channel | Sessions | Time |
> |---------|----------|------|
> | #DM:Rebeccah | 6 — 14:03, 14:18-14:20, ... | 1h 15m |
> | #acct-clc | 3 — 13:29-13:30, 15:46-15:50 | 45m |
> | **Total** | | **6h 30m** |
```

### Limitations

- **Huddles**: Not accessible via Slack API. No endpoint exposes huddle participation or duration.
- **Passive reading**: Only channels where you posted or reacted are tracked.
- **MCP mode**: No reactions data, slower pagination, but works without any setup.

## Granola Meeting Sync

Granola (granola.ai) meetings are synced into the vault via a two-stage pipeline: an Obsidian plugin handles API polling, and a bash script transforms the output into proper {{VAULT_NAME}} notes.

### Setup (one-time)

1. **Install the plugin** — [philfreo/obsidian-granola-plugin](https://github.com/philfreo/obsidian-granola-plugin) (manual install or community catalog). Desktop only.
2. **Authenticate** — Open Obsidian Settings → Granola Sync → click "Connect to Granola". Complete the OAuth flow in the browser.
3. **Configure the plugin settings:**
   - **Template path**: `05 Meta/templates/Granola.md`
   - **Folder path**: `Granola` (staging folder — the ingest script moves notes out of here)
   - **Filename pattern**: `{date} {title}`
   - **Sync frequency**: `15m` (or preference — `1m` to `12h`, or `manual`)
   - **Sync time range**: `last_30_days`
   - **Match attendees by email**: `enabled`
   - **Include full transcript**: `enabled` (optional)
   - **Skip existing notes**: `enabled`
4. **Configure your name** in `05 Meta/config.yaml` (see [Configuration](#configuration))
5. **Add emails to person notes** for attendee auto-linking:
   ```yaml
   emails:
     - alice@company.com
   ```

### How it works

```
Granola app → plugin polls API → Granola/ staging folder
                                      ↓
                          /eod Step 0.75 (or manual: granola-ingest)
                                      ↓
                          For each staged note:
                            1. Parse frontmatter (granola_id, title, date, attendees)
                            2. Derive meeting_name (strip dates, kebab-case)
                            3. Detect 1-on-1 (1 attendee excluding self)
                            4. Dedup by granola_id
                            5. Create meeting note in 04 Data/YYYY/MM/
                            6. Create person stubs for unknown attendees
                            7. Rewrite attendees with [[wiki-links]]
                            8. Delete staging file
```

### Meeting note layout

- `source: granola` and `granola_id` in frontmatter (for dedup)
- `## Log` — your private notes from Granola
- `> [!note]- Granola AI Summary` — collapsed AI-generated content
- `> [!note]- Transcript` — collapsed full transcript (if enabled)
- `/eod` Step 3 generates `## Summary` from the Log content

## Skills: Platform Plate Checks

`gh-onmyplate` and `gl-onmyplate` are Claude Code skills that surface what needs your attention on GitHub and GitLab respectively. Each bundles a set of shell scripts that query the platform APIs from different angles, then synthesize a briefing grouped by action needed.

### `gl-onmyplate` — GitLab

Five scripts for self-hosted or gitlab.com instances. Auto-detects the GitLab host from `glab` CLI config.

| Script | Purpose |
|---|---|
| `gl_notifications.sh` | Pending todos (GitLab inbox) — @mentions, assignments, review/approval requests |
| `gl_involved.sh` | All open MRs and issues where you're author, assignee, or reviewer |
| `gl_my_mrs.sh` | Your open MRs with pipeline status and last note |
| `gl_thread_context.sh` | Relevant tail of a specific MR or issue thread with action hint |
| `gl_mark_done.sh` | Mark a todo as done with audit log |

**Configuration** — edit `.claude/skills/gl-onmyplate/scripts/config.sh`:
- `GL_HOST` — self-hosted hostname (blank = auto-detect from glab config)
- `IGNORE_REVIEW_GROUPS` — namespace paths to filter out team-only review requests
- `FILTER_MERGED_REVIEWED` — filter merged MRs from todos (default: `true`)

**Prerequisites:** `glab` CLI authenticated, `jq`, `curl`.

### `gh-onmyplate` — GitHub

Four scripts plus a mark-done action for GitHub notifications and threads.

| Script | Purpose |
|---|---|
| `gh_notifications.sh` | New activity from GitHub notification inbox (unread/read) |
| `gh_involved.sh` | All open issues and PRs you're involved in |
| `gh_my_prs.sh` | Your open PRs with last post summary |
| `gh_thread_context.sh` | Relevant tail of a specific issue/PR thread with action hint |
| `gh_mark_done.sh` | Mark a notification thread as done with audit log |

**Configuration** — edit `.claude/skills/gh-onmyplate/scripts/config.sh`:
- `IGNORE_REVIEW_TEAMS` — `org/team-slug` entries to filter team-only review requests
- `FILTER_MERGED_REVIEWED` — filter merged PRs from notifications (default: `true`)

**Prerequisites:** `gh` CLI authenticated with `repo` and `notifications` scopes, `jq`.

### Timespan parameter

All discovery scripts accept an optional timespan: `3d`, `7d` (default), `2w`, `1m`, `1y`. For `*_my_prs.sh`/`*_my_mrs.sh`, the default is `1y`.

### Workflow

Both skills follow the same pattern:
1. **Discover** — run the three discovery scripts to find threads from different angles
2. **Dig in** — use `*_thread_context.sh` on threads that need more context
3. **Synthesize** — present a briefing grouped into "needs your response", "your open PRs/MRs — status", and "no action needed (FYI)"

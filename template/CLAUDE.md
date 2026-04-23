# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

An Obsidian vault (`{{VAULT_NAME}}`) functioning as a personal knowledge management system. It is NOT a code repository — it contains markdown notes, Obsidian Bases views, shell scripts, and type schemas.

## Vault Structure

```
{{VAULT_NAME}}/
├── CLAUDE.md              ← this file
├── Index.md               ← landing page (Today's Note link, Projects embed)
├── 01 Projects/           ← Active Projects.base
├── 02 Areas/              ← Browsing views (Today, Tasks, People, Meetings, GitHub, Digests, etc.)
├── 03 Resources/          ← Topic-based reference collections (folders by theme)
│   ├── Resources.base     ← Surfaces all resource notes; views: All, Recently Added, By Topic
│   └── <Topic>/           ← One folder per area of interest (e.g. AI Tooling/, Leadership/)
├── 04 Data/YYYY/MM/       ← ALL notes (single data lake)
│   └── YYYY.MM.DD-<name>.md
└── 05 Meta/               ← System files
    ├── bases/             ← Programmatic bases (Unprocessed Inbox, Dirty Notes, Modified Today)
    ├── claude/            ← Type schemas (<type>.claude.md)
    ├── config.yaml        ← classification, slack, granola settings
    ├── context/           ← work-profile.md, current-priorities.md, tags.md
    ├── templates/         ← Templater templates
    ├── logs/inbox-log.md  ← Classification audit trail
    └── scripts/           ← sb-ingest, gh-fetch, sync-memory.sh, calculate_dates.py
```

## Architecture: Type Dispatch System

Every note has a `type` frontmatter field. To understand a note's schema, conventions, and required fields, read the corresponding file at `05 Meta/claude/<type>.claude.md`.

Available types: `person`, `project`, `task`, `idea`, `admin`, `reference`, `meeting`, `inbox`, `digest`, `dailynote`, `github`, `notion`

All notes live in `04 Data/YYYY/MM/` regardless of type. The `02 Areas/*.base` files are Obsidian Bases views that query notes by frontmatter properties — they are live database views, not storage.

### Universal Frontmatter Fields (all note types)
- `type` — dispatches to schema
- `created` / `modified` — datetime strings (`YYYY-MM-DD HH:mm`)
  - The "Update frontmatter modified date" Obsidian plugin manages `modified` **only when editing inside Obsidian's UI** (editor keystrokes). It does NOT fire on CLI writes.
  - **When Claude creates or modifies a note via the `obsidian` CLI, it must set `modified` manually** to the current timestamp. Failure to do so means the `Modified Today` base will show stale data.
- `aliases` — kebab-case name without date prefix
- `classified_at` / `confidence` — system-managed classification metadata

## Critical Conventions

### File Naming
```
04 Data/YYYY/MM/YYYY.MM.DD-<kebab-case-name>.md
```
Date uses dots in filename (`2026.03.18-...`), hyphens in frontmatter (`2026-03-18`).

### Wiki-Links
Always use full filename with display text:
```
[[YYYY.MM.DD-name|display-text]]
```
**NEVER** use alias-only links (`[[marius]]`) — they create empty files at vault root.

### Obsidian CLI
All vault interaction goes through the `obsidian` CLI. Key commands:
```bash
obsidian vault={{VAULT_NAME}} create path="..." content="..." silent
obsidian vault={{VAULT_NAME}} search query="..." path="04 Data" format=json
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Today.base" format=json
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Tasks.base" view="ViewName" format=json
obsidian vault={{VAULT_NAME}} property:set path="..." name=status value=done
obsidian vault={{VAULT_NAME}} append path="..." content="..." silent
```

**NEVER pipe `obsidian` CLI output through `head`, `tail`, or `less`** — the CLI doesn't handle SIGPIPE and will hang. Use `| cat | head -20` as a workaround, or use filtered views/format=json and process in full.

## Available Commands

Slash commands are defined in `.claude/commands/<name>.md`:

| Command | Purpose | Weight |
|---------|---------|--------|
| `/verify` | Post-install health check — validates vault access, prerequisites, auth | Light |
| `/today` | Morning briefing + daily note + GitHub sync | Heavy (queries 3+ bases, runs GitHub discovery, marks notifications) |
| `/eod` | End-of-day processing (inbox, dirty detection, meeting summaries, Slack activity, digest enrichment) | Heavy |
| `/meeting` | Create meeting note from natural language | Light |
| `/learned` | End-of-session context capture | Light |
| `/gh-import` | Import or update a single GitHub issue/PR | Medium |
| `/notion-import` | Import or update a single Notion page (via Notion MCP) | Medium |
| `/gemini-import` | Ingest a Gemini-generated meeting-minutes Google Doc (via Google MCP) | Medium |
| `/generate-digests` | Backfill missing digests for date range | Heavy |
| `/slack:my-activity` | Slack activity report with time estimates per channel | Medium |

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `.claude/scripts/gh-fetch` | Fetch GitHub issue/PR data as JSON | `gh-fetch <url> [--since <ISO-date>]` |
| `.claude/scripts/sb-ingest` | Import files from `~/{{VAULT_NAME}}-inbox/` drop folder | `sb-ingest [--dry-run]` |
| `.claude/scripts/calculate_dates.py` | Date utility (runs on session start via hook) | Auto-invoked |
| `.claude/scripts/granola-ingest` | Transform staged Granola notes into meeting notes | `granola-ingest [--dry-run]` |
| `.claude/scripts/slack-my-activity` | Slack activity report with session-based time estimates | `slack-my-activity [YYYY-MM-DD] [--json]` |
| `.claude/scripts/sync-memory.sh` | Sync Claude memory files | Manual |

## Bases Views (02 Areas/)

These are the primary query surfaces. Use `base:query` to read them:

| Base | Key Views | What It Shows |
|------|-----------|---------------|
| Today.base | (default) | Overdue tasks, due today, active projects, needs review |
| Tasks.base | (default) | All open tasks sorted by due date |
| People.base | With Follow-ups | People with pending follow-ups |
| GitHub.base | (default) | All tracked GitHub issues/PRs |
| Notion.base | All, Assigned to me, Waiting on others, Open | Tracked Notion pages/tasks |
| Digests.base | Recent, All | Weekly/monthly digest notes |
| Meetings.base | All, Today, By Source, Gemini | Meeting notes (manual, granola, gemini) |

`03 Resources/Resources.base` — All, Recently Added, By Topic views over the `03 Resources/` folder tree.

System bases in `05 Meta/bases/`: Unprocessed Inbox, Dirty Notes, Modified Today.

## Resources Convention

`03 Resources/` holds **topic-based reference collections** — ongoing areas of interest where material is accumulating but hasn't committed to a project.

- **Structure:** One subfolder per topic (e.g. `03 Resources/AI Tooling/`, `03 Resources/Leadership/`)
- **Contents:** Collected articles, bookmarks, clippings, comparisons, pricing notes — reference material grouped by theme
- **Not for:** Active project files (`01 Projects/`), standalone deep-dive research (`04 Data/` as `type: reference`), or attachments for specific notes
- **Filing rule:** When classifying a captured note, if it is a clipping or thematic article and a matching topic folder already exists under `03 Resources/`, file it there instead of as a `type: reference` note in `04 Data/`
- **Discovery:** Use `Resources.base` → "By Topic" view to browse by subfolder

## Required Obsidian Plugins

- **Bases** (core) — Frontmatter-driven database views
- **Templater** (community) — Template folder: `05 Meta/templates`
- **Update frontmatter modified date** (community) — Format: `YYYY-MM-DD HH:mm`, excludes `05 Meta`
- **Granola Sync** ([philfreo/obsidian-granola-plugin](https://github.com/philfreo/obsidian-granola-plugin)) — Syncs Granola meetings to `Granola/` staging folder. See [Granola Meeting Sync](#granola-meeting-sync).

## Permissions

Pre-allowed in `.claude/settings.json`: obsidian CLI, git add/commit/status/diff/log, vault scripts.
Denied: git push, git reset, rm -rf.

## Git Conventions

Commit prefix: `sb:`. Individual commits for user actions; batched for `/eod` and `/today`.
Note: The vault may not always have git initialized.

## Classification Pipeline

1. New captures arrive as `type: inbox`, `status: unprocessed`
2. `/eod` classifies them: reads content → assigns type + required fields → renames file
3. If confidence < 0.6 threshold → `status: needs_review` (stays as inbox type, appears in Needs Review base)
4. Classification logged to `05 Meta/logs/inbox-log.md`, rolled into daily digest by `/eod`

## GitHub Sync Architecture

`/today` runs a full GitHub sync cycle:
1. **Discovery** — `gh-onmyplate` scripts (`gh_notifications.sh`, `gh_involved.sh`, `gh_my_prs.sh`) find threads
2. **Dedup** — merge results by `owner/repo#number`
3. **Categorize** — Needs Response, My PRs, Review Requests, FYI
4. **Vault sync** — for each thread, check GitHub.base for existing note → create or update via `gh-fetch` + `obsidian` CLI
5. **Task creation** — actionable items (Needs Response, Review Requests) get `type: task` notes
6. **Auto-resolve** — previously-actionable tasks where the thread is now FYI → `status: done`
7. **Mark done** — all notifications marked done via `gh_mark_done.sh` with thread IDs

GitHub vault notes (`type: github`) have append-only Activity Summaries and a user-owned My Notes section that automation never touches.

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
   - **Match attendees by email**: `enabled` (links attendees to person notes with `emails` frontmatter)
   - **Include full transcript**: `enabled` (optional — set to preference)
   - **Skip existing notes**: `enabled`
4. **Configure your name** — Edit `05 Meta/config.yaml`:
   ```yaml
   granola:
     self_name: "Your Name"    # excluded from attendee counts for 1-on-1 detection
     staging_folder: "Granola"  # must match plugin folder path
     series_overrides: {}       # optional: "Meeting Title": "forced-meeting-name"
   ```
5. **Add email to person notes** — For attendee auto-linking to work, add `emails` to existing person notes:
   ```yaml
   emails:
     - alice@company.com
   ```
   The plugin matches attendee emails against this field and creates `[[wiki-links]]` automatically.

### How It Works

```
Granola app → plugin polls MCP API → Granola/ staging folder
                                          ↓
                              /eod Step 0.75 (or manual)
                              runs: granola-ingest
                                          ↓
                              For each staged note:
                                1. Parse frontmatter (granola_id, title, date, attendees)
                                2. Derive meeting_name from title (strip dates, kebab-case)
                                3. Check series_overrides in config
                                4. Detect 1-on-1 (1 attendee excluding self → is_1on1: true)
                                5. Dedup by granola_id (skip if already in vault)
                                6. Create meeting note in 04 Data/YYYY/MM/
                                7. Create person stubs for unknown attendees
                                8. Update last_touched for known attendees
                                9. Rewrite ## Attendees with [[wiki-links]]
                               10. Delete staging file
                                          ↓
                              /eod Steps 3+5 handle summary + daily note
```

### Manual Run

```bash
".claude/scripts/granola-ingest"            # process staged notes
".claude/scripts/granola-ingest" --dry-run  # preview without writing
```

### Meeting Name Derivation

The `meeting_name` field (used for grouping recurring meetings) is derived by:
1. Checking `granola.series_overrides` in config for an exact title match
2. Stripping trailing date patterns (`- March 22`, `(2026-03-22)`), ordinals (`5th`), numbers (`#5`, `v3.2`)
3. Kebab-casing the remainder (`Weekly Team Standup` → `weekly-team-standup`)

For meetings that normalize incorrectly, add an override:
```yaml
granola:
  series_overrides:
    "Client ABC / Sprint Review": "client-abc-sprint-review"
```

### Meeting Note Layout

Granola-sourced meetings follow the standard `type: meeting` schema with extras:
- `source: granola` and `granola_id` in frontmatter (for dedup and filtering)
- `## Log` contains the user's private notes from Granola
- `> [!note]- Granola AI Summary` — collapsed callout with AI-generated content
- `> [!note]- Transcript` — collapsed callout with full transcript (if enabled)
- `/eod` Step 3 generates `## Summary` from the Log content, same as manual meetings

## GitLab Sync Architecture

For GitLab instances, use the `gl-onmyplate` skill (`.claude/skills/gl-onmyplate/`). It mirrors the `gh-onmyplate` workflow but targets a self-hosted GitLab via `glab` CLI.

- **Discovery** — `gl_notifications.sh` (todos), `gl_involved.sh` (open MRs/issues), `gl_my_mrs.sh` (authored MRs)
- **Thread context** — `gl_thread_context.sh <url>` fetches the relevant tail of any MR or issue
- **Mark done** — `gl_mark_done.sh TODO_ID PROJECT TYPE TITLE URL`
- **Host config** — auto-detects the authenticated self-hosted instance from the glab config file; override with `GL_HOST` in `scripts/config.sh`

GitLab todos are not stored as vault notes by default — use `gl-onmyplate` for triage and briefing during `/today` or on demand.

## Slack Activity & Time Estimates

Tracks personal Slack activity (messages sent, reactions placed) for a given day, groups by channel, clusters into sessions, and estimates time spent. Designed for Harvest time entry.

Full documentation: `05 Meta/claude/slack-activity.claude.md`

### Data Sources (graceful degradation)

| Source | Requires | Messages | Reactions | DM Names | Speed |
|--------|----------|----------|-----------|----------|-------|
| Direct API | `SLACK_USER_TOKEN` env | Yes (100/page) | Yes | Yes | Fast (1-2 calls) |
| MCP fallback | Slack MCP plugin | Yes (20/page) | No | Yes | Slower (3+ calls) |

### Setup

One-time Slack app creation for Direct API mode:
1. api.slack.com/apps → Create New App → From Scratch
2. OAuth scopes: `search:read`, `reactions:read`, `users:read`
3. Install to workspace → copy `xoxp-...` token
4. `export SLACK_USER_TOKEN="xoxp-..."` in `~/.zshrc`

Without the token, `/slack:my-activity` and `/eod` Step 5.5 fall back to the Slack MCP plugin automatically.

### Session Configuration

All parameters are tunable in `05 Meta/config.yaml`:

```yaml
slack:
  activity:
    session_gap_minutes: 15       # gap to split sessions
    single_msg_minutes: 10        # lone authored message duration
    reaction_msg_minutes: 5       # lone reaction-only duration
    session_buffer_minutes: 5     # buffer on each end of multi-message sessions
    round_to_minutes: 15          # Harvest-friendly rounding
    timezone_offset_hours: -7     # PDT
```

CLI flags `--session-gap` and `--single-msg-time` override for a single run.

### EOD Integration

`/eod` Step 5.5 appends Slack activity to the daily note with channel summaries and a collapsible time estimate table:

```markdown
### Slack Activity
- **#channel-1** — topic summary
- **#channel-2** — topic summary

> [!note]- Time Estimates (N channels, Xh Ym)
> | Channel | Sessions | Time |
> |---------|----------|------|
> | #channel-1 | 2 — 09:24 (1msg), 13:18-13:30 (4msg) | 45m |
> | **Total** | | **Xh Ym** |
```

### Limitations

- **Huddles**: Not accessible via Slack API. No endpoint exposes huddle participation or duration. Use Granola for meeting capture if running during huddles.
- **Read-only channels**: Only channels where you posted or reacted are tracked. Passive reading is invisible to the API.
- **MCP mode**: No reactions data, slower pagination, but works without any setup.

## Notion Task Tracking

Tracks tasks assigned to the user, pages where the user is mentioned, and items the user is waiting on from others. All Notion access goes through the **Notion MCP** (`mcp__claude_ai_Notion__notion-*` tools) — there is no CLI equivalent.

Two surfaces:

- `/notion-import <url>` — Import or update a single Notion page as a `type: notion` note in the vault (see `05 Meta/claude/notion.claude.md`).
- `notion-onmyplate` skill — Triages three buckets: *assigned to me*, *mentioned / follow-ups*, *waiting on others*. Invoked when the user asks "what's on my Notion plate?" or similar.

### Configuration (`05 Meta/config.yaml`)

```yaml
notion:
  self_name: "Your Name"       # used to match Notion user on mentions/assignees
  task_databases:              # Notion database IDs that contain your tasks
    - "abc123..."
  mention_lookback_days: 7
  follow_up_wait_days: 3       # items waiting on others for N+ days are flagged
```

To find a database ID: open the database in Notion → share → copy link → the 32-char hex string in the URL is the ID.

### Vault Storage

Each imported Notion page becomes a `type: notion` note in `04 Data/YYYY/MM/` with the alias `notion-<slug>`. Notes have three sections: static title/info line, user-owned `## My Notes`, and append-only `## Activity Summaries`. See `05 Meta/claude/notion.claude.md` for full schema.

## Google Workspace

Triages inbox and calendar, and ingests Gemini-generated team meeting minutes into `type: meeting, source: gemini` vault notes. All Google access goes through the **Google Workspace MCPs** (`mcp__claude_ai_Gmail__*`, `mcp__claude_ai_Google_Calendar__*`, `mcp__claude_ai_Google_Drive__*`) — there is no CLI equivalent. **Read-only** for Calendar — this integration never creates, updates, or deletes events.

Three surfaces:

- `gmail-onmyplate` skill — Triages inbox into three buckets: *needs your reply*, *your open threads (awaiting response)*, *FYI (counts per label)*. Invoked on "what's on my gmail plate?", "what's in my inbox?", etc.
- `gcal-agenda` skill — Lists today + upcoming calendar events with attendees, Meet links, and linked Gemini-notes docs. Cross-references `02 Areas/Meetings.base` to flag events that already have a vault note.
- `/gemini-import <url-or-thread>` — Ingest a Gemini-generated meeting-minutes Google Doc as a `type: meeting, source: gemini` note. Accepts a Google Doc URL, Doc ID, Gmail thread URL, or bare Gmail thread ID. Re-imports overwrite the Gemini-owned sections but never touch `## Summary` or user-added content.

Automatic sweep: `/eod` Step 0.8 searches Gmail for new Gemini distribution emails since the last sweep and ingests them via the `/gemini-import` flow. The last-sweep timestamp lives at `05 Meta/logs/gemini-sweep.json`.

### Configuration (`05 Meta/config.yaml`)

```yaml
google:
  self_name: "Your Name"
  self_email: "you@company.com"
  gmail:
    denylist_labels: [CATEGORY_PROMOTIONS, CATEGORY_SOCIAL, CATEGORY_UPDATES, SPAM]
    vip_senders: []              # emails to always surface in Needs your reply
    lookback_days: 3
    follow_up_wait_days: 3       # stale outbound threads (Bucket 2) older than N days
  calendar:
    calendar_ids: [primary]      # add additional calendar IDs to include in agenda
    agenda_days_ahead: 2         # 0 = today only, 1 = today + tomorrow, etc.
  gemini:
    sender_patterns: ["meetings-noreply@google.com", "noreply@google.com"]
    subject_patterns: ["took notes", "Notes by Gemini"]
    series_overrides: {}         # map exact Gemini doc titles → kebab meeting_name
```

### Vault Storage

Gemini-sourced meetings become `type: meeting` notes in `04 Data/YYYY/MM/` with `source: gemini` and `gemini_doc_id` as the dedup key. They appear in `02 Areas/Meetings.base` alongside manual and Granola-sourced meetings (see the *Gemini* and *By Source* views). See `05 Meta/claude/meeting.claude.md` for the full schema and the source-specific layout rules.

Gmail and Calendar are **not persisted** to the vault — the skills are read-only triage surfaces.

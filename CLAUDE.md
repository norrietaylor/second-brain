---
modified: 2026-03-22T15:14:39-07:00
---
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

An Obsidian vault (`second-brain`) functioning as a personal knowledge management system. It is NOT a code repository — it contains markdown notes, Obsidian Bases views, shell scripts, and type schemas.

## Vault Structure

```
second-brain/
├── CLAUDE.md              ← this file
├── Index.md               ← landing page (Today's Note link, Projects embed)
├── 01 Projects/           ← Active Projects.base
├── 02 Areas/              ← Browsing views (Today, Tasks, People, Meetings, GitHub, Digests, etc.)
├── 03 Resources/          ← Attachments and embedded data
├── 04 Data/YYYY/MM/       ← ALL notes (single data lake)
│   └── YYYY.MM.DD-<name>.md
└── 05 Meta/               ← System files
    ├── bases/             ← Programmatic bases (Unprocessed Inbox, Dirty Notes, Modified Today)
    ├── claude/            ← Type schemas (<type>.claude.md)
    ├── config.yaml        ← confidence_threshold: 0.6
    ├── context/           ← work-profile.md, current-priorities.md, tags.md
    ├── templates/         ← Templater templates
    ├── logs/inbox-log.md  ← Classification audit trail
    └── scripts/           ← sb-ingest, gh-fetch, sync-memory.sh, calculate_dates.py
```

## Architecture: Type Dispatch System

Every note has a `type` frontmatter field. To understand a note's schema, conventions, and required fields, read the corresponding file at `05 Meta/claude/<type>.claude.md`.

Available types: `person`, `project`, `task`, `idea`, `admin`, `reference`, `meeting`, `inbox`, `digest`, `dailynote`, `github`

All notes live in `04 Data/YYYY/MM/` regardless of type. The `02 Areas/*.base` files are Obsidian Bases views that query notes by frontmatter properties — they are live database views, not storage.

### Universal Frontmatter Fields (all note types)
- `type` — dispatches to schema
- `created` / `modified` — datetime strings (`YYYY-MM-DD HH:mm`)
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
obsidian vault=second-brain create path="..." content="..." silent
obsidian vault=second-brain search query="..." path="04 Data" format=json
obsidian vault=second-brain base:query path="02 Areas/Today.base" format=json
obsidian vault=second-brain base:query path="02 Areas/Tasks.base" view="ViewName" format=json
obsidian vault=second-brain property:set path="..." name=status value=done
obsidian vault=second-brain append path="..." content="..." silent
```

**NEVER pipe `obsidian` CLI output through `head`, `tail`, or `less`** — the CLI doesn't handle SIGPIPE and will hang. Use `| cat | head -20` as a workaround, or use filtered views/format=json and process in full.

## Available Commands

Slash commands are defined in `.claude/commands/<name>.md`:

| Command | Purpose | Weight |
|---------|---------|--------|
| `/today` | Morning briefing + daily note + GitHub sync | Heavy (queries 3+ bases, runs GitHub discovery, marks notifications) |
| `/eod` | End-of-day processing (inbox, dirty detection, meeting summaries, digest enrichment) | Heavy |
| `/meeting` | Create meeting note from natural language | Light |
| `/learned` | End-of-session context capture | Light |
| `/gh-import` | Import or update a single GitHub issue/PR | Medium |
| `/generate-digests` | Backfill missing digests for date range | Heavy |

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `05 Meta/scripts/gh-fetch` | Fetch GitHub issue/PR data as JSON | `gh-fetch <url> [--since <ISO-date>]` |
| `05 Meta/scripts/sb-ingest` | Import files from `~/second-brain-inbox/` drop folder | `sb-ingest [--dry-run]` |
| `05 Meta/scripts/calculate_dates.py` | Date utility (runs on session start via hook) | Auto-invoked |
| `05 Meta/scripts/sync-memory.sh` | Sync Claude memory files | Manual |

## Bases Views (02 Areas/)

These are the primary query surfaces. Use `base:query` to read them:

| Base | Key Views | What It Shows |
|------|-----------|---------------|
| Today.base | (default) | Overdue tasks, due today, active projects, needs review |
| Tasks.base | (default) | All open tasks sorted by due date |
| People.base | With Follow-ups | People with pending follow-ups |
| GitHub.base | (default) | All tracked GitHub issues/PRs |
| Digests.base | Recent, All | Weekly/monthly digest notes |
| Meetings.base | All, Today | Meeting notes |

System bases in `05 Meta/bases/`: Unprocessed Inbox, Dirty Notes, Modified Today.

## Required Obsidian Plugins

- **Bases** (core) — Frontmatter-driven database views
- **Templater** (community) — Template folder: `05 Meta/templates`
- **Update frontmatter modified date** (community) — Format: `YYYY-MM-DD HH:mm`, excludes `05 Meta`

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

# Second Brain — Vault Operations Guide

> This file contains the operational context for AI agents running vault commands
> (/today, /eod, /meeting, /learned, etc.). It is NOT auto-loaded — commands
> explicitly read this file when they need operational context.
>
> If you are editing this file, you are developing the system. See the root
> CLAUDE.md and `.cursor/rules/development-mode.md` for development guidance.

## Architecture: Virtual Folders

All data notes live in a single date-organized data lake: `04 Data/YYYY/MM/`.
There are **no physical category folders**. Categories exist only as frontmatter `type` fields,
surfaced through Obsidian Bases views in `01 Projects/` and `02 Areas/`.

Reclassifying a note = changing one frontmatter field. No file moves needed.

## Vault Structure

```
{{VAULT_NAME}}/
├── CLAUDE.md                  # This file — global conventions, vault map, type dispatch
├── Index.md                   # Landing page — links to all projects, areas, and key views
├── .obsidian/                 # Obsidian config (plugins, Bases enabled, modified-date plugin)
├── .cursor/                   # Cursor config (commands, skills, hooks)
│   ├── commands/today.md      # /today morning briefing + daily note creation
│   ├── commands/eod.md        # /eod end-of-day processing command
│   ├── commands/meeting.md    # /meeting create meeting notes from natural language
│   ├── commands/learned.md    # /learned end-of-session context capture
│   ├── commands/gh-import.md  # /gh-import import/update GitHub issues and PRs
│   └── skills/
│       ├── classify/          # Classification skill
│       └── obsidian-cli/      # Obsidian CLI reference (v1.12+)
│
├── 01 Projects/               # Bases views for active project tracking
│   └── Active Projects.base   # type: project AND status: active
│
├── 02 Areas/                  # Bases views for browsing (UI)
│   ├── Today.base             # Due today + overdue + needs review + today's meetings
│   ├── Tasks.base             # All open tasks
│   ├── People.base            # All people notes
│   ├── Ideas.base             # All ideas
│   ├── Admin.base             # All admin/reference notes
│   ├── Meetings.base          # All meeting notes (sub-views: All, Today)
│   ├── Needs Review.base      # Items flagged by bouncer
│   ├── All Notes.base         # Safety net — every note in 04 Data/
│   ├── Digests.base           # Weekly/monthly digests
│   └── GitHub.base            # Tracked GitHub issues and PRs (sub-views: All, Open)
│
├── 03 Resources/              # Attachments, images, embedded data
│
├── 04 Data/                   # ALL data notes — the single data lake (includes digests)
│   └── YYYY/MM/               # Date-organized: 04 Data/2026/02/
│       ├── YYYY.MM.DD-<name>.md
│       ├── YYYY.MM.DD-daily-note.md     # daily note (created by /today, enriched by /eod)
│       └── YYYY.MM.DD-<type>-digest.md  # weekly/monthly digests
│
└── 05 Meta/                   # System files
    ├── bases/                 # Programmatic bases (used by commands, not for UI browsing)
    │   ├── Unprocessed Inbox.base  # Inbox items not yet classified (used by /eod)
    │   └── Dirty Notes.base       # Notes edited since last classification (used by /eod)
    ├── claude/                # Type-specific schema files
    │   └── <type>.claude.md   # Schema and conventions per note type
    ├── config.yaml            # System configuration (confidence threshold, etc.)
    ├── context/               # Personal context library (who you are, loaded on demand)
    │   ├── work-profile.md    # Index — name, role, see-also links
    │   ├── current-priorities.md  # Top 3 focus areas
    │   └── tags.md            # Tag taxonomy for classification
    ├── templates/             # Templater note templates per type
    ├── logs/                  # Audit trail
    │   └── inbox-log.md       # Classification log (working buffer, rolled into daily note by /eod)
    └── scripts/               # Automation scripts
        ├── sb                 # Quick capture CLI
        ├── sb-fix             # Reclassify needs-review items
        ├── sb-ingest          # Import markdown files from ~/{{VAULT_NAME}}-inbox/ drop folder
        ├── gh-fetch           # Fetch GitHub issue/PR data as JSON (used by /gh-import and /today)
        ├── vault-cleanup      # Find and remove erroneous root-level files
        └── templater/         # Templater user scripts
            └── previousMeeting.js  # Finds previous meeting summary for templates
```

## Type Dispatch

When working with a note, read its `type` frontmatter field, then load the matching schema:

```
05 Meta/claude/<type>.claude.md
```

Available types: `person`, `project`, `task`, `idea`, `admin`, `reference`, `meeting`, `inbox`, `digest`, `dailynote`, `github`

The schema file defines required fields, optional fields, and conventions for that type.

## File Naming

All data notes follow this pattern:

```
04 Data/YYYY/MM/YYYY.MM.DD-<kebab-case-name>.md
```

Examples: `2026.02.12-sarah-chen.md` (person), `2026.02.12-inbox-091500.md` (inbox, renamed on classification), `2026.02.12-windows-platform.md` (meeting), `2026.02.12-1on1-sarah-chen.md` (1-on-1 meeting), `2026.02.12-daily-note.md` (daily note), `2026.02.12-gh-kibana-12345.md` (github issue/PR)

### Alias Convention

Every data note includes a frontmatter `aliases` field with the name without the date prefix:

```yaml
aliases: [sarah-chen]
```

### Linking Convention

When linking to vault notes, ALWAYS use the full filename with display text:

```
[[YYYY.MM.DD-name|display-text]]
```

Examples:
- `[[2026.02.13-sarah-chen|sarah-chen]]`
- `[[2026.02.18-gh-skills-8|gh-skills-8]]`
- `[[2026.02.16-weekly-digest|2026-W07-weekly-digest]]`

NEVER use alias-only links like `[[sarah-chen]]` or `[[gh-skills-8]]`. Obsidian does not
reliably resolve these and will create empty files at the vault root when clicked.

When building links, use the filename from Bases query results (the `file` field) to construct
the full `[[filename|display]]` format.

## Universal Frontmatter Fields

Every data note includes:
- `type` — Primary organizational axis (person, project, task, idea, admin, reference, meeting, inbox, digest, dailynote, github)
- `created` — Creation datetime in `YYYY-MM-DD HH:mm` format
- `modified` — Auto-updated by the Update Modified Date plugin on edit in Obsidian
- `aliases` — Reference name(s) without date prefix
- `tags` — Cross-cutting concerns that span types
- `classified_at` — Datetime of last classification/reclassification (system-managed, `YYYY-MM-DD HH:mm`)
- `confidence` — Classification confidence score 0.0-1.0 (system-managed)

## External Inbox

Agents working in other projects can write session logs and captures to `~/{{VAULT_NAME}}-inbox/`
(configurable via `SECOND_BRAIN_INBOX` env var). Files should be markdown with optional frontmatter.

The `sb-ingest` script moves these files into `04 Data/YYYY/MM/` as unprocessed inbox items.
It runs automatically at the start of `/today` and `/eod`, or can be run manually.

A `session-log` skill (`~/.claude/skills/session-log/SKILL.md`) is available across
all projects to create properly formatted session log files in the drop folder.

## Configuration

System config in `05 Meta/config.yaml` — currently: `classification.confidence_threshold: 0.6`.

## Dirty Detection

`05 Meta/bases/Dirty Notes.base` surfaces notes where `modified > classified_at`. `/eod` re-checks each; agrees → updates `classified_at`, disagrees → flags in daily note (no auto-changes).

## Personal Context

`05 Meta/context/` — load on demand, never all at once. Contains `work-profile.md`, `current-priorities.md`, `tags.md`. Grows via `/learned`.

## Obsidian Integration

### Obsidian CLI (v1.12+)

Obsidian CLI is **required** for all vault operations. See `.claude/skills/obsidian-cli/SKILL.md` for full reference, gotchas, and examples.

Key pattern: `obsidian vault={{VAULT_NAME}} <command> [key=value...] [flags]`

### Plugins

- **Bases** (core plugin) — Database-like views driven by frontmatter properties
- **Templater** (community, SilentVoid) — Note templates with dynamic `undefined` fields. Template folder: `05 Meta/templates`. User scripts: `.claude/scripts/templater`
- **Update frontmatter modified date** (community, Alan Grainger) — Auto-updates `modified` field. Format: `YYYY-MM-DD HH:mm`, exclude: `05 Meta`

## Available Commands

- `/today` — Morning briefing + daily note creation + GitHub sync. See `.claude/commands/today.md`
- `/eod` — End-of-day processing (inbox, dirty detection, meeting summaries, daily note enrichment). See `.claude/commands/eod.md`
- `/meeting` — Create meeting notes from natural language. See `.claude/commands/meeting.md`
- `/learned` — Session context capture. See `.claude/commands/learned.md`
- `/gh-import` — Import or update a GitHub issue/PR. See `.claude/commands/gh-import.md`
- `sb fix` — Reclassify needs-review items. Requires `obsidian` + `jq`. See `.claude/scripts/sb-fix`
- `sb-ingest` — Import markdown files from `~/{{VAULT_NAME}}-inbox/` drop folder. See `.claude/scripts/sb-ingest`
- `vault-cleanup` — Find and remove erroneous root-level vault files. See `.claude/scripts/vault-cleanup`

## Skills

- `classify` — Classifies thoughts into note types. See `.claude/skills/classify/SKILL.md`
- `obsidian-cli` — Obsidian CLI reference, syntax, gotchas. See `.claude/skills/obsidian-cli/SKILL.md`

## Confidence Threshold

Threshold in `05 Meta/config.yaml` (default 0.6). Below threshold routes to `type: inbox, status: needs_review`. See classify skill for details.

## Git Conventions

Prefix: `sb:`. Individual commits for user actions (capture, fix); batched for `/eod` and `/today` fallback. See command files for format.

# 02-spec-granola-meeting-sync

## Introduction/Overview

Automated pipeline that transforms raw Granola meeting notes (synced by the philfreo/obsidian-granola-plugin) into proper second-brain `type: meeting` notes with full frontmatter, person linking, recurring series detection, and daily note integration. The plugin handles API communication; this spec covers everything downstream — the staging template, the ingest script, person stub creation, and /eod integration.

## Goals

1. Every Granola meeting automatically becomes a properly-typed meeting note in `04 Data/YYYY/MM/` with correct frontmatter schema
2. Attendees are linked to existing person notes (or new stubs are created) — building the relationship graph passively
3. Recurring meetings share a canonical `meeting_name` derived from the calendar event title
4. 1-on-1 meetings are auto-detected and tagged appropriately
5. `/eod` processes Granola notes transparently alongside manually-created meetings — same summary generation, same daily note format

## User Stories

- As a user, I want meetings from Granola to appear in my vault as proper meeting notes so I don't have to manually create them after every call
- As a user, I want attendees automatically linked to person notes so the relationship graph grows without manual effort
- As a user, I want recurring meetings grouped by series name so I can trace decisions across instances
- As a user, I want `/eod` to summarize Granola meetings and include them in my daily note just like manual meetings
- As a user, I want Granola's AI-enhanced notes and transcript preserved but non-intrusive, so my meeting notes stay clean

## Demoable Units of Work

### Unit 1: Granola Plugin Template and Config

**Purpose:** Configure the philfreo/obsidian-granola-plugin to write structured intermediate notes to a `Granola/` staging folder, and add required config entries.

**Functional Requirements:**
- The system shall provide a Granola template at `05 Meta/templates/Granola.md` using the plugin's `{{variable}}` and `{{#variable}}...{{/variable}}` syntax
- The template shall output frontmatter with: `granola_id`, `title`, `date`, `granola_url`, `start_time`, `created`, and `source: granola`
- The template shall output attendees as a YAML list using `{{granola_attendees_linked_list}}` (wiki-linked, leveraging the plugin's email matching)
- The template body shall include: `## Attendees` (linked list), `## Log` (private notes in a callout), enhanced notes in a collapsed callout `> [!note]- Granola AI Summary`, and optionally `## Transcript` in a collapsed callout `> [!note]- Transcript`
- The system shall add a `granola` section to `05 Meta/config.yaml` with: `self_name` (user's name to exclude from attendee lists), `staging_folder` (default: `Granola`), and `series_overrides` (manual title→meeting_name mappings for edge cases)

**Proof Artifacts:**
- File: `05 Meta/templates/Granola.md` exists with all required template variables
- File: `05 Meta/config.yaml` contains `granola` section with `self_name`, `staging_folder`, and `series_overrides` fields

### Unit 2: Granola Ingest Script

**Purpose:** Transform staged Granola notes into second-brain meeting notes with proper schema, file naming, and location.

**Functional Requirements:**
- The system shall provide a script at `.claude/scripts/granola-ingest` that processes all `.md` files in the staging folder
- The script shall accept `--dry-run` to preview transformations without writing
- For each staged note, the script shall:
  - Parse frontmatter to extract `granola_id`, `title`, `date`, `start_time`, attendees list, and `granola_url`
  - Derive `meeting_name` from the title: strip trailing dates, numbers, and separators (` - March 22`, ` #5`, ` (2026-03-22)`), then kebab-case the remainder. Check `series_overrides` in config first.
  - Detect 1-on-1: if attendee count (excluding `self_name` from config) equals 1, set `is_1on1: true`, `meeting_name: 1on1-<person-kebab>`, and `tags: [1on1]`
  - Check for existing vault note with the same `granola_id` — if found, skip (idempotent)
  - Generate target filename: `YYYY.MM.DD-<meeting_name>.md` (with collision avoidance suffix if needed)
  - Create the note in `04 Data/YYYY/MM/` via `obsidian` CLI with full second-brain frontmatter:
    - `type: meeting`, `meeting_name`, `date`, `attendees` (list of names), `is_1on1`, `granola_id`, `granola_url`, `source: granola`
    - `aliases`, `created`, `modified`, `classified_at`, `confidence: 1.0`
  - Preserve the body sections from the template (Attendees with wiki-links, Log, callouts)
  - Delete the staging file after successful creation
- The script shall output a summary: `Ingested N meeting(s): meeting-name-1, meeting-name-2`
- The script shall be idempotent — running twice on the same staging folder produces no duplicate notes

**Proof Artifacts:**
- CLI: `granola-ingest --dry-run` with a test file in `Granola/` outputs the planned transformation without writing
- CLI: `granola-ingest` processes a staged note and creates a properly-formatted meeting note in `04 Data/YYYY/MM/`
- CLI: Running `granola-ingest` again on an empty staging folder exits cleanly with no output

### Unit 3: Person Stub Creation

**Purpose:** Automatically create person note stubs for meeting attendees who don't have existing vault notes.

**Functional Requirements:**
- During ingest, for each attendee name in the meeting note:
  - Search the vault for an existing person note where `name` matches (case-insensitive) or `aliases` contains the kebab-case version
  - If no match found, create a minimal person stub at `04 Data/YYYY/MM/YYYY.MM.DD-<person-kebab>.md` with:
    - `type: person`, `name: <Full Name>`, `context: "Met in <meeting_name> meeting"`, `last_touched: <meeting date>`
    - `aliases: [<person-kebab>]`, `created`, `modified`, `classified_at`, `confidence: 0.8`
    - Body: `## Notes\n\nAuto-created from Granola meeting [[YYYY.MM.DD-meeting-name|meeting-name]]`
  - If match found, update `last_touched` to the meeting date (if newer)
- The system shall update the meeting note's `## Attendees` section with wiki-links to the actual person note filenames (whether existing or newly created)
- The system shall report person stubs created: `Created N person stub(s): name-1, name-2`

**Proof Artifacts:**
- File: After ingesting a meeting with an unknown attendee, a person stub exists in `04 Data/YYYY/MM/` with correct frontmatter
- File: The meeting note's `## Attendees` section contains wiki-links in `[[YYYY.MM.DD-person|Name]]` format
- CLI: After ingesting a meeting with a known attendee, the person note's `last_touched` is updated

### Unit 4: EOD Integration

**Purpose:** Wire the ingest script into `/eod` and ensure Granola-sourced meetings appear in the daily note digest.

**Functional Requirements:**
- The system shall add Step 0.75 to `/eod` (after Step 0.5 sb-ingest, before Step 1 inbox processing):
  ```
  ".claude/scripts/granola-ingest"
  ```
- Step 0.75 output (ingested count, person stubs) shall be captured in `commit_details`
- The system shall add `granola_ingest_count` to the Step 0 tracking variables
- Step 3 (Meeting Summary Generation) already processes all today's meetings — Granola-sourced meetings will be picked up automatically since they have `type: meeting` and appear in `Meetings.base` Today view. No changes needed to Step 3.
- Step 5 (Enrich Daily Note) `### Meetings` section already reads from today's meetings. Granola-sourced meetings will appear with the same format. No changes needed to Step 5.
- Step 10 commit summary shall include Granola ingest count if > 0: append `, G granola meetings ingested`

**Proof Artifacts:**
- File: `/eod` command file contains Step 0.75 calling `granola-ingest`
- File: Step 0 tracking variables include `granola_ingest_count`
- File: Step 10 commit template includes Granola count conditional

## Non-Goals (Out of Scope)

- Forking or modifying the philfreo/obsidian-granola-plugin source code
- Real-time webhook or filesystem-watch integration (polling is sufficient)
- Syncing Granola folders or tags (not available via MCP API)
- Mobile support
- Modifying how the plugin authenticates with Granola (OAuth is handled by the plugin)
- Changing the existing meeting template used for manually-created meetings
- Automatic action item extraction from transcripts (let /eod Step 3 handle summarization)

## Design Considerations

- The Granola template (`05 Meta/templates/Granola.md`) is NOT a Templater template — it uses the plugin's own `{{variable}}` syntax and lives alongside Templater templates without conflict
- Collapsible callouts (`> [!note]- Title`) keep Granola AI content and transcripts available but collapsed by default, preserving the clean meeting note layout
- The `## Log` section receives the user's private notes from Granola — these are the user's own typed notes during the meeting, which is the closest analogue to the freeform Log section in manual meetings
- The `source: granola` frontmatter field distinguishes auto-ingested meetings from manual ones, useful for future filtering

## Repository Standards

- Script naming: `granola-ingest` (no extension, executable, in `.claude/scripts/`)
- Script style: bash, `set -euo pipefail`, uses `obsidian` CLI for all vault operations
- Config: YAML in `05 Meta/config.yaml`
- Git commit prefix: `sb:`
- File naming: `YYYY.MM.DD-<kebab-case-name>.md` in `04 Data/YYYY/MM/`
- Wiki-links: always `[[YYYY.MM.DD-name|display-text]]`, never alias-only

## Technical Considerations

- The ingest script must handle the case where the plugin hasn't synced yet (empty staging folder = no-op)
- Calendar event title normalization: strip common suffixes (dates, ordinals, parenthetical dates) before kebab-casing. The `series_overrides` map in config handles edge cases where normalization isn't sufficient.
- The `obsidian search` command is used for person matching and granola_id dedup — results are JSON-parsed
- Collision avoidance: if `YYYY.MM.DD-meeting-name.md` exists and has a different `granola_id`, append `-2`, `-3`, etc.
- The plugin's `{{granola_attendees_linked_list}}` already produces wiki-links for matched people — the ingest script should preserve these and only create stubs for unmatched names (those without `[[...]]` wrapping)

## Security Considerations

- No API keys or tokens are managed by this pipeline — the plugin handles OAuth internally
- The staging folder contains meeting content that may include sensitive discussion — ensure it's within the vault (not a shared location)
- Person stubs auto-created with `confidence: 0.8` (not 1.0) to signal they weren't manually verified

## Success Metrics

- 100% of Granola meetings appear as properly-typed notes in the vault within one /eod cycle
- Zero duplicate notes when running ingest multiple times (idempotent)
- Attendee person notes accumulate over time, building the relationship graph passively
- Recurring meetings are correctly grouped by `meeting_name` across instances
- `/eod` daily note shows Granola meetings indistinguishably from manual meetings

## Open Questions

- No open questions at this time.

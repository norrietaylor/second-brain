# 02-spec-raindrop-integration

## Introduction/Overview

Integrate Raindrop.io bookmarks into the second brain vault via the make-it-rain Obsidian plugin. Bookmarks saved throughout the day flow into the vault as inbox items, get surfaced during `/today` and `/eod` for triage, and can be promoted to typed notes (reference, idea, project) through the existing classification pipeline. This closes the gap where bookmarks accumulate in Raindrop without entering the knowledge system.

## Goals

1. Install and configure make-it-rain to write Raindrop bookmarks into the vault with second-brain-compatible frontmatter
2. Surface new Raindrop imports during `/today` (morning catch-up) and `/eod` (triage)
3. Reuse the existing inbox/classification pipeline — no new triage UI, just new input source
4. Keep lifecycle simple for phase 1: items are either promoted (reclassified) or left for next triage
5. Support filtering by collection and tag so the user controls what enters the vault

## User Stories

- As a user, I want bookmarks I save to Raindrop during the day to appear in my vault so I can process them alongside other inbox items
- As a user, I want my morning briefing to show how many new Raindrop items arrived overnight so I know what's waiting
- As a user, I want `/eod` to surface unprocessed Raindrop items for triage so nothing falls through the cracks
- As a user, I want to configure which Raindrop collections sync to the vault so I control the firehose

## Demoable Units of Work

### Unit 1: Plugin Installation and Template Configuration

**Purpose:** Install the make-it-rain plugin and configure it to produce vault-compatible markdown files with correct frontmatter.

**Functional Requirements:**
- The system shall install the make-it-rain plugin via BRAT (plugin is not yet in the official Obsidian community registry)
- The system shall configure a custom Handlebars template that produces frontmatter compatible with the second brain type system:
  ```yaml
  type: inbox
  status: unprocessed
  source: raindrop
  raindrop_id: {{id}}
  raindrop_type: {{renderedType}}
  url: {{url}}
  created: "{{formattedCreatedDate}}"
  modified: "{{formattedUpdatedDate}}"
  aliases: [{{kebab-title}}]
  tags: [{{formattedTags}}]
  ```
- The system shall configure the output folder to `04 Data/YYYY/MM/` following vault file naming conventions (`YYYY.MM.DD-rd-<kebab-title>.md`)
- The system shall document the Raindrop API token setup process (user generates a test token at raindrop.io/app#/settings/integrations)
- The system shall configure collection and/or tag filters per user preference (if any)

**Proof Artifacts:**
- File: `04 Data/2026/03/2026.03.22-rd-*.md` contains vault-compatible frontmatter with `type: inbox` and `source: raindrop`
- CLI: `obsidian vault=second-brain search query="source: raindrop" path="04 Data" format=json` returns imported items

### Unit 2: Raindrop Inbox Base View

**Purpose:** Create a Bases view that surfaces unprocessed Raindrop imports for triage.

**Functional Requirements:**
- The system shall create `05 Meta/bases/Raindrop Inbox.base` that filters for `type: inbox` AND `source: raindrop` AND `status: unprocessed`
- The base view shall display: file name, raindrop_type, url, tags, created date
- The base view shall sort by created date descending (newest first)

**Proof Artifacts:**
- CLI: `obsidian vault=second-brain base:query path="05 Meta/bases/Raindrop Inbox.base" format=json` returns only unprocessed Raindrop items
- File: `05 Meta/bases/Raindrop Inbox.base` exists with correct filter configuration

### Unit 3: /today and /eod Integration

**Purpose:** Wire Raindrop imports into the existing daily workflow so they're surfaced automatically.

**Functional Requirements:**
- `/today` shall query `Raindrop Inbox.base` and include a count in the morning briefing: "N Raindrop items waiting for triage"
- `/today` shall trigger a make-it-rain sync (via Obsidian command) before querying, to catch overnight saves
- `/eod` shall query `Raindrop Inbox.base` and list unprocessed items in the daily note's `## Day Summary` under a new `### Raindrop Inbox` subsection
- The `### Raindrop Inbox` subsection shall show each item as: `- [title](url) — raindrop_type, tags` (omit subsection if 0 items)
- `/eod` Step 1 (Process Inbox) shall include Raindrop items in its normal inbox processing — they already have `type: inbox, status: unprocessed` and will be classified through the standard pipeline
- Items classified by `/eod` shall have `source: raindrop` preserved in frontmatter (additive migration — never remove fields)

**Proof Artifacts:**
- CLI: `/today` briefing output includes "N Raindrop items waiting for triage" line
- File: Daily note contains `### Raindrop Inbox` subsection with item listings after `/eod` runs
- CLI: After `/eod`, `obsidian vault=second-brain search query="source: raindrop" path="04 Data" format=json` shows items with types other than `inbox` (promoted items)

## Non-Goals (Out of Scope)

- **Bidirectional sync** — No writing back to Raindrop from the vault (roadmap item for make-it-rain)
- **Content scraping** — No fetching full page content from bookmarked URLs (roadmap item for make-it-rain)
- **Knowledge graph** — Future phase; this spec only handles ingestion and triage
- **Auto-classification** — Raindrop items go through normal inbox classification, no special routing by collection/tag
- **Snooze/defer** — No snooze mechanism for items; they stay as inbox until promoted or stay for next triage
- **Raindrop deletion after import** — Items remain in Raindrop after vault import

## Design Considerations

No specific design requirements identified. The Bases view and daily note subsection follow existing vault conventions.

## Repository Standards

- File naming: `YYYY.MM.DD-rd-<kebab-title>.md` (the `rd-` prefix distinguishes Raindrop imports from other inbox items)
- Frontmatter: follows universal fields + inbox schema from `05 Meta/claude/inbox.claude.md`
- Git: changes committed with `sb:` prefix
- Commands: modifications to `/today` and `/eod` follow existing step structure

## Technical Considerations

- **make-it-rain is not in the official plugin registry** — Must be installed via BRAT or manual download. This adds a setup step but is straightforward.
- **Sync trigger:** make-it-rain syncs on-demand via Obsidian command palette (`Fetch Raindrops`). The `/today` and `/eod` commands can trigger this via `obsidian vault=second-brain command id="make-it-rain:fetch-raindrops"` (exact command ID to be verified after installation).
- **Rate limiting:** make-it-rain handles its own rate limiting (120 req/min). No vault-side throttling needed.
- **Duplicate detection:** make-it-rain tracks imported items by Raindrop ID. Re-running fetch should not create duplicates if the plugin's update detection is enabled.
- **Output folder:** make-it-rain supports configurable output folders. Need to verify if it supports date-based subfolders (`YYYY/MM/`) or if items land in a flat folder requiring a move step.
- **Template limitations:** If make-it-rain's template system can't produce the exact vault-compatible filename format, a post-processing rename step may be needed (handled by `sb-ingest` or a new script).

## Security Considerations

- **Raindrop API token** — Stored in Obsidian plugin settings (local, not committed to git). The `.obsidian/` directory is already gitignored.
- **No vault credentials exposed** — make-it-rain runs locally within Obsidian, no external API calls from the vault system itself.

## Success Metrics

- 100% of Raindrop bookmarks from configured collections appear as vault inbox items within one sync cycle
- `/eod` surfaces all unprocessed Raindrop items for triage (zero items silently lost)
- Promoted items retain `source: raindrop` for provenance tracking
- Setup process documented enough for a fresh install in under 10 minutes

## Open Questions

1. **Output folder format:** Does make-it-rain support date-based subfolder output (`04 Data/YYYY/MM/`)? If not, should items land in a staging folder and get moved by `sb-ingest`?
2. **Command ID:** What is the exact Obsidian command ID for triggering a make-it-rain sync programmatically? (Verify after installation with `obsidian vault=second-brain commands filter=make-it-rain`)
3. **Filename template:** Can make-it-rain produce filenames in `YYYY.MM.DD-rd-<kebab-title>.md` format, or will post-processing be needed?
4. **Collection selection:** Which Raindrop collections should sync? All, or a specific subset? (User to decide during setup)

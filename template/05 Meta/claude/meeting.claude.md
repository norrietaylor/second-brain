# Type: Meeting

Notes for specific meetings — attendees, agenda, discussion log, action items, and AI-generated summaries.
For non-actionable reference material without a specific meeting event, use `type: admin` instead.

## Required Fields
- `meeting_name` — Canonical kebab-case identifier for this meeting series (e.g., `windows-platform`, `api-review`). Used to link recurring meetings together.
- `date` — Meeting date (YYYY-MM-DD)
- `attendees` — List of attendee names

## Optional Fields
- `is_1on1` — Boolean, true for one-on-one meetings (default: false)
- `summary` — One-line AI-generated summary (populated post-meeting by `/eod` or on request)
- `tags` — Relevant topic tags
- `source` — Origin of the meeting note. Set to `granola` for notes ingested from Granola, or `gemini` for notes ingested from Gemini-generated Google Docs. Absent for manually-created notes.

### Granola-sourced fields (when `source: granola`)
- `granola_id` — Granola meeting ID (dedup key across ingests)
- `granola_url` — Canonical Granola app URL

### Gemini-sourced fields (when `source: gemini`)
- `gemini_doc_id` — Google Doc file ID (dedup key across re-imports)
- `gemini_doc_url` — Canonical Google Doc URL (`webViewLink`)
- `gemini_thread_id` — Gmail thread ID if the ingest originated from the distribution email (optional)
- `gemini_last_synced` — ISO timestamp of the last `/gemini-import` run for this note

## Universal Fields (always present)
- `type: meeting`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- File naming: `YYYY.MM.DD-<meeting-name>.md` for regular meetings, `YYYY.MM.DD-1on1-<person>.md` for 1-on-1s
- The `meeting_name` field is the canonical key for linking recurring meetings. All instances of the same recurring meeting share the same `meeting_name`.
- For 1-on-1s, `meeting_name` follows the pattern `1on1-<person-kebab>` (e.g., `1on1-sarah-chen`)
- 1-on-1 meeting notes should include `tags: [1on1]` and `is_1on1: true`
- The body has these standard sections in order:
  - `## Attendees` — Bullet list of attendees
  - `## Previous Meeting Summary` — Callout with the previous meeting's summary (injected at creation time)
  - `## Agenda` — Pre-meeting agenda items
  - `## Log` — Freeform notes taken during the meeting
  - `## Action Items` — Concrete next steps with owners
  - `## Summary` — AI-generated summary (added post-meeting by `/eod` or on request)
- The `summary` frontmatter field is a short one-liner; the `## Summary` body section contains the full summary
- After a meeting, `/eod` reads `## Log` and `## Action Items` to generate the summary
- If something becomes a standalone task, create a separate task note and link to it

## Source-Specific Layout

### `source: granola`
- `## Log` contains the user's private notes from Granola
- `> [!note]- Granola AI Summary` — collapsed callout with Granola's AI-generated content
- `> [!note]- Transcript` — collapsed callout with full transcript (if enabled in plugin)
- Dedup: `granola_id`
- Ingested via: `.claude/scripts/granola-ingest` (invoked by `/eod` Step 0.75 or manually)

### `source: gemini`
- `## Log` contains the Notes / Discussion body from the Gemini doc
- `## Action Items` populated from the doc's Action items section (owners resolved to `@firstname` when possible)
- `> [!note]- Gemini Meeting Summary` — collapsed callout with Gemini's summary paragraph
- `> [!note]- Transcript (collapsed)` — collapsed callout with transcript, if present in the doc
- Dedup: `gemini_doc_id`
- Ingested via: `/gemini-import` (on-demand) and `/eod` Step 0.8 (Gmail sweep for new Gemini distribution emails)
- Re-imports overwrite `## Log`, `## Action Items`, and the Gemini Summary / Transcript callouts (Gemini docs are authoritative on the source side) but never touch `## Summary` (owned by `/eod`) or any user-added section.

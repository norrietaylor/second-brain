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

# Type: Daily Note

The persistent workspace for a single day. Created by /today, one per calendar day.
Daily notes are NOT classified — they are system-generated containers.

## Required Fields
- date: The calendar date (YYYY-MM-DD)

## Optional Fields
- None — daily notes are structural, not content-typed

## Universal Fields (standard)
- type: "dailynote"
- created, modified, aliases, tags

## System-Managed Fields
- classified_at: Not applicable — daily notes are not classified
- confidence: Not applicable — daily notes are not classified

## Conventions
- Filename: YYYY.MM.DD-daily-note.md
- Alias: YYYY-MM-DD-daily-note
- Tag: dailynote
- One per calendar day — /today creates if missing, never duplicates
- Body structure: Notes, Meetings (inline base), Created Today (inline base),
  GitHub (briefing), Briefing (appended by /today), Day Summary (appended by /eod),
  Classification Log (appended by /eod), Modified Today (inline base), Slack (optional)
- Navigation links: <- Yesterday | Today | Tomorrow ->
- Daily notes are append-only during the day; /eod enriches them at end of day

# T02: Granola Ingest Script — Proof Summary

**Task:** T02 — Granola Ingest Script
**Spec:** 02-spec-granola-meeting-sync / unit-2-ingest-script.feature
**Executed:** 2026-03-23
**Model:** sonnet

## Implementation

Created `.claude/scripts/granola-ingest` — a bash script that:

- Uses `set -euo pipefail` and follows the same style as `sb-ingest`
- Reads `05 Meta/config.yaml` for `self_name`, `staging_folder`, and `series_overrides`
- Parses frontmatter from staged Granola `.md` files (granola_id, title, date, start_time, granola_url, attendees)
- Derives `meeting_name` via: series_overrides lookup → 1-on-1 detection → title normalization
- Title normalization strips trailing dates (`- March 22`, `(2026-03-22)`), issue numbers (`#5`), version suffixes (`v3.2`)
- 1-on-1 detection: if exactly one non-self attendee, sets `is_1on1: true`, `meeting_name: 1on1-<person-kebab>`, `tags: [1on1]`
- Dedup via `obsidian search` for `granola_id` — skips if already in vault
- Generates target path `04 Data/YYYY/MM/YYYY.MM.DD-<meeting_name>.md` with collision-avoidance suffix (`-2`, `-3`)
- Creates note via `obsidian` CLI with full second-brain meeting frontmatter
- Preserves body sections from the staged note (Attendees, Log, AI Summary callout, Transcript callout)
- Deletes staging file after successful creation
- Outputs: `Ingested N meeting(s): name1, name2`
- `--dry-run` flag previews without writing or deleting
- Empty staging folder is a no-op (exit 0, no output)

## Proof Artifacts

| File | Type | Status |
|------|------|--------|
| T02-01-cli.txt | cli — dry-run with 2 test files | PASS |
| T02-02-file.txt | file — existence, executable, strict mode, title normalization | PASS |
| T02-03-cli.txt | cli — empty staging folder no-op | PASS |

## Test Scenarios Verified

- `--dry-run` shows planned target path `04 Data/2026/03/2026.03.22-weekly-sync.md`
- `--dry-run` shows derived `meeting_name: weekly-sync` for "Weekly Sync - March 22"
- `--dry-run` shows `is_1on1: true` and `meeting_name: 1on1-alice-smith` for 2-person meeting
- No files created during dry-run; staged files remain
- Title normalization: all 5 Gherkin examples pass
- Empty staging folder: exit 0, no output
- Script is executable with `set -euo pipefail` at line 21

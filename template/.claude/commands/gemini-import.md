# /gemini-import — Ingest a Gemini Meeting Minutes Doc

Import a Gemini-generated team meeting-minutes Google Doc into the vault as a `type: meeting` note with `source: gemini`. Accepts either the Google Doc URL, a Gmail thread URL/ID containing the distribution email, or a bare Doc ID.

## Prerequisites

- Google Workspace MCP connectors enabled in claude.ai (`mcp__claude_ai_Gmail__*`, `mcp__claude_ai_Google_Drive__*`)
- Obsidian running (for CLI operations)
- Read `05 Meta/claude/vault-operations.md` for vault structure and conventions
- Read `05 Meta/claude/meeting.claude.md` for the meeting-note schema (the `source: gemini` variant)
- Read `05 Meta/config.yaml` for `google.gemini.series_overrides` and `google.self_name` / `self_email`

## When to Use

Run this command when the user provides a link to (or ID of) a Gemini meeting note:

- "Import https://docs.google.com/document/d/abc123.../edit"
- "Ingest the Gemini notes from the team sync email I just got"
- "/gemini-import <gmail-thread-url>"
- A bare Google Doc ID pasted into the terminal

## Steps

### Step 1: Parse Input

The input may be one of:

- **Google Doc URL** — `https://docs.google.com/document/d/<DOC_ID>/edit...`
- **Bare Doc ID** — a 44-character alphanumeric file ID
- **Gmail thread URL** — `https://mail.google.com/mail/u/0/#inbox/<THREAD_ID>` (or a `label/.../<THREAD_ID>` variant)
- **Gmail thread ID** — bare 16-hex-char thread ID

Extract one of:

- `DOC_ID` — if a Doc URL or Doc ID was given
- `THREAD_ID` — if a Gmail reference was given

If a Gmail reference was given, resolve to a `DOC_ID` by fetching the thread:

```
mcp__claude_ai_Gmail__get_thread with thread_id=<THREAD_ID>
```

Scan the latest message body for a Google Doc URL matching `docs.google.com/document/d/<id>`. Take the first match. If none found, report that this thread does not contain a Gemini notes doc link and stop.

Store `GMAIL_THREAD_ID` if applicable (used later for the `gemini_thread_id` frontmatter field).

### Step 2: Search Vault for Existing Note

Check if this doc has already been imported:

**Primary — Meetings.base query:**
```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Meetings.base" format=json
```

Parse the JSON output. Look for an entry where `gemini_doc_id` matches `DOC_ID`.

**Fallback — Frontmatter search:**
```bash
obsidian vault={{VAULT_NAME}} search query="gemini_doc_id: DOC_ID" format=json
```

If a match is found, the note **exists** — proceed to Step 5 (Update). If no match, proceed to Step 3 (Create).

### Step 3: Fetch the Doc

Read metadata first to get title + modified time:

```
mcp__claude_ai_Google_Drive__get_file_metadata with file_id=<DOC_ID>
```

Extract:
- `DOC_TITLE` — the doc title (Gemini uses patterns like "Team Weekly Sync - 2026/04/22" or "Standup — Apr 22")
- `MODIFIED_TIME` — ISO timestamp
- `CREATED_TIME` — ISO timestamp
- `DOC_URL` — `webViewLink` (the canonical URL)

Then read content:

```
mcp__claude_ai_Google_Drive__read_file_content with file_id=<DOC_ID>
```

If the content is returned as HTML or Google Docs JSON, convert to Markdown. If the MCP exposes a markdown export (some Drive MCPs expose `export_format=text/markdown`), prefer that. Store the body as `DOC_BODY`.

Scan `DOC_BODY` for the standard Gemini sections (Gemini notes docs have a consistent skeleton):

- **Attendees** / **Participants** — a list of names (sometimes with emails in parens)
- **Summary** / **Meeting Summary** — a short AI-generated summary paragraph
- **Notes** / **Discussion** — bulleted notes
- **Action items** / **Next steps** — owner/task pairs
- **Transcript** — optional, verbatim transcript (keep collapsed in a callout)

### Step 4: Derive Meeting Metadata

#### 4a: Meeting date

Use the earliest of:
1. A date present in the doc title (Gemini frequently includes `YYYY-MM-DD` or `Mon DD` — parse and resolve)
2. `CREATED_TIME` of the doc (converted to local date)

Set `MEETING_DATE = YYYY-MM-DD`.

#### 4b: Meeting name

Derive `MEETING_NAME` (kebab-case identifier, stable across recurring instances):

1. Check `google.gemini.series_overrides` in config for an exact match on `DOC_TITLE` — if found, use the override value as-is.
2. Otherwise, from `DOC_TITLE`:
   - Strip trailing date patterns (e.g. `- 2026-04-22`, `(Apr 22)`, `— April 22, 2026`)
   - Strip ordinals / instance numbers (`5th`, `#5`, `v3`)
   - Kebab-case the remainder (lowercase, non-alphanumerics → hyphens, collapse repeats, trim)

Example: `"Team Weekly Sync - 2026/04/22"` → `team-weekly-sync`.

#### 4c: Attendees

For each name in the Attendees section:

1. If an email is present, look up matching person notes in `02 Areas/People.base` by `emails` frontmatter field.
2. If no email, match by display name against person notes' aliases.
3. If matched → create `[[YYYY.MM.DD-person|@firstname]]` wiki-link using the person's filename.
4. If unmatched → record as a plain `@firstname` token (Step 3 of `/eod` or future person-stub creation handles stubs; this command does NOT auto-create person stubs — keep the scope tight).

Compute `IS_1ON1`: true iff exactly 1 attendee remains after excluding the user (`google.self_name` / `google.self_email`).

#### 4d: Filename

```
FILENAME = YYYY.MM.DD-<MEETING_NAME>.md     (regular)
FILENAME = YYYY.MM.DD-1on1-<person-kebab>.md (if IS_1ON1 and a single peer)
FILE_PATH = 04 Data/YYYY/MM/FILENAME
```

`YYYY.MM.DD` is the meeting date (not import date), matching existing meeting-note convention.

If a file with this path already exists but has no `gemini_doc_id` frontmatter, append a `-2` suffix to the filename (the existing file is a manual note for the same meeting; keep both and let the user reconcile).

### Step 5: Create the Note

Build the note:

```markdown
---
type: meeting
source: gemini
meeting_name: "MEETING_NAME"
date: "MEETING_DATE"
attendees: [ATTENDEE_WIKI_LINKS]
is_1on1: IS_1ON1
gemini_doc_id: "DOC_ID"
gemini_doc_url: "DOC_URL"
gemini_thread_id: "GMAIL_THREAD_ID_OR_EMPTY"
gemini_last_synced: "NOW_ISO"
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
aliases: [MEETING_NAME]
tags: [gemini]
classified_at: "YYYY-MM-DD HH:mm"
confidence: 1.0
---
# DOC_TITLE

[Gemini notes doc](DOC_URL) | MEETING_DATE | N attendees

## Attendees

ATTENDEE_BULLETS

## Log

DOC_BODY (Notes / Discussion section — keep as-is, preserve structure)

## Action Items

ACTION_ITEMS (from the doc's "Action items" section — one bullet per item; include owner as @name if resolvable)

> [!note]- Gemini Meeting Summary
> GEMINI_SUMMARY_PARAGRAPH

> [!note]- Transcript (collapsed)
> TRANSCRIPT_IF_PRESENT

## Summary

<!-- Populated by /eod Step 3 from ## Log + ## Action Items -->
```

Notes on body construction:
- If any of Attendees / Notes / Action items / Summary / Transcript sections are missing from the doc, omit that section rather than leaving an empty stub.
- For 1-on-1s, add `tags: [1on1]` and `is_1on1: true` per the meeting schema convention.
- Leave `## Summary` empty — `/eod` fills it in later.

Create the file:

```bash
obsidian vault={{VAULT_NAME}} create path="FILE_PATH" content="FULL_CONTENT" silent
```

Verify:

```bash
obsidian vault={{VAULT_NAME}} read file="MEETING_NAME"
```

### Step 6: Confirm + Commit

Report:

```
Imported: [[FILENAME|MEETING_NAME]] — "DOC_TITLE"
  Date: MEETING_DATE | Attendees: N | 1on1: IS_1ON1
  Doc: DOC_URL
```

Commit (if vault is git-backed):

```bash
git add "04 Data/YYYY/MM/FILENAME"
git commit -m "sb: import gemini-meeting ${MEETING_NAME} ${MEETING_DATE}"
```

### Step 7: Update Existing Note

Reached when Step 2 found an existing note.

#### 7a: Read stored metadata

```bash
obsidian vault={{VAULT_NAME}} read file="MEETING_NAME"
```

Extract `gemini_last_synced` and compare against the fresh `MODIFIED_TIME` from Step 3. If the doc has not changed since last sync, report "No changes on MEETING_NAME since last sync" and stop.

#### 7b: Regenerate body sections

Re-derive `## Log`, `## Action Items`, and the Gemini summary callout from the current doc. These sections are authoritative on the Gemini side — overwrite, don't append (this is different from the Notion / GitHub update pattern because Gemini docs are effectively immutable meeting minutes; updates reflect corrections, not new activity).

Do NOT touch `## Summary` (owned by `/eod`) or any section the user has manually added.

#### 7c: Update properties

```bash
obsidian vault={{VAULT_NAME}} property:set file="MEETING_NAME" property=gemini_last_synced value="NOW_ISO"
```

#### 7d: Commit

```bash
git add "04 Data/YYYY/MM/FILENAME"
git commit -m "sb: update gemini-meeting ${MEETING_NAME} ${MEETING_DATE}"
```

## Batch Mode

If the caller provides a list of inputs (e.g. invoked by `/eod` Step 0.8 with N thread IDs), process sequentially. Report a final tally:

```
Imported N Gemini meetings:
- [[...]] — title
- [[...]] — title (update)
```

## Error Handling

- **No doc URL found in Gmail thread** — report the thread ID and stop; do not create a note.
- **Drive MCP 403/404** — doc is private, deleted, or outside the MCP's scope. Report the URL and skip.
- **Title parsing fails** — fall back to `MEETING_NAME = "untitled-meeting"` and warn the user. The user can rename later.
- **Obsidian CLI failure** — check Obsidian is running, report the error, do not commit.
- Strip the Obsidian CLI loading line (matches `^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} Loading`) from all CLI output before parsing.

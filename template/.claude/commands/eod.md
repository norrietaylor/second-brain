# /eod — End of Day Processing

Run the end-of-day processing routine for the second brain vault. This command handles all heavy work: inbox processing, dirty detection, meeting summaries, log rolling, and enriching the daily note with digest content.

## When to Use

Run this command when you're wrapping up for the day. Timing is flexible — 5 PM, 9 PM, 2 AM, whenever you're done working. The daily note gets enriched with digest content covering whatever happened that calendar day.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## Important: Bash Command Style

**NEVER prefix Bash tool commands with `# comment` lines.** Comment-prefixed commands don't match permission patterns and trigger approval prompts. Use the Bash tool's `description` parameter for context instead.

**NEVER pipe `obsidian` CLI output directly through `head`, `tail`, `less`, or any truncating command.** The obsidian CLI does not handle SIGPIPE and will hang indefinitely. Use `| cat | head -20` as a workaround.

## Architecture

`/eod` uses a batch scan → LLM process → batch write pattern:

1. **Scan** (`sb-eod-scan`) — gathers ALL data in one parallel pass and returns a single JSON blob. No per-item obsidian reads during processing.
2. **Process** (Claude) — classifies inbox items, checks dirty notes, summarizes meetings, generates Day Summary — all from pre-loaded data.
3. **Write** (`sb-eod-write`) — applies ALL vault mutations in one batch call. No per-item obsidian writes.

This eliminates 20-30 sequential tool calls and completes in < 3 minutes on normal days.

## Steps

### Step 0.5: Ingest External Inbox

Import any files from the external drop folder before processing:

```bash
".claude/scripts/sb-ingest"
```

This picks up session logs and other captures written by agents in other projects. Files are moved into `04 Data/YYYY/MM/` as unprocessed inbox items that Step 1 will classify. If the drop folder is empty or doesn't exist, this is a no-op.

### Step 0.75: Ingest Granola Meetings

Process any staged Granola meeting notes and transform them into vault meeting notes:

```bash
".claude/scripts/granola-ingest"
```

This script reads Granola markdown files from the staging folder (configured in `05 Meta/config.yaml`), derives meeting metadata, creates properly-typed `type: meeting` notes in `04 Data/YYYY/MM/`, and deletes the staging files on success. The created meeting notes will be processed by Step 3 (Meeting Summary Generation) automatically.

Capture the script's output (number of meetings ingested) and store as `granola_ingest_count` for the commit message.

If the staging folder is empty or doesn't exist, this is a no-op.

### Step 0: Gather All Data

Run the vault scan script to gather everything needed in one pass:

```bash
".claude/scripts/sb-eod-scan" 2>/dev/null > /tmp/eod-scan.json
```

The output file `/tmp/eod-scan.json` is the source of truth for all processing. Use `jq < /tmp/eod-scan.json` to extract fields. **Do NOT use `echo "$SCAN" | jq`** — on macOS, `echo` interprets `\n` in JSON strings and produces invalid JSON. Always pipe via `cat /tmp/eod-scan.json | jq` or `jq < /tmp/eod-scan.json`.

**Output:** JSON object with keys:
- `date` — today, year, month, dot_date, now_dt, is_after_midnight, is_sunday, is_last_day_of_month, is_last_day_of_year, day_of_week
- `daily_note` — path, exists, content, has_day_summary
- `yesterday_note` — path, exists, content, open_threads_section
- `inbox_items` — array of `{ path, filename, content }`
- `dirty_notes` — array of `{ path, filename, type, classified_at, content }`
- `meetings_today` — array of `{ path, filename, title, content, has_summary, has_log }`
- `inbox_log` — entries, has_entries
- `raindrop_inbox_count` — N
- `config` — confidence_threshold, slack_denylist

Read the scan data using `jq < /tmp/eod-scan.json` for any field extraction. **Do not make additional obsidian read calls for Steps 1–5.**

### Step 1: Process Inbox

For each item in `SCAN.inbox_items`:

1. Read the `content` field (already loaded — no obsidian read needed)
2. Apply classification using the classify skill logic (type, confidence, required frontmatter)
3. If confidence ≥ `SCAN.config.confidence_threshold` → file as classified type
4. If confidence < threshold → keep as `type: inbox`, set `status: needs_review`
5. Build the new note content with full frontmatter + original content
6. Compute the new path: `04 Data/YYYY/MM/YYYY.MM.DD-<kebab-name>.md`
7. Build a log entry: `filed "name" → type (X.XX) [initial]`

Collect all items into `classified_items` array for the write payload:
```json
{
  "old_path": "04 Data/.../inbox-xxx.md",
  "new_path": "04 Data/YYYY/MM/YYYY.MM.DD-name.md",
  "content": "---\ntype: meeting\n...\n\n[original content]",
  "log_entry": "filed \"name\" → meeting (0.92) [initial]"
}
```

Track `inbox_count` (total items processed).

If `SCAN.inbox_items` is empty, skip this step.

### Step 2: Dirty Detection

For each item in `SCAN.dirty_notes`:

1. Read the `content` field (already loaded — no obsidian read needed)
2. Re-run classification analysis (type + confidence only — do NOT create files)
3. If new classification **agrees** with current `type`:
   - Add to `dirty_updates`: `{ "path": "...", "classified_at": "NOW_DT" }`
   - Add to commit_details: `dirty check: name — agrees, updated classified_at`
4. If new classification **disagrees**:
   - Add to `type_mismatches`: `{ name, current_type, suggested_type }`
   - Add to commit_details: `dirty check: name — DISAGREES (current vs suggested), flagged`
   - Do NOT add to dirty_updates (no automated type change)

Track `dirty_count`.

If `SCAN.dirty_notes` is empty, skip this step.

### Step 3: Meeting Summary Generation

For each item in `SCAN.meetings_today`:

1. Read the `content` field (already loaded — no obsidian read needed)
2. If `has_summary` is true: skip this meeting
3. If `has_log` is false: skip (no content to summarize)
4. If `has_log` is true and `has_summary` is false:
   - Generate a concise summary from Log and Action Items (2-4 sentences: key decisions, outcomes, next steps)
   - Generate a one-liner for the `summary` frontmatter property
   - Build `summary_section`:
     ```markdown

     ## Summary
     [2-4 sentence summary]
     ```
   - Add to `meeting_summaries`:
     ```json
     { "path": "...", "summary_property": "one-liner", "summary_section": "..." }
     ```
   - Add to commit_details: `summarized meeting: name`

Track `meeting_summary_count`.

If `SCAN.meetings_today` is empty, skip this step.

### Step 4: Roll Inbox Log

From `SCAN.inbox_log`:

1. If `has_entries` is true:
   - Save entries for the `## Classification Log` section in Step 5
   - Set `inbox_log_clear: true` in the write payload
   - Add to commit_details: `rolled inbox-log → daily note`
2. If `has_entries` is false: set `inbox_log_clear: false`

### Step 5: Enrich Daily Note with Content-Aware Digest

Using data from SCAN (no additional reads needed).

**5a. Compute today's note inventory:**

From `SCAN.daily_note.content`, `SCAN.meetings_today`, and the `classified_items` built in Step 1, you have a complete picture of today's activity. Group by type:
- **Meetings:** from `SCAN.meetings_today` (content already loaded)
- **Classified notes:** from `classified_items` (content in payload)
- **Existing daily note content:** from `SCAN.daily_note.content`

**5b. Generate structured Day Summary:**

Build `daily_note_content` — a string starting with `---\n## Day Summary\n` to be appended to (or used to replace the existing `## Day Summary` section in) the daily note.

**Linking rule:** All wiki-links MUST use full filename format: `[[YYYY.MM.DD-name|display-text]]`. NEVER use alias-only links.

```markdown
---
## Day Summary

### Meetings
- **meeting-name** [[YYYY.MM.DD-meeting-name|notes]]
  - [key topic/decision]
  - [action item, if any]

### Notes Created
- **type** [[YYYY.MM.DD-name|display]] — one-line description

### GitHub Activity
- [activity from github-type notes today, if any]

### Raindrop Inbox
- [N bookmarks unprocessed — raindrop inbox count from SCAN.raindrop_inbox_count]

### Housekeeping
- N inbox items classified, M dirty checks (K mismatches)
- [type mismatch lines if any]

### Open Threads
- [carried forward from SCAN.yesterday_note.open_threads_section, filtered for resolved items]
- ⚠️ [item open 3+ work days]

### Tomorrow
- [3-5 actionable forward-looking bullets]
- [synthesized from meeting action items, open threads, upcoming tasks]

## Classification Log

[Paste inbox_log entries from SCAN.inbox_log.entries, or "No classifications today." if empty]
```

**Format rules:**
- Omit any section with zero items
- Keep total Day Summary under ~250 words
- Open Threads: carry forward items from `SCAN.yesterday_note.open_threads_section` that are NOT resolved in today's activity. Add `(day N)` counter, prefix `⚠️` if 3+ work days open
- Tomorrow: always generate (3-5 bullets). Synthesize what to *do* about open items — don't just copy Open Threads verbatim

**5c. Compute nav link:**

Build `nav_link_line` using dates from `SCAN.date`:
- Yesterday: use `SCAN.yesterday_note.path` (filename without path) → `[[YYYY.MM.DD-daily-note|Yesterday]]`
- Today: `SCAN.date.today` (bold)
- Tomorrow: compute `SCAN.date.today + 1 day` → `[[YYYY.MM.DD-daily-note|Tomorrow]]`

```
← [[YYYY.MM.DD-daily-note|Yesterday]] | **YYYY-MM-DD** | [[YYYY.MM.DD-daily-note|Tomorrow]] →
```

**5d. Process task completion from daily note:**

Read `SCAN.daily_note.content` and scan two sections for checked `[x]` items:

**Briefing section — regular tasks:**

In the `## Briefing` section, find any checked `[x]` items that contain a wiki-link (pattern `[[YYYY.MM.DD-name|...]]`). For each:
- Extract the note filename from the wiki-link: `YYYY.MM.DD-name`
- Derive the path: `04 Data/YYYY/MM/YYYY.MM.DD-name.md` (parse year/month from the filename date)
- Add to `task_done_items`: `{ "path": "04 Data/YYYY/MM/YYYY.MM.DD-name.md", "alias": "display-text" }`

Only process items with wiki-links (skip plain-text checkboxes with no note reference). Only process items that are actually checked (`[x]`), not open (`[ ]`).

**GitHub section — github task notes:**

Find the `## GitHub` section. For each checked `[x]` item in Needs Response or Review Requests:
- Extract the GitHub URL
- Add to `github_done_items`: `{ "github_url": "...", "key": "owner/repo#N" }`

Both lists are processed AFTER `sb-eod-write` runs (fast `obsidian property:set` calls — typically 1-5 items total).

### Step 5 Write: Apply All Mutations

Build the write payload from Steps 1-5:

```json
{
  "classified_items": [...],
  "dirty_updates": [...],
  "meeting_summaries": [...],
  "daily_note_content": "---\n## Day Summary\n...",
  "nav_link_line": "← [[...]] | **date** | [[...]] →",
  "inbox_log_clear": true,
  "daily_note_path": "SCAN.daily_note.path",
  "commit_message": "sb: /eod — processed N inbox, M dirty checks, S meeting summaries, enriched daily note",
  "commit_details": ["filed ...", "dirty check: ...", ...]
}
```

Run the write script:

```bash
WRITE_RESULT=$(echo "$WRITE_PAYLOAD" | ".claude/scripts/sb-eod-write")
```

The script handles: note creation, inbox deletion, dirty updates, meeting properties, meeting sections, inbox log clear, daily note nav link, daily note Day Summary, and git commit — all in one batch.

**After write completes:**

If `task_done_items` is non-empty, mark each as done:
```bash
obsidian vault={{VAULT_NAME}} property:set path="04 Data/YYYY/MM/YYYY.MM.DD-name.md" name=status value=done
```

If `github_done_items` is non-empty, mark corresponding task notes as done:
```bash
obsidian vault={{VAULT_NAME}} property:set path="TASK_NOTE_PATH" name=status value=done
```

Track `task_done_count` (sum of both lists) for the display output.

### Step 5.5: Slack Activity Summary

**5.5a. MCP Detection:**

Attempt a lightweight Slack MCP call to detect availability:
```
slack_read_user_profile(user_id: "me")
```

If the call fails, skip the entire Step 5.5 (graceful skip — no error).

**5.5b. Channel Discovery:**

Use two complementary search strategies. Filter against `SCAN.config.slack_denylist`.

```
slack_search_public_and_private(query: "from:<@USER_ID> after:YESTERDAY_DATE")
slack_search_channels(query: "active recent")
```

**5.5c. Channel Summarization:**

For each non-denied channel, process sequentially:
1. Read recent messages: `slack_read_channel(channel_id, limit: 50)`
2. Filter to today only. Skip if no messages today.
3. Read threads for threaded messages: `slack_read_thread(channel_id, thread_ts)`
4. Generate 3-5 bullet summary per channel

**5.5d. Personal Activity & Time Estimates:**

If `SLACK_USER_TOKEN` is set:
```bash
".claude/scripts/slack-my-activity" --json TODAY
```

Otherwise use MCP results with `--stdin` flag.

**5.5e. Daily Note Integration:**

Append `### Slack Activity` section with channel summaries and collapsible time estimate callout:

```bash
obsidian vault={{VAULT_NAME}} append path="DAILY_NOTE_PATH" content="..." silent
```

### Step 6: Generate Weekly Digest (Sundays only)

**Skip if `SCAN.date.is_sunday` is false.**

Query digest and daily notes bases:

```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Digests.base" format=json
obsidian vault={{VAULT_NAME}} search 'query="type: dailynote"' path="04 Data" format=json
```

Select daily notes for Mon–Sun of this week. Read each to extract `## Day Summary` sections. Generate and create the weekly digest file.

**File:** `04 Data/YEAR/MONTH/YYYY.MM.DD-weekly-digest.md`

**Frontmatter:**
```yaml
---
type: digest
digest_type: weekly
aliases: [YYYY-WNN-weekly-digest]
period_start: YYYY-MM-DD  # Monday
period_end: YYYY-MM-DD    # Sunday (today)
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags: [digest]
---
```

**Body sections:** Week Summary, Decisions Made, Work Completed, In Progress, Blocked, Thread Lifecycles, Intention vs. Outcome, Correction Analysis, Stale Items, Reflection Prompts.

Commit:
```bash
git add -A
git commit -m "sb: /eod — weekly digest YYYY-WNN"
```

### Step 7: Generate Monthly Digest (last day of month only)

**Skip if `SCAN.date.is_last_day_of_month` is false.**

Reuse digests query from Step 6 (or run it now if Step 6 was skipped). Select weekly digests with `period_start` within this month.

**File:** `04 Data/YEAR/MONTH/YYYY.MM.DD-monthly-digest.md`

**Frontmatter:**
```yaml
---
type: digest
digest_type: monthly
aliases: [YYYY-MM-monthly-digest]
period_start: YYYY-MM-01
period_end: YYYY-MM-DD
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags: [digest]
---
```

**Body sections:** Month Summary, Key Decisions, Major Completions, Persistent Threads, New Initiatives, Trends, Reflection Prompts.

Commit:
```bash
git add -A
git commit -m "sb: /eod — monthly digest YYYY-MM"
```

### Step 7b: Generate Yearly Digest (December 31 only)

**Skip if `SCAN.date.is_last_day_of_year` is false.**

Select monthly digests for this year. Generate yearly digest file at `04 Data/YYYY/12/YYYY.12.31-yearly-digest.md`.

Commit:
```bash
git add -A
git commit -m "sb: /eod — yearly digest YYYY"
```

### Step 9b: Vault Cleanup

```bash
".claude/scripts/vault-cleanup" --clean
```

Detects and deletes empty `.md` files at the vault root created by clicking broken wiki-links. Commits its own changes if any files are removed.

### Display Output

After all processing completes, display a brief summary to the terminal:

```
/eod complete — YYYY-MM-DD
- N inbox items classified
- M dirty checks (K mismatches)
- S meeting summaries generated
- T tasks marked done
[+ G granola meetings ingested]
[+ weekly digest generated]
[+ monthly digest generated]
[Type mismatches: name (current → suggested), ...]
```

Omit the "T tasks marked done" line if `task_done_count` is 0.

If nothing was processed: "Nothing to process today."

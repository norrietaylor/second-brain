# /eod — End of Day Processing

Run the end-of-day processing routine for the second brain vault. This command handles all heavy work: inbox processing, dirty detection, meeting summaries, log rolling, and enriching the daily note with digest content.

## When to Use

Run this command when you're wrapping up for the day. Timing is flexible — 5 PM, 9 PM, 2 AM, whenever you're done working. The daily note gets enriched with digest content covering whatever happened that calendar day.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## Steps

### Step 0: Determine Date Context

Determine the current time. **If the current time is before 3:00 AM, treat "today" as yesterday's date** — this handles the common case of running /eod after midnight while still wrapping up the previous day's work. Otherwise, use the current calendar date.

Set the following based on the effective date:
- `TODAY` — YYYY-MM-DD format (adjusted if before 3 AM)
- `YEAR` — YYYY
- `MONTH` — MM
- `DAY_OF_WEEK` — Is the effective date Sunday? (weekly digest trigger)
- `IS_LAST_DAY_OF_MONTH` — Is the effective date the last day of the month? (monthly digest trigger)
- `IS_LAST_DAY_OF_YEAR` — Is the effective date December 31? (yearly digest trigger)
- `DAILY_NOTE_PATH` — `04 Data/YEAR/MONTH/YYYY.MM.DD-daily-note.md`

If the date was adjusted, note it for the commit message: "(after-midnight adjustment: processing for YYYY-MM-DD)".

Initialize tracking variables for the commit message:
- `inbox_count` = 0
- `dirty_count` = 0
- `meeting_summary_count` = 0
- `github_done_count` = 0
- `slack_channel_count` = 0
- `granola_ingest_count` = 0
- `commit_details` = [] (list of action strings for the commit body)

Pre-read shared configuration once (reuse for all steps in this run):
- `05 Meta/config.yaml` — confidence threshold, slack denylist
- `05 Meta/context/tags.md` — tag taxonomy

### Step 0.5: Ingest External Inbox

Import any files from the external drop folder before processing:

```bash
"05 Meta/scripts/sb-ingest"
```

This picks up session logs and other captures written by agents in other projects. Files are moved into `04 Data/YYYY/MM/` as unprocessed inbox items that Step 1 will classify. If the drop folder is empty or doesn't exist, this is a no-op.

### Step 0.75: Ingest Granola Meetings

Process any staged Granola meeting notes and transform them into second-brain meeting notes:

```bash
"05 Meta/scripts/granola-ingest"
```

This script reads Granola markdown files from the staging folder (configured in `05 Meta/config.yaml`), derives meeting metadata, creates properly-typed `type: meeting` notes in `04 Data/YYYY/MM/`, and deletes the staging files on success. The created meeting notes will be processed by Step 3 (Meeting Summary Generation) and Step 5 (Enrich Daily Note) automatically.

Capture the script's output (number of meetings ingested) and:
- Increment `granola_ingest_count` by the number of meetings processed
- Add to `commit_details`: `granola: ingested N meetings` (or if N=0, add nothing)

If the staging folder is empty or doesn't exist, this is a no-op.

### Step 1: Process Inbox

Query the Unprocessed Inbox base for pending items:

```bash
obsidian vault=second-brain base:query path="05 Meta/bases/Unprocessed Inbox.base" format=json
```

For each item in the JSON results:
1. Read the note at the returned `path` to get full content and `original_text`
2. Read `.claude/skills/classify/SKILL.md` as your classification guide and apply it in batch mode — pass the pre-read config and tags, and skip per-item git commits (Step 8). `/eod` handles the batch commit in Step 9.
3. The classify skill handles: creating the new typed note, renaming/replacing the inbox file, logging `[initial]` to inbox-log.md
4. Increment `inbox_count`
5. Add to `commit_details`: `filed "note-name" → type (X.XX) [initial]`

If the query returns `[]`, skip this step.

### Step 2: Dirty Detection

Query the Dirty Notes base for notes edited since last classification:

```bash
obsidian vault=second-brain base:query path="05 Meta/bases/Dirty Notes.base" format=json
```

This returns only notes where `modified > classified_at`, excluding digests and notes without `classified_at`. No manual filtering needed.

For each item in the JSON results:
   a. Read the note's current content at the returned `path`
   b. Re-run classification analysis against the content (determine what type the system would assign now — use the classify skill's analysis logic only: Steps 1-3 for analyzing and assigning confidence, but do NOT create files, rename, or log)
   c. If the new classification **agrees** with the current `type`:
      - Silently update `classified_at` to the current datetime
      - Do NOT change any other fields
      - Increment `dirty_count`
      - Add to `commit_details`: `dirty check: note-name — agrees, updated classified_at`
   d. If the new classification **disagrees** with the current `type`:
      - Do NOT auto-change the type
      - Add to a `type_mismatches` list (note name, current type, suggested type) for the daily note
      - Increment `dirty_count`
      - Add to `commit_details`: `dirty check: note-name — DISAGREES (current vs suggested), flagged`

If the query returns `[]`, skip this step.

### Step 3: Meeting Summary Generation

Query today's meetings:

```bash
obsidian vault=second-brain base:query path="02 Areas/Meetings.base" view="Today" format=json
```

For each meeting note in the results:
1. Read the meeting note's full content via `obsidian read`
2. Check if it has content in `## Log` or `## Action Items` sections
3. Check if it already has a `## Summary` section — if so, skip this meeting
4. If it has Log/Action Items content but no Summary:
   a. Generate a concise summary from the Log and Action Items (2-4 sentences covering key decisions, outcomes, and next steps)
   b. Generate a one-liner version for the frontmatter `summary` property
   c. Append `## Summary` section to the meeting note body:
      ```markdown
      ## Summary
      [2-4 sentence summary of key decisions, outcomes, and next steps]
      ```
   d. Set the frontmatter `summary` property:
      ```bash
      obsidian vault=second-brain property:set name=summary value="<one-liner>" path="<meeting-path>"
      ```
   e. Increment `meeting_summary_count`
   f. Add to `commit_details`: `summarized meeting: <meeting-name>`
5. If the meeting note has no Log or Action Items content, skip it (meeting notes without content don't need summarizing)

If the query returns `[]` or no meetings need summarizing, skip this step.

### Step 4: Roll Inbox Log

1. Read `05 Meta/logs/inbox-log.md`
2. Check if it has entries beyond the header (header = first 2 lines: `# Inbox Log` + blockquote)
3. If entries exist:
   a. Save the entries for inclusion in the daily note's `## Classification Log` section (Step 5)
   b. Clear `inbox-log.md` back to header only:
      ```markdown
      # Inbox Log
      > Classification decisions are appended here automatically. Rolled into daily notes by /eod.
      ```
   c. Add to `commit_details`: `rolled inbox-log → daily note`
4. If no entries beyond header, skip.

### Step 5: Enrich Daily Note with Content-Aware Digest

Find today's daily note. If it doesn't exist yet, create it first:

```bash
obsidian vault=second-brain search query="YYYY.MM.DD-daily-note" path="04 Data" format=json
```

If not found, create it using the same structure as `/today` Step 0.

**5a. Gather all notes created today:**

Query for all notes created today (not just classification activity):

```bash
obsidian vault=second-brain search query="created: \"YYYY-MM-DD" path="04 Data" format=json
```

For each result, read the full note content. Group by type:
- **Meetings:** Extract key decisions, action items, discussion topics from `## Log` and `## Action Items`
- **Tasks:** What was created or completed
- **Ideas:** What was captured
- **People:** Interactions, follow-ups set
- **Admin:** Reference material added
- **Projects:** Status changes, milestones

**5b. Generate structured Day Summary:**

Read the current daily note content. Append the following digest sections to the daily note (after any existing content, but before any `/eod`-generated sections from a previous run). If any of these sections already exist (from a previous `/eod` run), replace them.

**Linking rule:** All wiki-links in the Day Summary MUST use the full filename format: `[[YYYY.MM.DD-name|display-text]]`. Look up filenames from the notes gathered in Step 5a. NEVER use alias-only links like `[[alias]]`.

**Sections to append/update:**

```markdown
---
## Day Summary

### Meetings
- **meeting-name** [[YYYY.MM.DD-meeting-name|notes]]
  - [key topic/decision from Log]
  - [key topic/decision from Log]
  - [action item or open question, if any]

### Notes Created
- **type** [[YYYY.MM.DD-name|display]] — one-line description
- **type** [[YYYY.MM.DD-name|display]] — one-line description

### GitHub Activity
- [PR/issue activity from any github-type notes created today]

### Raindrop Inbox
- [title](url) — raindrop_type, tags
- [title](url) — raindrop_type, tags

### Housekeeping
- N inbox items classified, M dirty checks (K mismatches)
- [If type_mismatches is non-empty:] Mismatch: **note-name** — current: _type_, suggested: _type_

### Open Threads
- [item] — status (day N)
- ⚠️ [item] — status (day N, reason)

### Tomorrow
- [synthesized intention based on today's meetings, open threads, and upcoming tasks]
- [follow-up or decision that needs attention]
- [preparation for tomorrow's meetings, if any]

## Classification Log

[Paste the inbox-log entries rolled in Step 4. If no entries, write "No classifications today."]
```

**Format rules:**
- Omit any section (### heading + its bullets) that has zero items — do not show empty sections
- **Meetings:** 2-5 sub-bullets per meeting, extracted from `## Log` and `## Action Items` sections
- **Notes Created:** one line per note, grouped by type
- **GitHub Activity:** only if github-type notes exist
- **Raindrop Inbox:** only if unprocessed Raindrop items exist. Query `05 Meta/bases/Raindrop Inbox.base` and list each item as `- [title](url) — raindrop_type, tags`. Items will be classified by Step 1 in the next `/eod` run.
- **Housekeeping:** always present (even if "0 inbox, 0 dirty")
- **Open Threads:** see Step 5c below
- **Tomorrow:** see Step 5d below — always present (3-5 actionable bullets)
- Keep total Day Summary under ~250 words

**5c. Open Threads carry-forward:**

After generating the main bullet sections above, populate the `### Open Threads` section:

1. Find the previous work day's daily note. Scan backward from yesterday (skip weekends/gaps) — reuse the same gap-aware logic from `/today` Step 1's backward scan.
2. Read its `### Open Threads` section (if it exists) plus any items listed under its `### In Progress` or `### Blocked` headings (from weekly digest carry-over) or items mentioned as in-progress/blocked in its meeting bullets.
3. For each carried-forward item, check if it appears as resolved/completed/merged in today's notes (from the data gathered in Step 5a).
4. Items that are NOT resolved carry forward into today's `### Open Threads`:
   - Include a day counter: `(day N)` where N is the number of work days since the item first appeared
   - Prefix with `⚠️` if the item has been open for 3+ work days
   - Include the blocking reason if known: `⚠️ [item] — blocked (day 4, waiting on X)`
5. If the previous day has no Day Summary or no Open Threads, skip this step gracefully — just omit the `### Open Threads` section.

**5d. Generate Tomorrow intentions:**

After Open Threads, generate the `### Tomorrow` section — 3-5 forward-looking, actionable bullets synthesized from today's content:

1. Draw from: meeting action items assigned to the user, open threads (especially ⚠️ items), upcoming due dates from task notes gathered in Step 5a, unresolved decisions
2. Each bullet should be actionable: "Follow up on X", "Decide Y", "Prep for Z meeting"
3. Prioritize: blocked items needing escalation > due dates > follow-ups > general continuations
4. This section is always generated — even if minimal, write "Continue with open threads" as a baseline
5. Do NOT just copy Open Threads verbatim — synthesize what the user should *do* about them

Update the daily note using `obsidian append` or by rewriting the content:

```bash
obsidian vault=second-brain append path="<DAILY_NOTE_PATH>" content="<digest sections>"
```

Add to `commit_details`: `enriched daily note with digest content`

**5e. Process GitHub Task Completion:**

After enriching the daily note, process checked-off GitHub items:

1. Read today's daily note and find the `## GitHub` section.
2. For each line in the "Needs Response" and "Review Requests" subsections:
   - Parse whether the checkbox is checked `[x]` or unchecked `[ ]`
   - Extract the GitHub URL from the markdown link `[...](URL)`
3. For each **checked** item:
   - Search for the task note with matching `github_url` and `status: pending`:
     ```bash
     obsidian vault=second-brain search query="github_url: GITHUB_URL" path="04 Data" format=json
     ```
   - Filter results for `type: task` with `status: pending`
   - Set `status: done` via:
     ```bash
     obsidian vault=second-brain property:set name=status value=done path="TASK_NOTE_PATH"
     ```
   - Increment `github_done_count`
   - Add to `commit_details`: `completed github task: gh-task-REPO-NUMBER`
4. For **unchecked** items: no action (task stays pending, resurfaces in next `/today` briefing as overdue).
5. If no `## GitHub` section exists or no items are checked, skip this step.

### Step 5.5: Slack Activity Summary

**5.5a. MCP Detection:**

Attempt a lightweight Slack MCP call to detect whether the Slack MCP server is configured and available:

```
slack_read_user_profile(user_id: "me")
```

If the call fails for any reason (server not configured, authentication error, network error), skip the entire Step 5.5:

- Log to `commit_details`: `slack: skipped (MCP not configured)`
- Continue to Step 6

No error should be raised — this is a graceful skip.

**5.5b. Channel Discovery:**

Use two complementary search strategies to find channels with relevant activity today. Compute `YESTERDAY_DATE` as `TODAY` minus one day (accounting for the after-midnight adjustment from Step 0 if applied).

1. Search for channels where the user posted:
   ```
   slack_search_public_and_private(query: "from:<@USER_ID> after:YESTERDAY_DATE")
   ```

2. Search for channels with recent activity using broad activity terms:
   ```
   slack_search_channels(query: "active recent")
   ```

Combine results from both searches and extract unique channel names/IDs. Deduplicate by channel ID.

Filter the discovered channels against the `slack.denylist` loaded in Step 0 — exclude any channel whose name or ID appears in the denylist.

Log to `commit_details`: `slack: discovered N channels, M denied, processing K`

**5.5c. Channel Summarization:**

For each non-denied channel, process sequentially (to avoid rate limiting):

1. Read recent messages from the channel:
   ```
   slack_read_channel(channel_id: CHANNEL_ID, limit: 50)
   ```

2. Filter to messages timestamped on `TODAY` only. If no messages today, skip this channel.

3. For any message that has threaded replies, read the full thread:
   ```
   slack_read_thread(channel_id: CHANNEL_ID, thread_ts: MESSAGE_TS)
   ```

4. Generate a 3–5 bullet summary for the channel covering:
   - Key topics discussed
   - Decisions made
   - Action items assigned
   - Notable announcements

Collect each channel summary as `{ channel_name, bullets }`.

**5.5d. Daily Note Integration:**

If no channels have activity today, omit the Slack section entirely and skip the rest of this step.

Otherwise, produce a `### Slack Activity` section formatted as:

```markdown
### Slack Activity
- **#channel-1** — [summary point], [summary point]
- **#channel-2** — [summary point], [summary point]
```

Insert this section into the Day Summary of the daily note:

- Insert between `### Meetings` and `### Notes Created`
- If `### Notes Created` does not exist, insert after `### Meetings`

Use `obsidian append` or rewrite the daily note content to include the section:

```bash
obsidian vault=second-brain append path="<DAILY_NOTE_PATH>" content="<slack activity section>"
```

Set `slack_channel_count` to the number of channels summarized.

Add to `commit_details`: `slack: summarized N channels (M denied)`

### Step 6: Generate Weekly Digest (Sundays only)

**Skip this step if today is not Sunday.**

Query the Digests base for existing digests. For daily notes, search by filename pattern since Daily Notes.base was removed. **Cache these results for reuse in Step 7.**

```bash
obsidian vault=second-brain base:query path="02 Areas/Digests.base" format=json
obsidian vault=second-brain search 'query="type: dailynote"' path="04 Data" format=json
```

From the Digests results, check for existing weekly/monthly digests. From the search results, select daily notes with dates falling within Monday–Sunday of this week. Read each daily note to extract their `## Day Summary` sections.

**File:** `04 Data/YYYY/MM/YYYY.MM.DD-weekly-digest.md`

**Frontmatter:**
```yaml
---
type: digest
digest_type: weekly
aliases: [YYYY-WNN-weekly-digest]
period_start: YYYY-MM-DD  # Monday of this week
period_end: YYYY-MM-DD    # Sunday (today)
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags: [digest]
---
```

**Body:**

```markdown
## Week Summary

Active across N/5 work days. M meetings, K tasks created, J ideas.

### Decisions Made
- [decision or outcome] (Day)
- [decision or outcome] (Day)

### Work Completed
- [item completed or merged] (Day)

### In Progress
- [item still in progress at week end]

### Blocked
- ⚠️ [blocked item] — reason (since Day)

### Thread Lifecycles
- **[item]**: opened Day (status) → status Day [→ resolved Day ✓]
- ⚠️ **[item]**: opened Day (status) → still blocked/in-progress Day

### Intention vs. Outcome
- Mon: planned N, completed N, carried N
- Tue: planned N, completed N, deferred N
- ...
- **Week completion rate: NN%**

## Correction Analysis

[Extract all [correction] and [approved] entries from daily notes' Classification Log sections.
Count corrections by confidence band (0.5-0.6, 0.6-0.7, 0.7-0.8, 0.8+).
Count approvals by confidence band.

If 2+ weeks of weekly digests exist in the vault, generate a threshold recommendation:]

Threshold suggestion: Current X.XX. This week: N corrections on notes
filed at 0.60-0.68, M needs-review items approved as-is at 0.55-0.59.
Consider raising/lowering to Y.YY? (edit 05 Meta/config.yaml to adjust)

[If fewer than 2 weeks of data:]
Insufficient data for threshold recommendation (need 2+ weeks).

## Stale Items

[Query type-specific bases for stale items:]
```

**Format rules for Week Summary:**
- Omit any subsection (### heading + bullets) with zero items
- **Decisions Made / Work Completed:** one bullet per item, annotated with day of week
- **In Progress / Blocked:** items from the last day's Open Threads that weren't resolved by week end
- **Thread Lifecycles:** trace each tracked item across the week using daily Open Threads data. Show state transitions with `→`. Mark resolved items with `✓`. Flag items stuck all week with `⚠️`.
- **Intention vs. Outcome:** for each day, read its `### Tomorrow` section and check the next day's summary for whether those items were addressed. Count planned vs completed vs carried/deferred. Calculate weekly completion rate. If no Tomorrow sections exist (early adoption), note "Intention tracking not yet available."
- **Reflection Prompts** should reference thread lifecycle AND intention data (e.g., "X blocked all week — escalation needed?", "Completion rate dropped to 50% — overcommitting?")

```bash
obsidian vault=second-brain base:query path="01 Projects/Active Projects.base" format=json
obsidian vault=second-brain base:query path="02 Areas/People.base" format=json
obsidian vault=second-brain base:query path="02 Areas/Tasks.base" format=json
```

From the JSON results, identify:
- Projects with `modified` 14+ days ago
- People with `last_touched` 30+ days ago
- Tasks with `due` < today minus 7 days and `status` != done

[List each stale item with how long it's been stale.]

## Reflection Prompts

[Generate questions based on the analysis:]
- Stale project prompts: "Project X hasn't moved in N days — still active?"
- Idea review: "You captured N ideas this week but promoted 0 to projects — review any?"
- Follow-up prompts: "You haven't touched Person Y in N days — follow up needed?"
- Threshold prompt (if applicable): the suggestion from Correction Analysis
```

Add to `commit_details`: `generated weekly digest: YYYY-WNN`

### Step 7: Generate Monthly Digest (last day of month only)

**Skip this step if today is not the last day of the month.**

Reuse the Digests query cached in Step 6 (no additional query needed). If Step 6 was skipped (not Sunday), run the query now:

```bash
obsidian vault=second-brain base:query path="02 Areas/Digests.base" format=json
```

From the JSON results, select entries where `digest_type: weekly` and `period_start` falls within this month.

**File:** `04 Data/YYYY/MM/YYYY.MM.DD-monthly-digest.md`

**Frontmatter:**
```yaml
---
type: digest
digest_type: monthly
aliases: [YYYY-MM-monthly-digest]
period_start: YYYY-MM-01
period_end: YYYY-MM-DD  # Last day of month (today)
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags: [digest]
---
```

**Body:**

```markdown
## Month Summary

N work days active. M meetings total. K tasks created, J completed.

### Key Decisions
- [significant decision that shaped direction] (W##)
- [significant decision] (W##)

### Major Completions
- [completed item or milestone] (W##)

### Persistent Threads
- **[thread]** — status at month end (first appeared W##)
- ⚠️ **[thread]** — blocked N+ days across M weeks

### New Initiatives
- [projects or tasks started this month]

## Trends

- **Captures per week:** [trending up/down/stable, with numbers]
- **Type distribution:** [% person, project, task, idea, admin, meeting]
- **Correction rate:** [corrections / total classifications]
- **Threshold changes:** [any changes made this month]

## Reflection Prompts

[Bigger-picture questions informed by persistent thread data:]
- "Your most active project was X — is it wrapping up or expanding?"
- "Admin notes are N% of captures — is that intentional or noise?"
- "N ideas have been sitting for 30+ days — promote, archive, or drop?"
- "You interacted with N people this month — anyone missing?"
- "[Thread Y] persisted all month — needs escalation or acceptance?"
```

**Format rules for Month Summary:**
- Monthly filters for **significance** — not every daily decision makes it. Include only items that appeared across multiple weeks or had meaningful impact.
- **Persistent Threads:** items that carried across 2+ weekly digests. Strong signal of something important or stuck.
- **New Initiatives:** projects/tasks that started this month (first appeared in a weekly digest this month).

Add to `commit_details`: `generated monthly digest: YYYY-MM`

### Step 7b: Generate Yearly Digest (December 31 only)

**Skip this step if today is not December 31 (`IS_LAST_DAY_OF_YEAR` is false).**

Reuse the Digests query cached in Step 6/7. If neither Step 6 nor Step 7 ran, run the query now:

```bash
obsidian vault=second-brain base:query path="02 Areas/Digests.base" format=json
```

From the JSON results, select entries where `digest_type: monthly` and `period_start` falls within this year (YYYY-01-01 through YYYY-12-31). Read each monthly digest to extract their `## Month Summary` and `## Trends` sections.

**File:** `04 Data/YYYY/12/YYYY.12.31-yearly-digest.md`

**Frontmatter:**
```yaml
---
type: digest
digest_type: yearly
aliases: [YYYY-yearly-digest]
period_start: YYYY-01-01
period_end: YYYY-12-31
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags: [digest]
---
```

**Body:**

```markdown
## Year Summary

[Aggregation of monthly digests: key projects completed, team changes, major decisions,
growth areas. Synthesize the year's arc — what themes emerged, what shifted, what was
accomplished. Under 500 words.]

## Trends

- **Captures per month:** [monthly counts, trending up/down/stable]
- **Type distribution shift:** [Q1 vs Q4 comparison — are you doing more meetings? fewer ideas?]
- **Meeting frequency:** [trend across the year]
- **Key relationships:** [most interacted people, based on meeting frequency]
- **Correction rate:** [yearly average, trend across quarters]

## Key Projects

[List major projects that were active this year, with their current status and key milestones.]

## Reflection Prompts

[Year-level questions:]
- "Your most active quarter was QN — what drove that?"
- "You interacted with N people this year — any key relationships that faded?"
- "N ideas were captured but never promoted — review or archive?"
- "Meeting frequency was X/week average — is that sustainable?"
- "What's the one thing you'd do differently next year?"
```

Add to `commit_details`: `generated yearly digest: YYYY`

### Step 8: /learned Prompt (skippable)

After all processing and digest generation is complete, ask:

```
Run /learned to capture what we learned today? (y/n)
```

- **If yes:** Run the full `/learned` flow from `.claude/commands/learned.md`:
  1. Scan the session for patterns worth capturing
  2. Propose updates to `05 Meta/context/` files
  3. Ask "anything else?"
  4. Apply all approved changes
  5. Add to `commit_details`: `/learned: updated <file1>, <file2>` (and `created <new-file>` if applicable)
  
- **If no:** Skip directly to the git commit.

The `/learned` changes are included in the `/eod` batch commit — no separate commit.

### Step 9: Navigation Link

Update today's daily note to add a forward navigation link pointing to tomorrow:

Read the daily note and check if it already has a navigation line. If not, add or update the navigation line (after the heading, before ## Notes):

```markdown
← [[YYYY.MM.DD-daily-note|Yesterday]] | **YYYY-MM-DD** | [[YYYY.MM.DD-daily-note|Tomorrow]] →
```

This ensures the daily note chain is navigable. Tomorrow's daily note (when created by `/today`) will link back to today.

### Step 9b: Vault Cleanup

Run the vault cleanup script to remove any erroneous root-level files created by clicking broken wiki-links:

```bash
"05 Meta/scripts/vault-cleanup" --clean
```

This detects and deletes empty `.md` files at the vault root whose names match aliases in `04 Data/` notes. These files are artifacts of clicking alias-only wiki-links that Obsidian couldn't resolve. The script commits its own changes if any files are removed.

If the script reports misplaced files in `04 Data/` root, note them for manual review but do not block the `/eod` flow.

### Step 10: Git Commit

Single batched commit for the entire `/eod` run:

```bash
git add -A
git commit -m "sb: /eod — processed N inbox, M dirty checks, S meeting summaries, enriched daily note [+ weekly] [+ monthly]" -m "
- [each entry from commit_details, one per line]
"
```

Build the summary line dynamically:
- Always: `processed N inbox, M dirty checks, S meeting summaries, enriched daily note`
- If `granola_ingest_count` > 0: append `, G granola meetings ingested`
- If `github_done_count` > 0: append `, G github tasks completed`
- If `slack_channel_count` > 0: append `, S slack channels summarized`
- If weekly: append `+ weekly`
- If monthly: append `+ monthly`
- If yearly: append `+ yearly`
- If /learned ran: append `, /learned: updated <files>`

The commit body lists all individual actions from `commit_details`.

If no changes were made at all (nothing to process, no dirty notes, no meetings to summarize, log was empty), skip the commit entirely and display: "Nothing to process today."

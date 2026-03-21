# /today — Morning Briefing + Daily Note

Morning briefing that creates (or updates) a persistent daily note. The daily note is the day's workspace — it includes embedded Bases views for live data and gets enriched by `/eod` with digest content.

## When to Use

Run this command each morning (or whenever you want a quick status update). It's designed to be fast — no inbox processing, no dirty detection, no classification. Just a scan and display.

If `/eod` was missed, `/today` detects this and runs the missing processing first (slower that morning, but you're never stuck).

## Execution Mode

`/today` can run in two modes:

**Inline (default):** Runs in the current conversation context. Fast for light days, but GitHub sync with 200+ notifications can consume significant context.

**Agent (recommended for heavy days):** The caller dispatches `/today` as an Agent subagent. The agent gets its own context window, runs all Steps 0-6, and returns only the final briefing text (Step 4 output). The main conversation stays clean.

To run as an agent, the caller should use:

```
Agent(prompt="Run /today for today's date. Return ONLY the final briefing markdown (the Step 4 output) and a one-line commit summary. Do not return base query JSON, script output, or intermediate processing details.", subagent_type="general-purpose")
```

The agent must still run GitHub discovery scripts directly via Bash (not delegate further). All vault mutations (note creation, property updates, git commits) happen inside the agent. The only thing returned to the caller is the briefing text.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## Important: Obsidian CLI Output

**NEVER pipe `obsidian` CLI output directly through `head`, `tail`, `less`, or any truncating command.** The obsidian CLI does not handle SIGPIPE and will hang indefinitely, blocking the entire session. **Workaround:** Insert `cat` as a buffer — `obsidian ... | cat | head -20` works because `cat` absorbs the SIGPIPE.

Preferred approaches to reduce output at the source:
- Use `view="ViewName"` to query a filtered view (e.g., `base:query path="..." view="Recent"`)
- Use `format=json` and process the full output
- If output is too large, use filtered views (see Tasks/People/Digests bases)

## Steps

### Step 0: Create or Find Today's Daily Note

Determine the current date context:
- `TODAY` — YYYY-MM-DD format
- `YEAR` — YYYY
- `MONTH` — MM
- `DAILY_NOTE_PATH` — `04 Data/YEAR/MONTH/YYYY.MM.DD-daily-note.md`

Check if today's daily note already exists:

```bash
obsidian vault=second-brain search query="YYYY.MM.DD-daily-note" path="04 Data" format=json
```

**If it does not exist**, create it with inline Bases views (not embedded `.base` files, since those use `today()` and won't work for historical daily notes):

```bash
obsidian vault=second-brain create path="04 Data/YEAR/MONTH/YYYY.MM.DD-daily-note.md" content="---
type: dailynote
aliases: [YYYY-MM-DD-daily-note]
date: YYYY-MM-DD
created: \"YYYY-MM-DD HH:mm\"
modified: \"YYYY-MM-DD HH:mm\"
tags: [dailynote]
---

# DayOfWeek, Month DD, YYYY

---
## Notes
-

---
## Meetings
\`\`\`base
filters:
  and:
    - file.inFolder(\"04 Data\")
    - type == \"meeting\"
formulas:
  File: |
    if(aliases,link(file, aliases), file)
views:
  - type: table
    name: Meetings
    filters:
      and:
        - this.date == date
    order:
      - meeting_name
      - summary
      - formula.File
    sort:
      - property: created
        direction: ASC
\`\`\`

---
## Created Today
\`\`\`base
filters:
  and:
    - file.inFolder(\"04 Data\")
formulas:
  File: |
    if(aliases,link(file, aliases), file)
  Test: 'this.created.toString().split(\"T\",1) == created.toString().split(\"T\",1) '
views:
  - type: table
    name: Notes
    filters:
      and:
        - 'this.created.toString().split(\"T\",1) == created.toString().split(\"T\",1) '
    order:
      - date
      - summary
      - formula.File
    sort:
      - property: formula.Test
        direction: ASC
      - property: date
        direction: DESC
\`\`\`

## Modified Today
\`\`\`base
filters:
  and:
    - file.inFolder(\"04 Data\")
formulas:
  File: |
    if(aliases,link(file, aliases), file)
  Test: 'this.created.toString().split(\"T\",1) == modified.toString().split(\"T\",1) '
views:
  - type: table
    name: Notes
    filters:
      and:
        - 'this.created.toString().split(\"T\",1) == modified.toString().split(\"T\",1) '
    order:
      - date
      - summary
      - formula.File
    sort:
      - property: formula.Test
        direction: ASC
      - property: date
        direction: DESC
\`\`\`
" silent
```

**If it already exists**, read it to check what sections are already present.

### Step 1: Check for Missing Daily Notes / Digests

Query the Digests base and search for daily notes:

```bash
obsidian vault=second-brain base:query path="02 Areas/Digests.base" view="Recent" format=json
obsidian vault=second-brain search 'query="type: dailynote"' path="04 Data" format=json
```

Note: The "Recent" view returns digests from the last 45 days. For yearly digest checks (January 1), fall back to `view="All"` if needed.

From the combined results, check:

1. **Last work day enrichment** — Was `/eod` run for the most recent work day?

   Scan backward from yesterday up to 7 days to find the most recent daily note:
   ```bash
   obsidian vault=second-brain search 'query="type: dailynote"' path="04 Data" format=json
   ```
   From the results, find the daily note with the most recent `date` that is before today and within 7 days. Call this `LAST_WORK_DAY`.

   - **If no daily note found within 7 days:** Old gap — skip daily fallback. The user should run `/generate-digests` for extended absences. Note the gap for the Step 1 summary (see sub-check 5).
   - **If `LAST_WORK_DAY` daily note found:** Read it and check for a `## Day Summary` section.
     - **No `## Day Summary`:** `/eod` was missed for `LAST_WORK_DAY`. Run fallback `/eod` processing for that date:
       - Process any inbox items (query `05 Meta/bases/Unprocessed Inbox.base`)
       - Run dirty detection (query `05 Meta/bases/Dirty Notes.base`)
       - Roll the inbox log
       - Enrich the existing daily note with digest content (do NOT recreate it)
       - Follow the `/eod` command steps (`.claude/commands/eod.md`) but with `LAST_WORK_DAY`'s date context
     - **`## Day Summary` present:** `/eod` ran successfully for the most recent work day. Skip.

   **Note:** This only catches the single most recent gap. For multi-day gaps (e.g., PTO), see sub-check 5.

2. **Last week's weekly digest (if today is Monday, Tuesday, or Wednesday)** — Is there an entry with `digest_type: weekly` and `period_end` = last Sunday?
   - If missing: Generate it now from last week's daily notes (follow `/eod` Step 6 with last week's dates)
   - If present or today is Thursday or later: skip.

3. **Last month's monthly digest (if today is the 1st)** — Is there an entry with `digest_type: monthly` and `period_end` = last day of previous month?
   - If missing: Generate it now from last month's weekly digests (follow `/eod` Step 7 with last month's dates)
   - If present or today is not the 1st: skip.

4. **Last year's yearly digest (if today is January 1)** — Is there an entry with `digest_type: yearly` and `period_end` = YYYY-12-31 for the previous year?
   - If missing: Generate it now from last year's monthly digests (follow `/eod` Step 7b with last year's dates)
   - If present or today is not January 1: skip.

5. **Gap summary (always)** — Scan daily notes from the last 14 days. Identify any that are missing a `## Day Summary` section (excluding today's note). If gaps are found:
   - Record the gap dates for display in the Step 4 briefing
   - The briefing will include a prompt like:
     > **Gaps detected:** Daily notes for [dates] are missing Day Summaries.
     > Run `/generate-digests start_date=YYYY-MM-DD end_date=YYYY-MM-DD level=all` to backfill.
   - Do NOT attempt to backfill automatically — only surface the information
   - If no gaps found within 14 days, skip this message

If any fallback processing was done, commit all changes:
```bash
git add -A
git commit -m "sb: /today fallback — generated missing daily notes/digests for [dates]"
```

### Step 1.5: Ingest External Inbox

Import any files from the external drop folder before scanning the vault:

```bash
"05 Meta/scripts/sb-ingest"
```

This picks up session logs and other captures written by agents in other projects. Files are moved into `04 Data/YYYY/MM/` as unprocessed inbox items. If the drop folder is empty or doesn't exist, this is a no-op.

### Step 2: Navigation Links + Vault Scan

Find yesterday's daily note and add a navigation link to today's note (if not already present):

```bash
obsidian vault=second-brain search query="<yesterday-YYYY.MM.DD>-daily-note" path="04 Data" format=json
```

If found, prepend a navigation line to today's daily note (after the heading, before ## Notes):
```markdown
← [[YYYY.MM.DD-daily-note|Yesterday]] | **Today**
```

Also update yesterday's daily note to add a forward link if it doesn't have one:
```markdown
← [[previous-day]] | **YYYY-MM-DD** | [[YYYY.MM.DD-daily-note|Tomorrow]] →
```

Then run the vault scan. Query the vault via 3 Obsidian CLI calls:

```bash
# Today's view — covers overdue tasks, due today, needs review, active projects
obsidian vault=second-brain base:query path="02 Areas/Today.base" format=json

# All open tasks — for upcoming (next 7 days) not already in Today's view
obsidian vault=second-brain base:query path="02 Areas/Tasks.base" format=json

# People — only those with active follow-ups
obsidian vault=second-brain base:query path="02 Areas/People.base" view="With Follow-ups" format=json
```

From the JSON results, extract:

- **Overdue tasks:** Today.base entries with `type: task`, `due` < today. Sorted oldest first.
- **Due today:** Today.base entries with `type: task`, `due` = today.
- **Upcoming tasks:** Tasks.base entries with `due` within next 7 days (exclude those already in Today.base). Grouped by date.
- **Active projects:** Today.base entries with `type: project`, `status: active`. Show `name` + `next_action`.
- **People with follow-ups:** People.base entries with `follow_ups` that is not empty/null.
- **Needs review:** Today.base entries with `status: needs_review`. Show with confidence scores.
- **Type mismatches:** Check yesterday's daily note for any type mismatches flagged by `/eod` dirty detection.

### Step 2.5: GitHub Briefing

**IMPORTANT:** Run all GitHub discovery scripts and mark-done calls directly in the main context using the Bash tool. Do NOT delegate to Agent subagents — subagents have restricted Bash permissions and the calls will be denied.

Run the gh-onmyplate discovery scripts to find threads needing attention, then create or update vault notes for each.

**Discovery — run the gh-onmyplate scripts:**

```bash
SKILL_DIR=~/.claude/skills/gh-onmyplate/scripts
$SKILL_DIR/gh_notifications.sh 7d --compact
$SKILL_DIR/gh_involved.sh 7d --compact
$SKILL_DIR/gh_my_prs.sh --compact
```

Note: `--compact` changes the output column layout:
- `gh_notifications.sh --compact`: `THREAD_ID  REPO#N  REASON  STATUS  TITLE`
- `gh_involved.sh --compact`: `REPO#N  TYPE  TITLE`
- `gh_my_prs.sh --compact`: `REPO#N  CREATED  TITLE  LAST_POST_SUMMARY`

The URL is not in compact output — reconstruct as `https://github.com/REPO/pull/N` or `https://github.com/REPO/issues/N` based on TYPE.

Note: `gh_notifications.sh` outputs a `THREAD_ID` as its first column — capture this for each notification item.

Deduplicate results by `owner/repo#number` across all three scripts. For each unique thread, determine the action category from the gh-onmyplate output:
- **Needs Response** — someone asked a question, requested changes, or @mentioned the user
- **My PRs** — user's own open PRs (status: approved, changes requested, CI pass/fail, stale)
- **Review Requests** — someone requested the user's review
- **FYI (No Action)** — user's last post is the latest, or only CI/bot updates

**For each thread**, run the `/gh-import` logic:

1. Check if a vault note exists by querying `02 Areas/GitHub.base`:
   ```bash
   obsidian vault=second-brain base:query path="02 Areas/GitHub.base" format=json
   ```
   Filter the results for the matching `github_repo` + `github_number`.

2. **If note exists**: read `github_last_synced` from the base query results, then:
   ```bash
   "05 Meta/scripts/gh-fetch" "GITHUB_URL" --since "GITHUB_LAST_SYNCED"
   ```
   If new activity: summarize it, update frontmatter via `obsidian property:set`, append summary via `obsidian append`. (Follow `/gh-import` Step 4 logic.)

3. **If note does not exist**: full fetch + create:
   ```bash
   "05 Meta/scripts/gh-fetch" "GITHUB_URL"
   ```
   Create the vault note following `/gh-import` Step 3 logic.

4. Record the action category and summary for use in the daily note's GitHub section.

**Mark notifications as done in GitHub:**

After processing each notification from `gh_notifications.sh` (both actionable and FYI), mark it done **and log it** using the wrapper script:

```bash
SKILL_DIR=~/.claude/skills/gh-onmyplate/scripts
$SKILL_DIR/gh_mark_done.sh "THREAD_ID" "REPO" "TYPE" "TITLE" "URL"
```

Where:
- `THREAD_ID` — notification thread ID (first column from `gh_notifications.sh`)
- `REPO` — owner/repo (e.g. `elastic/beats`)
- `TYPE` — `PullRequest` or `Issue`
- `TITLE` — notification subject title
- `URL` — web URL to the issue/PR

This logs each mark-done to `~/.local/share/gh-onmyplate/marked-done.tsv` for error recovery, then runs the PATCH call. The log file path is configured via `MARKED_DONE_AUDIT_LOG` in `config.sh`.

This only applies to items from `gh_notifications.sh` — items from `gh_involved.sh` and `gh_my_prs.sh` don't have notification thread IDs and are not marked. Track the count as `notifications_marked_done`.

**Create task notes for actionable items:**

For items categorized as "Needs Response" or "Review Requests" only:

1. Search for an existing task note with matching `github_url`:
   ```bash
   obsidian vault=second-brain search query="github_url: GITHUB_URL" path="04 Data" format=json
   ```
   Filter results for notes with `type: task` (not `type: github` which also has `github_url`).

2. **If found with `status: pending`** → reuse the existing task note (no new note created). Link it in the daily note.
3. **If found with `status: done`** → new activity on a previously-resolved thread means new work. Create a new task note.
4. **If not found** → create a new task note.

Task note creation:
```bash
obsidian vault=second-brain create path="04 Data/YYYY/MM/YYYY.MM.DD-gh-task-REPO-NUMBER.md" content="---
type: task
task: \"Respond to owner/repo#NUMBER — [brief context]\"
status: pending
due: YYYY-MM-DD
priority: medium
github_url: GITHUB_URL
github_thread_id: \"THREAD_ID\"
aliases: [gh-task-REPO-NUMBER]
tags: [github, task]
created: \"YYYY-MM-DD HH:mm\"
modified: \"YYYY-MM-DD HH:mm\"
classified_at: \"YYYY-MM-DD HH:mm\"
confidence: 1.0
---

# Respond to owner/repo#NUMBER

[owner/repo#NUMBER](GITHUB_URL) | Action needed: [context]

**Vault note:** [[YYYY.MM.DD-gh-REPO-NUMBER|gh-REPO-NUMBER]]
" silent
```

Where:
- `REPO` is the short repo name (e.g., `security`, `kibana`)
- `NUMBER` is the issue/PR number
- `THREAD_ID` is the notification thread ID from `gh_notifications.sh` (omit field if item came from `gh_involved.sh`/`gh_my_prs.sh`)
- `due` is set to today's date (unchecked items become overdue next morning)
- The vault note link references the GitHub-type vault note (from `/gh-import`), not the task note itself

Track the count as `task_notes_created`.

**Auto-resolve previously-actionable items:**

After categorizing all threads, check for task notes that should be auto-resolved:

1. **Threads now categorized as FYI or My PRs:** For each thread in a non-actionable category:
   - Search for a pending task note with matching `github_url`:
     ```bash
     obsidian vault=second-brain search query="github_url: GITHUB_URL" path="04 Data" format=json
     ```
   - If found with `type: task` and `status: pending` → the user responded on GitHub since the task was created
   - Set `status: done` via `obsidian property:set`
   - Add to a "Resolved Since Yesterday" list for the daily note

2. **Threads no longer appearing in any discovery script output:**
   - Search for all pending GitHub task notes:
     ```bash
     obsidian vault=second-brain search query="type: task" path="04 Data" format=json
     ```
   - Filter for notes whose filename matches the pattern `*-gh-task-*` and have `status: pending`
   - For each, check if its `github_url` appears in today's discovery results
   - If absent: verify the thread state via GitHub API:
     ```bash
     gh api /repos/OWNER/REPO/issues/NUMBER --jq '.state'
     ```
   - If closed/merged: set `status: done` via `obsidian property:set`
   - If still open but not in discovery results: leave as-is (may reappear tomorrow)

Track the count as `auto_resolved_count`.

**Build the `## GitHub` section** for the daily note and briefing output. Group items by action category. The primary click target is the GitHub URL:

```markdown
## GitHub

### Resolved Since Yesterday
- ~~elastic/security#8470~~ — you responded · [[2026.02.18-gh-task-security-8470|task]] ✓

### Needs Response
- [ ] [**elastic/security#8470** — summary](https://github.com/elastic/security/issues/8470) · [[2026.02.18-gh-security-8470|notes]]
- [ ] [**elastic/other-repo#999** — summary](https://github.com/elastic/other-repo/issues/999)

### My PRs
- [ ] [**elastic/skills#8** — approved, reviewer asked "Can we test it?"](https://github.com/elastic/skills/pull/8) · [[2026.02.18-gh-skills-8|notes]]

### Review Requests
- [ ] [**elastic/kibana#54321** — brief context](https://github.com/elastic/kibana/pull/54321) · [[2026.02.18-gh-kibana-54321|notes]]

### FYI (No Action)
- [**elastic/beats#9999** — your comment is the latest](https://github.com/elastic/beats/issues/9999) · [[2026.02.18-gh-beats-9999|notes]]
```

**Rules for the GitHub section:**
- Omit empty sub-sections (e.g., if no review requests, skip that heading)
- Needs Response and Review Requests get checkboxes (`- [ ]`)
- FYI items do NOT get checkboxes (no action needed)
- My PRs get checkboxes
- Keep each item to one line — GitHub URL as primary link, vault note reference as secondary
- Items WITH a vault note: `[**owner/repo#N** — summary](URL) · [[filename|notes]]`
- Items WITHOUT a vault note: `[**owner/repo#N** — summary](URL)`
- Resolved items use strikethrough: `~~owner/repo#N~~ — reason · [[task-note|task]] ✓`
- If no GitHub threads found at all, omit the entire `## GitHub` section

**Git commit** after all GitHub notes are created/updated:
```bash
git add -A
git commit -m "sb: /today — github sync (N created, M updated, P notifications marked done, Q task notes, R auto-resolved)"
```

Skip the commit if no notes were created or updated and no notifications were marked done.

### Step 3: Check for Recent Digests

Reuse the Digests query from Step 1 (no additional query needed). If a weekly or monthly digest was recently generated, note it for display:

- Look for weekly digests with `period_end` within the last 7 days
- Look for monthly digests with `period_end` within the last 31 days

### Step 4: Write Briefing to Daily Note + Display

Build the briefing content and **both** append it to the daily note as a `## Briefing` section **and** display it in the terminal.

**4a. Read yesterday's intentions:**

Find yesterday's daily note (or last work day's, using the same backward scan from Step 1). Read its `### Tomorrow` section if present. These become the "Yesterday you planned:" items in the briefing.

If yesterday has no `### Tomorrow` section (first run, or gap), omit the "Yesterday you planned:" section entirely.

If a `## Briefing` section already exists in the daily note (from a previous `/today` run), replace it with the updated content.

Append to the daily note (before any `/eod`-generated sections like `## Day Summary`):

```markdown
---
## Briefing
[briefing content]
```

Also output the briefing in the Cursor terminal under **250 words**.

ALL wiki-links in the briefing must use the full filename format: `[[YYYY.MM.DD-name|display-text]]`. Look up filenames from the Bases query results used in Step 2. GitHub items follow the same conditional linking rule as the GitHub section (wiki-link if vault note exists, markdown URL if not).

```markdown
## Good morning — Mon DD, YYYY

Daily note: [[YYYY.MM.DD-daily-note]]

**Yesterday you planned:**
- [ ] [intention from yesterday's ### Tomorrow section]
- [ ] [intention from yesterday's ### Tomorrow section]
- [ ] [intention from yesterday's ### Tomorrow section]

**Overdue (N):**
- [ ] Task name (due Mon DD) — [[YYYY.MM.DD-task-name|task-name]]

**Due today (N):**
- [ ] Task name — [[YYYY.MM.DD-task-name|task-name]]

**Upcoming (N this week):**
- Mon DD: Task name — [[YYYY.MM.DD-task-name|task-name]]

**Active projects (N):**
- Project Name → "next action text"

**Follow-ups (N):**
- Person Name — "follow-up item"

**GitHub — Resolved (N):**
- ~~owner/repo#123~~ — you responded ✓

**GitHub — Needs Response (N):**
- [ ] [**owner/repo#123** — what happened](URL) · [[YYYY.MM.DD-gh-repo-123|notes]]

**GitHub — My PRs (N):**
- [ ] [**owner/repo#456** — status](URL) · [[YYYY.MM.DD-gh-repo-456|notes]]

**GitHub — Review Requests (N):**
- [ ] [**owner/repo#789** — context](URL) · [[YYYY.MM.DD-gh-repo-789|notes]]

**Needs review (N):** note-name (0.43), other-note (0.51)

**Type mismatches (N):** note-name (current: idea, suggested: project)

Weekly review available: [[YYYY.MM.DD-weekly-digest|YYYY-WNN-weekly-digest]]
Monthly review available: [[YYYY.MM.DD-monthly-digest|YYYY-MM-monthly-digest]]

**Gaps detected (N days):**
> Daily notes for Feb 20, Feb 21, Feb 22 are missing Day Summaries.
> Run `/generate-digests start_date=2026-02-20 end_date=2026-02-22 level=all` to backfill.
```

**Rules:**
- Omit empty sections entirely
- Sort overdue tasks oldest-first (most urgent)
- Sort upcoming tasks by due date
- Needs review items show confidence scores inline
- Type mismatches show current type vs. suggested type
- Keep it scannable — checkboxes for tasks, bold for section headers
- ALL wiki-links use full filename format `[[YYYY.MM.DD-name|display-text]]`
- GitHub items without vault notes use markdown URLs: `[**owner/repo#123** — summary](URL)`
- If no items in any category, say "All clear — nothing needs attention today."
- If fallback processing was needed, note at the top: "Note: /eod was missed — ran catchup processing first."
- Gap notification: only show if un-enriched daily notes exist in the last 14 days (excluding today)
- "Yesterday you planned:" shows items from yesterday's `### Tomorrow` section as checkboxes
- Omit if yesterday has no Tomorrow section
- These are informational — checking them off in the daily note is optional but encouraged
- End with: `> Run /eod tonight to process today's captures.`

### Step 5: Update Index + Current Priorities

Update the vault landing page and current priorities to reflect the latest state.

**5a. Update Index.md**

Read `Index.md` and update the "Today's Note" link to point to today's daily note:

```markdown
- [[YYYY.MM.DD-daily-note|Today's Note]]
```

No other changes to Index.md — the Projects embed and Areas table are self-updating via Bases.

**5b. Update Current Priorities**

Read `05 Meta/context/current-priorities.md` and rewrite it based on the current vault state gathered in Steps 2–3:

1. **Top Focus Areas** — Derive from active projects (Today.base), high-priority tasks due within 3 days, and any items the user flagged as top priority in recent daily notes or meetings. Limit to 3–5 items. Rank by urgency (due date) then importance (priority field).

2. **Active Threads** — Compile from:
   - Open tasks with `status: pending` (group related tasks into a single thread)
   - Person follow-ups from People.base
   - Unchecked action items from meetings in the last 7 days
   - GitHub threads categorized as "Needs Response" or "Review Requests"
   - Remove threads where all related tasks are `status: done`

Keep each thread to one line. Include due dates where relevant. Remove stale items that no longer appear in any active view.

**5c. Commit updates:**

```bash
git add Index.md "05 Meta/context/current-priorities.md"
git commit -m "sb: /today — updated index and current priorities"
```

### Step 6: Git Commit (if daily note was created)

If a new daily note was created in Step 0 (not pre-existing), commit it:

```bash
git add "04 Data/YEAR/MONTH/YYYY.MM.DD-daily-note.md"
git commit -m "sb: /today — created daily note for YYYY-MM-DD"
```

If only the briefing section was updated on an existing note, do NOT commit (it's ephemeral content that `/eod` will finalize).

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

The agent must still run the scripts directly via Bash (not delegate further). All vault mutations (note creation, property updates, git commits) happen inside the agent. The only thing returned to the caller is the briefing text.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## Important: Bash Command Style

**NEVER prefix Bash tool commands with `# comment` lines.** Comment-prefixed commands don't match permission patterns and trigger approval prompts. Use the Bash tool's `description` parameter for context instead.

**NEVER pipe `obsidian` CLI output directly through `head`, `tail`, `less`, or any truncating command.** The obsidian CLI does not handle SIGPIPE and will hang indefinitely. Use `| cat | head -20` as a workaround.

## Steps

### Steps 0–2: Vault Scan (scripted)

Run the vault scan script. This handles daily note creation, ingest, navigation links, gap detection, and all base queries in a single invocation:

```bash
"05 Meta/scripts/sb-today-scan"
```

**Output:** JSON object with keys:
- `date` — today, dot_date, year, month, display, now
- `daily_note` — path, created (bool)
- `ingest` — count
- `navigation` — yesterday_note, yesterday_date, yesterday_tomorrow, links_added
- `gaps` — last_work_day, last_work_day_has_summary, eod_fallback_needed, missing_summaries[]
- `bases` — today[], tasks[], people[], digests[]

Save the JSON output for use in later steps.

**If `gaps.eod_fallback_needed` is true:** `/eod` was missed for the last work day. Run fallback `/eod` processing:
- Process any inbox items (query `05 Meta/bases/Unprocessed Inbox.base`)
- Run dirty detection (query `05 Meta/bases/Dirty Notes.base`)
- Roll the inbox log
- Enrich the existing daily note with digest content (do NOT recreate it)
- Follow the `/eod` command steps (`.claude/commands/eod.md`) but with last_work_day's date context

If any fallback processing was done, commit:
```bash
git add -A
git commit -m "sb: /today fallback — generated missing daily notes/digests for [dates]"
```

**Digest checks** (from `bases.digests`):
- If today is Mon/Tue/Wed: check for weekly digest with `period_end` = last Sunday. If missing, generate.
- If today is the 1st: check for monthly digest. If missing, generate.
- If today is Jan 1: check for yearly digest. If missing, generate.

### Step 2.5: GitHub Sync (scripted)

Run the GitHub sync script. This handles discovery, categorization, mark-done, and vault state lookup:

```bash
"05 Meta/scripts/sb-github-sync"
```

**Output:** JSON object with keys:
- `discovery.notifications[]` — thread_id, repo, type, reason, status, updated, title, url, source
- `discovery.involved_raw` — raw text from gh_involved.sh
- `discovery.my_prs_raw` — raw text from gh_my_prs.sh
- `discovery.counts` — notifications, involved, my_prs
- `vault_state.github_notes[]` — existing GitHub vault notes from GitHub.base
- `vault_state.task_notes[]` — existing task notes
- `mark_done` — count, errors
- `stale_tasks[]` — path, github_url, key, github_state, should_resolve

### Step 1.75: Sync Raindrop Bookmarks

Trigger a make-it-rain sync to catch any bookmarks saved since the last sync:

```bash
obsidian vault=second-brain command id="make-it-rain:fetch-raindrops"
```

This fetches new Raindrop bookmarks and writes them as `type: inbox, status: unprocessed, source: raindrop` notes in `04 Data/`. They will be processed by `/eod` Step 1 (inbox classification).

After the sync, query the Raindrop Inbox base for a count:

```bash
obsidian vault=second-brain base:query path="05 Meta/bases/Raindrop Inbox.base" format=json
```

Record the count as `raindrop_inbox_count` for the Step 4 briefing. If 0, skip the Raindrop section in the briefing.

**Processing the output:**

1. **Deduplicate** threads across notifications, involved, and my_prs by `owner/repo#number`.

2. **Categorize** each thread:
   - **Needs Response** — notification reason: mention, comment, assign, or state_change
   - **My PRs** — from my_prs output
   - **Review Requests** — notification reason: review_requested
   - **FYI** — everything else (subscribed, ci_activity, or user's last post is latest)

3. **For each thread**, check `vault_state.github_notes` for an existing vault note (match by `github_repo` + `github_number`).

4. **Fetch and update vault notes** — for each unique thread:
   - **If vault note exists** with `github_last_synced` older than the thread's `updated` timestamp:
     ```bash
     "05 Meta/scripts/gh-fetch" "GITHUB_URL" --since "GITHUB_LAST_SYNCED"
     ```
     If new activity: summarize it, update frontmatter via `obsidian property:set`, append summary via `obsidian append`. Follow `/gh-import` Step 4 logic.
   - **If vault note does not exist** and thread is in Needs Response, My PRs, or Review Requests:
     ```bash
     "05 Meta/scripts/gh-fetch" "GITHUB_URL"
     ```
     Create vault note following `/gh-import` Step 3 logic.
   - **FYI threads without vault notes**: skip gh-fetch (no vault note needed).

5. **Create task notes** for Needs Response and Review Requests items:
   - Check `vault_state.task_notes` for existing task with matching `github_url` and `type: task`
   - If found with `status: pending` → reuse (no new note)
   - If found with `status: done` → new activity, create new task note
   - If not found → create task note:
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

6. **Auto-resolve stale tasks** from `stale_tasks[]`:
   - For entries with `should_resolve: true` (closed/merged on GitHub):
     ```bash
     obsidian vault=second-brain property:set path="TASK_PATH" name=status value=done
     ```
   - Also check non-actionable threads (FYI, My PRs) against `vault_state.task_notes` — if a pending task exists for a now-FYI thread, mark it done.

7. **Build the `## GitHub` section** for the daily note. Group by category:
   ```markdown
   ## GitHub

   ### Resolved Since Yesterday
   - ~~owner/repo#N~~ — reason · [[task-note|task]] ✓

   ### Needs Response
   - [ ] [**owner/repo#N** — summary](URL) · [[vault-note|notes]]

   ### My PRs
   - [ ] [**owner/repo#N** — status](URL) · [[vault-note|notes]]

   ### Review Requests
   - [ ] [**owner/repo#N** — context](URL) · [[vault-note|notes]]

   ### FYI (No Action)
   - [**owner/repo#N** — summary](URL) · [[vault-note|notes]]
   ```
   Rules: omit empty sub-sections, checkboxes for actionable items only, items with vault notes get `· [[filename|notes]]`, items without use markdown URL only.

8. **Git commit** after all GitHub work:
   ```bash
   git add -A
   git commit -m "sb: /today — github sync (N created, M updated, P notifications marked done, Q task notes, R auto-resolved)"
   ```
   Skip if no vault changes were made (mark_done.count alone doesn't warrant a commit).

### Step 3: Check for Recent Digests

From the `bases.digests` data in the scan output, check:
- Weekly digests with `period_end` within the last 7 days
- Monthly digests with `period_end` within the last 31 days

Note any for display in the briefing.

### Step 4: Write Briefing to Daily Note + Display

Build the briefing content and **both** append it to the daily note as a `## Briefing` section **and** display it in the terminal.

**4a. Read yesterday's intentions:**

Use `navigation.yesterday_tomorrow` from the scan output. These become the "Yesterday you planned:" items.

If null (no Tomorrow section), omit the "Yesterday you planned:" section entirely.

If a `## Briefing` section already exists in the daily note (from a previous `/today` run), replace it with the updated content.

Append to the daily note (before any `/eod`-generated sections like `## Day Summary`):

```markdown
---
## Briefing
[briefing content]
```

Also output the briefing in the terminal under **250 words**.

ALL wiki-links in the briefing must use the full filename format: `[[YYYY.MM.DD-name|display-text]]`. Look up filenames from the base query results. GitHub items follow the same conditional linking rule as the GitHub section.

```markdown
## Good morning — Mon DD, YYYY

Daily note: [[YYYY.MM.DD-daily-note]]

**Yesterday you planned:**
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

**Raindrop Inbox (N):** N bookmarks waiting for triage

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

If a new daily note was created (check `daily_note.created` from scan output), commit it:

```bash
git add "04 Data/YEAR/MONTH/YYYY.MM.DD-daily-note.md"
git commit -m "sb: /today — created daily note for YYYY-MM-DD"
```

If only the briefing section was updated on an existing note, do NOT commit (it's ephemeral content that `/eod` will finalize).

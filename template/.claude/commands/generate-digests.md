# /generate-digests — Retroactive Digest Generation

Generate retroactive digests for a date range. Used after migration waves to backfill daily, weekly, monthly, and yearly digests for historical notes that were imported without live `/eod` processing.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## When to Use

Run this after migrating a batch of notes from the SB vault. It creates the same digest artifacts that `/eod` would have created if it had been running at the time.

## Parameters

- `start_date` — First date to process (YYYY-MM-DD)
- `end_date` — Last date to process (YYYY-MM-DD)
- `level` — One or more of: `daily`, `weekly`, `monthly`, `yearly` (comma-separated or `all`)

## Steps

### Step 0: Parse Parameters and Build Date Range

Parse the provided `start_date`, `end_date`, and `level`. If `level` is `all`, expand to `daily,weekly,monthly,yearly`.

Compute:
- `DATES` — List of all calendar dates from `start_date` to `end_date`
- `WEEKS` — List of ISO weeks (Mon-Sun) that overlap the range, with their Monday and Sunday dates
- `MONTHS` — List of calendar months that overlap the range, with first and last day
- `YEARS` — List of calendar years that overlap the range

### Step 1: Generate Daily Digests

**Skip if `daily` is not in `level`.**

For each date in `DATES`:

**1a. Find or create the daily note:**

```bash
obsidian vault={{VAULT_NAME}} search query="YYYY.MM.DD-daily-note" path="04 Data" format=json
```

If not found, create it with the inline Bases template from `/today` Step 0. Use the date to derive the day-of-week for the heading (e.g., "Monday, February 02, 2026").

**1b. Check if digest already exists:**

Read the daily note. If it already has a `## Day Summary` section, skip this date.

**1c. Gather all notes created on this date:**

```bash
obsidian vault={{VAULT_NAME}} search query="created: \"YYYY-MM-DD" path="04 Data" format=json
```

For each result (excluding the daily note itself and any digest notes), read the full content.

**1d. Generate structured Day Summary:**

Group notes by type and generate a structured bullet summary:

**Format rules:**
- Omit any section (### heading + bullets) with zero items
- **Meetings:** 2-5 sub-bullets per meeting from `## Log` and `## Action Items`
- **Notes Created:** one line per note, grouped by type
- **GitHub Activity:** only if github-type notes exist
- **Housekeeping:** always present

**1e. Open Threads carry-forward (retroactive):**

For retroactive generation, scan the *previous date in the generation range* for its Day Summary:
1. If the previous date's daily note has `### Open Threads` or items listed as in-progress/blocked, check if they appear resolved in the current date's notes
2. Unresolved items carry forward with day counter and `⚠️` prefix at 3+ days
3. If no previous Day Summary exists, skip — omit the `### Open Threads` section

**1f. Append to daily note:**

Append after the last existing section:

````markdown
---
## Day Summary

### Meetings
- **meeting-name** [[YYYY.MM.DD-meeting-name|notes]]
  - [key topic/decision]
  - [action item or open question]

### Notes Created
- **type** [[YYYY.MM.DD-name|display]] — one-line description

### GitHub Activity
- [PR/issue activity]

### Housekeeping
- 0 inbox items classified (retroactive digest from migration)

### Open Threads
- [item] — status (day N)
- ⚠️ [item] — status (day N, reason)

## Classification Log

No classifications today (retroactive digest from migration).
````

If the date has no notes at all (just the daily note), write:

````markdown
---
## Day Summary

No meetings or substantive notes captured.

## Classification Log

No classifications today (retroactive digest from migration).
````

### Step 2: Generate Weekly Digests

**Skip if `weekly` is not in `level`.**

For each week in `WEEKS`:

**2a. Check if digest already exists:**

```bash
obsidian vault={{VAULT_NAME}} search query="YYYY-WNN-weekly-digest" path="04 Data" format=json
```

If found, skip this week.

**2b. Gather daily summaries:**

For each day (Monday through Sunday) of the week, find the daily note and extract its `## Day Summary` section. If a daily note doesn't exist for a day, note it as "no daily note."

**2c. Create the weekly digest file:**

**File:** `04 Data/YYYY/MM/YYYY.MM.DD-weekly-digest.md` (where `YYYY.MM.DD` is the Sunday of the week; `MM` is the month of that Sunday)

**Frontmatter:**
```yaml
---
type: digest
digest_type: weekly
aliases:
  - YYYY-WNN-weekly-digest
period_start: YYYY-MM-DD  # Monday
period_end: YYYY-MM-DD    # Sunday
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags:
  - digest
---
```

**Body** (follow `/eod` Step 6 structure):

````markdown
## Week Summary

Active across N/7 days with notes. M meetings, K tasks created, J ideas.

### Decisions Made
- [decision or outcome] (Day)

### Work Completed
- [item completed or merged] (Day)

### In Progress
- [item still in progress at week end]

### Blocked
- ⚠️ [blocked item] — reason (since Day)

### Thread Lifecycles
- **[item]**: opened Day (status) → status Day [→ resolved Day ✓]
- ⚠️ **[item]**: opened Day (status) → still status Day

### Intention vs. Outcome
Intention tracking not available (retroactive digest from migration).

## Correction Analysis

Insufficient data for threshold recommendation (retroactive digest from migration — no classification data available).

## Stale Items

Not available (retroactive digest from migration).

## Reflection Prompts

[Generate 3-5 questions based on the week's content:
- Thread stuck all week — escalation needed?
- Meetings without notes logged — cancelled or uncaptured?
- Parallel workstreams that might need coordination?
- Patterns in the week worth noting?]
````

**Format rules:** Same as `/eod` Step 6 — omit empty subsections, trace thread lifecycles from daily Open Threads data. Intention tracking unavailable for retroactive digests.

### Step 3: Generate Monthly Digests

**Skip if `monthly` is not in `level`.**

For each month in `MONTHS`:

**3a. Check if digest already exists:**

```bash
obsidian vault={{VAULT_NAME}} search query="YYYY-MM-monthly-digest" path="04 Data" format=json
```

If found, skip this month.

**3b. Gather weekly digests:**

Find all weekly digests with `period_start` falling within this month. Read each to extract `## Week Summary` sections.

If no weekly digests exist for weeks in this month, read the daily notes directly instead and aggregate from their `## Day Summary` sections.

**3c. Create the monthly digest file:**

**File:** `04 Data/YYYY/MM/YYYY.MM.DD-monthly-digest.md` (where `YYYY.MM.DD` is the last day of the month)

**Frontmatter:**
```yaml
---
type: digest
digest_type: monthly
aliases:
  - YYYY-MM-monthly-digest
period_start: YYYY-MM-01
period_end: YYYY-MM-DD  # Last day of month
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags:
  - digest
---
```

**Body** (follow `/eod` Step 7 structure):

````markdown
## Month Summary

N work days active. M meetings total. K tasks created, J completed.

### Key Decisions
- [significant decision] (W##)

### Major Completions
- [completed item or milestone] (W##)

### Persistent Threads
- **[thread]** — status at month end (first appeared W##)
- ⚠️ **[thread]** — blocked N+ days across M weeks

### New Initiatives
- [projects or tasks started this month]

## Trends

- **Meetings per week:** [counts]
- **Type distribution:** [% meeting, person, task, idea, admin, project]
- **Active days:** [days with notes vs total days in month]

## Reflection Prompts

[Generate 3-5 bigger-picture questions:
- Most active project and its trajectory
- Persistent threads — escalation or acceptance?
- Ideas aging without promotion
- People interactions — anyone missing?
- Meeting frequency — sustainable?]
````

**Format rules:** Same as `/eod` Step 7 — filter for significance (items spanning 2+ weeks), flag persistent threads.

### Step 4: Generate Yearly Digests

**Skip if `yearly` is not in `level`.**

For each year in `YEARS`:

**4a. Check if digest already exists:**

```bash
obsidian vault={{VAULT_NAME}} search query="YYYY-yearly-digest" path="04 Data" format=json
```

If found, skip this year.

**4b. Gather monthly digests:**

Find all monthly digests for this year (12 max). Read each to extract `## Month Summary` and `## Trends` sections.

If fewer than 12 monthly digests exist (partial year), note which months are covered.

**4c. Create the yearly digest file:**

**File:** `04 Data/YYYY/12/YYYY.12.31-yearly-digest.md`

**Frontmatter:**
```yaml
---
type: digest
digest_type: yearly
aliases:
  - YYYY-yearly-digest
period_start: YYYY-01-01
period_end: YYYY-12-31
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
tags:
  - digest
---
```

**Body** (follow `/eod` Step 7b structure):

```markdown
## Year Summary

[Aggregate monthly digests: key projects completed, team changes, major decisions, growth areas. Synthesize the year's arc — what themes emerged, what shifted, what was accomplished. Under 500 words.

If this is a partial year (e.g., only Oct-Dec), note the coverage period.]

## Trends

- **Captures per month:** [monthly counts, trending up/down/stable]
- **Type distribution shift:** [early months vs late months comparison]
- **Meeting frequency:** [trend across the year]
- **Key relationships:** [most interacted people, based on meeting frequency]

## Key Projects

[List major projects that were active, with status and key milestones.]

## Reflection Prompts

[Year-level questions:
- Most active quarter and what drove it
- Key relationships that faded
- Ideas never promoted — review or archive?
- Meeting frequency sustainability
- What to do differently next year]
```

### Step 5: Git Commit

Single batched commit for all generated digests:

```bash
git add -A
git commit -m "sb: /generate-digests — START_DATE to END_DATE [daily] [weekly] [monthly] [yearly]" -m "
- [list each digest created: daily for YYYY-MM-DD, weekly W06, monthly Jan 2026, etc.]
"
```

Build the summary line from which levels were actually generated (skip levels that had nothing to create because digests already existed).

## Important Notes

- **Idempotency:** Every step checks for existing digests before creating. Re-running is always safe.
- **Order matters:** Run `daily` before `weekly`, `weekly` before `monthly`, `monthly` before `yearly`. If `level=all`, steps execute in this order automatically.
- **Daily note creation:** If a daily note doesn't exist for a date that has notes, create it with the inline Bases template from `/today` Step 0 before appending the digest.
- **Partial periods:** Weekly digests at the boundary of the date range may cover days outside the range — that's fine, use whatever daily notes exist.
- **No classification data:** Retroactive digests don't have classification activity. Correction Analysis and Stale Items sections should note this explicitly.

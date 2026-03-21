# /gh-import — Import or Update a GitHub Issue/PR

Import a GitHub issue or pull request into the vault, or update an existing one with new activity. Creates a `type: github` note with AI-generated summaries of the discussion.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## When to Use

Run this command when the user provides a GitHub URL or reference:
- "Import https://github.com/elastic/kibana/issues/12345"
- "Update the kibana 12345 issue"
- "gh-import elastic/kibana#12345"
- A bare GitHub URL pasted into the terminal

## Prerequisites

- `gh` CLI authenticated
- `jq` installed
- Obsidian running (for CLI operations)
- Load type schema: `05 Meta/claude/github.claude.md`

## Steps

### Step 1: Parse Input

Accept any of these formats:
- Full URL: `https://github.com/owner/repo/issues/123` or `.../pull/123`
- Shorthand: `owner/repo#123`

Extract:
- `OWNER_REPO` — e.g., `elastic/kibana`
- `REPO` — just the repo name, e.g., `kibana`
- `NUMBER` — the issue/PR number
- `GITHUB_URL` — normalize to full URL if shorthand was given

If a shorthand was given without a URL, construct the URL after detecting issue vs PR (Step 3 will reveal this).

### Step 2: Search Vault for Existing Note

Check if this issue/PR already has a vault note, using three methods in order:

**Primary — GitHub.base query:**
```bash
obsidian vault=second-brain base:query path="02 Areas/GitHub.base" format=json
```
Parse the JSON output (strip the loading line). Look for an entry where `github_repo` matches `OWNER_REPO` and `github_number` matches `NUMBER`.

**Fallback 1 — Frontmatter search:**
```bash
obsidian vault=second-brain search query="github_url: GITHUB_URL" format=json
```

**Fallback 2 — Alias lookup:**
```bash
obsidian vault=second-brain read file="gh-REPO-NUMBER"
```
(e.g., `file="gh-kibana-12345"`)

If any method finds a match, the note **exists** — proceed to Step 4 (Update).
If no match, the note is **new** — proceed to Step 3 (Create).

### Step 3: Create New Note

#### 3a: Fetch full data

```bash
"05 Meta/scripts/gh-fetch" "GITHUB_URL"
```

Capture the JSON output. This contains:
- `metadata` — title, state, author, created_at, labels, assignees, url
- `comments` — all comments (opening post + discussion), sorted chronologically
- `events` — label changes, assignments, state changes
- `pr_specific` — merge/review info (PRs only)
- `newest_activity` — ISO timestamp for `github_last_synced`

#### 3b: Determine file naming

```
ALIAS = gh-REPO-NUMBER          (e.g., gh-kibana-12345)
FILENAME = YYYY.MM.DD-ALIAS.md  (e.g., 2026.02.13-gh-kibana-12345.md)
FILE_PATH = 04 Data/YYYY/MM/FILENAME
```

Use today's date for the filename (import date).

#### 3c: Generate AI summary

Analyze ALL comments and events from the gh-fetch output. Write a summary that:
- Captures the full arc of the discussion — what was proposed, debated, decided
- Prioritizes design decisions and points of debate over boilerplate
- Includes key participants and their positions
- Notes any label/assignment/state changes that occurred
- For PRs: mentions review status, CI status, merge state
- Length is proportional to content — a 5-comment thread gets a short summary, a 100-comment design discussion gets a thorough one

#### 3d: Build note content

Determine `github_type`:
- If the gh-fetch output has `is_pr: true` → `pr`
- Otherwise → `issue`

Assemble the full markdown content:

```markdown
---
type: github
github_type: "GITHUB_TYPE"
github_repo: "OWNER_REPO"
github_number: NUMBER
github_url: "GITHUB_URL"
github_state: "STATE"
github_author: "AUTHOR"
github_labels: [LABELS]
github_assignees: [ASSIGNEES]
github_last_synced: "NEWEST_ACTIVITY"
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
aliases: [ALIAS]
tags: [github]
classified_at: "YYYY-MM-DD HH:mm"
confidence: 1.0
---
# TITLE

[OWNER_REPO#NUMBER](GITHUB_URL) | Created YYYY-MM-DD by @AUTHOR

## My Notes


## Activity Summaries

### YYYY-MM-DD — Initial import (CREATED_DATE to NEWEST_ACTIVITY_DATE, N comments)

AI_SUMMARY_HERE
```

Replace all placeholders with actual values from the gh-fetch output. The date ranges in the summary heading should use `YYYY-MM-DD` format (extracted from ISO timestamps).

#### 3e: Create the note

```bash
obsidian vault=second-brain create path="FILE_PATH" content="FULL_CONTENT" silent
```

Verify the note was created:
```bash
obsidian vault=second-brain read file="ALIAS"
```

#### 3f: Confirm

Report to the user:
```
Imported: [[FILENAME|ALIAS]] — "TITLE"
  Type: issue/pr | State: open/closed | Comments: N
  Summary covers: START_DATE to END_DATE
```

Where `FILENAME` is the full filename (e.g., `2026.02.13-gh-kibana-12345`) and `ALIAS` is the short name (e.g., `gh-kibana-12345`).

#### 3g: Git commit

```bash
git add "04 Data/YYYY/MM/FILENAME"
git commit -m "sb: import gh-REPO-NUMBER"
```

### Step 4: Update Existing Note

#### 4a: Read existing note

```bash
obsidian vault=second-brain read file="ALIAS"
```

Extract from frontmatter:
- `github_last_synced` — the timestamp to use for `--since`
- `github_url` — the canonical URL
- Current title from the `# Title` heading (first `#` line in the body)

#### 4b: Fetch incremental data

```bash
"05 Meta/scripts/gh-fetch" "GITHUB_URL" --since "GITHUB_LAST_SYNCED"
```

Check the output:
- If `comment_count` is 0 AND `event_count` is 0: report "No new activity on OWNER_REPO#NUMBER since last sync" and **stop** (no update needed).
- Otherwise: proceed with the update.

#### 4c: Generate AI summary of new activity

Analyze only the NEW comments and events (everything returned by the incremental fetch). Write a summary that:
- Focuses on what changed since the last sync
- Captures new discussion, decisions, and positions
- Notes any label/assignment/state changes
- For PRs: mentions new reviews, CI results, merge status changes
- Length is proportional to content

#### 4d: Check for title mismatch

Compare the `metadata.title` from gh-fetch with the existing `# Title` heading in the note.

If they differ, prepend this notice line before the summary text:
```markdown
> **Title changed:** "Old Title" → "New Title"
```

#### 4e: Update frontmatter properties

```bash
obsidian vault=second-brain property:set file="ALIAS" property=github_state value="NEW_STATE"
obsidian vault=second-brain property:set file="ALIAS" property=github_labels value='["label1","label2"]' type=list
obsidian vault=second-brain property:set file="ALIAS" property=github_assignees value='["user1"]' type=list
obsidian vault=second-brain property:set file="ALIAS" property=github_last_synced value="NEWEST_ACTIVITY"
```

#### 4f: Append summary

Build the new summary block:

```markdown

### YYYY-MM-DD — Update (LAST_SYNCED_DATE to NEWEST_ACTIVITY_DATE, N new comments, M events)

[optional title changed notice]

AI_SUMMARY_HERE
```

Append to the note:
```bash
obsidian vault=second-brain append file="ALIAS" content="SUMMARY_BLOCK"
```

#### 4g: Confirm

Report to the user:
```
Updated: [[FILENAME|ALIAS]] — "TITLE"
  New activity: N comments, M events (LAST_SYNCED to NEWEST_ACTIVITY)
  State: open/closed | Labels: [labels]
```

Where `FILENAME` is the full filename (e.g., `2026.02.13-gh-kibana-12345`) and `ALIAS` is the short name (e.g., `gh-kibana-12345`).

#### 4h: Git commit

```bash
git add -A
git commit -m "sb: update gh-REPO-NUMBER"
```

## Batch Import

If the user provides multiple URLs or says "import all from ...", process them sequentially. The rate-limit-aware queue in `gh-fetch` handles API limits automatically. Report progress after each item.

## Error Handling

- If `gh-fetch` fails: report the error and the URL that failed, continue with remaining items if batch
- If Obsidian CLI fails: check that Obsidian is running, report the error
- If the note creation/update fails: report and do not commit
- Strip the Obsidian CLI loading line (matches `^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} Loading`) from all CLI output before parsing

# /notion-import — Import or Update a Notion Page

Import a Notion page (or database item) into the vault, or update an existing one with new activity. Creates a `type: notion` note with an AI-generated summary of the page content and any change history.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## When to Use

Run this command when the user provides a Notion URL or ID:
- "Import https://www.notion.so/workspace/Q2-Roadmap-abc123..."
- "Update the Q2 roadmap Notion page"
- A bare Notion URL pasted into the terminal

## Prerequisites

- Notion MCP configured (`mcp__claude_ai_Notion__notion-*` tools available)
- Obsidian running (for CLI operations)
- Load type schema: `05 Meta/claude/notion.claude.md`

## Steps

### Step 1: Parse Input

Accept:
- Full URL: `https://www.notion.so/.../Page-Title-<id>`
- Bare page ID (32-char UUID, with or without hyphens)

Extract:
- `NOTION_URL` — full URL (or reconstruct from ID)
- `NOTION_ID` — the page ID (normalize to hyphenated UUID form)

### Step 2: Search Vault for Existing Note

Check if this page already has a vault note:

**Primary — Notion.base query:**
```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Notion.base" format=json
```
Parse the JSON output. Look for an entry where `notion_id` matches `NOTION_ID`.

**Fallback — Frontmatter search:**
```bash
obsidian vault={{VAULT_NAME}} search query="notion_id: NOTION_ID" format=json
```

If a match is found, the note **exists** — proceed to Step 4 (Update).
If no match, the note is **new** — proceed to Step 3 (Create).

### Step 3: Create New Note

#### 3a: Fetch the page

Use the Notion MCP:
```
mcp__claude_ai_Notion__notion-fetch with url=NOTION_URL
```

From the response, extract:
- `title` — page title
- `last_edited_time` — ISO timestamp
- `created_time` — ISO timestamp
- Status / Assignee / Due / other database properties (when `notion_type == database_item`)
- The page body (convert to markdown if needed)

If the page is part of a database, also note:
- `notion_database` — parent database ID
- `notion_database_name` — database title (fetch once with `notion-fetch` on the database URL if not already in context)

#### 3b: Determine file naming

Derive `slug`:
- Lowercase the title
- Replace any non-alphanumeric run with a single hyphen
- Trim leading/trailing hyphens
- If empty (untitled), use `<first-8-chars-of-id>`

Build:
```
ALIAS = notion-<slug>                (e.g., notion-q2-roadmap)
FILENAME = YYYY.MM.DD-ALIAS.md       (e.g., 2026.04.22-notion-q2-roadmap.md)
FILE_PATH = 04 Data/YYYY/MM/FILENAME
```

Use today's date for the filename (import date).

If a file with `ALIAS` already exists from another import, append `-2`, `-3`, etc. to the slug.

#### 3c: Generate AI summary

Analyze the page body and metadata. Write a summary that:
- Captures what the page is for and what state it is in
- For tasks: notes status, assignee, due date, and any blockers called out in the body
- For docs: summarizes the main decisions / open questions / structure
- Keeps length proportional — a short task entry gets a one-liner, a design doc gets a thorough summary

#### 3d: Determine `notion_type`

- If the page is a database item (has `parent.database_id`) → `database_item` (or `task` if the parent database is listed in `notion.task_databases` in `config.yaml`)
- Otherwise → `page`

#### 3e: Build note content

```markdown
---
type: notion
notion_type: "NOTION_TYPE"
notion_id: "NOTION_ID"
notion_url: "NOTION_URL"
notion_title: "TITLE"
notion_database: "DATABASE_ID_OR_EMPTY"
notion_database_name: "DATABASE_NAME_OR_EMPTY"
notion_status: "STATUS_OR_EMPTY"
notion_assignee: [ASSIGNEES]
notion_waiting_on: [WAITING_ON]
notion_due: "YYYY-MM-DD_OR_EMPTY"
notion_last_edited: "LAST_EDITED_TIME"
notion_last_synced: "NOW_ISO"
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
aliases: [ALIAS]
tags: [notion]
classified_at: "YYYY-MM-DD HH:mm"
confidence: 1.0
---
# TITLE

[Notion](NOTION_URL) | INFO_LINE

## My Notes


## Activity Summaries

### YYYY-MM-DD — Initial import (created CREATED_DATE, last edited LAST_EDITED_DATE)

AI_SUMMARY_HERE
```

Build `INFO_LINE` conditionally:
- If it's a task: `Assigned: @ASSIGNEE | Status: STATUS | Due: DUE`
- If it's a page: `Created YYYY-MM-DD | Last edited YYYY-MM-DD`

Leave `notion_assignee` / `notion_waiting_on` as empty lists if not present. Leave `notion_database`, `notion_database_name`, `notion_status`, `notion_due` as empty strings if not present.

Resolve assignee user IDs to display names via `mcp__claude_ai_Notion__notion-get-users` (bulk lookup once, cache for the session).

#### 3f: Create the note

```bash
obsidian vault={{VAULT_NAME}} create path="FILE_PATH" content="FULL_CONTENT" silent
```

Verify creation:
```bash
obsidian vault={{VAULT_NAME}} read file="ALIAS"
```

#### 3g: Confirm

```
Imported: [[FILENAME|ALIAS]] — "TITLE"
  Type: page/database_item/task | Status: STATUS | Assignee: @ASSIGNEE
  Last edited: LAST_EDITED_DATE
```

#### 3h: Git commit

```bash
git add "04 Data/YYYY/MM/FILENAME"
git commit -m "sb: import notion-<slug>"
```

### Step 4: Update Existing Note

#### 4a: Read existing note

```bash
obsidian vault={{VAULT_NAME}} read file="ALIAS"
```

Extract from frontmatter:
- `notion_last_edited` — compared against the fresh fetch to decide if an update is needed
- `notion_url` — canonical URL
- `notion_id` — for re-fetch
- Current `# Title` heading

#### 4b: Re-fetch the page

```
mcp__claude_ai_Notion__notion-fetch with url=NOTION_URL
```

Compare the new `last_edited_time` with the stored `notion_last_edited`. If they are equal, report "No changes on TITLE since last sync" and **stop**.

#### 4c: Generate AI summary of changes

Describe what changed since the last sync:
- Status transitions (e.g. `In Progress` → `Done`)
- Assignee / waiting-on changes
- Due-date changes
- New body content or comments (if visible in the fetch)
- Title changes

Keep the summary proportional to the delta — a status-only change is a one-liner.

#### 4d: Check for title mismatch

Compare `title` from the fetch with the existing `# Title` heading. If they differ, prepend:
```markdown
> **Title changed:** "Old Title" → "New Title"
```

#### 4e: Update frontmatter properties

```bash
obsidian vault={{VAULT_NAME}} property:set file="ALIAS" property=notion_status value="NEW_STATUS"
obsidian vault={{VAULT_NAME}} property:set file="ALIAS" property=notion_assignee value='["user1"]' type=list
obsidian vault={{VAULT_NAME}} property:set file="ALIAS" property=notion_waiting_on value='["user2"]' type=list
obsidian vault={{VAULT_NAME}} property:set file="ALIAS" property=notion_due value="NEW_DUE"
obsidian vault={{VAULT_NAME}} property:set file="ALIAS" property=notion_last_edited value="NEW_LAST_EDITED"
obsidian vault={{VAULT_NAME}} property:set file="ALIAS" property=notion_last_synced value="NOW_ISO"
```

Skip any property whose value is unchanged.

#### 4f: Append summary

```markdown

### YYYY-MM-DD — Update (LAST_SYNCED_DATE to NEW_LAST_EDITED_DATE)

[optional title changed notice]

AI_SUMMARY_HERE
```

```bash
obsidian vault={{VAULT_NAME}} append file="ALIAS" content="SUMMARY_BLOCK"
```

#### 4g: Confirm

```
Updated: [[FILENAME|ALIAS]] — "TITLE"
  Changes: <1-line delta>
  Status: STATUS | Assignee: @ASSIGNEE
```

#### 4h: Git commit

```bash
git add -A
git commit -m "sb: update notion-<slug>"
```

## Batch Import

If the user provides multiple URLs, process them sequentially. Report progress after each.

## Error Handling

- If the Notion MCP call fails (auth, permission, 404): report the error and the URL, continue with remaining items if batch
- If Obsidian CLI fails: check that Obsidian is running, report the error
- If the note creation/update fails: report and do not commit
- Strip the Obsidian CLI loading line (matches `^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} Loading`) from all CLI output before parsing

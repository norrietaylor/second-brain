# Type: Notion

Tracked Notion pages and database items (tasks, docs, project pages), imported via `/notion-import` or the `notion-onmyplate` skill. Each note contains the user's private annotations plus chronological AI-generated summaries of page activity.

All Notion API access happens through the Notion MCP (`mcp__claude_ai_Notion__notion-*` tools) — there is no CLI shell script equivalent of `gh-fetch`.

## Required Fields
- `notion_type` — One of `page`, `database_item`, `task`
- `notion_id` — Notion's page ID (UUID, used for dedup and MCP fetches)
- `notion_url` — Canonical Notion URL
- `notion_title` — Page title at import time

## Optional Fields
- `notion_database` — Parent database ID (if the page is a database item)
- `notion_database_name` — Human-readable database name (e.g. "Tasks", "Follow-ups")
- `notion_status` — Status value from the page (e.g. `Todo`, `In Progress`, `Done`)
- `notion_assignee` — Notion user(s) the page is assigned to
- `notion_waiting_on` — Person(s) the user is waiting on (for follow-ups the user owns)
- `notion_due` — Due date if present (`YYYY-MM-DD`)
- `notion_last_edited` — ISO timestamp of the page's `last_edited_time` from Notion (used for change detection)
- `notion_last_synced` — ISO timestamp of the last time this note was synced (set by automation)
- `tags` — Always includes `notion`; may include additional topic tags

## Universal Fields (always present)
- `type: notion`
- `created` — Creation datetime (YYYY-MM-DD HH:mm) — import date, not Notion creation date
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Format: `notion-<slug>` where slug is a kebab-cased, de-deduped form of the title (e.g. `notion-q2-roadmap`)
- `classified_at` — Set to creation time on import (not reclassified by /eod)
- `confidence` — Always `1.0` (not AI-classified)

## File Naming

```
YYYY.MM.DD-notion-<slug>.md
```

The date is the **import date** (when the note was created in the vault). The slug is derived from the Notion page title: lowercased, non-alphanumerics replaced with hyphens, collapsed and trimmed. For untitled pages, fall back to `notion-<first-8-chars-of-id>`.

## Body Structure

The body has three sections, always in this order:

### 1. Title and Info Line (static after creation)

```markdown
# Page Title

[Notion](https://www.notion.so/...) | Assigned: @someone | Due: 2026-05-01
```

The title and info line are set on initial import and NOT updated automatically. If the Notion title changes, a notice is appended with the summary (see Update Rules below).

### 2. My Notes (user-owned)

```markdown
## My Notes

(user's annotations — automation NEVER touches this section)
```

This section is exclusively for the user's private annotations, thoughts, and context they don't want pushed to Notion. Automation must never read from, write to, or modify this section.

### 3. Activity Summaries (append-only)

```markdown
## Activity Summaries

### 2026-04-22 — Initial import (page created 2026-03-14, last edited 2026-04-20)

AI-generated summary of the page content and any recent edits...

### 2026-04-29 — Update (2026-04-22 to 2026-04-29, status: In Progress → Done)

Summary of what changed since last sync...
```

Each summary is a `###` sub-heading under `## Activity Summaries`. New summaries are appended to the **end of the file** (always the last section).

## Update Rules

When updating an existing note (`/notion-import` or the on-my-plate sync):

1. **Update frontmatter** via `obsidian property:set`:
   - `notion_status` — current status
   - `notion_assignee` — current assignee(s)
   - `notion_waiting_on` — current waiting-on list
   - `notion_due` — current due date
   - `notion_last_edited` — the page's `last_edited_time` from the new fetch
   - `notion_last_synced` — now

2. **Append summary** via `obsidian append`:
   - A new `### YYYY-MM-DD — Update (...)` block at the end of the file
   - If the Notion title has changed since the note's `# Title` heading, prepend a notice line:
     ```markdown
     > **Title changed:** "Old Title" → "New Title"
     ```

3. **Never modify** the `# Title` heading, info line, or `## My Notes` section.

4. **No-op on no change**: If `last_edited_time` from Notion equals `notion_last_edited` on the note, skip the update entirely.

## Summary Guidelines

Summaries should be **proportional to the content** they cover:
- Prioritize status transitions, due-date changes, and what was actually decided or completed
- A page whose only change is a status bump gets a one-liner
- A doc with new discussion or significant new body content gets a thorough summary
- Include assignee/waiting-on changes when they occurred

## Vault Lookup

To find an existing Notion note in the vault (in priority order):

1. **Primary**: Query `02 Areas/Notion.base` via `obsidian base:query path="02 Areas/Notion.base" format=json` and filter by `notion_id`
2. **Fallback**: `obsidian search query="notion_id: <id>" format=json`
3. **Fallback**: `obsidian read file=notion-<slug>` (alias lookup)

## Data Fetching

All Notion data comes from the Notion MCP:

- **Single page**: `mcp__claude_ai_Notion__notion-fetch` with the page URL or ID
- **Task discovery**: `mcp__claude_ai_Notion__notion-search` — scope by `query` (for mentions/waiting-on) or by `data_source_url` (for task databases listed in `notion.task_databases` in `config.yaml`)
- **User mapping**: `mcp__claude_ai_Notion__notion-get-users` to resolve `notion_assignee` / `notion_waiting_on` IDs to display names on first use

The MCP's `last_edited_time` field is the authoritative source for `notion_last_edited`.

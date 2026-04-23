---
name: notion-onmyplate
description: Check what's on the user's Notion plate by querying task databases, mentions, and waiting-on items. Use when the user asks about Notion tasks, follow-ups, what's assigned to them in Notion, what they're waiting on from others, or what they owe replies to in Notion.
---

# Notion: What's On My Plate

This skill reports what needs the user's attention in Notion. Unlike `gh-onmyplate` / `gl-onmyplate`, there is no CLI — all queries go through the **Notion MCP** (`mcp__claude_ai_Notion__notion-*` tools).

Three buckets, each a separate query:

1. **Assigned to me** — Tasks where the user is the assignee in a known task database
2. **I'm mentioned / need to follow up** — Pages where the user is @mentioned recently (and may owe a reply)
3. **Waiting on others** — Tasks the user owns where someone else is the assignee or is listed in a `Waiting on` / `Follow-up` property

## Configuration

Everything this skill needs is in `05 Meta/config.yaml` under `notion:`:

```yaml
notion:
  self_name: "Jane Smith"          # used to match assignee / mentions
  task_databases:                  # databases that hold tasks
    - "abc123..."
    - "def456..."
  mention_lookback_days: 7         # how far back to look for mentions
  follow_up_wait_days: 3           # flag items waiting on others for N+ days
```

Read this file first. If `task_databases` is empty, skip bucket 1 and tell the user to add database IDs to the config.

## Workflow

### Step 1: Resolve the user's Notion identity

The `notion_assignee` and mentions fields in Notion are user IDs (UUIDs), not names. Resolve `notion.self_name` (from config) to the matching Notion user ID using:

```
mcp__claude_ai_Notion__notion-get-users
```

Cache the result for the session — don't re-query for each bucket.

### Step 2: Query each bucket

#### Bucket 1 — Assigned to me

For each database ID in `notion.task_databases`:

```
mcp__claude_ai_Notion__notion-fetch with url=<database_url>
```

(or use `notion-search` scoped to the database). Filter the results to items where:
- The assignee / owner property contains the user's Notion user ID, AND
- The status is not `Done` / `Archived` / similar terminal state

Collect: `id`, `url`, `title`, `status`, `due_date`, `last_edited_time`, parent database name.

#### Bucket 2 — I'm mentioned / need to follow up

Search for pages that mention the user:

```
mcp__claude_ai_Notion__notion-search with query="@<self_name>"
```

(Or, if the MCP exposes a dedicated mentions lookup, prefer that.) Filter to items with `last_edited_time` within `mention_lookback_days`. Skip anything already covered by Bucket 1 (dedup by page ID).

For each hit, fetch just enough context to determine "does the user owe a reply?" — typically the last few lines after the user's mention.

#### Bucket 3 — Waiting on others

For each database in `notion.task_databases`:

- Find items where the user is the **creator / owner** (not assignee), AND
- An assignee or `Waiting on` / `Follow-up` property points to someone else, AND
- `last_edited_time` is older than `follow_up_wait_days` days ago (stale — time to nudge)

Collect: `id`, `url`, `title`, `waiting_on_name`, `last_edited_time`, `due_date`.

### Step 3: Cross-reference the vault

For items across all three buckets, check if there's already a `type: notion` note in the vault:

```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Notion.base" format=json
```

For each query result, filter by `notion_id` matching the MCP result. The output tells you:
- **Has vault note** — cite the vault alias in the briefing (`[[notion-<slug>]]`)
- **No vault note** — suggest `/notion-import <url>` as a follow-up action

### Step 4: Synthesize the briefing

Present a summary grouped by bucket. Use clear visual separation so the user can scan quickly:

**Assigned to me:**
- For each: title, status, due date (or "no due date"), parent database, URL
- Sort: overdue first, then by due date ascending, then `last_edited_time` descending
- Flag items overdue or due today

**I'm mentioned (last N days):**
- For each: title, who mentioned the user, 1-sentence summary of the surrounding context, URL
- Sort: most recent first
- Mark "likely needs reply" vs "FYI"

**Waiting on others (idle ≥N days):**
- For each: title, waiting on whom, days since last edit, URL
- Sort: oldest idle first

At the end, list any items that don't yet have a vault note and suggest: `Consider /notion-import for: <URLs>`.

Always present URLs as full clickable links (`https://www.notion.so/...`), not markdown-wrapped text.

## When to Use This Skill

Trigger on prompts like:
- "What's on my Notion plate?"
- "What Notion tasks are assigned to me?"
- "What am I waiting on in Notion?"
- "Any Notion follow-ups I owe?"
- "Check Notion for pending tasks"

Do NOT use this skill to:
- Import a specific page — that's `/notion-import`
- Search Notion for arbitrary content — use `mcp__claude_ai_Notion__notion-search` directly
- Create or edit Notion pages — this skill is read-only

## Known Limitations

- **User ID resolution** depends on `notion-get-users` returning the user with a matching display name. If the user's Notion display name differs from `notion.self_name` in config, adjust the config.
- **Mentions search** is approximate — `notion-search` with an `@name` query may pick up the name as plain text, not just mentions. Filter results heuristically (e.g. "does the page body actually contain an @-mention block near `last_edited_time`?").
- **Property schema varies per database** — "status" may be called `Status`, `State`, or a custom name. When fetching a new database for the first time, inspect the property schema and record the mapping to `notion_status` / `notion_due` / `notion_assignee` in session notes for reuse.
- **Archived pages** are typically excluded by the MCP by default, but confirm via `archived: false` in the response if rigor matters.
- **No sync direction back to Notion** — this skill is strictly read-only. Status updates in the vault (e.g. marking a `type: notion` note as done) do not propagate back to Notion.

# Type: GitHub

Tracked GitHub issues and pull requests, imported via `/gh-import` or `/today`.
Each note contains the user's private annotations and chronological AI-generated
summaries of the thread's activity.

## Required Fields
- `github_type` — Either `issue` or `pr`
- `github_repo` — Full `owner/repo` string (e.g., `elastic/kibana`)
- `github_number` — Issue or PR number (integer)
- `github_url` — Full GitHub URL (e.g., `https://github.com/elastic/kibana/issues/12345`)
- `github_state` — Current state: `open`, `closed`, or `merged` (PRs only)
- `github_author` — GitHub login of the author

## Optional Fields
- `github_labels` — List of label names (e.g., `[bug, "team:security"]`)
- `github_assignees` — List of assigned GitHub logins
- `github_last_synced` — ISO timestamp of the newest activity from the last fetch (set by automation, used for incremental updates)
- `tags` — Always includes `github`; may include additional topic tags

## PR-Specific Optional Fields
- `github_draft` — Boolean, true if PR is a draft
- `github_base_branch` — Target branch (e.g., `main`)

## Universal Fields (always present)
- `type: github`
- `created` — Creation datetime (YYYY-MM-DD HH:mm) — import date, not GitHub creation date
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Format: `gh-<short-repo>-<number>` (e.g., `gh-kibana-12345`)
- `classified_at` — Set to creation time on import (not reclassified by /eod)
- `confidence` — Always `1.0` (not AI-classified)

## File Naming

```
YYYY.MM.DD-gh-<short-repo>-<number>.md
```

The date is the **import date** (when the note was created in the vault), not the GitHub issue/PR creation date. The short-repo is the repository name without the org (e.g., `kibana` from `elastic/kibana`).

For org-ambiguous repos, use the full form: `gh-<owner>-<repo>-<number>`.

## Body Structure

The body has three sections, always in this order:

### 1. Title and Info Line (static after creation)

```markdown
# Issue Title Here

[elastic/kibana#12345](https://github.com/elastic/kibana/issues/12345) | Created 2025-12-01 by @someuser
```

The title and info line are set on initial import and NOT updated automatically. If the GitHub title changes, a notice is appended with the summary (see Update Rules below).

### 2. My Notes (user-owned)

```markdown
## My Notes

(user's annotations — automation NEVER touches this section)
```

This section is exclusively for the user's private annotations, thoughts, and context that they don't want posted to GitHub. Automation must never read from, write to, or modify this section.

### 3. Activity Summaries (append-only)

```markdown
## Activity Summaries

### 2026-02-13 — Initial import (2025-12-01 to 2026-02-13, 23 comments)

AI-generated summary of the issue and all discussion...

### 2026-02-14 — Update (2026-02-13 to 2026-02-14, 5 new comments, 2 events)

AI-generated summary of new activity since last sync...
```

Each summary is a `###` sub-heading under `## Activity Summaries`. New summaries are appended to the **end of the file** (always the last section).

## Update Rules

When updating an existing note (`/gh-import` or `/today`):

1. **Update frontmatter** via `obsidian property:set`:
   - `github_state` — current state
   - `github_labels` — current labels
   - `github_assignees` — current assignees
   - `github_last_synced` — timestamp of the newest activity from this fetch

2. **Append summary** via `obsidian append`:
   - A new `### YYYY-MM-DD — Update (...)` block at the end of the file
   - If the GitHub title has changed since the note's `# Title` heading, prepend a notice line above the summary text:
     ```markdown
     > **Title changed:** "Old Title" → "New Title"
     ```

3. **Never modify** the `# Title` heading, info line, or `## My Notes` section.

4. **No-op on no new activity**: If gh-fetch returns no new comments or events since `github_last_synced`, report "no changes" and skip the update entirely.

## Summary Guidelines

Summaries should be **proportional to the content** they cover:
- Prioritize design decisions, points of debate, and outcomes
- A 5-comment substantive design discussion gets a thorough summary
- A 20-comment thread of CI bot noise gets a one-liner
- No artificial word limits — let the content dictate the length
- Include label/assignment changes and state changes when they occurred
- For initial imports of large issues, provide a comprehensive narrative that captures the full arc of the discussion

## Vault Lookup

To find an existing GitHub note in the vault (in priority order):

1. **Primary**: Query `02 Areas/GitHub.base` via `obsidian base:query path="02 Areas/GitHub.base" format=json` and filter results by `github_url`
2. **Fallback**: `obsidian search query="github_url: <url>" format=json`
3. **Fallback**: `obsidian file=gh-<repo>-<number>` (alias lookup)

## Data Fetching

The `05 Meta/scripts/gh-fetch` shell script handles all GitHub API interaction:

```bash
# Full fetch (initial import)
05 Meta/scripts/gh-fetch https://github.com/owner/repo/issues/123

# Incremental fetch (update)
05 Meta/scripts/gh-fetch https://github.com/owner/repo/issues/123 --since 2026-02-10T00:00:00Z
```

Output is structured JSON with metadata, comments, events, and pr_specific fields. The `newest_activity` field in the output should be used as the value for `github_last_synced`.

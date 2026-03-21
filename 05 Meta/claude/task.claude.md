# Type: Task

Actionable items with due dates and priority. Use this for things you need to do.

## Required Fields
- `task` — Clear description of the actionable item
- `due` — Due date (YYYY-MM-DD)
- `status` — One of: `pending`, `in_progress`, `done`
- `priority` — One of: `high`, `medium`, `low`

## Optional Fields
- `project` — Wikilink to related project note (e.g., `"[[api-redesign]]"`)
- `tags` — Relevant topic tags

## Universal Fields (always present)
- `type: task`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- Tasks are actionable items with due dates — use `type: admin` for non-actionable reference
- Priority defaults to `medium` if not specified or unclear from context
- When status changes to "done", note the outcome in the body under ## Details
- Overdue tasks (due < today, status != done) are flagged prominently in /today
- The `project` field links this task to a project note for cross-referencing in Bases views
- If no explicit due date is mentioned, infer a reasonable one (today for urgent, end of week for normal)

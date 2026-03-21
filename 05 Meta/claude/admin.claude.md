# Type: Admin

Non-actionable logistics, reference material, and policies.
For actionable items with due dates, use `type: task` instead.
For meeting notes, use `type: meeting` instead.

## Required Fields
- `description` — Brief description of what this note covers

## Optional Fields
- `tags` — Relevant topic tags

## Universal Fields (always present)
- `type: admin`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- Admin notes have NO `due`, `status`, or `priority` fields — those belong on tasks
- Use for: policies, reference info, travel logistics, process docs (NOT meeting notes — use `type: meeting`)
- The body section `## Details` is for the actual content
- If something becomes actionable, create a separate task note and link to it

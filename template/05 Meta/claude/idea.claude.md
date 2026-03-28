# Type: Idea

Creative thoughts, future possibilities, things to explore. Not actionable yet.

## Required Fields
- `name` — Short descriptive name
- `oneliner` — One-sentence summary of the idea

## Optional Fields
- `tags` — Relevant topic tags

## Universal Fields (always present)
- `type: idea`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- Ideas are not actionable — if it has a due date or needs to be done, it's a task
- If an idea matures into something actionable, create a new task or project note and link back
- The body section `## Notes` is for exploration, pros/cons, related thinking
- Keep the `oneliner` genuinely one sentence — it appears in Bases view columns

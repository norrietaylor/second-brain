# Type: Reference

Deep-dive research, technical breakdowns, domain context documents, and collected knowledge on a topic. Not actionable — these are durable reference materials to be consulted later.

## Required Fields
- `name` — Short descriptive name for the reference topic
- `oneliner` — One-sentence summary of what this reference covers

## Optional Fields
- `tags` — Relevant topic tags
- `sources` — List of key sources (Slack channels, GitHub repos, people consulted)

## Universal Fields (always present)
- `type: reference`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- Reference notes are **not actionable** — if something needs doing, create a task or project
- Distinguish from `admin`: admin is logistics/policies; reference is research/deep-dives/technical context
- Distinguish from `idea`: ideas are speculative/exploratory; references document existing knowledge
- Good candidates: product deep-dives, architecture overviews, competitive analysis, historical timelines, domain expertise documents
- The body should be structured for scannability — use headers, tables, and bullet lists
- Keep the `oneliner` genuinely one sentence — it appears in Bases view columns

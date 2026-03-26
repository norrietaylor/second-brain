# Type: Person

Notes about specific individuals — relationship context, interaction history, and follow-ups.

## Required Fields
- `name` — Full name
- `context` — One-line description of relationship/role (e.g., "Engineering lead on Project X")
- `last_touched` — Date of last meaningful interaction (YYYY-MM-DD)

## Optional Fields
- `follow_ups` — List of pending actions related to this person
- `tags` — Relevant topic/project tags

## Universal Fields (always present)
- `type: person`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- Update `last_touched` whenever you interact with this person
- Follow-ups should be specific next actions, not vague intentions
  - Good: "Send architecture doc by Friday"
  - Bad: "Stay in touch"
- If a follow-up is completed, remove it and note the outcome in the body under ## Notes
- The body section `## Notes` is for freeform interaction history and context

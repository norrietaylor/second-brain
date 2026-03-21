# Type: Project

Active work items with milestones, goals, and tracked progress.

## Required Fields
- `name` — Project name
- `status` — One of: `active`, `waiting`, `blocked`, `done`
- `next_action` — Clear, specific next step (required for active projects)

## Optional Fields
- `due` — Target completion date (YYYY-MM-DD)
- `tags` — Relevant topic tags

## Universal Fields (always present)
- `type: project`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Kebab-case name without date prefix

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Conventions
- `next_action` must always be defined for active projects — this is the execution unit
  - Good: "Draft OpenAPI spec for v2 endpoints"
  - Bad: "Work on API stuff"
- Log significant updates under a `## Log` section with date headers (### YYYY-MM-DD)
- When status changes to "done", record the outcome in the body
- For large projects, consider structuring sections as:
  - `## Overview` (stable description)
  - `## Context` (current state, max ~50 lines)
  - `## Log` (append-only history)

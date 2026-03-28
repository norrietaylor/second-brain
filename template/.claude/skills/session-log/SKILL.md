---
name: session-log
description: "Create a session log + summary for ingestion into the Second Brain vault. Use when wrapping up a chat session, ending a work session, or when the user says 'log this session', 'save session', 'session log', or 'capture session'."
---

# Session Log — Capture Session Context for the Second Brain

Write a structured session summary to the Second Brain inbox drop folder for later ingestion into the vault.

## When to Use

- End of a productive work session
- When the user says "log this", "save session", "session log", "capture this session"
- Before switching to a different project or task
- Any time valuable context, decisions, or learnings should be preserved

## The Process

### Step 1: Determine Drop Folder

```bash
INBOX="${SECOND_BRAIN_INBOX:-$HOME/{{VAULT_NAME}}-inbox}"
mkdir -p "$INBOX"
```

### Step 2: Determine Context

Gather from the current session:
- **Project:** The repository name, workspace, or project being worked on
- **What was done:** Key changes, implementations, fixes
- **Decisions made:** Architectural choices, trade-offs, why something was done a certain way
- **Open questions:** Anything unresolved, blocked, or needing follow-up
- **Key files:** Important files that were created or modified

If any of this is unclear from the session context, ask the user.

### Step 3: Write the Session Log

Create a markdown file in the drop folder:

```
INBOX/YYYY.MM.DD-session-HHMMSS.md
```

**Format:**

```markdown
---
type: inbox
source: agent-session
project: "<project-name>"
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
original_text: "<one-line summary of the session>"
tags: [session-log]
---

# Session: <brief title>

**Project:** <project-name>
**Duration:** <approximate time if known>

## What Was Done

- <bullet points of key work completed>

## Decisions

- <architectural choices, trade-offs, rationale>

## Open Questions

- <unresolved items, blockers, things to revisit>

## Key Files

- `path/to/file` — what was changed/created
```

### Step 4: Confirm

Report to the user:

```
Session logged: YYYY.MM.DD-session-HHMMSS.md
  Project: <project-name>
  Drop folder: ~/{{VAULT_NAME}}-inbox/
  Will be ingested on next /today or /eod run, or manually via: sb-ingest
```

## Rules

- Keep summaries concise but complete — this is reference material for future you
- Focus on decisions and rationale over implementation details (code is in git)
- Include enough context that the note makes sense weeks later
- The `original_text` field should be a single sentence summary (used by the classifier)
- Omit empty sections (e.g., skip "Open Questions" if there are none)
- Do NOT run `sb-ingest` — just write the file and let the normal workflow handle it

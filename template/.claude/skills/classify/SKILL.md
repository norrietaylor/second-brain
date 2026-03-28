# Classify and File a Thought

Classify a raw thought into the second brain system and create the appropriate note. Also supports reclassifying existing notes.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## When to Use

Invoke this skill when:
- The user shares a thought, task, idea, or note about a person that should be captured
- `/today` processes unprocessed inbox items
- The user asks to reclassify an existing note (e.g., "that should be a task, not an idea")

## Classification Process

### Step 1: Load Configuration and Tags

Read both files in one batch:
- `05 Meta/config.yaml` — for `classification.confidence_threshold` (default 0.6)
- `05 Meta/context/tags.md` — for the approved tag taxonomy

Use the threshold for the needs_review routing decision. Prefer existing tags over inventing new ones; if a new tag is clearly needed, use it anyway — `/learned` will propose adding it later. Tags should be lowercase, hyphenated.

### Step 2: Analyze the Input

Read the raw text and determine the best category:

| Type | Use When |
|------|----------|
| `person` | About a specific individual — relationship notes, follow-ups, interactions |
| `project` | An active work item, goal with milestones, something being tracked over time |
| `task` | A specific actionable item with a due date or deadline |
| `idea` | A future possibility, creative thought, something to explore (not actionable yet) |
| `meeting` | About a specific meeting — attendees, agenda, log, action items, recurring meeting tracking |
| `admin` | Non-actionable logistics, policies (NOT meetings — use `meeting` type) |
| `reference` | Deep-dive research, technical breakdowns, domain context documents, collected knowledge on a topic |

### Step 3: Assign Confidence

Rate your classification confidence from 0.0 to 1.0:
- **0.9+** — Unambiguous (e.g., "Follow up with Sarah" is clearly about a person)
- **0.7-0.9** — Strong signal but some ambiguity
- **0.5-0.7** — Could go either way
- **Below threshold** — Route to inbox with `status: needs_review`

**If confidence < threshold (from config):** Set `type: inbox`, `status: needs_review`, preserve `original_text`, and skip to Step 6.

### Step 4: Load the Type Schema

Read the schema file for the classified type:

```
05 Meta/claude/<type>.claude.md
```

This tells you the required and optional fields for this note type.

### Step 5: Generate the Filename

Format: `YYYY.MM.DD-<kebab-case-name>.md`

Rules:
- Use today's date
- Derive a short, descriptive kebab-case name from the content
- For person notes: use the person's name (e.g., `sarah-chen`)
- For tasks: use a brief task summary (e.g., `review-api-spec`)
- For projects: use the project name (e.g., `api-redesign`)
- For meetings: use the meeting topic (e.g., `windows-platform`). For 1-on-1s: `1on1-<person>` (e.g., `1on1-sarah-chen`)

The file path is: `04 Data/YYYY/MM/YYYY.MM.DD-<name>.md`

### Step 6: Create the Note

Create the note using Obsidian CLI:

```bash
obsidian vault={{VAULT_NAME}} create path="04 Data/YYYY/MM/YYYY.MM.DD-<name>.md" content="<full markdown content>" silent
```

Obsidian CLI is required — there is no fallback. If the CLI is not available, stop and report the error.

**Frontmatter requirements:**
- ALL universal fields: `type`, `created`, `modified`, `aliases`, `tags`
- ALL required fields for the classified type (per the schema file)
- `aliases` must contain the kebab-case name without the date prefix
- `created` and `modified` in `YYYY-MM-DD HH:mm` format
- `classified_at` — Set to the current datetime (`YYYY-MM-DD HH:mm`)
- `confidence` — Set to the classification confidence score (0.0-1.0)

### Step 7: Log the Classification

Append an entry to `05 Meta/logs/inbox-log.md` using the tagged format:

**For initial classifications (`[initial]`):**

```markdown
### YYYY-MM-DD HH:MM [initial]
- **Input:** "original text snippet"
- **Type:** <type> (confidence: X.XX)
- **Filed:** YYYY.MM.DD-<name>.md
- **Reasoning:** One sentence explaining the classification
```

### Step 8: Git Commit

**When invoked by `/eod`:** Skip this step — `/eod` handles the batch commit in its Step 10.

**Otherwise:**

```bash
git add "04 Data/YYYY/MM/YYYY.MM.DD-<name>.md" "05 Meta/logs/inbox-log.md"
git commit -m "sb: filed '<name>' as <type> (confidence: X.XX)"
```

---

## Reclassification Process

When asked to reclassify an existing note (e.g., "that David meeting note should be a task, not a person"):

### Step R1: Find the Note

Search for the referenced note via Obsidian CLI:

```bash
obsidian vault={{VAULT_NAME}} search query="<note-name>"
```

Read the matched note's current frontmatter.

### Step R2: Load the New Type Schema

Read `05 Meta/claude/<new-type>.claude.md` for the target type's required fields.

### Step R3: Update the Note — Additive Migration

**Rules:**
- Change the `type` field to the new type
- Add any missing required fields for the new type with sensible defaults
- **Never remove existing fields** (additive only — no data loss)
- Update `classified_at` to the current datetime
- Update `confidence` to the new classification score
- If `status` was `needs_review`, replace with the type's appropriate default status (e.g., `active` for project, `pending` for task)
- **Do NOT rename the file** — only inbox items (`inbox-HHMMSS` pattern) get renamed on first classification. Already-named notes keep their filename forever.

### Step R4: Log the Reclassification

Append a `[correction]` entry to `05 Meta/logs/inbox-log.md`:

```markdown
### YYYY-MM-DD HH:MM [correction]
- **Input:** <name> (reclassified)
- **Previous:** <old-type> (confidence: X.XX)
- **New type:** <new-type> (confidence: X.XX)
- **Trigger:** classify skill
- **Reasoning:** Why the type changed
```

### Step R5: Git Commit

**When invoked by `/eod`:** Skip this step — `/eod` handles the batch commit.

**Otherwise:**

```bash
git add "04 Data/YYYY/MM/<filename>" "05 Meta/logs/inbox-log.md"
git commit -m "sb: fix reclassified <name> <old-type> → <new-type>"
```

---

## Classification Contract

For internal reasoning, structure your classification as:

```
INPUT: Raw thought text
OUTPUT:
  type: person|project|task|idea|meeting|admin (or inbox if low confidence)
  confidence: 0.0-1.0
  suggested_filename: kebab-case-name
  fields: { type-specific frontmatter values }
  reasoning: One sentence explaining the classification
RULES:
  - confidence < threshold (from config) → type = "inbox", status = "needs_review"
  - Extract only fields clearly present in the input
  - Do not invent or assume information not stated
  - If input contains multiple thoughts, classify by the PRIMARY thought
  - If a due date is mentioned, capture it; if "by Friday" or similar, resolve to actual date
  - Default task priority to "medium" unless urgency is clear
  - Every classified note gets classified_at (now) and confidence (the score)
```

## Examples

**Input:** "Need to follow up with Sarah about the API deadline"
- Type: `person` (confidence: 0.90)
- File: `04 Data/2026/02/2026.02.12-sarah-chen.md`
- Alias: `sarah-chen`
- Key fields: `name: Sarah`, `follow_ups: ["Follow up about API deadline"]`, `classified_at: "2026-02-12 10:30"`, `confidence: 0.90`

**Input:** "hmm something about that thing from last week"
- Type: `inbox` (confidence: 0.35)
- File: `04 Data/2026/02/2026.02.12-inbox-143000.md`
- Key fields: `status: needs_review`, `original_text: "hmm something about that thing from last week"`, `classified_at: "2026-02-12 14:30"`, `confidence: 0.35`

**Input:** "Had a meeting with the Windows Platform team about the new driver model"
- Type: `meeting` (confidence: 0.95)
- File: `04 Data/2026/02/2026.02.12-windows-platform.md`
- Alias: `windows-platform`
- Key fields: `meeting_name: "windows-platform"`, `date: 2026-02-12`, `attendees: []`, `is_1on1: false`, `classified_at: "2026-02-12 16:00"`, `confidence: 0.95`

**Reclassification:** "that websocket idea should be a project"
- Find: `04 Data/2026/02/2026.02.12-websocket-replacement.md`
- Change: `type: idea` → `type: project`
- Add: `status: active`, `next_action: "Research WebSocket libraries"` (sensible defaults)
- Keep: `name`, `oneliner` (additive — never remove fields)
- Update: `classified_at: "2026-02-12 15:00"`, `confidence: 0.85`
- File stays: `2026.02.12-websocket-replacement.md` (no rename)
- Log: `[correction]` entry with previous type and confidence

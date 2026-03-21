# /meeting — Create a Meeting Note

Create a meeting note from natural language. Handles both regular meetings and 1-on-1s.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## When to Use

Run this command when the user says something like:
- "Starting the Windows Platform meeting"
- "Logging on to meeting about API review"
- "One on one with Sarah"
- "1on1 with David"
- "Meeting with the Linux team"

## Steps

### Step 1: Parse Intent

Analyze the user's input to determine:

1. **Is this a 1-on-1?** Look for keywords: "one on one", "1on1", "1-on-1", "1:1", or context indicating a two-person meeting with a specific individual.
2. **Meeting name:** Extract a short, descriptive name for the meeting.
   - Regular meeting: the meeting topic or group name (e.g., "Windows Platform", "API Review")
   - 1-on-1: the person's name (e.g., "Sarah Chen")

### Step 2: Derive Canonical Names

- `meeting_name` — kebab-case canonical identifier:
  - Regular: `<topic-kebab>` (e.g., `windows-platform`, `api-review`)
  - 1-on-1: `1on1-<person-kebab>` (e.g., `1on1-sarah-chen`)
- `filename` — `YYYY.MM.DD-<meeting_name>.md` (e.g., `2026.02.13-windows-platform.md` or `2026.02.13-1on1-sarah-chen.md`)
- `file_path` — `04 Data/YYYY/MM/<filename>`

### Step 3: Look Up Person (1-on-1 only)

For 1-on-1 meetings, search for the person's note to get full name and context:

```bash
obsidian vault=second-brain search query="<person-name>" path="04 Data" format=json
```

If a matching `type: person` note is found, read it and extract:
- `name` and `context` — for the attendees section
- `follow_ups` — list of pending follow-up items (for the prep section in Step 3b)

If no person note exists, use the name as provided — the person note can be created later.

### Step 3b: Gather Follow-up Context (1-on-1 only)

Surface all open items related to the attendee so you can prep for the conversation. Run these queries in parallel:

**a) Person follow-ups:**
Extract the `follow_ups` list from the person note (from Step 3). These are direct commitments to or about this person.

**b) Open tasks mentioning the person:**
Search open task notes for the person's name (first name, last name, or kebab-case alias):

```bash
obsidian vault=second-brain base:query path="02 Areas/Tasks.base" format=json
```

From the results, filter tasks where the `file.name` or content contains the person's name or alias. Read matching task notes to get `task`, `due`, `status`, and `priority`.

**c) Unchecked action items from recent meetings:**
Search the last 4 weeks of meeting notes for unchecked action items (`- [ ]`) mentioning the person's name:

```bash
# Search meeting notes from the last 4 weeks for unchecked items mentioning the attendee
obsidian vault=second-brain search query="<person-name>" path="04 Data" format=json
```

From the results, filter for `type: meeting` notes. Read each and scan the `## Action Items` section for unchecked items (`- [ ]`) where the line or its section header contains the person's name. Exclude the current meeting's previous instance (already covered in Step 4).

**d) Build the Follow-up Context callout:**

Compile all findings into a callout block. Omit any subsection with zero items.

```markdown
> [!todo]- Follow-up Context for <Person Name>
> **From person note:**
> - follow-up item 1
> - follow-up item 2
>
> **Open tasks:**
> - [[YYYY.MM.DD-task-name|task name]] — due YYYY-MM-DD (priority)
> - [[YYYY.MM.DD-task-name|task name]] — due YYYY-MM-DD (priority)
>
> **Unchecked items from other meetings:**
> - [action item text] — from [[YYYY.MM.DD-meeting-name|meeting]] (YYYY-MM-DD)
> - [action item text] — from [[YYYY.MM.DD-meeting-name|meeting]] (YYYY-MM-DD)
```

If no follow-up context is found at all (no person note, no tasks, no unchecked items), skip the callout entirely.

### Step 4: Find Previous Meeting

Search for previous meetings with the same `meeting_name`:

```bash
obsidian vault=second-brain base:query path="02 Areas/Meetings.base" format=json
```

From the JSON results, filter entries where `meeting_name` matches (case-insensitive). Sort by `date` descending and select the first (most recent) that is before today.

If a previous meeting is found:
1. Read its content via `obsidian read`
2. Extract the `## Summary` section. If no summary exists, extract `## Log` + `## Action Items`.
3. Format as a callout:
   ```markdown
   > [!quote]- Previous: YYYY.MM.DD-meeting-name
   > <summary content>
   ```

If no previous meeting exists:
```markdown
> [!info] First occurrence of this meeting
> No previous meetings found for **meeting-name**
```

### Step 5: Create the Meeting Note

Build the full note content and create via Obsidian CLI:

```bash
obsidian vault=second-brain create path="<file_path>" content="<full markdown>" silent
```

**Regular meeting frontmatter:**
```yaml
---
type: meeting
meeting_name: "<meeting-name>"
aliases: [<meeting-name>]
date: YYYY-MM-DD
attendees: []
is_1on1: false
summary: ""
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
classified_at: "YYYY-MM-DD HH:mm"
confidence: 1.0
tags: [meeting]
---
```

**1-on-1 frontmatter:**
```yaml
---
type: meeting
meeting_name: "1on1-<person-kebab>"
aliases: [1on1-<person-kebab>]
date: YYYY-MM-DD
attendees: ["<Person Name>"]
is_1on1: true
summary: ""
created: "YYYY-MM-DD HH:mm"
modified: "YYYY-MM-DD HH:mm"
classified_at: "YYYY-MM-DD HH:mm"
confidence: 1.0
tags: [meeting, 1on1]
---
```

**Body structure:**
```markdown
# YYYY.MM.DD-<meeting-name>
Daily Note: [[YYYY.MM.DD-daily-note]]

## Attendees
- [list attendees, or leave blank for regular meetings]

## Previous Meeting Summary
[callout from Step 4]

## Follow-up Context
[callout from Step 3b — 1-on-1 only, omit section entirely for regular meetings or if no context found]

## Agenda


## Log


## Action Items

```

### Step 6: Confirm and Link

1. Confirm creation: "Created meeting note: [[YYYY.MM.DD-meeting-name|meeting-name]]" (use the actual filename and alias)
2. If today's daily note exists, mention it shows in the Meetings section automatically via the inline base in the daily note and the "Today" view in `Meetings.base`
3. Remind: "Take notes in the ## Log and ## Action Items sections. Run `/eod` when done to generate a summary."

### Step 7: Git Commit

```bash
git add "04 Data/YYYY/MM/<filename>"
git commit -m "sb: meeting '<meeting-name>'"
```

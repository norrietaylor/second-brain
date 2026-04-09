# /learned — End-of-Session Context Capture

Scan the current session for patterns worth capturing and update the personal context library in `05 Meta/context/`.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## When to Use

- Run standalone at the end of any session where you noticed insights, corrections, or preferences worth remembering
- Also available as a skippable final step in `/eod`

## Steps

### Step 1: Scan the Session

Review the current conversation for patterns worth capturing. Look for:

- **Classification corrections** — Did the user correct a classification? ("that's a project not an idea") → Propose a rule for `tags.md` or a classification hint
- **New people mentioned** — Did a new person come up with enough context to be useful? → Propose creating `05 Meta/context/team/<name>.md` (requires approval)
- **Preferences expressed** — Did the user express a preference about output format, writing style, or system behavior? → Propose creating or updating a context file (e.g., `preferences.md`)
- **Priority shifts** — Did the user mention new focus areas or deprioritize something? → Update `current-priorities.md`
- **Repeated corrections** — Did the user explain the same convention multiple times? → Capture it in the appropriate context file
- **New tags used** — Did the user use tags not in the taxonomy? → Propose adding them to `tags.md`

If nothing worth capturing was found, say so: "Nothing new to capture from this session." and stop.

### Step 2: Propose Updates

For each finding, present a specific proposed change:

```
I noticed a few things worth capturing:

1. You corrected "standup notes" from task → admin twice.
   → Add rule to tags.md: "standup/meeting notes → type: admin"

2. You mentioned Sarah Chen is leading the API redesign.
   → Create 05 Meta/context/team/sarah-chen.md? (needs approval)

3. You said priorities shifted — API redesign is now #1.
   → Update current-priorities.md: move API redesign to position 1
```

**Rules for proposals:**
- Existing file updates: apply directly (no approval needed)
- New file creation: wait for explicit user approval
- Be specific about what changes — show the actual content that would be added/changed

### Step 3: Ask "Anything Else?"

After presenting proposals (and applying approved ones):

```
Anything else from this session we should capture?
```

The user can add context in natural language. Figure out which file to update or propose a new one. Repeat until the user says they're done.

### Step 4: Apply and Commit

Apply all approved changes to the context files.

If a new file was created, update `05 Meta/context/work-profile.md`'s "See also" section with a link to the new file:

```markdown
- [[team/sarah-chen]] — Engineering lead, API redesign project
```

**Standalone /learned commit:**

```bash
git add "05 Meta/context/"
git commit -m "sb: /learned — updated <file1>, <file2>[, created <new-file>]"
```

**Inside /eod:** Changes are included in the `/eod` batch commit instead. Append `/learned: updated <files>` to the commit message.

### Step 5: Sync Global Memory

After committing context changes, regenerate the global Claude memory file so vault knowledge is available in all projects:

```bash
".claude/scripts/sync-memory.sh"
```

This writes `~/.claude/memory/work-context.md` from the updated `05 Meta/context/` files. Skip this step if no context files were actually changed (nothing new to capture).

## Guardrails

These rules are non-negotiable:

- **NEVER edit CLAUDE.md** — That's system config, managed manually. If the user asks, explain and propose a context file instead.
- **NEVER edit type-specific schema files** (`05 Meta/claude/*.claude.md`) — Those define the data model.
- **NEVER edit data notes in `04 Data/`** — `/learned` only touches `05 Meta/context/`.
- **NEVER edit templates** (`05 Meta/templates/`) — Those are Templater templates.
- **If a context file exceeds 200 lines after update** — Suggest splitting it into focused sub-files.
- **One topic per file** — If an update doesn't fit the file's scope, propose a new file.
- **New file creation always requires explicit user approval** — Propose, wait for "yes", then create.
- **When creating new files, always update work-profile.md** — Add to the "See also" section.

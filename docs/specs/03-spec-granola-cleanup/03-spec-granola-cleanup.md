# 03-spec-granola-cleanup

## Introduction/Overview
Post-launch cleanup for the Granola meeting sync pipeline. Fixes script defaults, restores permissions, guards against template corruption, validates /eod wiring, and removes a Python deprecation warning. Tracked in GitHub issue #5.

## Goals
1. Scripts work without requiring `SECOND_BRAIN_VAULT` env var override
2. `granola-ingest` is pre-allowed in `.claude/settings.json`
3. Template corruption is detected early with a clear error message
4. `/eod` Step 0.75 correctly invokes `granola-ingest`
5. No deprecation warnings in `granola-initial-sync`

## User Stories
- As a vault operator, I want `granola-ingest` to find my vault automatically so I don't need to set env vars every run.
- As a vault operator, I want Claude Code to run `granola-ingest` without permission prompts.
- As a vault operator, I want `granola-ingest` to warn me if the plugin template has been corrupted rather than silently producing broken notes.

## Demoable Units of Work

### Unit 1: Fix vault path defaults and permissions

**Purpose:** Scripts locate the vault correctly out of the box; Claude Code can run them without prompts.

**Functional Requirements:**
- The default `VAULT` in `granola-ingest` shall be `~/Sites/second-brain/second-brain`
- The default `VAULT_DIR` in `granola-initial-sync` shall be `~/Sites/second-brain/second-brain`
- `.claude/settings.json` shall include `Bash(*.claude/scripts/granola-ingest*)` and `Bash(*.claude/scripts/granola-initial-sync*)` in the allow list

**Proof Artifacts:**
- CLI: `grep -c 'Sites/second-brain' ".claude/scripts/granola-ingest"` returns 1
- CLI: `grep -c 'Sites/second-brain' ".claude/scripts/granola-initial-sync"` returns 1
- File: `.claude/settings.json` contains `granola-ingest` and `granola-initial-sync` in allow list

### Unit 2: Template validation guard

**Purpose:** Detect corrupted Granola template before processing files, preventing broken note ingestion.

**Functional Requirements:**
- `granola-ingest` shall validate that `05 Meta/templates/Granola.md` contains `{{granola_id}}` before processing any files
- If the template check fails, the script shall print a clear error message naming the expected variable and exit non-zero
- The check shall run once at startup, not per-file

**Proof Artifacts:**
- CLI: Temporarily break the template, run `granola-ingest --dry-run`, verify error message and non-zero exit
- File: `granola-ingest` contains template validation logic near the top of main processing

### Unit 3: Validate /eod Step 0.75 wiring

**Purpose:** Confirm the eod command correctly invokes granola-ingest with the right vault path.

**Functional Requirements:**
- `/eod` Step 0.75 shall call `granola-ingest` (not `granola-ingest --dry-run`)
- The eod command shall set `SECOND_BRAIN_VAULT` or the script default shall be correct (covered by Unit 1)
- The `granola_ingest_count` variable shall be populated from script output

**Proof Artifacts:**
- File: `.claude/commands/eod.md` contains Step 0.75 with `granola-ingest` invocation
- File: `.claude/commands/eod.md` references `granola_ingest_count` in Step 10

### Unit 4: Fix datetime.utcnow() deprecation

**Purpose:** Remove Python deprecation warning from granola-initial-sync.

**Functional Requirements:**
- All uses of `datetime.utcnow()` shall be replaced with `datetime.now(datetime.UTC)`
- The `from datetime import datetime` import shall remain (no new imports needed for datetime.UTC on Python 3.11+)

**Proof Artifacts:**
- CLI: `grep -c 'utcnow' ".claude/scripts/granola-initial-sync"` returns 0
- CLI: `python3 -W error::DeprecationWarning -c "from datetime import datetime; datetime.now(datetime.UTC)"` exits 0

## Non-Goals (Out of Scope)
- Preventing template file overwrites by Obsidian plugins (would require plugin modification)
- Changing the Granola plugin configuration
- Any changes to meeting note content or frontmatter schema

## Technical Considerations
- The vault path change is specific to this user's setup. The env var override remains available for other environments.
- Template validation only checks for `{{granola_id}}` as a canary — if that's present with the prefix, the rest almost certainly is too.
- `datetime.UTC` requires Python 3.11+. The script already uses f-strings and other 3.10+ features, so this is safe.

## Success Metrics
- `granola-ingest` runs successfully without `SECOND_BRAIN_VAULT` override
- No permission prompts in Claude Code for granola scripts
- Corrupted template produces clear error instead of broken notes
- No deprecation warnings during `granola-initial-sync` execution

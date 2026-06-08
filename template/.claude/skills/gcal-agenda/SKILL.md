---
name: gcal-agenda
description: Check the user's Google Calendar for today and the next few days. Use when the user asks about their calendar, agenda, meetings today, what's coming up, next meeting, schedule, or what's on the calendar. Read-only — never creates or modifies events.
---

# Google Calendar: Agenda

This skill reports the user's upcoming calendar agenda. All queries go through the **Google Calendar MCP** (`mcp__claude_ai_Google_Calendar__*` tools) — read-only, no event mutation.

## Configuration

Everything this skill needs is in `05 Meta/config.yaml` under `google:`:

```yaml
google:
  self_email: "jane@company.com"
  calendar:
    calendar_ids: [primary]       # primary + any additional calendars to include
    agenda_days_ahead: 2          # 0 = today only, 1 = today + tomorrow, etc.
```

Read this file first. If `calendar.calendar_ids` is empty, default to `[primary]`.

## Workflow

### Step 1: Gather events

For each `calendar_id` in `google.calendar.calendar_ids`:

```
mcp__claude_ai_Google_Calendar__list_events with
  calendar_id=<id>
  time_min=<today 00:00 local>
  time_max=<today + agenda_days_ahead days, 23:59 local>
```

Merge results, de-dup by event ID, sort by start time. Drop:

- Events the user has declined (`self.responseStatus == "declined"`)
- All-day informational holidays (`transparency == "transparent"` AND `summary` matches a holiday pattern) — keep OOO blocks
- Events with no other attendees AND summary matching `focus|block|heads-down|dnd` (solo focus blocks — user knows about these)

### Step 2: Enrich per event

For each kept event, pull:

- `summary` — title
- `start` / `end` — use `dateTime` if present, fall back to `date` for all-day
- `location` — location string
- `hangoutLink` or conference link — Google Meet / Zoom URL
- `attendees` — count and list
- `description` — scan for linked Google Doc URLs (Gemini notes doc, agenda, pre-read) and for meeting-name hints

If the event has an attached document via `attachments[]`, include the file URL — this is commonly the Gemini notes doc after the meeting ends.

### Step 3: Cross-reference the vault

For each event, check whether a meeting note already exists:

```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Meetings.base" format=json
```

Filter results in-memory: match events to meeting notes by:

1. Exact match on the event's linked Google Doc ID against `gemini_doc_id` in frontmatter (for past meetings with Gemini notes already imported)
2. Fuzzy match: same `date` + kebab-cased title ↔ `meeting_name`

For each event, record: **has vault note** (cite the alias `[[...]]`) or **no vault note**.

### Step 4: Synthesize the briefing

Present a per-day agenda. For each day with events:

```
## Today (YYYY-MM-DD)

- 09:00–09:30 — Meeting title (3 attendees)
  Meet: https://meet.google.com/abc-defg-hij
  Notes: <linked Gemini doc URL or "—">
  Vault: [[2026.04.23-meeting-name]] or "no note yet"
  
- 10:00–11:00 — Another meeting (8 attendees, you, @alice, @bob, +5)
  ...
```

Day headers: **Today**, **Tomorrow**, then `YYYY-MM-DD (Weekday)`.

For attendees, resolve emails to `@person` wiki-links via `02 Areas/People.base` (check `emails` frontmatter). Show up to 3 named attendees then `+N`.

If a day has no events, say "no meetings".

End the briefing with:
- A count of meetings today vs. remaining days
- Any Gemini notes docs linked that are not yet in the vault — suggest `/gemini-import <url>` per line

## When to Use This Skill

Trigger on prompts like:
- "What's on my calendar?"
- "What's my agenda today / tomorrow / this week?"
- "What meetings do I have?"
- "Next meeting?"
- "Schedule for today"

Do NOT use this skill to:
- Create, update, or delete events — NEVER call `create_event` / `update_event` / `delete_event` / `respond_to_event`. This integration is read-only.
- Ingest a past meeting's notes — that's `/gemini-import`.
- Find free time — that's `mcp__claude_ai_Google_Calendar__suggest_time` directly (not this skill).

## Known Limitations

- **Timezone** — events use the calendar's timezone. Display times in the calendar's local TZ; if the user is traveling, they need to trust the device.
- **Recurring events** — the MCP expands recurring events into concrete instances within `time_min`/`time_max`, so we don't need to handle recurrence rules.
- **Private events** — events on shared calendars marked `visibility: private` return a stub with `Busy` as the title. Display as "Busy (private)" with the time block.
- **Response status** — if `self.responseStatus == "needsAction"`, flag with "⟡ awaiting response" in the listing.
- **No cross-calendar dedup semantics** — if the same meeting appears on multiple included calendars, we dedup by event ID only. Events copied to multiple calendars with different IDs will appear twice.

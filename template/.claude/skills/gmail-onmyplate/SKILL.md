---
name: gmail-onmyplate
description: Check what's on the user's Gmail plate by triaging unread and recent threads for actionable items. Use when the user asks about email, inbox, what's on their plate, what they owe replies to, or what follow-ups are waiting in email. Also trigger on "check my gmail", "what's in my inbox", or "anything actionable in email".
---

# Gmail: What's On My Plate

This skill reports what needs the user's attention in Gmail. All queries go through the **Gmail MCP** (`mcp__claude_ai_Gmail__*` tools) — there is no CLI.

Three buckets, each a separate query:

1. **Needs your reply** — Unread threads where the last message is from someone else AND the user is a direct recipient (To/Cc)
2. **Your open threads** — Threads where the user sent the last message but no response has come back (stale ≥ `follow_up_wait_days`)
3. **FYI** — Remaining unread threads (newsletters, CI noise, notifications) — counts only, not individual list

## Configuration

Everything this skill needs is in `05 Meta/config.yaml` under `google:`:

```yaml
google:
  self_name: "Jane Smith"
  self_email: "jane@company.com"
  gmail:
    denylist_labels: [CATEGORY_PROMOTIONS, CATEGORY_SOCIAL, CATEGORY_UPDATES, SPAM]
    vip_senders: []                     # always surface these senders in Bucket 1
    lookback_days: 3
    follow_up_wait_days: 3
```

Read this file first. If `google.self_email` is empty, tell the user to fill it in (used to detect "the user is a direct recipient" vs `Cc`-only noise).

## Workflow

### Step 1: Query each bucket

#### Bucket 1 — Needs your reply

Build a Gmail search query:

```
in:inbox is:unread -category:promotions -category:social -category:updates newer_than:3d
```

Where `3d` comes from `gmail.lookback_days`, and the `-category:*` tokens come from `gmail.denylist_labels` (translated: `CATEGORY_PROMOTIONS` → `-category:promotions`, `SPAM` → `-in:spam`, etc.).

Use:
```
mcp__claude_ai_Gmail__search_threads with q="<query>"
```

For each returned thread, call `mcp__claude_ai_Gmail__get_thread` and inspect the latest message:

- **Keep** if the latest message is from someone *other* than the user AND the user is in `To:` or `Cc:`.
- **Drop** if the latest message is from the user (move to Bucket 2 consideration).
- **Drop** if the user is only on `Bcc:` / implicit (likely mass email).

Then apply a second pass for VIP senders — for any sender address in `gmail.vip_senders`, include the thread in Bucket 1 even if already read (subject to `lookback_days`).

Collect: thread ID, subject, latest sender (name + email), received timestamp, short preview of the latest message, web URL (`https://mail.google.com/mail/u/0/#inbox/<thread_id>`).

#### Bucket 2 — Your open threads

Search:
```
in:sent newer_than:14d -in:chats
```

Use a wider lookback than Bucket 1 because outbound threads can legitimately sit for days. For each result, fetch the thread:

- **Keep** if the user's message is the latest in the thread AND the thread is older than `follow_up_wait_days`.
- **Drop** if someone has replied since.
- **Drop** if the thread is a one-shot transactional email (single message, no recipient likely to reply — heuristic: body contains an unsubscribe link, or sender is a no-reply address on the original thread before user's reply).

Collect: thread ID, subject, recipients (names + emails), days since last sent, 1-sentence gist of what the user asked / said.

#### Bucket 3 — FYI

Re-use the Bucket 1 search but *without* the recipient filter. Subtract the threads already placed in Bucket 1. Count the remainder and group by label (e.g. `CATEGORY_UPDATES`, `CATEGORY_FORUMS`, or specific labels like `ci` / `github`). Do NOT list individual threads — just counts per label.

### Step 2: Cross-reference the vault

Gmail threads are not persisted in the vault by default (no `type: email`). The only cross-reference worth doing is the **Gemini meeting minutes** case:

- If a thread in Bucket 1 or Bucket 3 matches the Gemini sweep pattern (`sender_patterns` + `subject_patterns` from `google.gemini` in config), flag it: *"Gemini meeting notes — will be auto-ingested by /eod, or run `/gemini-import <thread_id>`."*
- Do this flag inline inside the relevant bucket; don't carve out a separate bucket.

### Step 3: Synthesize the briefing

Present a summary grouped by bucket. Use clear visual separation:

**Needs your reply (N):**
- For each: sender, subject, 1-line gist, received time, URL
- Sort: VIP senders first, then most recent
- Mark overdue (> 24h) distinctly from fresh

**Your open threads (N):**
- For each: recipient, subject, "sent X days ago", 1-sentence gist of what the user sent, URL
- Sort: oldest first (most likely to need a nudge)

**FYI (N unread):**
- Summary line per label: "12 CI notifications, 3 GitHub digests, 5 newsletters"
- No individual threads

Always present Gmail URLs as full clickable links (`https://mail.google.com/mail/u/0/#inbox/<thread_id>`), not markdown-wrapped text.

## When to Use This Skill

Trigger on prompts like:
- "What's on my gmail plate?"
- "What's in my inbox?"
- "Check email / gmail"
- "Anything actionable in email?"
- "What replies do I owe?"
- "Any stale follow-ups in email?"

Do NOT use this skill to:
- Search Gmail for arbitrary content — use `mcp__claude_ai_Gmail__search_threads` directly
- Read a specific thread — use `mcp__claude_ai_Gmail__get_thread` directly
- Ingest a Gemini meeting note — that's `/gemini-import`
- Send, draft, or label messages — this skill is read-only triage

## Known Limitations

- **No persistent state** — every run re-queries Gmail. If the user asks the same question twice in a session, results may shift slightly as new mail arrives.
- **Latest-message heuristics** — "who sent the last message" is extracted from the most recent message header in the thread. Forwarded threads can confuse this; accept the occasional false positive.
- **Category translation** — Gmail MCP may expose labels as `CATEGORY_PROMOTIONS` (system) while search queries use `category:promotions` (search syntax). Translate by convention: strip `CATEGORY_` prefix and lowercase.
- **VIP matching** — compare senders case-insensitively on the email portion only (`From: "Alice Example" <alice@corp.com>` → match `alice@corp.com`).
- **Threading** — Gmail threads can include messages across multiple labels (Sent + Inbox). Treat the thread as a unit and use its latest message for bucket placement.

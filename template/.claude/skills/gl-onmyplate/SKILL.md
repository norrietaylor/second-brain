---
name: gl-onmyplate
description: Check what's on the user's GitLab plate by querying todos and open threads, then dig into each to determine required action. Use when the user asks about GitLab notifications, what needs their attention, what's on their plate, pending issues or MRs, or what they should reply to.
---

# GitLab: What's On My Plate

Four scripts work together to report what needs the user's attention on GitLab. The first three discover threads from different angles; the fourth digs into a specific thread to determine what action is needed.

Scripts location: `scripts/` directory within this skill.

## Configuration

Edit `scripts/config.sh` before first use. The most important setting:

```bash
# Leave blank to auto-detect from glab config, or set explicitly:
GL_HOST="git.yourcompany.com"
```

Auto-detection scans `~/Library/Application Support/glab-cli/config.yml` for the first authenticated non-gitlab.com host. If you only have one self-hosted instance, it works without any configuration.

## Scripts

### 1. `gl_notifications.sh` — Pending Todos (Inbox)

Queries the GitLab Todos API for **pending action items**.

```bash
scripts/gl_notifications.sh              # all pending todos
scripts/gl_notifications.sh 7d           # todos updated in last 7 days
scripts/gl_notifications.sh 2w --compact # compact output with todo IDs
```

- Covers @mentions, assignments, review requests, approval requests
- Filters out build failures and other automated noise
- Filters out merged MRs unless you were @mentioned post-merge
- Filters out MRs where your only involvement is via an ignored group (see `IGNORE_REVIEW_GROUPS` in config.sh)

**Best for**: "Is there anything pending that needs my attention?"

### 2. `gl_involved.sh` — All Open Threads

Searches GitLab for all **open** MRs and issues you're involved in.

```bash
scripts/gl_involved.sh                   # default: last 7 days
scripts/gl_involved.sh 1m                # last 1 month
```

- Queries author, assignee, and reviewer dimensions separately, deduplicates
- Always works regardless of todo inbox state
- Immune to "Done" clearing — queries source of truth directly

**Best for**: "What open threads am I part of that had recent activity?"

### 3. `gl_my_mrs.sh` — My Open MRs

Lists all open MRs **authored by the user**, with pipeline status and last note on each.

```bash
scripts/gl_my_mrs.sh              # default: MRs created within last 1 year
scripts/gl_my_mrs.sh 6m           # last 6 months
scripts/gl_my_mrs.sh --compact    # compact TSV output
```

- Shows every open MR you created (no date-of-activity filter)
- Includes pipeline status (`none`, `success`, `failed`, `running`, etc.)
- Last non-system note shows who posted, when, and the body
- MRs with no notes are likely stale/forgotten

**Best for**: "What MRs do I own that are still open? Any need attention?"

### 4. `gl_thread_context.sh` — Thread Deep Dive

Fetches the relevant tail of a specific MR or issue discussion.

```bash
scripts/gl_thread_context.sh <gitlab-url>
scripts/gl_thread_context.sh https://git.example.com/group/project/-/merge_requests/123
scripts/gl_thread_context.sh https://git.example.com/group/project/-/issues/456
```

- Finds the **anchor point**: your last post, or the latest post mentioning @you
- Returns only posts from the anchor onward (avoids loading the full thread)
- Output header includes `ACTION_HINT`:
  - "Last post is yours — likely no action needed"
  - "Last post is by someone else — may need your response"

**Best for**: "Do I need to respond to this thread, and what's the context?"

### 5. `gl_mark_done.sh` — Mark Todo as Done

Marks a GitLab todo as done and logs the action.

```bash
scripts/gl_mark_done.sh TODO_ID PROJECT TYPE TITLE URL
```

Arguments come from `gl_notifications.sh` output (TODO_ID is the first column).

### Timespan Parameter (scripts 1, 2, 3)

| Format | Meaning |
|--------|---------|
| `7d` | Last 7 days (default for notifications/involved) |
| `3d` | Last 3 days |
| `2w` | Last 2 weeks |
| `1m` | Last 1 month |
| `1y` | Last 1 year (default for my MRs) |

## Workflow

### Step 1: Discover threads

```bash
SKILL_DIR=~/.claude/skills/gl-onmyplate/scripts  # adjust path as needed
$SKILL_DIR/gl_notifications.sh 7d
$SKILL_DIR/gl_involved.sh 7d
$SKILL_DIR/gl_my_mrs.sh
```

Deduplicate results (same project!IID from multiple scripts = one thread).

`gl_my_mrs.sh` already includes pipeline status and last note per MR. Use that to assess status directly — only dig deeper with `gl_thread_context.sh` if the last note suggests a conversation needing more context.

### Step 2: Dig into threads that need more context

```bash
$SKILL_DIR/gl_thread_context.sh <url>
```

Determine:
- **No action needed** if `ACTION_HINT` says last post is by the user, OR remaining posts are automated (CI, bot comments)
- **Action needed** if someone asked a question, requested changes, replied to the user, or @mentioned them — and the user hasn't responded

### Step 3: Synthesize briefing

Present a summary grouped by action needed:

**Needs your response:**
- For each: project!IID or project#IID, title, what happened (1-sentence), URL

**Your open MRs — status:**
- For each: project!IID, title, status (pipeline / last note summary), URL

**No action needed (FYI):**
- For each: project!IID, title, brief reason, URL

Always present URLs as full clickable links.

## Configuration Reference

Edit `scripts/config.sh`:

### `GL_HOST`
Self-hosted GitLab hostname. Leave blank for auto-detection.
```bash
GL_HOST="git.yourcompany.com"
```

### `IGNORE_REVIEW_GROUPS`
Array of namespace paths. If your only involvement in an MR is as a reviewer on a project under one of these namespaces, the MR is filtered out.
```bash
IGNORE_REVIEW_GROUPS=(
  "myorg/platform"
)
```
Find namespace paths: `glab api /groups | jq '.[].full_path'`

### `FILTER_MERGED_REVIEWED`
When `true` (default), merged MRs are filtered from todos unless you were @mentioned post-merge.

## Interpreting Todo Actions

| Action | Meaning | Likely needs reply? |
|--------|---------|-------------------|
| `mentioned` | You were @mentioned | Yes |
| `directly_addressed` | Message opened with @you | Yes |
| `review_requested` | Someone wants your review | Yes |
| `approval_required` | Your approval is needed | Yes |
| `assigned` | You were assigned | Likely |
| `review_submitted` | Someone reviewed your MR | Check it |
| `marked` | You marked this (informational) | No |

## Known Limitations

- **Todos are inbox-dependent**: todos marked "done" in GitLab UI are permanently gone from the API
- **gl_involved.sh doesn't capture @mentions**: only author/assignee/reviewer involvement; use gl_notifications.sh for mention-based todos
- **gl_my_mrs.sh takes ~1s per MR** to fetch the last note — 20 open MRs takes ~20s
- **GitLab doesn't expose "requested groups"** in the MR API the same way GitHub does; group filtering is based on project namespace, not a requested_teams field

---
name: gh-onmyplate
description: Check what's on the user's GitHub plate by querying notifications and open threads, then dig into each to determine required action. Use when the user asks about GitHub notifications, what needs their attention, what's on their plate, pending issues or PRs, or what they should reply to.
---

# GitHub: What's On My Plate

Four scripts work together to report what needs the user's attention on GitHub. The first three discover threads from different angles; the fourth digs into a specific thread to determine what action is needed. Noise from team-only review requests and merged PRs is filtered out automatically (see Configuration).

Scripts location: `scripts/` directory within this skill (`~/.cursor/skills/gh-onmyplate/scripts/`)

## Scripts

### 1. `gh_notifications.sh` — New Activity (Inbox)

Queries the GitHub Notifications API for threads with **new activity since last seen**.

```bash
~/.cursor/skills/gh-onmyplate/scripts/gh_notifications.sh [TIMESPAN]
```

- Shows only threads where the user is **participating** (authored, commented, mentioned, assigned, review requested)
- Distinguishes **NEW** (unread) vs **read**
- Filters out repo-wide subscription noise, CI, and security alerts
- Filters out PRs where user's only involvement is via an ignored team (see Configuration)
- Filters out merged PRs unless user is the author or was @mentioned post-merge
- Depends on "Web" notifications being enabled in GitHub Settings

**Best for**: "Is there anything new I haven't seen yet?"

### 2. `gh_involved.sh` — All Open Threads

Searches GitHub for all **open** issues and PRs the user is involved in.

```bash
~/.cursor/skills/gh-onmyplate/scripts/gh_involved.sh [TIMESPAN]
```

- Always works regardless of notification settings or inbox state
- No read/unread distinction — shows everything with recent activity
- Filters out PRs where user's only involvement is via an ignored team (see Configuration)
- Output includes: repo, type (PR/Issue), updated date, title, URL

**Best for**: "What open threads am I part of that had recent activity?"

### 3. `gh_my_prs.sh` — My Open PRs

Lists all open PRs **authored by the user**, with the last post on each. Catches stale PRs, PRs waiting for review, and PRs with CI failures that the other scripts might miss.

```bash
~/.cursor/skills/gh-onmyplate/scripts/gh_my_prs.sh [TIMESPAN]
```

- Shows every open PR the user created (no date-of-activity filter — if it's open, it's shown)
- Timespan controls PR creation date (default `1y`; supports `Ny` for years in addition to `Nd`, `Nw`, `Nm`)
- For each PR: shows the last post (who, when, type, body) so the agent can assess status
- Last post is often from a CI bot — use it to determine build pass/fail
- PRs with no comments at all are likely stale/forgotten

**Best for**: "What PRs do I own that are still open? Any need attention?"

### 4. `gh_thread_context.sh` — Thread Deep Dive

Fetches the relevant tail of a specific issue/PR discussion to determine what action is needed.

```bash
~/.cursor/skills/gh-onmyplate/scripts/gh_thread_context.sh <github-url>
~/.cursor/skills/gh-onmyplate/scripts/gh_thread_context.sh https://github.com/owner/repo/pull/123
~/.cursor/skills/gh-onmyplate/scripts/gh_thread_context.sh https://github.com/owner/repo/issues/456
```

- Finds the **anchor point**: the user's last post, or the latest post mentioning @user
- Returns only posts from the anchor onward (avoids loading the full, often long, thread)
- For PRs: includes issue comments, review summaries, and inline review comments
- Output header includes an `ACTION_HINT` line:
  - "Last post is yours — likely no action needed"
  - "Last post is by someone else — may need your response"

**Best for**: "Do I need to respond to this thread, and what's the context?"

### Timespan Parameter (scripts 1, 2, and 3)

| Format | Meaning |
|--------|---------|
| `7d` | Last 7 days (default if omitted) |
| `3d` | Last 3 days |
| `2w` | Last 2 weeks |
| `1m` | Last 1 month |
| `1y` | Last 1 year (default for `gh_my_prs.sh`) |

## Workflow

### Step 1: Discover threads

Run the discovery scripts (default timespan `7d` for the first two, `1y` for my PRs):

```bash
SKILL_DIR=~/.cursor/skills/gh-onmyplate/scripts
$SKILL_DIR/gh_notifications.sh 7d
$SKILL_DIR/gh_involved.sh 7d
$SKILL_DIR/gh_my_prs.sh
```

Deduplicate results (same repo#number from multiple scripts = one thread).

Note: `gh_my_prs.sh` already includes the last post per PR in its output. For those PRs, you can often determine action needed directly from that output without running `gh_thread_context.sh` — especially if the last post is a simple CI result or approval. Only dig deeper if the last post suggests a conversation that needs more context.

### Step 2: Dig into threads that need more context

For threads from step 1 where you need to understand what happened, run the context script:

```bash
~/.cursor/skills/gh-onmyplate/scripts/gh_thread_context.sh <url>
```

Read the output and determine:
- **No action needed** if `ACTION_HINT` says last post is by the user, OR the remaining posts are just CI bot output / automated messages
- **Action needed** if someone asked a question, requested changes, replied to the user's comment, or @mentioned the user — and the user hasn't responded yet

When processing the thread context output, ignore noise like:
- CI bot build status reports (from @elasticmachine or similar bots)
- Automated merge/rebase messages
- Build trigger commands (e.g. "bk1 gtest linux:extended")

### Step 3: Synthesize briefing

Present a summary grouped by action needed. Use clear visual separation between sections (headings, blank lines, dividers) so the user can quickly scan the briefing and find what matters:

**Needs your response:**
- For each: repo#number, title, what happened (1-sentence summary of what was said after the user's last post), URL

**Your open PRs — status:**
- For each: repo#number, title, status (approved/changes requested/CI passing/CI failing/stale-no-activity/waiting for review), URL

**No action needed (FYI):**
- For each: repo#number, title, brief reason why no action (e.g. "your comment is the latest", "only CI updates since your review"), URL

Always present URLs as full clickable links (e.g. `https://github.com/owner/repo/pull/123`), not as shortened text or markdown link syntax that may not be clickable in the user's terminal.

## Configuration

Edit `scripts/config.sh` to control filtering behavior. The file is sourced by `gh_notifications.sh` and `gh_involved.sh`. If the file is missing, no filtering is applied.

### `IGNORE_REVIEW_TEAMS`

Array of `org/team-slug` strings. If the user's **only** involvement in a PR is via one of these teams (team review request or team @mention), the PR is filtered out.

```bash
IGNORE_REVIEW_TEAMS=(
  "elastic/beats-tech-leads"
  "myorg/platform-reviewers"
)
```

To find team slugs: `gh api /orgs/YOUR_ORG/teams --jq '.[].slug'`

### `FILTER_MERGED_REVIEWED`

When `true` (default), merged PRs are filtered out of notifications unless:
- The user authored the PR, or
- Someone @mentioned the user in a comment **after** the merge date

Pre-merge mentions, approvals, and review requests on merged PRs are treated as historical noise. Set to `false` to disable.

## Interpreting Notification Reasons

| Reason | Meaning | Likely needs reply? |
|--------|---------|-------------------|
| `comment` | Someone replied on a thread the user commented on | Yes |
| `mention` | User was @mentioned | Yes |
| `review_requested` | Someone wants the user's review | Yes |
| `author` | Activity on a thread the user created | Likely |
| `assign` | User was assigned | Likely |
| `team_mention` | User's team was @mentioned | Maybe |
| `state_change` | Thread was opened/closed/merged | Informational |

## Known Limitations

- **Notifications script may return empty** if the user previously had Web notifications disabled in GitHub Settings. Only activity *after* enabling will appear.
- **Notifications marked "Done"** in the GitHub UI are permanently gone from the API.
- **Involved script** cannot tell if there's new activity since the user last looked — it just shows open threads with any recent update.
- **My PRs script** takes ~2s per PR (API calls to fetch last post), so 25 open PRs takes ~45s. This is expected.
- **Thread context script** treats the user's last post as the anchor — if you posted and then someone else posted and then you posted again, it anchors on your second post (the latest), which is correct.
- **Team filtering adds API calls**: Each PullRequest notification/result that is not clearly personally authored or assigned requires one `GET /repos/.../pulls/N` call to check `requested_teams`. Typically adds a few seconds to the total runtime.
- **Team filter may have false negatives**: If the user personally commented on a PR where their only other involvement is via an ignored team, the filter does not detect the comment (to avoid an extra API call per item) and may incorrectly filter the PR. In practice this is rare — if the user engaged enough to comment, they typically also show up via other involvement qualifiers.

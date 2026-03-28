# Slack Activity & Time Estimates

Personal Slack activity tracking with session-based time estimation, designed for Harvest time entry.

## Overview

The system tracks your Slack activity (messages sent, reactions placed) for a given day, groups by channel, clusters messages into sessions, and estimates time spent per channel. Output is formatted for manual Harvest entry or future automated submission.

## Components

| Component | Path | Purpose |
|-----------|------|---------|
| Script | `05 Meta/scripts/slack-my-activity` | Core engine — fetches, clusters, estimates, formats |
| Skill | `.claude/commands/slack/my-activity.md` | `/slack:my-activity` command definition |
| Config | `05 Meta/config.yaml` → `slack.activity` | Tunable session parameters |
| EOD integration | `.claude/commands/eod.md` Step 5.5d-e | Appends time estimates to daily note |

## Data Sources

### Direct API (preferred)
Requires `SLACK_USER_TOKEN` env var (`xoxp-...`). Uses two Slack API endpoints:
- `search.messages` — finds all messages you sent on the target date (100/page, usually 1 call)
- `reactions.list` — finds messages you reacted to (for channels where you read but didn't post)
- `users.info` — resolves DM user IDs to display names (cached per run)

Required OAuth scopes: `search:read`, `reactions:read`, `users:read`

### MCP Fallback
When no token is available, the skill uses `slack_search_public_and_private` MCP tool with `detailed` response format. Results are piped to the script via `--stdin`. Limitations:
- No reactions data (no MCP endpoint for `reactions.list`)
- 20 results per page (vs 100 for direct API)
- Requires user consent for private channel search

## Session Clustering Algorithm

1. **Group** all activity (messages + reactions) by channel
2. **Sort** chronologically within each channel
3. **Cluster** into sessions: a gap > `session_gap_minutes` between consecutive messages starts a new session
4. **Estimate** each session's duration:
   - Single authored message → `single_msg_minutes` (default: 10)
   - Single reaction-only → `reaction_msg_minutes` (default: 5)
   - Multiple messages → (last timestamp - first timestamp) + `session_buffer_minutes` on each end
5. **Round** each channel's total up to `round_to_minutes` (default: 15, Harvest-friendly)
6. **Flag** if grand total exceeds 10 hours

### Why these defaults

- **15-min session gap**: Slack conversations tend to be bursty. A 15-minute silence usually means you switched context.
- **10-min single message**: Accounts for reading context before composing and reviewing after sending.
- **5-min reaction only**: You read enough to react but didn't compose anything.
- **5-min buffer**: Assumes you were reading before your first message and wrapping up after your last.
- **15-min rounding**: Harvest's minimum billable increment for most configurations.

## Configuration

All session parameters live in `05 Meta/config.yaml` under `slack.activity`:

```yaml
slack:
  activity:
    session_gap_minutes: 15       # gap to split sessions
    single_msg_minutes: 10        # lone authored message duration
    reaction_msg_minutes: 5       # lone reaction-only duration
    session_buffer_minutes: 5     # buffer on each end of multi-message sessions
    round_to_minutes: 15          # round channel totals to this increment
    timezone_offset_hours: -7     # PDT (-7) or PST (-8)
```

CLI flags `--session-gap` and `--single-msg-time` override config values for a single run.

## Usage

### Standalone
```bash
# Today (defaults to yesterday if before 3 AM)
slack-my-activity

# Specific date
slack-my-activity 2026-03-23

# JSON output (for piping to harvest or other tools)
slack-my-activity --json 2026-03-23

# Override session gap for this run
slack-my-activity --session-gap 30 2026-03-23
```

### Via skill
```
/slack:my-activity
/slack:my-activity 2026-03-23
```

### Via /eod
Step 5.5d-e runs automatically during `/eod`. Output appears in the daily note as a collapsible callout:

```markdown
### Slack Activity
- **#channel-1** — topic summary
- **#channel-2** — topic summary

> [!note]- Time Estimates (13 channels, 6h 30m)
> | Channel | Sessions | Time |
> |---------|----------|------|
> | #DM:Rebeccah | 6 — 14:03, 14:18-14:20, ... | 1h 15m |
> | #acct-clc | 3 — 13:29-13:30, 15:46-15:50, 16:23 | 45m |
> | **Total** | | **6h 30m** |
```

### Graceful degradation in /eod

| Token | MCP | Channel summaries | Time estimates |
|-------|-----|-------------------|----------------|
| Yes   | Yes | Yes               | Yes (script)   |
| No    | Yes | Yes               | Yes (MCP→stdin) |
| No    | No  | Skipped           | Skipped        |

## Setup

One-time Slack app creation:
1. Go to api.slack.com/apps → Create New App → From Scratch
2. Name: anything (e.g., "My Activity")
3. OAuth & Permissions → User Token Scopes → add: `search:read`, `reactions:read`, `users:read`
4. Install to Workspace → approve
5. Copy User OAuth Token (`xoxp-...`)
6. Add to shell: `export SLACK_USER_TOKEN="xoxp-..."` in `~/.zshrc`

## Future: Harvest Integration

The `--json` output is structured for a future `/slack:harvest-entry` skill that maps channels to Harvest projects/tasks and submits time entries via the Harvest MCP server (already configured in Claude Desktop).

A channel-to-project mapping would live in `05 Meta/config.yaml`:
```yaml
slack:
  harvest_map:
    acct-clc-canadian-labour-congress: { project: "CLC", task: "Development" }
    acct-wilderness-committee: { project: "Wilderness Committee", task: "Support" }
    ab-affinity-bridge: { project: "Internal", task: "Communication" }
  harvest_default: { project: "General", task: "Communication" }
```

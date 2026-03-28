# /slack:my-activity — Slack Activity Report with Time Estimates

Generate a report of the user's Slack activity for a given day, grouped by channel with estimated time spent. Designed to feed into Harvest time entry.

## Arguments

`$ARGUMENTS` — optional date in `YYYY-MM-DD` format. Defaults to today.

## Steps

### Step 1: Parse Date

```
TARGET_DATE = $ARGUMENTS if provided and valid YYYY-MM-DD, else today's date
```

If the current time is before 3:00 AM and no date was provided, use yesterday's date (same convention as /eod).

### Step 2: Choose Data Source

Check if `SLACK_USER_TOKEN` is set in the environment.

**If token is available** — run the script directly:
```bash
"05 Meta/scripts/slack-my-activity" [TARGET_DATE]
# or with --json for machine-readable output
"05 Meta/scripts/slack-my-activity" --json [TARGET_DATE]
```
The script handles fetching, clustering, and formatting. Skip to Step 6.

**If no token** — fall back to MCP mode (Steps 3-5).

### Step 3: Fetch via MCP (fallback)

Use `mcp__plugin_slack_slack__slack_search_public_and_private` with **detailed** response format to get real timestamps. The user's Slack ID is `U03G8EUL4`.

```
query: "from:<@U03G8EUL4> on:{TARGET_DATE}"
sort: "timestamp"
sort_dir: "asc"
limit: 20
include_context: false
response_format: "detailed"
```

**Paginate**: if results return a cursor, continue fetching until all messages are collected.

From each result, extract:
- `Channel` name and `(ID: ...)`
- `Message_ts` — the Unix timestamp (e.g., `1774283074.451769`)
- `Text` — first ~120 chars for topic summary
- `Time` — human-readable time string

### Step 4: Pipe to Script

Convert MCP results to JSON lines and pipe to the script:

```bash
echo '{"channel":"#channel-name","channel_id":"C123","ts":1774283074.451769,"text":"message preview"}
{"channel":"#other","channel_id":"C456","ts":1774284000.0,"text":"another message"}' | "05 Meta/scripts/slack-my-activity" --stdin [TARGET_DATE]
```

Each line is a JSON object with: `channel`, `channel_id`, `ts` (float), `text`.

The script handles session clustering, time estimation, and formatting.

### Step 5: Add Topic Summaries

The script output doesn't include topic summaries (it only has message previews). After displaying the script output, add a brief **Topics** line for each channel based on the message previews you collected in Step 3. Keep it to one line per channel.

### Step 6: Offer Next Steps

After printing the report, say:

> This report can be used with `/slack:harvest-entry` (when available) to submit time entries. You can also adjust estimates before entering time manually.

## Script Details

The script lives at `05 Meta/scripts/slack-my-activity` and supports:
- `--json` — output as JSON (for piping to harvest or other tools)
- `--stdin` — read pre-fetched messages as JSON lines (for MCP fallback mode)
- `--session-gap N` — override the 15-minute session gap threshold
- `--single-msg-time N` — override the 10-minute single-message duration
- Env: `SLACK_USER_TOKEN` (xoxp-...), `SLACK_USER_ID` (default: U03G8EUL4)

## Session Clustering Algorithm

1. Group messages by channel (authored messages + reactions merged)
2. Sort chronologically within each channel
3. If gap between consecutive messages > 15 minutes → new session
4. Single authored-message session = 10 minutes
5. Single reaction-only session = 5 minutes (reading, not composing)
6. Multi-message session = (last - first timestamp) + 5 min buffer each end
7. Round each channel total up to nearest 15 minutes
8. Flag if grand total > 10 hours

## Reactions

When using Direct API mode with `reactions:read` scope, the script also calls `reactions.list` to find channels where you reacted but didn't post. These appear as lighter-weight activity (5min per reaction-only session vs 10min for authored messages). Reactions are deduplicated against authored messages.

MCP mode does not support reactions (no MCP tool exposes `reactions.list`).

## Setup for Direct API Mode

One-time setup for faster execution:
1. Go to api.slack.com/apps → Create New App → From Scratch
2. Add OAuth scopes: `search:read`, `reactions:read`
3. Install to workspace → copy User OAuth Token (`xoxp-...`)
4. `export SLACK_USER_TOKEN=xoxp-...` (add to shell profile)

## Important Notes

- MCP fallback requires user consent for `slack_search_public_and_private` (searches private channels and DMs)
- MCP fallback does not include reactions data
- Message content is used only for topic summaries — no full message bodies are stored
- Session parameters are tunable via script flags

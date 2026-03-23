---
modified: 2026-03-22T21:35:53-07:00
---
# Slack MCP Server Setup

## Authentication Methods

| Method | Env Var(s) | Notes |
|--------|-----------|-------|
| **XOXC/XOXD** (browser tokens) | `SLACK_MCP_XOXC_TOKEN` + `SLACK_MCP_XOXD_TOKEN` | Extracted from browser, acts as your user. Expires frequently. |
| **XOXP** (user OAuth) | `SLACK_MCP_XOXP_TOKEN` | Single user OAuth token |
| **XOXB** (bot token) | `SLACK_MCP_XOXB_TOKEN` | Bot user token via Slack app. Most stable. |

## Creating a Bot Token (XOXB)

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**
2. Name it (e.g. "Claude MCP"), select workspace
3. **OAuth & Permissions** → add **Bot Token Scopes**:
   - `channels:history`, `channels:read`
   - `groups:history`, `groups:read`
   - `im:history`, `im:read`
   - `mpim:history`, `mpim:read`
   - `users:read`, `users:read.email`
   - `search:read`
4. **Install to Workspace** → authorize
5. Copy the **Bot User OAuth Token** (`xoxb-...`)

> [!warning] `search:read` requires a user token (xoxp), not a bot token. If search is critical, use **User Token Scopes** and the `xoxp` token instead.

## Docker Startup

```bash
export SLACK_MCP_XOXB_TOKEN=xoxb-...

docker pull ghcr.io/korotovsky/slack-mcp-server:latest
docker run -i --rm \
  -e SLACK_MCP_XOXB_TOKEN \
  ghcr.io/korotovsky/slack-mcp-server:latest --transport stdio
```

### Docker Compose

```bash
wget -O docker-compose.yml \
  https://github.com/korotovsky/slack-mcp-server/releases/latest/download/docker-compose.yml
wget -O .env \
  https://github.com/korotovsky/slack-mcp-server/releases/latest/download/default.env.dist
nano .env  # Add your token
docker network create app-tier
docker-compose up -d
```

## Additional Config

| Variable | Purpose |
|----------|---------|
| `SLACK_MCP_API_KEY` | Bearer token for SSE/HTTP transports |
| `SLACK_MCP_USER_AGENT` | Custom User-Agent for Enterprise Slack |
| `SLACK_MCP_CUSTOM_TLS` | Custom TLS handshakes for enterprise security |
| `SLACK_MCP_ADD_MESSAGE_TOOL` | Enable write tools (off by default) |
| `SLACK_MCP_PORT` | Server port |
| `SLACK_MCP_LOG_LEVEL` | Logging verbosity |

## Fallback: agent-slack

If the bot token OAuth is not approved, [stablyai/agent-slack](https://github.com/stablyai/agent-slack) is an alternative Slack MCP server to evaluate.

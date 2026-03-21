set -a
source .env

docker run -d --name slack-mcp \
    -e SLACK_MCP_XOXC_TOKEN \
    -e SLACK_MCP_XOXD_TOKEN \
    -e SLACK_MCP_PORT=13080 \
    -e SLACK_MCP_USER_AGENT \
    -e SLACK_MPC_CUSTOM_TLS \
    -e SLACK_MCP_HOST=0.0.0.0 \
    -p 13080:13080 \
    ghcr.io/korotovsky/slack-mcp-server:latest --transport sse
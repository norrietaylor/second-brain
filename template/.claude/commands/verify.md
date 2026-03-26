# /verify — Post-Install Health Check

Validate that the vault is correctly set up and all integrations are working. Run this after opening the vault in Obsidian for the first time, or any time something feels broken.

## Steps

### Step 1: Obsidian Vault Access

This is the most important check — it confirms the Obsidian CLI can reach this vault.

Run:
```bash
obsidian vault={{VAULT_NAME}} search query="type" path="05 Meta/claude" format=json | cat
```

If this fails, tell the user:
- Obsidian must be running with the vault open
- The Obsidian CLI requires the desktop app to be running
- The vault must be registered in Obsidian (Open folder as vault)

If it succeeds, report the number of type schemas found (should be ~12).

### Step 2: Bases Views

Verify the primary query surfaces respond:

```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Tasks.base" format=json | cat
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Today.base" format=json | cat
```

Report pass/fail for each. Empty results are OK (no notes yet) — errors are not.

### Step 3: Prerequisites

Check each tool. For each, run the version command and report pass/fail:

| Check | Command | Required |
|-------|---------|----------|
| Obsidian CLI | `obsidian --version` | v1.12+ |
| GitHub CLI | `gh --version` | if GitHub integration enabled |
| GitLab CLI | `glab --version` | if GitLab integration enabled |
| jq | `jq --version` | yes |
| Python 3 | `python3 --version` | yes |

### Step 4: Authentication

Check auth for enabled integrations:

- **GitHub**: `gh auth status` — if not authenticated, tell user to run `! gh auth login`
- **GitLab**: `glab auth status` — if not authenticated, tell user to run `! glab auth login`
- **Slack**: check if `SLACK_USER_TOKEN` env var is set (optional — MCP fallback works without it)

### Step 5: Scripts Are Executable

Check that key scripts have execute permission:
```bash
ls -la "05 Meta/scripts/gh-fetch" "05 Meta/scripts/sb-ingest" "05 Meta/scripts/calculate_dates.py" "05 Meta/scripts/slack-my-activity"
```

If not executable, fix with `chmod +x`.

### Step 6: Directory Structure

Verify these directories exist (create any that are missing):

- `04 Data/`
- `05 Meta/context/`
- `05 Meta/logs/`
- `03 Resources/`

Check for the inbox drop folder:
```bash
ls -d ~/*-inbox 2>/dev/null
```

### Step 7: Obsidian Plugins

Remind the user to verify these plugins are installed and configured:

**Required:**
- **Bases** — enable in Settings > Core Plugins
- **Templater** by SilentVoid — set template folder to `05 Meta/templates`
- **Update frontmatter modified date** by Alan Grainger — format: `YYYY-MM-DD HH:mm`, exclude: `05 Meta`

**Optional (if Granola integration enabled):**
- **Granola Sync** by philfreo — see CLAUDE.md for setup details

Note: Plugin installation/configuration must be done in the Obsidian UI — it cannot be automated from the CLI.

### Step 8: Summary

Print a summary table:

```
Vault Health Check
─────────────────────────────────
Obsidian access:      <ok / not running>
Bases views:          <N/N responding>
Prerequisites:        <N/N passing>
Authentication:       <status per integration>
Scripts:              <executable / fixed>
Directories:          <all present / created N>
Plugins:              <remind user to verify>
─────────────────────────────────
```

If everything passed, suggest running `/today` to start.

If anything failed, list the specific remediation steps.

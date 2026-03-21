# /setup — Initialize Second Brain Vault

Set up the second-brain vault for a new user. Creates gitignored directories, scaffolds personal context files, and validates prerequisites.

## When to Use

Run this command after cloning the repo, before using any other commands (`/today`, `/eod`, etc.).

## Steps

### Step 1: Read Vault Structure

Read `05 Meta/claude/vault-operations.md` to get the canonical directory layout. The directories and files defined there are the source of truth — do not hardcode a duplicate layout here.

From that layout, identify every directory and file that:
1. Appears in the vault structure but is **not tracked in git** (check with `git ls-tree -r --name-only HEAD`)
2. Is referenced as a prerequisite (e.g., `~/second-brain-inbox/`)

These are the items this command needs to create.

### Step 2: Create Missing Directories

For each directory from Step 1 that does not yet exist on disk, create it. Use `mkdir -p` to handle nested paths. Expected gitignored directories include:

- `04 Data/` (the data lake root — year/month subdirs are created on demand by other commands)
- `05 Meta/context/`
- `05 Meta/context/team/`
- `05 Meta/logs/`
- `03 Resources/`
- `~/second-brain-inbox/` (external inbox drop folder)

Verify each with `ls -d` first; skip any that already exist. Report what was created.

### Step 3: Scaffold Personal Context Files

These gitignored files need to exist for commands to function. For each, check if it already exists — **never overwrite existing files**.

**`05 Meta/context/work-profile.md`** — Ask the user for:
- Full name
- Role / title
- Email (optional)

Create the file:
```markdown
---
type: context
---
# Work Profile

- **Name:** <name>
- **Role:** <role>
- **Email:** <email>
```

**`05 Meta/context/current-priorities.md`** — Ask the user for their top 3 current priorities. Create:
```markdown
---
type: context
---
# Current Priorities

1. <priority 1>
2. <priority 2>
3. <priority 3>
```

**`05 Meta/logs/inbox-log.md`** — Create as empty file if missing (no user input needed).

**`Index.md`** (vault root) — Check if missing. If so, create from the pattern used by the vault (link to today's daily note, embed of Active Projects base). Ask the user if they want one generated or will create it manually in Obsidian.

### Step 4: Validate Prerequisites

Check each prerequisite tool. For each, run the version/status command and report pass/fail:

| Check | Command | Required |
|-------|---------|----------|
| Obsidian CLI | `obsidian --version` | v1.12+ |
| GitHub CLI | `gh --version` | any |
| jq | `jq --version` | any |
| Python 3 | `python3 --version` | any |
| Claude Code | Check that we're running (implicit — we are) | — |
| Docker | `docker --version` | optional |

For each **failed** check:
- Print the install command (from the README prerequisites table)
- Note whether it's required or optional

### Step 5: Validate GitHub Auth

Run `gh auth status`. If not authenticated:
- Tell the user to run `! gh auth login` to authenticate interactively
- Wait for them to confirm before proceeding

### Step 6: Validate Obsidian Vault Access

Run:
```bash
obsidian vault=second-brain search query="type" path="05 Meta/claude" format=json | cat
```

If this fails, tell the user:
- Obsidian must be running with the `second-brain` vault open
- The Obsidian CLI requires the desktop app to be running

### Step 7: Validate Scripts Are Executable

Check that key scripts have execute permission:
```bash
ls -la "05 Meta/scripts/gh-fetch" "05 Meta/scripts/sb-ingest"
```

If not executable, offer to fix with `chmod +x`.

### Step 8: Check Obsidian Plugins

Remind the user to verify these plugins are installed and configured in Obsidian:

**Required:**
- **Bases** — enable in Settings > Core Plugins
- **Templater** by SilentVoid — set template folder to `05 Meta/templates`
- **Update frontmatter modified date** by Alan Grainger — format: `YYYY-MM-DD HH:mm`, exclude: `05 Meta`

Note: Plugin installation/configuration must be done in the Obsidian UI — it cannot be automated from the CLI.

### Step 9: Create Local Settings

Check if `.claude/settings.local.json` exists. If not, create it:
```json
{
  "permissions": {
    "allow": []
  }
}
```

### Step 10: Summary

Print a summary table:

```
Setup Complete
─────────────────────────────────
Directories created:  <list or "all existed">
Context files:        <created / skipped (existed)>
Prerequisites:        <N/N passing>
GitHub auth:          <authenticated / not authenticated>
Obsidian access:      <ok / not running>
Scripts:              <executable / fixed>
Plugins:              <remind user to verify in Obsidian>
─────────────────────────────────
```

If everything passed, suggest running `/today` to start.

If anything failed, list the remaining manual steps.

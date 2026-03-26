# People-Expertise Map

Builds and queries a bidirectional knowledge graph: **Domain → People** and **People → Domains**.

Use when asked "who knows about X", "what does person Y work on", "who should I ask about Z", or when building expertise profiles.

## Prerequisites

Read `05 Meta/claude/vault-operations.md` for vault structure, conventions, and configuration context before proceeding.

## Two Query Modes

### Mode 1: "Who knows about X?"
Returns people with expertise in a domain, ranked by depth, with evidence.

### Mode 2: "What does @person do?"
Returns their domains, projects, communication style, and expertise profile.

## Data Gathering

### Sources to Mine

| Source | What to Extract |
|--------|-----------------|
| Slack messages | Topics they discuss, questions they answer, tone |
| Slack threads | Problems they solve, expertise they demonstrate |
| GitHub PRs (multiple repos) | Code areas, review patterns, technical depth |
| GitHub issues (multiple repos) | Problems they file/fix, roadmap items, epics |
| PR reviews | What they review = what they know |
| CODEOWNERS | Official ownership areas |
| GitHub Projects | Roadmap items, epics they're assigned to |
| Existing vault notes | Person notes, meeting notes that reference them |

### Critical: Slack Search Strategy

**Use the Slack MCP tool `conversations_search_messages`** to search Slack.

#### Rule 1: Search BOTH mentions AND authored content

To build a complete profile, you need TWO searches:

```
# 1. Find what OTHERS say about them (mentions, tags, discussions)
conversations_search_messages(search_query="firstname.lastname", limit=50)

# 2. Find what THEY do (their own messages, PoCs, demos, ideas)
conversations_search_messages(search_query="from:firstname.lastname", limit=50)
```

Only searching mentions misses all the person's own work — their PoCs, demos, ideas, and contributions.

#### Rule 2: Use correct username format

```
# CORRECT formats
search_query="firstname.lastname"        # e.g., "sarah.chen"
search_query="from:firstname.lastname"   # e.g., "from:sarah.chen"

# For filter_users_from parameter (if needed):
filter_users_from="firstname.lastname"
filter_users_from="U08TSNBB1PS"          # User ID

# WRONG - will fail with "user not found"
filter_users_from="@firstname"           # Partial name with @
```

If you don't know the exact username, do a search first to discover it from results.

#### Rule 3: Never assume channels

The `search_query` parameter searches the **entire Slack workspace**. Never filter by channel until after global search.

#### Slack Search Commands Reference

| Goal | MCP Tool Call |
|------|---------------|
| Find mentions of person | `conversations_search_messages(search_query="firstname.lastname", limit=50)` |
| Find person's own messages | `conversations_search_messages(search_query="from:firstname.lastname", limit=50)` |
| Find topic discussions | `conversations_search_messages(search_query="topic keyword", limit=50)` |
| Find person's demos/PoCs | `conversations_search_messages(search_query="from:firstname.lastname PoC demo", limit=30)` |

### GitHub Repos to Search

Read **PR_TARGET_REPO** and **ISSUE_REPO** from workspace rules (team config). Also search org-wide:

| Repo | Contains |
|------|----------|
| `<PR_TARGET_REPO>` (from team config) | Code, PRs, public issues |
| `<ISSUE_REPO>` (from team config) | Private issues, roadmap, epics, bugs |
| `elastic/elasticsearch` | ES core code and issues |

### Team Labels

Read **TEAM_LABEL** from workspace rules (team config) to filter by your team.

### Searching GitHub

**Use `gh` CLI** — it's authenticated and can access private repos.

```bash
# PRs authored by person across Elastic org
gh search prs --author=USERNAME --org=elastic --limit=30

# Issues assigned to person (private repos too)
gh search issues --assignee=USERNAME --repo=<ISSUE_REPO> --limit=30

# Issues authored by person
gh search issues --author=USERNAME --repo=<ISSUE_REPO> --limit=30

# PRs reviewed by person
gh search prs --reviewed-by=USERNAME --org=elastic --limit=20

# Get detailed PR info
gh pr view 12345 --repo <PR_TARGET_REPO>

# Get issue with comments
gh issue view 12345 --repo <ISSUE_REPO> --comments

# List person's recent merged PRs
gh search prs --author=USERNAME --repo=<PR_TARGET_REPO> --merged --limit=20
```

### Searching by Team Label

Read **TEAM_LABEL** and repos from workspace rules (team config):

```bash
# All open issues for your team
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --state=open

# Recent PRs for your team
gh search prs --repo=<PR_TARGET_REPO> --label="<TEAM_LABEL>" --limit=20

# Epics and roadmap items
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --label="epic"

# Bugs for the team
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --label="bug" --state=open
```

### Why `gh` over `git`

| Command | `git` | `gh` |
|---------|-------|------|
| View commits | Only local clone | Query any repo remotely |
| Private repos | Need clone + access | Already authenticated |
| Issues | Can't access | Full access |
| PR details | Can't access | Full access with comments |
| Search across repos | Not possible | `--org=elastic` |

### Searching the Vault

Check for existing person notes and meeting references:

```bash
# Find existing person notes
obsidian vault={{VAULT_NAME}} search query="<person-name>"

# Search meeting notes that mention them
obsidian vault={{VAULT_NAME}} search query="<person-name>" tags="meeting"
```

## Query: "Who knows about X?"

### Process

1. **Search Slack** for messages about X:
   ```
   conversations_search_messages(search_query="X topic keyword", limit=50)
   ```
2. **Search GitHub** across multiple repos:
   ```bash
   gh search prs "X" --org=elastic --limit=20
   gh search issues "X" --repo=<PR_TARGET_REPO> --limit=20
   gh search issues "X" --repo=<ISSUE_REPO> --limit=20
   ```
3. **Search the vault** for existing notes on the topic:
   ```bash
   obsidian vault={{VAULT_NAME}} search query="X topic"
   ```
4. For each hit, note who authored/participated
5. Score and rank by evidence depth

### Output Format

```markdown
# Who knows about: [Topic]

## Top Experts

### 1. @person_name (High confidence)
**Why**: Authored the main implementation, answers questions in Slack

**Evidence**:
- PR owner/repo#123: Implemented the core feature
- Slack thread: Explained the architecture in detail
- Issue owner/repo#456: Filed and resolved related bugs

**Best for**: Deep technical questions, architectural decisions
```

## Query: "What does @person do?"

### Process

1. **Search Slack for mentions** (what others say about them):
   ```
   conversations_search_messages(search_query="firstname.lastname", limit=50)
   ```

2. **Search Slack for their authored content** (what they do):
   ```
   conversations_search_messages(search_query="from:firstname.lastname", limit=50)
   ```

3. **Fetch their GitHub activity** using `gh` CLI:
   ```bash
   # PRs they authored
   gh search prs --author=USERNAME --org=elastic --limit=30

   # Issues assigned to them (roadmap, epics)
   gh search issues --assignee=USERNAME --repo=<ISSUE_REPO> --limit=30

   # PRs they reviewed (shows what areas they know)
   gh search prs --reviewed-by=USERNAME --org=elastic --limit=20

   # Issues they created (bugs found, features proposed)
   gh search issues --author=USERNAME --repo=<ISSUE_REPO> --limit=20
   ```

4. **Check the vault** for existing notes:
   ```bash
   obsidian vault={{VAULT_NAME}} search query="<person-name>"
   ```

5. Analyze communication style from Slack
6. Build comprehensive profile

## Storing Results as Vault Notes

Profiles are stored as `person` type notes in the vault. Use the classify skill's conventions.

### Creating a New Person Note

If no person note exists, create one using Obsidian CLI:

```bash
obsidian vault={{VAULT_NAME}} create path="04 Data/YYYY/MM/YYYY.MM.DD-<person-name>.md" content="<content>" silent
```

**Frontmatter** (per `05 Meta/claude/person.claude.md`):

```yaml
---
type: person
name: "Full Name"
context: "Role/relationship summary"
last_touched: YYYY-MM-DD
aliases:
  - person-name
tags:
  - domain-tags
  - from-research
created: YYYY-MM-DD HH:mm
modified: YYYY-MM-DD HH:mm
classified_at: YYYY-MM-DD HH:mm
confidence: 0.95
---
```

**Body structure:**

```markdown
## Expertise

| Domain | Confidence | Key Evidence |
|--------|-----------|--------------|
| workflow execution | High | Authored PRs #123, #456; owns epic #789 |
| API design | Medium | Reviews PRs in api/ directory |

## Projects

- **Project Name** — Role, key PRs/issues
- **Another Project** — Contributions summary

## Communication Style

- Tone: direct, technical
- Prefers: async Slack threads over meetings
- Active in: #channel-a, #channel-b

## Notes

Freeform interaction history and context goes here.
```

### Updating an Existing Person Note

If a person note already exists, read it and **append** new expertise data — don't overwrite. Update:
- `last_touched` to today
- `modified` to now
- Add new domains to the Expertise table
- Add new projects
- Merge new tags

### Git Commit

```bash
git add "04 Data/YYYY/MM/YYYY.MM.DD-<person-name>.md"
git commit -m "sb: people-expertise-map — profiled <person-name>"
```

## Example Queries

**"Who should I ask about X?"**
```
# Step 1: Search Slack
conversations_search_messages(search_query="X topic", limit=50)

# Step 2: Search GitHub (repos from team config)
gh search issues "X topic" --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --limit=20
gh search prs "X topic" --repo=<PR_TARGET_REPO> --label="<TEAM_LABEL>" --limit=20

# Step 3: Check vault
obsidian vault={{VAULT_NAME}} search query="X topic"
```

**"What does the team own?"**
```
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --state=open --limit=30
gh search prs --repo=<PR_TARGET_REPO> --label="<TEAM_LABEL>" --limit=20
```

**"Build a profile for someone"**
```
# Step 1: Slack mentions (what others say)
conversations_search_messages(search_query="firstname.lastname", limit=50)

# Step 2: Slack authored (what they do)
conversations_search_messages(search_query="from:firstname.lastname", limit=50)

# Step 3: GitHub PRs
gh search prs --author=USERNAME --org=elastic --limit=30

# Step 4: GitHub issues
gh search issues --assignee=USERNAME --repo=<ISSUE_REPO> --limit=20

# Step 5: Existing vault context
obsidian vault={{VAULT_NAME}} search query="person-name"

# Step 6: Create/update person note in vault
```

**"Find all PRs someone authored"**
```
gh search prs --author=USERNAME --org=elastic
```

**"What does @person work on?"**
```
# Same as profile build — emphasize recent activity
conversations_search_messages(search_query="from:firstname.lastname", limit=50)
gh search prs --author=USERNAME --merged --limit=20
```

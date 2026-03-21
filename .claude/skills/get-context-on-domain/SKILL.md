---
name: get-context-on-domain
description: Deep-dive investigation into a technical domain's history, architecture evolution, key people, and decisions. Use when asked to understand "how X works", "history of Y", "who built Z", or when needing comprehensive context on a codebase area, feature, or system.
---

# Get Context on Domain

Builds comprehensive understanding of a technical domain through **iterative cross-referencing** between code, people, Slack, GitHub, and docs.

## Core Philosophy

**Ping-pong discovery**: Don't just search once. Each finding leads to new questions:
- Code → Who authored it? → What did they discuss? → What decisions were made? → What other code?
- Slack thread → Who participated? → What PRs did they create? → What architecture emerged?
- PR → What issue motivated it? → What alternatives were considered? → Who reviewed?

## Execution Workflow

### Phase 1: Initial Discovery (Breadth)

Run these searches **in parallel** to establish the landscape:

```
# 1. Code structure
Glob("**/domain_name/**/*.ts")
Grep("class.*DomainName|interface.*DomainName")

# 2. Slack mentions (global - both mentions AND authored)
conversations_search_messages(search_query="domain_name")
conversations_search_messages(search_query="from:likely.author domain_name")

# 3. GitHub activity (use PR_TARGET_REPO and ISSUE_REPO from team config)
gh search issues --repo=<PR_TARGET_REPO> --search="domain_name" --limit=30
gh search prs --repo=<PR_TARGET_REPO> --search="domain_name" --limit=30
```

### Phase 2: Identify Key Actors

From Phase 1 results, extract:

| Actor Type | How to Find |
|------------|-------------|
| **Code owners** | CODEOWNERS file, git blame on core files |
| **PR authors** | `gh search prs --author=USERNAME` |
| **Active discussants** | Slack thread participants |
| **Reviewers** | PR review comments |

For each key person discovered:
```bash
# Get their activity on this domain
gh search prs --author=USERNAME --repo=<PR_TARGET_REPO> --search="domain_name"
conversations_search_messages(search_query="from:username domain_name")
```

### Phase 3: Timeline Reconstruction

Build chronological understanding:

```
1. Find the EARLIEST commits/PRs
   gh search prs --repo=<PR_TARGET_REPO> --search="domain_name" --sort=created --order=asc

2. Identify major milestones
   - Initial implementation
   - Major refactors
   - Architecture changes
   - Performance improvements

3. For each milestone:
   - Read the PR description
   - Find related Slack discussions
   - Note decision rationale
```

### Phase 4: Architecture Evolution

Track how the system changed:

```markdown
## Architecture Timeline

### v1: [Date] - Initial Implementation
- **PR**: #12345
- **Author**: @person
- **Key decisions**: 
  - Chose X over Y because...
- **Slack context**: [link to thread]

### v2: [Date] - Major Refactor  
- **PR**: #23456
- **Motivation**: Performance issues reported in #issue
- **Changes**: Moved from sync to async
- **Discussion**: [slack thread where alternatives were debated]
```

### Phase 5: Iterative Deep Dives

For each interesting finding, **go deeper**:

```
WHILE new_insights_found:
    FOR each PR/issue/thread:
        - Read linked issues ("closes #X", "relates to #Y")
        - Check comments for context
        - Find related Slack threads
        - Identify mentioned alternatives/tradeoffs
        
    FOR each person discovered:
        - Search their messages on this topic
        - Find their other PRs in this area
        - Note their expertise areas
        
    FOR each decision point:
        - Find the discussion where it was made
        - Document alternatives considered
        - Note who made the call and why
```

## Output Format

### Domain Context Report

```markdown
# Domain: [Name]

## Executive Summary
[2-3 sentences: what it is, why it exists, current state]

## Key People

| Person | Role | Expertise | Active Period |
|--------|------|-----------|---------------|
| @name | Original author | Core architecture | 2023-2024 |
| @name | Current maintainer | Performance | 2024-present |

## Architecture Evolution

### Phase 1: [Name] (Date Range)
**Goal**: [What problem was being solved]
**Key PRs**: #123, #456
**Architecture**: [Brief description]
**Key Decisions**:
- Decision 1: Chose X because [rationale from Slack/PR]
- Decision 2: [...]

### Phase 2: [Name] (Date Range)
[...]

## Key Decisions & Rationale

| Decision | Date | Who | Why | Alternatives Considered |
|----------|------|-----|-----|------------------------|
| Use async | 2024-03 | @author | Performance at scale | Sync with caching |

## Current State

**Codebase location**: `src/path/to/domain/`
**Main interfaces**: `Interface1`, `Interface2`
**Key dependencies**: Plugin A, Service B
**Known issues/debt**: #issue1, #issue2

## Sources
- PR #123: [title]
- Slack thread: [link]
- Issue #456: [title]
```

## Search Strategies

### Finding Original Implementation

```bash
# Sort PRs by creation date (oldest first)
gh search prs --repo=<PR_TARGET_REPO> --search="domain_name" --sort=created --order=asc --limit=10

# Git log for the directory
git log --oneline --follow -- "src/path/to/domain" | tail -20
```

### Finding Decision Discussions

```
# Slack searches
conversations_search_messages(search_query="domain_name architecture")
conversations_search_messages(search_query="domain_name alternative")
conversations_search_messages(search_query="domain_name decision")
conversations_search_messages(search_query="domain_name why")

# GitHub issue comments
gh issue view ISSUE_NUMBER --comments
```

### Finding Breaking Changes

```bash
# PRs with "breaking" or "refactor" 
gh search prs --repo=<PR_TARGET_REPO> --search="domain_name breaking OR refactor"

# Look for deprecation notices
Grep("@deprecated.*DomainName|DEPRECATED.*domain")
```

### Cross-Repository Context

Some decisions span repos:

```bash
# Elasticsearch side
gh search issues --repo=elastic/elasticsearch --search="domain_name"

# Security team discussions (private)
# Private issue repo (read ISSUE_REPO from team config)
gh search issues --repo=<ISSUE_REPO> --search="domain_name"
```

## Iteration Triggers

**Keep digging when you find:**

| Finding | Next Action |
|---------|-------------|
| PR mentions "as discussed with @person" | Search that person's Slack messages |
| Issue links to another issue | Read the linked issue |
| Comment says "see RFC/doc" | Find and read the doc |
| Person is very active | Build their profile, find their other work |
| Decision seems controversial | Find the debate thread |
| Architecture changed significantly | Find the motivation (issues, Slack) |
| "Temporary solution" or "TODO" | Find if it was ever addressed |

## Anti-Patterns

**DON'T:**
- Stop after first search - iterate!
- Assume code tells the whole story - find the humans
- Ignore Slack - that's where real decisions happen
- Skip old PRs - history explains current state
- Forget to check private repos (ISSUE_REPO from team config)

**DO:**
- Cross-reference everything
- Build person profiles as you go
- Note uncertainty ("unclear why X was chosen")
- Capture alternative approaches that were rejected
- Link everything back to sources

## Example: "Get context on Task Manager"

```
1. Initial search:
   - Glob("**/task_manager/**")
   - gh search prs --search="task manager" --repo=<PR_TARGET_REPO>
   - conversations_search_messages(search_query="task manager")

2. Discover key people:
   - @mike.cote - lots of early PRs
   - @yuliia.naumenko - recent issues about execution context

3. For Mike Cote:
   - gh search prs --author=mikecote --search="task manager"
   - conversations_search_messages(search_query="from:mike.cote task manager")

4. Find architecture evolution:
   - Early: Simple polling mechanism
   - Mid: Added concurrency controls  
   - Recent: Execution as current user (#190661)

5. Find decision points:
   - Why polling vs events? → Find Slack discussion
   - Why max workers limit? → Find the perf issue

6. Document timeline with sources
```

## Completeness Checklist

Before finishing, verify you have:

- [ ] Identified the original author(s)
- [ ] Found the initial PR/commit
- [ ] Documented at least 2-3 architecture phases
- [ ] Captured key decisions with rationale
- [ ] Listed current maintainers
- [ ] Noted known issues/tech debt
- [ ] Cross-referenced code ↔ people ↔ discussions
- [ ] Checked both public and private repos (if accessible)

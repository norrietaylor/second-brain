---
name: obsidian-cli
description: >
  Reference for the Obsidian CLI (v1.12+). Provides command syntax, parameter
  patterns, output formats, and gotchas. Use when running obsidian commands,
  writing scripts that call the CLI, or automating vault operations.
---
# Obsidian CLI Reference

## Version and Source

- **CLI version:** 1.12.5 (installer 1.12.5)
- **Documentation source:** https://help.obsidian.md/cli
- **Documentation date:** 2026-03-13
- **Changelog:** https://obsidian.md/changelog/

When a newer Obsidian version is released, compare the output of `obsidian help` against the command catalog in [commands-reference.md](commands-reference.md) to identify changes.

## Critical Gotchas

These behaviors will silently cause failures if you are not aware of them:

1. **Exit codes are always 0.** Even errors return exit code 0. You MUST parse stdout for error strings (`"Error:"`, `"No vault found."`, `"not found"`) rather than checking `$?`.

2. **~~Loading line on stdout.~~** Fixed in installer 1.12.5. Previously every command emitted a `Loading updated app package` line to stdout. No longer present — no need to strip it.

3. **Obsidian must be running.** The CLI communicates with the running Obsidian desktop app via IPC. If Obsidian is not open, commands will hang or fail silently.

4. **Paths are vault-relative.** All `path=` arguments are relative to the vault root, never absolute filesystem paths. Example: `path="04 Data/2026/02/file.md"`, not `path="/Users/nick/vault/04 Data/..."`.

5. **`base:query` requires `.base` extension.** `path="02 Areas/Today"` returns "Base file not found". Correct: `path="02 Areas/Today.base"`.

6. **`file=` vs `path=`.** `file=` matches by filename without extension. `path=` matches by full vault-relative path including extension. Prefer `path=` for precision.

7. **List properties require JSON.** When setting a list property: `value='["tag1","tag2"]' type=list`.

8. **`append` vs `append inline`.** `append` inserts a newline before the content. `append inline` appends directly to the last character with no newline.

9. **`delete` moves to trash** by default. Add the `permanent` flag to permanently delete.

10. **`silent` flag on `create`** prevents the new file from being opened in the Obsidian UI. Always use `silent` in scripts and automation.

11. **`property:set` hangs on 3+ byte UTF-8 characters.** Values containing em dash (`—`), en dash (`–`), ellipsis (`…`), arrows (`→`), stars (`★`), emoji, or other characters encoded as 3+ bytes in UTF-8 cause `property:set` to hang indefinitely. No quoting or escaping strategy resolves this — it is a CLI bug. **Workaround:** Fall back to direct file editing (read file, string-replace the frontmatter value, write file) when the value contains these characters. ASCII, regular hyphens (`-`), and 2-byte UTF-8 (accented Latin like `é`, `ñ`, `ü`) all work fine.

12. **~~SIGPIPE causes hangs.~~** Fixed in installer 1.12.5. Piping through `head`, `tail`, etc. now works directly. No `cat` buffer workaround needed.

## Syntax

```
obsidian [vault=<name>] <command> [key=value ...] [flags]
```

Rules:
- All arguments use `key=value` syntax -- no `--` prefixes, no spaces around `=`
- Quote values containing spaces: `path="04 Data/2026/02/file.md"`
- When calling from bash with special characters, quote the whole argument: `obsidian "vault=My Vault" ...`
- Boolean flags are bare words (no value): `silent`, `overwrite`, `permanent`, `inline`, `matches`, `case`, `total`, `counts`, `verbose`
- Commands use colons for namespacing: `property:set`, `base:query`, `plugin:enable`

## Most-Used Commands

### create

Create a new note. Multiline content with frontmatter works.

```bash
obsidian vault={{VAULT_NAME}} create path="04 Data/2026/02/file.md" content="---
type: task
---
# My Note
Content here." silent
```

Output: `Created: 04 Data/2026/02/file.md`

Flags: `silent` (don't open in UI), `overwrite` (replace existing), `newtab` (open in new tab)

### read

Read file contents (frontmatter + body).

```bash
obsidian vault={{VAULT_NAME}} read path="04 Data/2026/02/file.md"
```

Output: raw file contents including `---` frontmatter block.

### append / prepend

Add content to an existing file.

```bash
# Adds newline + content
obsidian vault={{VAULT_NAME}} append path="file.md" content="New line"

# Appends directly to last character (no newline)
obsidian vault={{VAULT_NAME}} append path="file.md" content=" inline text" inline
```

Output: `Appended to: file.md` or `Prepended to: file.md`

### move

Rename or move a file.

```bash
obsidian vault={{VAULT_NAME}} move path="04 Data/old-name.md" to="04 Data/new-name.md"
```

### delete

Move to system trash (or permanently delete).

```bash
obsidian vault={{VAULT_NAME}} delete path="04 Data/file.md"
obsidian vault={{VAULT_NAME}} delete path="04 Data/file.md" permanent
```

Output: `Moved to trash: 04 Data/file.md` or `Deleted: 04 Data/file.md`

### property:set

Set a frontmatter property. Creates the property if it doesn't exist.

```bash
# Text (default type)
obsidian vault={{VAULT_NAME}} property:set name=type value=person path="file.md"

# Number
obsidian vault={{VAULT_NAME}} property:set name=confidence value=0.85 type=number path="file.md"

# List (pass JSON array)
obsidian vault={{VAULT_NAME}} property:set name=tags value='["api","backend"]' type=list path="file.md"

# Checkbox
obsidian vault={{VAULT_NAME}} property:set name=done value=true type=checkbox path="file.md"

# Date / Datetime
obsidian vault={{VAULT_NAME}} property:set name=due value="2026-02-14" type=date path="file.md"
obsidian vault={{VAULT_NAME}} property:set name=classified_at value="2026-02-13 14:00" type=datetime path="file.md"
```

Output: `Set <name>: <value>`

### property:read

Read a single property value from a file.

```bash
obsidian vault={{VAULT_NAME}} property:read name=type path="file.md"
```

Output: the raw value. For lists, one item per line:
```
engineering
api
```

### property:remove

Remove a property from a file's frontmatter.

```bash
obsidian vault={{VAULT_NAME}} property:remove name=status path="file.md"
```

### search

Search vault text content.

```bash
# Basic search (returns file paths, one per line)
obsidian vault={{VAULT_NAME}} search query="API deadline"

# JSON format (returns JSON array of paths)
obsidian vault={{VAULT_NAME}} search query="sarah-chen" format=json
# Output: ["CLAUDE.md","04 Data/2026/02/2026.02.13-sarah-chen.md"]

# Scoped to a folder
obsidian vault={{VAULT_NAME}} search query="sarah" path="04 Data" format=json

# Case-sensitive
obsidian vault={{VAULT_NAME}} search query="API" case
```

Flags: `case` (case-sensitive), `total` (count only), `limit=<n>` (max files)

For matching line context, use the separate `search:context` command:

```bash
obsidian vault={{VAULT_NAME}} search:context query="sarah-chen" format=json
```

### base:query

Query an Obsidian Bases view. **Always include the `.base` extension in the path.**

```bash
obsidian vault={{VAULT_NAME}} base:query path="02 Areas/Tasks.base" format=json
```

Output formats:
- `format=json` -- JSON array of objects with columns as keys (best for scripting)
- `format=paths` -- one vault-relative path per line
- `format=csv` / `format=tsv` -- tabular
- `format=md` -- markdown table

JSON example output:
```json
[
  {
    "path": "04 Data/2026/02/2026.02.13-complete-talent-review.md",
    "file name": "2026.02.13-complete-talent-review"
  }
]
```

You can also target a specific view within a base: `view="View Name"`.

### daily:path

Get the vault-relative path of today's daily note.

```bash
obsidian vault={{VAULT_NAME}} daily:path
```

Output: the vault-relative path, e.g. `04 Data/2026/03/2026.03.13-daily-note.md`

### rename

Rename a file (without moving it to a different folder).

```bash
obsidian vault={{VAULT_NAME}} rename path="04 Data/old-name.md" name="new-name"
```

### bases

List all `.base` files in the vault.

```bash
obsidian vault={{VAULT_NAME}} bases
```

### file

Show file metadata.

```bash
obsidian vault={{VAULT_NAME}} file path="04 Data/2026/02/file.md"
```

Output (tab-separated):
```
path	04 Data/2026/02/file.md
name	file
extension	md
size	402
created	1770990073797
modified	1770990167846
```

Note: `created` and `modified` are Unix epoch **milliseconds**.

### vaults

List known vault names (for discovering the vault= value).

```bash
obsidian vaults
```

Output: one vault name per line.

## Error Patterns

Since exit codes are always 0, check stdout for these error strings:

| Error String | Meaning |
|---|---|
| `No vault found.` | vault= name doesn't match any known vault |
| `Error: File "..." not found.` | file/path doesn't exist in the vault |
| `Error: Base file not found: ...` | base path is wrong (likely missing .base extension) |
| `Error: Command "..." not found. Did you mean: ...?` | typo in command name |
| `Error: Missing required parameter: ...` | a required key=value was omitted |

## Stripping the Loading Line (Legacy)

As of installer 1.12.5, the loading line is no longer emitted. The stripping pattern below is only needed if targeting older CLI versions:

```bash
# Bash: strip the loading line (only needed for CLI < 1.12.5)
OUTPUT=$(obsidian vault={{VAULT_NAME}} base:query path="file.base" format=json)
OUTPUT=$(echo "$OUTPUT" | grep -v "^[0-9]\{4\}-" || true)

# Then parse with jq, etc.
echo "$OUTPUT" | jq 'length'
```

## Additional Commands

For the full command catalog (80+ commands), see [commands-reference.md](commands-reference.md).

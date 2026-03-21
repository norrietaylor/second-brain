# Obsidian CLI — Full Command Reference

> Source: `obsidian help` output from Obsidian v1.12.5 (2026-03-13)
> See [SKILL.md](SKILL.md) for syntax, gotchas, and most-used command examples.

## File Operations

| Command | Signature | Description |
|---|---|---|
| `create` | `[name=<name>] [path=<path>] [content=<text>] [template=<name>] [overwrite] [open] [silent] [newtab]` | Create a new file |
| `read` | `[file=<name>] [path=<path>]` | Read file contents |
| `append` | `[file=<name>] [path=<path>] content=<text> [inline]` | Append content to a file |
| `prepend` | `[file=<name>] [path=<path>] content=<text> [inline]` | Prepend content to a file |
| `move` | `[file=<name>] [path=<path>] to=<path>` | Move or rename a file |
| `delete` | `[file=<name>] [path=<path>] [permanent]` | Delete a file |
| `rename` | `[file=<name>] [path=<path>] name=<name>` | Rename a file |
| `open` | `[file=<name>] [path=<path>] [newtab]` | Open a file in Obsidian |
| `file` | `[file=<name>] [path=<path>]` | Show file info (path, size, created, modified) |
| `files` | `[folder=<path>] [ext=<extension>] [total]` | List files in the vault |
| `folder` | `path=<path> [info=files\|folders\|size]` | Show folder info |
| `folders` | `[folder=<path>] [total]` | List folders in the vault |
| `wordcount` | `[file=<name>] [path=<path>] [words] [characters]` | Count words and characters |

## Properties

| Command | Signature | Description |
|---|---|---|
| `property:set` | `name=<name> value=<value> [type=text\|list\|number\|checkbox\|date\|datetime] [file=<name>] [path=<path>]` | Set a property on a file |
| `property:read` | `name=<name> [file=<name>] [path=<path>]` | Read a property value from a file |
| `property:remove` | `name=<name> [file=<name>] [path=<path>]` | Remove a property from a file |
| `properties` | `[active] [file=<name>] [path=<path>] [name=<name>] [total] [sort=count] [counts] [format=yaml\|json\|tsv]` | List properties in the vault or for a file |
| `aliases` | `[active] [file=<name>] [path=<path>] [total] [verbose]` | List aliases in the vault or file |

## Search

| Command | Signature | Description |
|---|---|---|
| `search` | `query=<text> [path=<folder>] [limit=<n>] [total] [case] [format=text\|json]` | Search vault for text |
| `search:context` | `query=<text> [path=<folder>] [limit=<n>] [case] [format=text\|json]` | Search with matching line context |
| `search:open` | `[query=<text>]` | Open search view in Obsidian |

## Bases

| Command | Signature | Description |
|---|---|---|
| `bases` | | List all base files in vault |
| `base:query` | `[file=<name>] [path=<path>] [view=<name>] [format=json\|csv\|tsv\|md\|paths]` | Query a base and return results |
| `base:views` | | List views in the current base file |
| `base:create` | `[file=<name>] [path=<path>] [view=<name>] [name=<name>] [content=<text>] [open] [newtab]` | Create a new item in the current base view |

## Daily Notes

| Command | Signature | Description |
|---|---|---|
| `daily` | `[paneType=tab\|split\|window]` | Open daily note |
| `daily:path` | | Get daily note path |
| `daily:read` | | Read daily note contents |
| `daily:append` | `content=<text> [inline] [silent] [paneType=tab\|split\|window]` | Append content to daily note |
| `daily:prepend` | `content=<text> [inline] [silent] [paneType=tab\|split\|window]` | Prepend content to daily note |

## Links

| Command | Signature | Description |
|---|---|---|
| `backlinks` | `[file=<name>] [path=<path>] [counts] [total] [format=json\|tsv\|csv]` | List backlinks to a file |
| `links` | `[file=<name>] [path=<path>] [total]` | List outgoing links from a file |
| `unresolved` | `[total] [counts] [verbose]` | List unresolved links in vault |
| `orphans` | `[total] [all]` | List files with no incoming links |
| `deadends` | `[total] [all]` | List files with no outgoing links |

## Tags

| Command | Signature | Description |
|---|---|---|
| `tags` | `[active] [file=<name>] [path=<path>] [total] [counts] [sort=count] [format=json\|tsv\|csv]` | List tags in the vault or file |
| `tag` | `name=<tag> [total] [verbose]` | Get tag info |

## Tasks

| Command | Signature | Description |
|---|---|---|
| `tasks` | `[active] [daily] [file=<name>] [path=<path>] [total] [done] [todo] [status="<char>"] [verbose] [format=json\|tsv\|csv]` | List tasks in the vault or file |
| `task` | `[ref=<path:line>] [file=<name>] [path=<path>] [line=<n>] [toggle] [done] [todo] [daily] [status="<char>"]` | Show or update a task |

## Templates

| Command | Signature | Description |
|---|---|---|
| `templates` | `[total]` | List templates |
| `template:read` | `name=<template> [resolve] [title=<title>]` | Read template content |
| `template:insert` | `name=<template>` | Insert template into active file |

## Outline

| Command | Signature | Description |
|---|---|---|
| `outline` | `[file=<name>] [path=<path>] [format=tree\|md\|json] [total]` | Show headings for a file |

## Bookmarks

| Command | Signature | Description |
|---|---|---|
| `bookmarks` | `[total] [verbose] [format=json\|tsv\|csv]` | List bookmarks |
| `bookmark` | `[file=<path>] [subpath=<subpath>] [folder=<path>] [search=<query>] [url=<url>] [title=<title>]` | Add a bookmark |

## Plugins

| Command | Signature | Description |
|---|---|---|
| `plugins` | `[filter=core\|community] [versions] [format=json\|tsv\|csv]` | List installed plugins |
| `plugins:enabled` | `[filter=core\|community] [versions] [format=json\|tsv\|csv]` | List enabled plugins |
| `plugins:restrict` | `[on] [off]` | Toggle or check restricted mode |
| `plugin` | `id=<plugin-id>` | Get plugin info |
| `plugin:enable` | `id=<id> [filter=core\|community]` | Enable a plugin |
| `plugin:disable` | `id=<id> [filter=core\|community]` | Disable a plugin |
| `plugin:install` | `id=<id> [enable]` | Install a community plugin |
| `plugin:uninstall` | `id=<id>` | Uninstall a community plugin |
| `plugin:reload` | `id=<id>` | Reload a plugin (for developers) |

## Vault Management

| Command | Signature | Description |
|---|---|---|
| `vault` | `[info=name\|path\|files\|folders\|size]` | Show vault info |
| `vaults` | `[total] [verbose]` | List known vaults |
| `recents` | `[total]` | List recently opened files |
| `random` | `[folder=<path>] [newtab]` | Open a random note |
| `random:read` | `[folder=<path>]` | Read a random note |

## Themes and Snippets

| Command | Signature | Description |
|---|---|---|
| `themes` | `[versions]` | List installed themes |
| `theme` | `[name=<name>]` | Show active theme or get info |
| `theme:set` | `name=<name>` | Set active theme |
| `theme:install` | `name=<name> [enable]` | Install a community theme |
| `theme:uninstall` | `name=<name>` | Uninstall a theme |
| `snippets` | | List installed CSS snippets |
| `snippets:enabled` | | List enabled CSS snippets |
| `snippet:enable` | `name=<name>` | Enable a CSS snippet |
| `snippet:disable` | `name=<name>` | Disable a CSS snippet |

## Sync

| Command | Signature | Description |
|---|---|---|
| `sync` | `[on] [off]` | Pause or resume sync |
| `sync:status` | | Show sync status |
| `sync:history` | `[file=<name>] [path=<path>] [total]` | List sync version history for a file |
| `sync:read` | `[file=<name>] [path=<path>] version=<n>` | Read a sync version |
| `sync:restore` | `[file=<name>] [path=<path>] version=<n>` | Restore a sync version |
| `sync:open` | `[file=<name>] [path=<path>]` | Open sync history |
| `sync:deleted` | `[total]` | List deleted files in sync |

## File History

| Command | Signature | Description |
|---|---|---|
| `diff` | `[file=<name>] [path=<path>] [from=<n>] [to=<n>] [filter=local\|sync]` | List or diff local/sync versions |
| `history` | `[file=<name>] [path=<path>]` | List file history versions |
| `history:list` | | List files with history |
| `history:read` | `[file=<name>] [path=<path>] [version=<n>]` | Read a file history version |
| `history:restore` | `[file=<name>] [path=<path>] version=<n>` | Restore a file history version |
| `history:open` | `[file=<name>] [path=<path>]` | Open file recovery |

## Workspace and Tabs

| Command | Signature | Description |
|---|---|---|
| `workspace` | `[ids]` | Show workspace tree |
| `tabs` | `[ids]` | List open tabs |
| `tab:open` | `[group=<id>] [file=<path>] [view=<type>]` | Open a new tab |

## Command Palette

| Command | Signature | Description |
|---|---|---|
| `commands` | `[filter=<prefix>]` | List available command IDs |
| `command` | `id=<command-id>` | Execute an Obsidian command |
| `hotkeys` | `[total] [all] [verbose] [format=json\|tsv\|csv]` | List hotkeys |
| `hotkey` | `id=<command-id> [verbose]` | Get hotkey for a command |

## General

| Command | Signature | Description |
|---|---|---|
| `help` | | Show list of all available commands |
| `version` | | Show Obsidian version |
| `reload` | | Reload the vault |
| `restart` | | Restart the app |

## Developer

| Command | Signature | Description |
|---|---|---|
| `devtools` | | Toggle Electron dev tools |
| `dev:debug` | `[on] [off]` | Attach/detach Chrome DevTools Protocol debugger |
| `dev:cdp` | `method=<CDP.method> [params=<json>]` | Run a Chrome DevTools Protocol command |
| `dev:errors` | `[clear]` | Show captured errors |
| `dev:screenshot` | `[path=<filename>]` | Take a screenshot |
| `dev:console` | `[clear] [limit=<n>] [level=log\|warn\|error\|info\|debug]` | Show captured console messages |
| `dev:css` | `selector=<css> [prop=<name>]` | Inspect CSS with source locations |
| `dev:dom` | `selector=<css> [total] [text] [inner] [all] [attr=<name>] [css=<prop>]` | Query DOM elements |
| `dev:mobile` | `[on] [off]` | Toggle mobile emulation |
| `eval` | `code=<javascript>` | Execute JavaScript and return result |

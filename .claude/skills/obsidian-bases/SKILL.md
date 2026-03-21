---
name: obsidian-bases
description: >
  Create and edit Obsidian Bases (.base files) with views, filters, formulas, and summaries.
  Use when working with .base files, creating database-like views of notes, or when the user
  mentions Bases, table views, card views, filters, or formulas in Obsidian.
---

# Obsidian Bases Skill

## Workflow

1. **Create the file**: Create a `.base` file in the vault with valid YAML content
2. **Define scope**: Add `filters` to select which notes appear (by tag, folder, property, or date)
3. **Add formulas** (optional): Define computed properties in the `formulas` section
4. **Configure views**: Add one or more views (`table`, `cards`, `list`, or `map`) with `order` specifying which properties to display
5. **Validate**: Verify the file is valid YAML with no syntax errors. Check that all referenced properties and formulas exist. Common issues: unquoted strings containing special YAML characters, mismatched quotes in formula expressions, referencing `formula.X` without defining `X` in `formulas`
6. **Test in Obsidian**: Open the `.base` file in Obsidian to confirm the view renders correctly. If it shows a YAML error, check quoting rules below

## Critical Gotchas

1. **SIGPIPE hangs**: Never pipe `obsidian base:query` output through `head`/`tail` directly. Use `obsidian ... | cat | head` or built-in `view=` filtering instead. See the obsidian-cli skill gotcha #12.

2. **Duration syntax**: Use `duration("45 days")` not `dur("45d")`. The `dur()` shorthand does not work in Base filter expressions.

3. **Empty array filtering**: Properties stored as empty YAML arrays (`[]`) are NOT matched by `!= ""` or `!= null`. Use `length(property) > 0` to filter for non-empty arrays.

4. **YAML quoting**: Formulas with double quotes must be wrapped in single quotes: `'if(done, "Yes", "No")'`. Strings with `:`, `{`, `}`, `[`, `]` must be quoted.

5. **Duration math**: Subtracting dates returns Duration, not number. Always access `.days`, `.hours`, etc. before applying `.round()`.

6. **Null guards**: Use `if()` to guard properties that may not exist: `'if(due_date, (date(due_date) - today()).days, "")'`

## Schema

Base files use the `.base` extension and contain valid YAML.

```yaml
# Global filters apply to ALL views in the base
filters:
  # Can be a single filter string
  # OR a recursive filter object with and/or/not
  and: []
  or: []
  not: []

# Define formula properties that can be used across all views
formulas:
  formula_name: 'expression'

# Configure display names and settings for properties
properties:
  property_name:
    displayName: "Display Name"
  formula.formula_name:
    displayName: "Formula Display Name"

# Define custom summary formulas
summaries:
  custom_summary_name: 'values.mean().round(3)'

# Define one or more views
views:
  - type: table | cards | list | map
    name: "View Name"
    limit: 10                    # Optional: limit results
    groupBy:                     # Optional: group results
      property: property_name
      direction: ASC | DESC
    filters:                     # View-specific filters (narrow global)
      and: []
    order:                       # Properties to display in order
      - file.name
      - property_name
      - formula.formula_name
    sort:                        # Sort order
      - property: property_name
        direction: ASC | DESC
    summaries:                   # Map properties to summary formulas
      property_name: Average
```

## Querying Bases via CLI

```bash
# Query default (first) view
obsidian vault=second-brain base:query path="02 Areas/Tasks.base" format=json

# Query a specific named view
obsidian vault=second-brain base:query path="02 Areas/Digests.base" view="Recent" format=json

# List views in a base
obsidian vault=second-brain base:views
```

Always include the `.base` extension in the path. Never pipe output through `head`/`tail` directly.

## Filter Syntax

Filters narrow down results. They can be applied globally or per-view.

### Filter Structure

```yaml
# Single filter
filters: 'status == "done"'

# AND - all conditions must be true
filters:
  and:
    - 'status == "done"'
    - 'priority > 3'

# OR - any condition can be true
filters:
  or:
    - 'file.hasTag("book")'
    - 'file.hasTag("article")'

# NOT - exclude matching items
filters:
  not:
    - 'file.hasTag("archived")'

# Nested filters
filters:
  or:
    - file.hasTag("tag")
    - and:
        - file.hasTag("book")
        - file.inFolder("Required Reading")
```

### Filter Operators

| Operator | Description |
|----------|-------------|
| `==` | equals |
| `!=` | not equal |
| `>` | greater than |
| `<` | less than |
| `>=` | greater than or equal |
| `<=` | less than or equal |
| `&&` | logical and |
| `\|\|` | logical or |

### Common Filter Patterns

```yaml
# Filter by folder
- file.inFolder("04 Data")

# Filter by type property
- type == "task"

# Filter by tag
- file.hasTag("project")

# Filter by date range (use duration(), not dur())
- period_end >= today() - duration("45 days")
- due <= today()

# Filter for non-empty arrays (NOT != "")
- length(follow_ups) > 0

# Filter for non-empty strings
- summary != ""
```

## Properties

### Three Types

1. **Note properties** — From frontmatter: `author`, `status`, `due`
2. **File properties** — File metadata: `file.name`, `file.mtime`, `file.ctime`, `file.size`, `file.folder`, `file.tags`
3. **Formula properties** — Computed values: `formula.my_formula`

### The `this` Keyword

- In main content area: refers to the base file itself
- When embedded: refers to the embedding file (useful for daily notes with inline bases)

## Formula Syntax

```yaml
formulas:
  # Conditional logic (single quotes wrapping double quotes!)
  status_icon: 'if(done, "Yes", "No")'

  # Date formatting
  created: 'file.ctime.format("YYYY-MM-DD")'

  # Days since created (Duration → .days → number)
  days_old: '(now() - file.ctime).days'

  # Null-safe date calculation
  days_until_due: 'if(due_date, (date(due_date) - today()).days, "")'

  # Link formatting
  File: |
    if(aliases, link(file, aliases), file)
```

## Key Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `date()` | `date(string): date` | Parse string to date |
| `now()` | `now(): date` | Current date and time |
| `today()` | `today(): date` | Current date (time = 00:00:00) |
| `duration()` | `duration(string): duration` | Parse duration (e.g., `"45 days"`, `"7d"`, `"1M"`) |
| `if()` | `if(cond, true, false?)` | Conditional |
| `link()` | `link(path, display?): Link` | Create a link |
| `file()` | `file(path): file` | Get file object |
| `length()` | `length(list): number` | List/array length |

For the complete function reference (Date, String, Number, List, File, Link, Object, RegExp), see [FUNCTIONS_REFERENCE.md](references/FUNCTIONS_REFERENCE.md).

## Duration Type

When subtracting two dates, the result is a **Duration** (not a number).

**Fields:** `.days`, `.hours`, `.minutes`, `.seconds`, `.milliseconds`

```yaml
# CORRECT
"(date(due_date) - today()).days"              # Number of days
"(now() - file.ctime).days.round(0)"           # Rounded days

# WRONG — Duration doesn't support .round() directly
"(now() - file.ctime).round(0)"
```

### Date Arithmetic

```yaml
# Duration units: y/year/years, M/month/months, d/day/days,
#                 w/week/weeks, h/hour/hours, m/minute/minutes
"today() + duration(\"7d\")"                    # A week from today
"today() - duration(\"45 days\")"               # 45 days ago
```

## Default Summary Formulas

| Name | Input | Description |
|------|-------|-------------|
| `Sum` | Number | Sum of all |
| `Average` | Number | Mean |
| `Min` / `Max` | Number | Smallest / largest |
| `Median` | Number | Median |
| `Earliest` / `Latest` | Date | Date range |
| `Checked` / `Unchecked` | Boolean | Count true/false |
| `Empty` / `Filled` | Any | Count empty/non-empty |
| `Unique` | Any | Count unique values |

## Embedding Bases in Markdown

```markdown
![[MyBase.base]]

<!-- Specific view -->
![[MyBase.base#View Name]]
```

## Troubleshooting

### YAML Errors

```yaml
# WRONG — colon in unquoted string
displayName: Status: Active

# CORRECT
displayName: "Status: Active"

# WRONG — double quotes inside double quotes
label: "if(done, "Yes", "No")"

# CORRECT — single quotes wrapping double quotes
label: 'if(done, "Yes", "No")'
```

### Common Formula Errors

```yaml
# WRONG — Duration is not a number
"(now() - file.ctime).round(0)"

# CORRECT — access .days first
"(now() - file.ctime).days.round(0)"

# WRONG — crashes on empty property
"(date(due_date) - today()).days"

# CORRECT — null guard
'if(due_date, (date(due_date) - today()).days, "")'

# WRONG — undefined formula reference
order:
  - formula.total  # Must exist in formulas: section
```

## References

- [Bases Syntax](https://help.obsidian.md/bases/syntax)
- [Functions](https://help.obsidian.md/bases/functions)
- [Views](https://help.obsidian.md/bases/views)
- [Complete Functions Reference](references/FUNCTIONS_REFERENCE.md)

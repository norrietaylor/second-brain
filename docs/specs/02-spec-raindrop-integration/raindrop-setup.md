# Raindrop Integration Setup

## Prerequisites

- Obsidian vault: `second-brain`
- Raindrop.io account

## Plugin Installation

make-it-rain is installed via direct download (not in the official Obsidian community registry).

**Already done:**
1. BRAT plugin installed and enabled
2. make-it-rain v1.7.2 downloaded and enabled

## API Token Setup

1. Go to [raindrop.io/app#/settings/integrations](https://app.raindrop.io/settings/integrations)
2. Under "For Developers", click **Create new app**
3. Name it (e.g., "Obsidian Sync")
4. Click the app, then **Create test token**
5. Copy the token
6. In Obsidian: Settings → make-it-rain → paste the token into **API Token**

## Configuration

The template has been configured to produce vault-compatible frontmatter:

| make-it-rain field | Vault field | Notes |
|----|----|----|
| `type` (raindrop) | `raindrop_type` | Remapped to avoid conflict with vault `type` |
| — | `type: inbox` | All imports enter as inbox items |
| — | `status: unprocessed` | Picked up by Unprocessed Inbox base |
| — | `source: raindrop` | Provenance tracking |
| `id` | `raindrop_id` | Raindrop item ID |
| `link` | `url` | Source URL |
| `title` | `original_text` | Used by classification pipeline |
| `formattedCreatedDate` | `created` | Creation date |
| `formattedUpdatedDate` | `modified` | Last update |
| `tags` | `tags` | Passed through as-is |
| `collectionTitle` | `collection` | Raindrop collection name |

**Output folder:** `04 Data/` (root of data lake — files land here and get moved to `04 Data/YYYY/MM/` during classification)

**Filename format:** `rd-<title>.md` (the `rd-` prefix identifies Raindrop imports)

## Obsidian Commands

| Command ID | Description |
|---|---|
| `make-it-rain:fetch-raindrops` | Bulk fetch with filters |
| `make-it-rain:quick-import-raindrop` | Import single item by URL/ID |

Trigger programmatically:
```bash
obsidian vault=second-brain command id="make-it-rain:fetch-raindrops"
```

## Collection Filtering

To limit which collections sync, configure in Obsidian: Settings → make-it-rain → Collection Filter. Leave empty to sync all collections.

## Workflow

1. Save bookmarks to Raindrop throughout the day (browser extension, mobile app)
2. `/today` triggers `make-it-rain:fetch-raindrops` → items appear in `04 Data/` as `type: inbox`
3. Unprocessed Inbox base picks them up
4. `/eod` classifies them → moves to `04 Data/YYYY/MM/` with proper type and naming
5. Promoted items retain `source: raindrop` for provenance

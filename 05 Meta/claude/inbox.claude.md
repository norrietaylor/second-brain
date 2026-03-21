# Type: Inbox

Unprocessed or low-confidence captures awaiting classification or human review.

## Required Fields
- `status` — One of: `unprocessed`, `needs_review`
- `original_text` — The raw captured text, preserved verbatim

## Optional Fields
- `confidence` — Classification confidence score (0.0-1.0), present when status is `needs_review`

## Universal Fields (always present)
- `type: inbox`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)

## System-Managed Fields (do not set manually)
- `classified_at` — Datetime of last classification (set by classify skill and /today)
- `confidence` — Classification confidence score 0.0-1.0 (set by classify skill)

## Resolution Tracking
When a needs_review item is resolved:
- If reclassified: log with [correction] tag, original confidence, old type, new type
- If approved as-is: log with [approved] tag, original confidence, confirmed type
Both feed the adaptive threshold analysis in /weekly.

## Conventions
- `unprocessed` — Raw capture from `sb` script, not yet classified by the AI
- `needs_review` — AI attempted classification but confidence was below 0.6 threshold
- Inbox items use temporary filenames: `YYYY.MM.DD-inbox-HHMMSS.md`
- Once classified, the file is renamed in place with the proper name and type changes
- The /today command processes unprocessed inbox items automatically
- Needs-review items appear in the Needs Review Bases view for human correction
- To fix: change the `type` field to the correct type and add required fields for that type

# Type: Digest

System-generated summaries of vault activity. Created by /eod, never manually.

## Required Fields
- `digest_type` — One of: `daily`, `weekly`, `monthly`, `yearly`
- `period_start` — First day covered (YYYY-MM-DD)
- `period_end` — Last day covered (YYYY-MM-DD, same as start for daily)

## System-Managed Fields
- `classified_at` — Not applicable — digests are not classified
- `confidence` — Not applicable — digests are not classified

## Universal Fields (always present)
- `type: digest`
- `created` — Creation datetime (YYYY-MM-DD HH:mm)
- `modified` — Auto-updated on edit (YYYY-MM-DD HH:mm)
- `aliases` — Reference name(s)
- `tags` — Always includes `digest`

## Conventions
- Daily digests: under 150 words + classification log appended
- Weekly digests: under 250 words + analysis appendix + reflection prompts
- Monthly digests: under 400 words + trend appendix + reflection prompts
- Yearly digests: under 500 words + trends + key projects + reflection prompts
- Alias format: YYYY-MM-DD-daily-digest, YYYY-WNN-weekly-digest, YYYY-MM-monthly-digest, YYYY-yearly-digest
- Digests are append-only after creation — don't edit past digests
- The classification log section in daily digests is the rolled inbox-log entries

## Body Structure

### Daily
- `## Summary` (what happened today, under 150 words)
- `## Classification Log` (rolled from inbox-log.md)

### Weekly
- `## Week Summary` (aggregation of daily digests)
- `## Correction Analysis` (confidence patterns, threshold suggestion)
- `## Stale Items` (projects 14+ days inactive, people 30+ days untouched, tasks overdue 7+ days)
- `## Reflection Prompts` (questions to provoke action)

### Monthly
- `## Month Summary` (aggregation of weekly digests)
- `## Trends` (captures/week, type distribution, correction rate)
- `## Reflection Prompts` (bigger-picture questions)

### Yearly
- `## Year Summary` (aggregation of monthly digests, under 500 words)
- `## Trends` (captures/month, type distribution shift, meeting frequency, key relationships)
- `## Key Projects` (major projects active during the year, status, milestones)
- `## Reflection Prompts` (career and priority-level questions)

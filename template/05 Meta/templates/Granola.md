---
granola_id: {{granola_id}}
title: "{{granola_title}}"
date: {{granola_date}}
granola_url: {{granola_url}}
start_time: {{granola_start_time}}
source: granola
type: meeting
created: {{granola_created}}
modified: {{granola_created}}
classified_at: {{granola_created}}
confidence: 1.0
attendees:
{{granola_attendees_linked_list}}
aliases: []
tags: []
---

## Attendees

{{granola_attendees_linked_list}}

{{#granola_private_notes}}
## Log

{{granola_private_notes}}
{{/granola_private_notes}}

{{#granola_enhanced_notes}}
> [!note]- Granola AI Summary
> {{granola_enhanced_notes}}
{{/granola_enhanced_notes}}

{{#granola_transcript}}
> [!note]- Transcript
> {{granola_transcript}}
{{/granola_transcript}}

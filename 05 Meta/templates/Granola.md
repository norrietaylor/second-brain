---
granola_id: "{{granola_id}}"
title: "{{title}}"
date: "{{date}}"
granola_url: "{{granola_url}}"
start_time: "{{start_time}}"
source: granola
type: meeting
created: "{{created}}"
modified: "{{created}}"
classified_at: "{{created}}"
confidence: 1.0
attendees: {{granola_attendees_linked_list}}
aliases: []
tags: []
---

## Attendees

{{granola_attendees_linked_list}}

## Log

> [!warning] Private Notes
{{#granola_private_notes}}
{{granola_private_notes}}
{{/granola_private_notes}}

## Granola AI Summary

> [!note]- Granola AI Summary
{{#granola_notes}}
{{granola_notes}}
{{/granola_notes}}

## Transcript

> [!note]- Transcript
{{#granola_transcript}}
{{granola_transcript}}
{{/granola_transcript}}

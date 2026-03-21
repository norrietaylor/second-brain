<%*
const name = await tp.system.prompt("Project name (kebab-case)");
const dotDate = tp.date.now("YYYY.MM.DD");
const date = tp.date.now("YYYY-MM-DD");
const filename = `${dotDate}-${name}`;
await tp.file.rename(filename);
await tp.file.move(`04 Data/${tp.date.now("YYYY")}/${tp.date.now("MM")}/${filename}`);
-%>
---
type: project
name: <% name %>
status: active
next_action: ""
aliases: [<% name %>]
created: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
modified: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
classified_at: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
confidence: 1.0
tags: []
---

# <% name %>

## Overview

## Context

## Log

### <% date %>
- Project created

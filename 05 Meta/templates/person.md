<%*
const name = await tp.system.prompt("Person name (kebab-case, e.g. sarah-chen)");
const dotDate = tp.date.now("YYYY.MM.DD");
const date = tp.date.now("YYYY-MM-DD");
const filename = `${dotDate}-${name}`;
await tp.file.rename(filename);
await tp.file.move(`04 Data/${tp.date.now("YYYY")}/${tp.date.now("MM")}/${filename}`);
-%>
---
type: person
name: <% name %>
context: ""
last_touched: "<% date %>"
follow_ups: []
aliases: [<% name %>]
created: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
modified: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
classified_at: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
confidence: 1.0
tags: []
---

## Notes

<%*
const meetingName = await tp.system.prompt("Meeting name (kebab-case, e.g. windows-platform)");
const date = tp.date.now("YYYY-MM-DD");
const dotDate = tp.date.now("YYYY.MM.DD");
const filename = `${dotDate}-${meetingName}`;
await tp.file.rename(filename);
await tp.file.move(`04 Data/${tp.date.now("YYYY")}/${tp.date.now("MM")}/${filename}`);
-%>
---
type: meeting
meeting_name: <% meetingName %>
date: "<% date %>"
attendees: []
aliases: [<% meetingName %>]
created: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
modified: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
classified_at: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
confidence: 1.0
tags: []
---

# <% meetingName %> — <% date %>

## Attendees

## Previous Meeting Summary

> <%* const prev = await tp.user.previousMeeting(meetingName); tR += prev ? prev : "No previous meeting on record." %>

## Agenda

## Log

## Action Items

- [ ]

## Summary

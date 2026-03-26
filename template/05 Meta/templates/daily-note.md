<%*
const date = tp.date.now("YYYY-MM-DD");
const dotDate = tp.date.now("YYYY.MM.DD");
const yesterday = tp.date.now("YYYY.MM.DD", -1);
const tomorrow = tp.date.now("YYYY.MM.DD", 1);
const filename = `${dotDate}-daily-note`;
await tp.file.rename(filename);
await tp.file.move(`04 Data/${tp.date.now("YYYY")}/${tp.date.now("MM")}/${filename}`);
-%>
---
type: dailynote
date: "<% date %>"
aliases: [<% date %>-daily-note]
created: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
modified: "<% tp.date.now("YYYY-MM-DD HH:mm") %>"
tags: [dailynote]
---

← [[<% yesterday %>-daily-note|Yesterday]] | **<% date %>** | [[<% tomorrow %>-daily-note|Tomorrow]] →

## Notes

## Meetings

![[Meetings.base#Today]]

## GitHub

## Briefing

## Day Summary

## Classification Log

## Modified Today

![[Modified Today.base]]

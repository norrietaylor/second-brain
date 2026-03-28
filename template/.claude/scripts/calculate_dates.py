#!/usr/bin/env python3
"""Calculate date strings for the Second Brain vault.

Outputs JSON consumed by the SessionStart hook to inject
date context into the Claude Code session.
"""

from datetime import date, timedelta
import json

today = date.today()
yesterday = today - timedelta(days=1)

data = {
    "today": today.isoformat(),
    "today_dot": today.strftime("%Y.%m.%d"),
    "yesterday": yesterday.isoformat(),
    "yesterday_dot": yesterday.strftime("%Y.%m.%d"),
    "year": today.strftime("%Y"),
    "month": today.strftime("%m"),
    "data_path": f"04 Data/{today.strftime('%Y')}/{today.strftime('%m')}",
    "daily_note": f"{today.strftime('%Y.%m.%d')}-daily-note.md",
}

print(json.dumps(data))

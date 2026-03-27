# /verify — Post-Install Health Check

Run the vault health check script:

```bash
"05 Meta/scripts/sb-verify"
```

The script checks Obsidian access, Bases views, prerequisites, authentication, scripts, and directories. It reads `.sb-installer.json` to only check enabled integrations.

If the script reports failures, help the user fix them. If it reports all checks passed, suggest running `/today`.

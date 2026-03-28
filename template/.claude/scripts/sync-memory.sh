#!/bin/bash
# sync-memory.sh — Sync vault context to global Claude memory
#
# Aggregates 05 Meta/context/ files into ~/.claude/memory/work-context.md
# so vault knowledge is available to Claude Code sessions in all projects.
#
# Called at the end of /learned (and /eod) after context files change.

set -euo pipefail

VAULT="${SECOND_BRAIN_VAULT:-{{VAULT_PATH}}}"
CONTEXT_DIR="$VAULT/05 Meta/context"
OUTPUT_DIR="$HOME/.claude/memory"
OUTPUT_FILE="$OUTPUT_DIR/work-context.md"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Build the aggregated file
{
  echo "# Work Context (auto-generated)"
  echo ""
  echo "Source: vault \`05 Meta/context/\`"
  echo "Updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""

  # Work profile
  if [ -f "$CONTEXT_DIR/work-profile.md" ]; then
    echo "---"
    echo ""
    echo "## Work Profile"
    echo ""
    # Strip frontmatter, output body
    awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$CONTEXT_DIR/work-profile.md"
    echo ""
  fi

  # Current priorities
  if [ -f "$CONTEXT_DIR/current-priorities.md" ]; then
    echo "---"
    echo ""
    echo "## Current Priorities"
    echo ""
    awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$CONTEXT_DIR/current-priorities.md"
    echo ""
  fi

  # Tags taxonomy
  if [ -f "$CONTEXT_DIR/tags.md" ]; then
    echo "---"
    echo ""
    echo "## Tags Taxonomy"
    echo ""
    awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$CONTEXT_DIR/tags.md"
    echo ""
  fi

  # Team context — one section per person
  if [ -d "$CONTEXT_DIR/team" ]; then
    team_files=("$CONTEXT_DIR/team/"*.md)
    if [ -e "${team_files[0]}" ]; then
      echo "---"
      echo ""
      echo "## Team"
      echo ""
      for f in "${team_files[@]}"; do
        name=$(basename "$f" .md)
        echo "### $name"
        echo ""
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$f"
        echo ""
      done
    fi
  fi

} > "$OUTPUT_FILE"

echo "Synced context to $OUTPUT_FILE"

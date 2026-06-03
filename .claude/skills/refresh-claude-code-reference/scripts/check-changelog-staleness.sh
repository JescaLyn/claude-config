#!/usr/bin/env bash
set -euo pipefail
# Compute changelog cache age and flag staleness.
# Usage: check-changelog-staleness.sh [changelog-path]
# Output JSON: { "changelog_path", "mtime_date", "age_days", "is_stale", "warning" }

CHANGELOG="${1:-$HOME/.claude/cache/changelog.md}"
STALE_THRESHOLD_DAYS=30

if [[ ! -f "$CHANGELOG" ]]; then
  jq -n --arg p "$CHANGELOG" --arg w "Changelog cache not found at $CHANGELOG — cannot check for updates." \
    '{"error": "changelog not found", "changelog_path": $p, "is_stale": true, "warning": $w}'
  exit 0
fi

MTIME_EPOCH=$(stat -f "%m" "$CHANGELOG")
MTIME_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$CHANGELOG")
NOW_EPOCH=$(date +%s)
AGE_DAYS=$(( (NOW_EPOCH - MTIME_EPOCH) / 86400 ))

IS_STALE=$( [[ $AGE_DAYS -gt $STALE_THRESHOLD_DAYS ]] && echo true || echo false )

WARNING=""
if [[ "$IS_STALE" == "true" ]]; then
  WARNING="Changelog cache last updated $MTIME_DATE (${AGE_DAYS} days ago) — may be stale. Consider refreshing before proceeding."
fi

jq -n \
  --arg path "$CHANGELOG" \
  --arg date "$MTIME_DATE" \
  --argjson age "$AGE_DAYS" \
  --argjson stale "$IS_STALE" \
  --arg warning "$WARNING" \
  '{
    "changelog_path": $path,
    "mtime_date": $date,
    "age_days": $age,
    "is_stale": $stale,
    "warning": (if $warning != "" then $warning else null end)
  }'

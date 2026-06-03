#!/usr/bin/env bash
# PostToolUse hook (matcher: Skill): restore a SKILL.md model field that was
# temporarily patched to claude-sonnet-4-6[1m] by guard-skill-model.sh.
#
# If no backup file exists for this skill, exits immediately (no-op).

set -euo pipefail

RESTORE_DIR="/tmp/claude-skill-model-restore"

INPUT="$(cat)"
SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.name // .tool_input.skill // empty' 2>/dev/null || true)
[ -n "$SKILL_NAME" ] || exit 0

BACKUP_FILE="${RESTORE_DIR}/${SKILL_NAME}.bak"
[ -f "$BACKUP_FILE" ] || exit 0

SKILL_FILE=$(cat "$BACKUP_FILE")

[ -f "$SKILL_FILE" ] || { rm -f "$BACKUP_FILE"; exit 0; }

{
  awk 'BEGIN{fm=0}
    /^---[[:space:]]*$/ { fm++; print; next }
    fm==1 && /^model[[:space:]]*:/ { print "model: sonnet"; next }
    { print }
  ' "$SKILL_FILE" > "${SKILL_FILE}.tmp" && mv "${SKILL_FILE}.tmp" "$SKILL_FILE" && rm -f "$BACKUP_FILE"
} 2>/dev/null || rm -f "${SKILL_FILE}.tmp"

exit 0

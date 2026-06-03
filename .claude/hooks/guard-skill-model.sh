#!/usr/bin/env bash
# PreToolUse hook (matcher: Skill): guard against model downgrade causing
# context overflow or compaction in long sessions.
#
# Sonnet (non-forked, >150K tokens): silently patches the skill's SKILL.md
#   frontmatter to use claude-sonnet-4-6[1m] before the invocation. A paired
#   PostToolUse hook (restore-skill-model.sh) restores the original afterward.
#   Patching the file before returning exit 0 works because PreToolUse is
#   synchronous — Claude Code reads the frontmatter only after this hook exits.
#
# Haiku (non-forked, >150K tokens): asks the user before proceeding.
#   Haiku has no 1M variant; the risk of compaction must be a conscious choice.
#
# Fails open on every unknown / unparseable condition.
# Hard bypass: CLAUDE_SKIP_SKILL_GUARD=1 (for CI / scripted flows).

set -euo pipefail

HAIKU_LIMIT=150000
SONNET_LIMIT=150000
CHARS_PER_TOKEN=4
RESTORE_DIR="/tmp/claude-skill-model-restore"

INPUT="$(cat)"

SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.name // .tool_input.skill // empty' 2>/dev/null || true)
[ -n "$SKILL_NAME" ] || exit 0

[[ "$SKILL_NAME" == *:* ]] && exit 0
[ -n "${CLAUDE_SKIP_SKILL_GUARD:-}" ] && exit 0

# --- Locate the skill file -------------------------------------------------
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
[ -z "$CWD" ] && CWD="$(pwd)"

find_skill_file() {
  local name="$1" dir="$2"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    [ -f "${dir}/.claude/skills/${name}/SKILL.md" ] && echo "${dir}/.claude/skills/${name}/SKILL.md" && return 0
    [ -f "${dir}/.claude/commands/${name}.md" ]    && echo "${dir}/.claude/commands/${name}.md"    && return 0
    dir=$(dirname "$dir")
  done
  [ -f "${HOME}/.claude/skills/${name}/SKILL.md" ] && echo "${HOME}/.claude/skills/${name}/SKILL.md" && return 0
  [ -f "${HOME}/.claude/commands/${name}.md" ]    && echo "${HOME}/.claude/commands/${name}.md"    && return 0
  return 1
}

SKILL_FILE=$(find_skill_file "$SKILL_NAME" "$CWD" || true)
[ -z "$SKILL_FILE" ] && exit 0

# --- Parse frontmatter -----------------------------------------------------
fm_field() {
  local file="$1" field="$2"
  awk -v key="$field" '
    /^---[[:space:]]*$/ { fm++; if (fm==2) exit; next }
    fm == 1 {
      if (index($0, key ":") == 1) {
        val = substr($0, length(key) + 2)
        sub(/^[[:space:]]+/, "", val)
        sub(/[[:space:]]+$/, "", val)
        sub(/^["'"'"']/, "", val)
        sub(/["'"'"']$/, "", val)
        print val
        exit
      }
    }
  ' "$file"
}

MODEL=$(fm_field "$SKILL_FILE" "model")
CONTEXT=$(fm_field "$SKILL_FILE" "context")

[ "$CONTEXT" = "fork" ] && exit 0
[[ "$MODEL" != "haiku" && "$MODEL" != "sonnet" ]] && exit 0

# --- Transcript size check -------------------------------------------------
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

CHARS=$(wc -c < "$TRANSCRIPT" | tr -d ' ')
TOKENS=$((CHARS / CHARS_PER_TOKEN))
TOKENS_K=$((TOKENS / 1000))

# --- Sonnet: upgrade to 1M -------------------------------------------------
if [ "$MODEL" = "sonnet" ] && [ "$TOKENS" -gt "$SONNET_LIMIT" ]; then
  mkdir -p "$RESTORE_DIR"
  echo "$SKILL_FILE" > "${RESTORE_DIR}/${SKILL_NAME}.bak"
  {
    awk 'BEGIN{fm=0}
      /^---[[:space:]]*$/ { fm++; print; next }
      fm==1 && /^model[[:space:]]*:/ { print "model: claude-sonnet-4-6[1m]"; next }
      { print }
    ' "$SKILL_FILE" > "${SKILL_FILE}.tmp" && mv "${SKILL_FILE}.tmp" "$SKILL_FILE"
  } 2>/dev/null || {
    rm -f "${SKILL_FILE}.tmp" "${RESTORE_DIR}/${SKILL_NAME}.bak"
  }
  exit 0
fi

# --- Haiku: no 1M variant — ask the user -----------------------------------
if [ "$MODEL" = "haiku" ] && [ "$TOKENS" -gt "$HAIKU_LIMIT" ]; then
  REASON="/$SKILL_NAME runs on model: haiku (200K context). Conversation is ~${TOKENS_K}K tokens — invoking will trigger auto-compaction and destroy state. Proceed anyway?"
  jq -n --arg reason "$REASON" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
fi

exit 0

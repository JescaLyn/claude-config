#!/usr/bin/env bash
# check-slash-conflict.sh — PreToolUse(Write|Bash)
# Write: intercepts new skill/command file creation; checks all conflict types.
# Bash:  intercepts mkdir creating skill directories (commands are files, not dirs); checks built-ins and bundled only.
#
# Conflict types (Write):
#   - Built-in CLI command (always, any scope)
#   - Bundled skill shipped with Claude Code (always, any scope)
#   - Cross-scope custom override (project shadowing global, or vice versa)
#
# Conflict types (Bash mkdir):
#   - Built-in CLI command and bundled skill only
#
# Approval mechanism: Claude writes a session-scoped approval file before retrying;
# the hook allows the retry and cleans up the file.

set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0  # fail-open
fi

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -re '.session_id // "shared"' 2>/dev/null) || SESSION_ID="shared"
APPROVAL_DIR="$HOME/.claude/.tmp/sessions/$SESSION_ID"

SLASH_NAME=""
IS_GLOBAL=false
CHECK_CUSTOM=true  # false for mkdir: skip cross-scope custom skill check

# --- Determine context from tool input fields ---

FILE_PATH=$(echo "$INPUT" | jq -re '.tool_input.file_path // empty' 2>/dev/null) || FILE_PATH=""
CMD=$(echo "$INPUT" | jq -re '.tool_input.command // empty' 2>/dev/null) || CMD=""

if [[ -n "$FILE_PATH" ]]; then
  # Write tool: extract skill name from file path
  if [[ "$FILE_PATH" =~ \.claude/skills/([^/]+)/SKILL\.md$ ]]; then
    SLASH_NAME="${BASH_REMATCH[1]}"
  elif [[ "$FILE_PATH" =~ \.claude/commands/([^/]+)\.md$ ]]; then
    SLASH_NAME="${BASH_REMATCH[1]}"
  fi
  [[ -z "$SLASH_NAME" ]] && exit 0
  [[ -f "$FILE_PATH" ]] && exit 0  # existing file = update, not new
  [[ "$FILE_PATH" == "$HOME/.claude/"* ]] && IS_GLOBAL=true

elif [[ -n "$CMD" ]]; then
  # Bash tool: only check mkdir targeting skill directories (commands are files, not dirs)
  echo "$CMD" | grep -qE '\bmkdir\b' || exit 0
  echo "$CMD" | grep -qF '.claude/skills/' || exit 0

  # Extract the terminal path component immediately after .claude/skills/
  # Matches .claude/skills/<name> but NOT .claude/skills/<name>/subdir
  if [[ "$CMD" =~ \.claude/skills/([^/[:space:]]+)([[:space:]]|/?$) ]]; then
    SLASH_NAME="${BASH_REMATCH[1]%/}"
  fi
  [[ -z "$SLASH_NAME" ]] && exit 0

  # Expand ~ and $HOME for scope check
  CMD_EXPANDED="${CMD/\~/$HOME}"
  CMD_EXPANDED="${CMD_EXPANDED/\$HOME/$HOME}"
  [[ "$CMD_EXPANDED" == *"$HOME/.claude/skills/"* ]] && IS_GLOBAL=true

  CHECK_CUSTOM=false

else
  exit 0
fi

APPROVAL_FILE="$APPROVAL_DIR/slash-conflict-approved-$SLASH_NAME"

# User already confirmed this conflict — allow and clean up
if [[ -f "$APPROVAL_FILE" ]]; then
  rm -f "$APPROVAL_FILE"
  exit 0
fi

# Built-in commands — hardcoded CLI operations that cannot be overridden
BUILTIN_COMMANDS=(
  clear compact config context exit fast feedback
  help hooks login logout memory model permissions
  quit resume settings skills status upgrade usage version
)

# Bundled skills — prompt-based skills shipped with Claude Code
BUNDLED_SKILLS=(
  batch claude-api claude-code-guide code-review debug effort
  fewer-permission-prompts init keybindings-help loop
  reload-plugins review run schedule security-review
  simplify statusline-setup theme update-config verify
)

conflict_block() {
  local conflict_label="$1"
  local conflict_detail="$2"
  mkdir -p "$APPROVAL_DIR"
  cat >&2 <<EOF
Slash command conflict: /$SLASH_NAME is already a ${conflict_label}.
${conflict_detail}

Use AskUserQuestion to ask the user:
  "/$SLASH_NAME conflicts with an existing ${conflict_label}. Proceed with this name anyway?"
  Options: "Yes, use this name" / "No, pick a different name"

If the user confirms, run this command before retrying:
  touch "${APPROVAL_FILE}"
EOF
  exit 2
}

for cmd in "${BUILTIN_COMMANDS[@]}"; do
  if [[ "$SLASH_NAME" == "$cmd" ]]; then
    conflict_block "built-in CLI command" \
      "Using this name will shadow the built-in /$SLASH_NAME command."
  fi
done

for skill in "${BUNDLED_SKILLS[@]}"; do
  if [[ "$SLASH_NAME" == "$skill" ]]; then
    conflict_block "bundled skill" \
      "Using this name will hide the bundled version of /$SLASH_NAME."
  fi
done

if [[ "$CHECK_CUSTOM" == "true" ]]; then
  if [[ "$IS_GLOBAL" == "false" ]]; then
    if [[ -d "$HOME/.claude/skills/$SLASH_NAME" ]]; then
      conflict_block "global custom skill" \
        "The project-scope /$SLASH_NAME will shadow ~/.claude/skills/$SLASH_NAME/."
    fi
    if [[ -f "$HOME/.claude/commands/$SLASH_NAME.md" ]]; then
      conflict_block "global custom command" \
        "The project-scope /$SLASH_NAME will shadow ~/.claude/commands/$SLASH_NAME.md."
    fi
  fi

  if [[ "$IS_GLOBAL" == "true" ]]; then
    if [[ -d ".claude/skills/$SLASH_NAME" ]]; then
      conflict_block "project custom skill" \
        "The global /$SLASH_NAME will not take effect in this project — .claude/skills/$SLASH_NAME/ already exists here."
    fi
    if [[ -f ".claude/commands/$SLASH_NAME.md" ]]; then
      conflict_block "project custom command" \
        "The global /$SLASH_NAME will not take effect in this project — .claude/commands/$SLASH_NAME.md already exists here."
    fi
  fi
fi

exit 0

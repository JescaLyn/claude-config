---
name: Hooks reference
description: Deterministic automation on lifecycle events — all 25+ events, four hook types (command/http/prompt/agent), matching, configuration in settings.json and frontmatter, common patterns, gotchas
type: reference
---

## What Hooks Are

Hooks are shell scripts, HTTP endpoints, or single-turn Claude evaluations that fire automatically on lifecycle events. They run outside of Claude's conversation — Claude doesn't see or control them. Use them to enforce rules, format code, validate output, send notifications, or block dangerous operations. Defined in `settings.json` or in skill/subagent frontmatter.

## Lifecycle Events

"Can block" means the hook can prevent the action from proceeding (exit code 2 for command hooks, `"ok": false` for prompt/agent hooks). Non-blocking hooks can only observe or provide feedback to Claude after the fact.

**Special blocking behaviors:**
- **PostToolUse**: Cannot block (the tool already ran). Can only send feedback to Claude about the result.
- **PermissionRequest**: Blocking means auto-approving or auto-denying the permission dialog, not preventing it from appearing.
- **Stop**: Blocking means forcing Claude to continue working instead of stopping. Check `stop_hook_active` to avoid infinite loops (see gotchas).

| Event | When it fires | Can block? |
|-------|---------------|-----------|
| **SessionStart** | Session begins or resumes | Yes |
| **SessionEnd** | Session terminates | No |
| **UserPromptSubmit** | User submits a prompt | Yes |
| **PreToolUse** | Before any tool executes | Yes |
| **PostToolUse** | After tool succeeds | No |
| **PostToolUseFailure** | After tool fails | No |
| **PermissionRequest** | Permission dialog appears | Yes |
| **Stop** | Claude finishes responding | Yes |
| **StopFailure** | Turn ends due to API error | No |
| **SubagentStart** | Subagent spawned | Yes |
| **SubagentStop** | Subagent finishes | No |
| **Notification** | Claude needs input or permission | No |
| **InstructionsLoaded** | CLAUDE.md or rules loaded | Yes |
| **PreCompact** | Before context compaction | Yes |
| **PostCompact** | After compaction completes | No |
| **ConfigChange** | Config file changes during session | Yes |
| **TaskCompleted** | Task marked complete | Yes |
| **TeammateIdle** | Agent Teams teammate about to idle | Yes |
| **WorktreeCreate** | Git worktree created | Yes |
| **WorktreeRemove** | Worktree removed | No |
| **Elicitation** | MCP server requests user input | Yes |
| **ElicitationResult** | User responds to elicitation | Yes |

## Hook Types

**Command** (`type: "command"`): Shell script. Receives JSON on stdin, returns JSON on stdout. Exit 0 = allow, exit 2 = block (stderr shown as feedback to Claude). Default timeout: 600s.

**HTTP** (`type: "http"`): POST JSON to a URL. Response uses same JSON format as command hooks. Supports `headers` and `allowedEnvVars` for secret interpolation. Default timeout: request default.

**Prompt** (`type: "prompt"`): Single-turn LLM call. Returns `{"ok": true/false, "reason": "..."}`. Default model: Haiku. Default timeout: 30s. Use for semantic validation without scripts.

**Agent** (`type: "agent"`): Multi-turn subagent with tool access (Read, Grep, Glob, Bash). Same response format as prompt. Default timeout: 60s, up to 50 turns. Use when validation requires inspecting the filesystem.

## Matching

Matchers are regex patterns that filter when hooks fire:

```json
{
  "matcher": "Bash|Edit|Write",           // Tool names for PreToolUse/PostToolUse
  "matcher": "mcp__github__.*",           // MCP tools
  "matcher": "startup|resume|compact",    // SessionStart sources
  "matcher": "Explore|Plan",              // SubagentStart/Stop agent types
  "matcher": ""                           // Match all (or omit matcher)
}
```

## Configuration

### In settings.json

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

**Settings hierarchy** (highest priority first): Managed policy > `.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json` > Plugin hooks > Skill/agent frontmatter hooks.

### In skill or subagent frontmatter

```yaml
---
name: my-skill
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate.sh"
---
```

Scoped to the skill/subagent's lifecycle — only active while it's running.

### Async hooks

Set `"async": true` to run in the background (fire-and-forget). Action proceeds immediately. Use for long-running operations like tests or builds.

## Common Patterns

**Auto-format after edits** (PostToolUse, matcher: `Edit|Write`): Run prettier/black/gofmt on changed files.

**Block dangerous commands** (PreToolUse, matcher: `Bash`): Check stdin for forbidden patterns, exit 2 to block.

**Desktop notification when Claude needs input** (Notification): Run `osascript`/`notify-send`.

**Reinject context after compaction** (SessionStart, matcher: `compact`): Echo critical reminders that should survive context compression.

**Auto-approve plan mode exit** (PermissionRequest, matcher: `ExitPlanMode`): Return `{"hookSpecificOutput": {"decision": {"behavior": "allow"}}}`.

**Audit logging** (ConfigChange, PostToolUse): Append structured JSON to a log file.

## Key Gotchas

- **PreToolUse hooks run before permissions**, but returning `"allow"` does NOT override deny rules. Deny rules from any scope always take precedence.
- **PostToolUse cannot undo actions.** The tool has already executed. Feedback only.
- **Stop fires after every response**, not just task completion. Check `stop_hook_active` to prevent infinite loops.
- **Profile echo statements break JSON parsing.** Wrap shell profile noise with `if [[ $- == *i* ]]; then`.
- **Multiple matching hooks run in parallel**, not sequentially. One hook cannot prevent another from running.
- **Command hook stdout must be valid JSON** (or empty with exit 0). Malformed JSON causes a parse error.
- **Managed deny rules override everything**, including hook-approved actions.

## Environment Variables

- `CLAUDE_PROJECT_DIR`: Project root for relative paths in hook commands.
- `CLAUDE_ENV_FILE`: Path to file where SessionStart hooks can inject env vars.
- `CLAUDE_SESSION_ID`: Unique session identifier.

Use `/hooks` to view all configured hooks grouped by event.

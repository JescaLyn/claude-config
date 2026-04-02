---
name: Hooks reference
description: Deterministic automation on lifecycle events — all events with matcher values, four hook types, configuration, sources/scope/merge behavior, PreToolUse tool enforcement, input JSON schemas, gotchas
type: reference
---

## What Hooks Are

Hooks are shell scripts, HTTP endpoints, or single-turn Claude evaluations that fire automatically on lifecycle events. They run outside of Claude's conversation — Claude doesn't see or control them. Use them to enforce rules, format code, validate output, send notifications, or block dangerous operations. Defined in `settings.json` (any scope), skill/subagent frontmatter, or plugin packages (see "Hook Sources and Scope Behavior" for the full list).

## Lifecycle Events

"Can block" means the hook can prevent the action from proceeding (exit code 2 for command hooks, `"ok": false` for prompt/agent hooks). Non-blocking hooks can only observe or provide feedback to Claude after the fact.

**Special blocking behaviors:**
- **PostToolUse**: Cannot block (the tool already ran). Can only send feedback to Claude about the result.
- **PermissionRequest**: Blocking means auto-resolving the permission dialog, not preventing it from appearing. Return `{"hookSpecificOutput": {"decision": {"behavior": "allow"}}}` to auto-approve or `{"hookSpecificOutput": {"decision": {"behavior": "deny"}}}` to auto-deny.
- **Stop**: Blocking means forcing Claude to continue working instead of stopping. Check `stop_hook_active` to avoid infinite loops (see gotchas).

| Event | When it fires | Can block? |
|-------|---------------|-----------|
| **SessionStart** | Session begins or resumes | No |
| **SessionEnd** | Session terminates | No |
| **UserPromptSubmit** | User submits a prompt | Yes |
| **PreToolUse** | Before any tool executes | Yes |
| **PostToolUse** | After tool succeeds | No |
| **PostToolUseFailure** | After tool fails | No |
| **PermissionRequest** | Permission dialog appears | Yes |
| **Stop** | Claude finishes responding | Yes |
| **StopFailure** | Turn ends due to API error | No |
| **SubagentStart** | Subagent spawned | No |
| **SubagentStop** | Subagent finishes | Yes (forces continuation) |
| **Notification** | Claude needs input or permission | No |
| **InstructionsLoaded** | CLAUDE.md or rules loaded | No (observability only) |
| **PreCompact** | Before context compaction | No |
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

The `matcher` field is a regex that filters when a hook fires. What it matches against depends on the event. Omit `matcher` (or set to `""`) to match all.

### Matches tool name
**Events:** PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest

**Values:** Any built-in tool name (full list in `reference_tools.md`) or MCP tool in the pattern `mcp__<server>__<tool>`.
```json
"matcher": "Bash|Edit|Write"
"matcher": "mcp__github__.*"
```

### Matches agent type
**Events:** SubagentStart, SubagentStop

**Values:** `Explore`, `Plan`, `general-purpose`, or custom agent names. Custom agents spawned via the general-purpose workaround (see `reference_subagent_pipelines.md`) all appear as `general-purpose`, not their custom name. You cannot distinguish between different custom agents via matchers — see "PreToolUse-specific" gotchas for scoping alternatives.
```json
"matcher": "Explore|Plan"
"matcher": "general-purpose"
```

### Matches session source
**Events:** SessionStart

**Values:** `startup`, `resume`, `clear`, `compact`
```json
"matcher": "startup|resume"
"matcher": "compact"
```

### Matches session end reason
**Events:** SessionEnd

**Values:** `clear`, `resume`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`
```json
"matcher": "clear|logout"
"matcher": "prompt_input_exit"
```

### Matches compaction trigger
**Events:** PreCompact, PostCompact

**Values:** `manual`, `auto`
```json
"matcher": "auto"
```

### Matches notification type
**Events:** Notification

**Values:** `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`
```json
"matcher": "permission_prompt|idle_prompt"
```

### Matches config source
**Events:** ConfigChange

**Values:** `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills`
```json
"matcher": "project_settings|local_settings"
```

### Matches error type
**Events:** StopFailure

**Values:** `rate_limit`, `authentication_failed`, `billing_error`, `invalid_request`, `server_error`, `max_output_tokens`, `unknown`
```json
"matcher": "rate_limit|server_error"
```

### Matches load reason
**Events:** InstructionsLoaded

**Values:** `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`
```json
"matcher": "session_start|compact"
```

### Matches MCP server name
**Events:** Elicitation, ElicitationResult

**Values:** User-defined MCP server names from `.mcp.json` or settings.
```json
"matcher": "github|filesystem"
```

### No matcher support
**Events:** UserPromptSubmit, Stop, TaskCompleted, TeammateIdle, WorktreeCreate, WorktreeRemove

These always fire. The `matcher` field is ignored.

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

Same JSON format applies to all settings.json scopes (user, project, local, managed).

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

### Async hooks

Set `"async": true` to run in the background (fire-and-forget). Action proceeds immediately. Use for long-running operations like tests or builds.

## Hook Sources and Scope Behavior

**Sources and their lifetimes:**

| Source | Format | Active when |
|--------|--------|-------------|
| Managed policy (`managed-settings.json`) | JSON | Always |
| `~/.claude/settings.json` (user) | JSON | Always |
| `.claude/settings.json` (project) | JSON | Always (in that project) |
| `.claude/settings.local.json` (local) | JSON | Always (in that project) |
| Plugin package (`<plugin-dir>/hooks/hooks.json`) | JSON | While plugin is enabled |
| Skill frontmatter | YAML | While skill is executing |
| Agent frontmatter | YAML | While subagent is running |

`/hooks` labels each with its origin: `[User]`, `[Project]`, `[Local]`, `[Plugin]`, `[Session]` (registered in memory for the current session only), or `[Built-in]` (internal Claude Code hooks). Plugin hooks use `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` environment variables.

**Where to define a hook:** Use settings.json (any scope) for rules that should always apply. Use skill/agent frontmatter for rules that only matter during that skill or agent's lifecycle — e.g., PreToolUse restrictions on a read-only analyzer skill.

**How hooks merge across scopes:** All matching hooks from all sources **run in parallel**. Hooks do not override each other — a hook in `.claude/settings.json` cannot prevent a hook in `~/.claude/settings.json` from firing. If the exact same command string (or URL for HTTP hooks) appears in multiple scopes, it runs once (auto-deduplicated). Different command strings always run independently, even if they do the same work. This differs from scalar settings, where more specific scopes override broader ones (see `reference_settings.md`).

**Kill switches:**
- `disableAllHooks` — suppresses all hooks from all sources. Can be set at any scope (follows normal settings precedence).
- `allowManagedHooksOnly` — (managed scope only) suppresses all non-managed hooks. Only managed-scope hooks survive.

## Common Patterns

**Auto-format after edits** (PostToolUse, matcher: `Edit|Write`): Run prettier/black/gofmt on changed files.

**Block dangerous commands** (PreToolUse, matcher: `Bash`): Check stdin for forbidden patterns, exit 2 to block.

**Desktop notification when Claude needs input** (Notification): Run `osascript`/`notify-send`.

**Reinject context after compaction** (SessionStart, matcher: `compact`): Echo critical reminders that should survive context compression.

**Auto-approve plan mode exit** (PermissionRequest, matcher: `ExitPlanMode`): Return `{"hookSpecificOutput": {"decision": {"behavior": "allow"}}}`.

**Audit logging** (ConfigChange, PostToolUse): Append structured JSON to a log file.

## PreToolUse as Tool Enforcement

PreToolUse hooks are the reliable way to restrict which tools a skill or custom subagent can use. The built-in mechanisms are broken or bypassable:
- Skill `allowed-tools` frontmatter is **not enforced** (see `reference_skills.md`)
- Agent `tools:` frontmatter works for native spawning but is **bypassed by the general-purpose workaround**, which is required for custom agents (see `reference_subagent_pipelines.md`)

A PreToolUse hook blocks a tool call by exiting with code 2. Stderr is shown to Claude as feedback explaining why the call was rejected. See "Hook Input JSON Schemas" for the full payload format.

### Patterns

**Allowlist — block everything except specific tools:**
```bash
#!/bin/bash
ALLOWED="Read|Grep|Glob"
TOOL=$(jq -r '.tool_name' < /dev/stdin)
if ! echo "$TOOL" | grep -qE "^($ALLOWED)$"; then
  echo "Tool '$TOOL' is not in the allowed set: $ALLOWED" >&2
  exit 2
fi
```

**Denylist — block specific tools:**
```bash
#!/bin/bash
TOOL=$(jq -r '.tool_name' < /dev/stdin)
if echo "$TOOL" | grep -qE "^(Bash|Write|Agent)$"; then
  echo "Tool '$TOOL' is blocked in this context" >&2
  exit 2
fi
```

**Scoped to a skill or subagent** — define the hook in frontmatter so it only runs during that skill/subagent's lifecycle:
```yaml
---
name: read-only-analyzer
hooks:
  PreToolUse:
    - hooks:
        - type: command
          command: "jq -r '.tool_name' | grep -qE '^(Read|Grep|Glob)$' || exit 2"
---
```

**Global with context filtering** — if defined in `settings.json`, the hook fires for all tool calls (main conversation and subagents). There is no built-in field to distinguish which skill or subagent triggered the call. To scope globally-defined hooks, use external state (e.g., a file written by a SubagentStart hook and checked by the PreToolUse hook).

## Gotchas

### General
- **All matching hooks run in parallel**, not sequentially. You cannot depend on execution order between hooks, and one hook cannot prevent another from firing.
- **PostToolUse cannot undo actions.** The tool has already executed. It can only send feedback to Claude.
- **Stop fires after every response**, not just task completion. The input JSON includes `"stop_hook_active": true/false`. If `true`, Claude is already continuing from a previous Stop hook — exit 0 to allow the stop and prevent an infinite loop.
- **Command hook stdout must be valid JSON** (or empty with exit 0). Malformed JSON causes a parse error.
- **Stdin is consumed once.** If your hook script reads stdin, store it in a variable — you can't read it again.
- **Profile echo statements break JSON parsing.** Wrap shell profile noise with `if [[ $- == *i* ]]; then`.
- **Managed deny rules override everything**, including hook-approved actions.

### PreToolUse-specific
- **Can block but not approve.** Hooks run before the permission dialog. Exit 2 blocks the call, but exit 0 does not bypass `permissions.deny` rules. Hooks add restrictions, they cannot remove them.
- **If any matching hook blocks, the call is blocked.** A permissive hook cannot override a blocking one.
- **No subagent identity in input JSON.** The payload does not include which subagent or skill triggered the call. Scope per-agent restrictions via frontmatter hooks (see "PreToolUse as Tool Enforcement" above).
- **MCP tools use prefixed names** (e.g., `mcp__github__create_issue`). Match with regex: `matcher: "mcp__github__.*"`.

## Hook Input JSON Schemas

All events receive JSON on stdin with common fields: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`. Event-specific fields below. Not all events are documented here — see https://code.claude.com/docs/en/hooks for the full reference.

**PreToolUse:**
```json
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf /tmp/foo", "description": "..." },
  "tool_use_id": "toolu_01ABC..."
}
```
`tool_name` is the tool being called. `tool_input` contains the full arguments passed to the tool.

**PostToolUse:**
```json
{
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "/path/to/file.txt", "content": "..." },
  "tool_response": { "filePath": "/path/to/file.txt", "success": true },
  "tool_use_id": "toolu_01ABC123..."
}
```

**SubagentStart:**
```json
{
  "hook_event_name": "SubagentStart",
  "agent_id": "agent-abc123",
  "agent_type": "Explore"
}
```

**SubagentStop:**
```json
{
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "agent-def456",
  "agent_type": "Explore",
  "agent_transcript_path": "~/.claude/projects/.../subagents/agent-def456.jsonl",
  "last_assistant_message": "The subagent's final response text..."
}
```
`last_assistant_message` contains the subagent's return text. `agent_type` is "Explore", "Plan", or "general-purpose" for custom agents.

## Environment Variables

- `CLAUDE_PROJECT_DIR`: Project root for relative paths in hook commands.
- `CLAUDE_ENV_FILE`: Path to file where SessionStart hooks can inject env vars.
- `CLAUDE_SESSION_ID`: Unique session identifier.

Use `/hooks` to view all configured hooks grouped by event.

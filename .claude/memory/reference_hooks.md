---
name: Hooks reference
description: Deterministic automation on lifecycle events — all events with matcher values, five hook types, configuration, sources/scope/merge behavior, PreToolUse tool enforcement, input JSON schemas, per-event constraints (ConfigChange/FileChanged/SessionStart/agent hook availability), gotchas
type: reference
---

## What Hooks Are

Shell scripts, HTTP endpoints, or LLM evaluations on lifecycle events. Run outside Claude's conversation. Defined in settings.json, skill/agent frontmatter, or plugin packages. "Can block" means exit code 2 (command) or `"ok": false` (prompt/agent). Exceptions: **PermissionRequest** "blocking" means auto-resolving the dialog (`{"hookSpecificOutput": {"decision": {"behavior": "allow/deny"}}}`), not preventing it. **Stop** "blocking" forces Claude to continue — check `stop_hook_active` to avoid infinite loops.

## Lifecycle Events

| Event | When it fires | Can block? |
|-------|---------------|-----------|
| **SessionStart** | Session begins or resumes | No |
| **SessionEnd** | Session terminates | No |
| **UserPromptSubmit** | User submits a prompt | Yes |
| **UserPromptExpansion** | User prompt is expanded (e.g. slash command) | No |
| **PreToolUse** | Before any tool executes | Yes |
| **PermissionRequest** | Permission dialog appears | Yes |
| **PermissionDenied** | Auto mode classifier denies a tool call. hookSpecificOutput supports `retry: true` to retry. | No |
| **PostToolUse** | After tool succeeds | No |
| **PostToolUseFailure** | After tool fails | No |
| **PostToolBatch** | After a batch of tool calls completes | No |
| **Stop** | Claude finishes responding | Yes |
| **StopFailure** | Turn ends due to API error | No |
| **SubagentStart** | Subagent spawned | No |
| **SubagentStop** | Subagent finishes | Yes (forces continuation) |
| **Notification** | Claude needs input or permission | No |
| **InstructionsLoaded** | CLAUDE.md or rules loaded | No (observability only) |
| **PreCompact** | Before context compaction | Yes (exit code 2 cancels) |
| **PostCompact** | After compaction completes | No |
| **ConfigChange** | Config file changes during session | Yes |
| **TaskCreated** | Task created via TaskCreate | Yes |
| **TaskCompleted** | Task marked complete | Yes |
| **TeammateIdle** | Agent Teams teammate about to idle | Yes |
| **WorktreeCreate** | Git worktree created | Yes |
| **WorktreeRemove** | Worktree removed | No |
| **Elicitation** | MCP server requests user input | Yes |
| **ElicitationResult** | User responds to elicitation | Yes |
| **CwdChanged** | Working directory changes | No |
| **FileChanged** | Watched file changes on disk | No |
| **Setup** | Triggered by `--init`, `--init-only`, or `--maintenance` CLI flags (no matcher support) | No |

## Hook Types

**Command:** Shell script. JSON in/out. Exit 0=allow, 2=block. Timeout 600s. Optional `"shell"` field: `"bash"` or `"powershell"`.

**HTTP:** POST JSON to URL, same response format. Supports `headers`/`allowedEnvVars`. Default timeout.

**MCP tool:** Calls an MCP tool directly. Fields: `server`, `tool`, `input` (supports `${path}` substitution).

**Prompt:** Single-turn LLM call. Response: `{"ok": true/false, "reason": "..."}`. Haiku, 30s timeout. Semantic validation. Optional `"model"` field to override.

**Agent:** Multi-turn subagent with Read/Grep/Glob/Bash. Same response format. 60s timeout, up to 50 turns. For validation requiring filesystem inspection.

## Matching

`matcher` is a regex that filters hook firing. What it matches depends on the event. Omit or set to `""` to match all.

### Matches tool name
**Events:** PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest. **Values:** tool name or `mcp__<server>__<tool>`.
```json
"matcher": "Bash|Edit|Write" or "mcp__github__.*"
```

### Matches agent type
**Events:** SubagentStart, SubagentStop. **Values:** Explore, Plan, general-purpose. (Custom agents appear as general-purpose; scope via frontmatter hooks.)
```json
"matcher": "Explore|Plan" or "general-purpose"
```

### Matches session source
**Events:** SessionStart. **Values:** startup, resume, clear, compact. `"matcher": "startup|resume"`

### Matches session end reason
**Events:** SessionEnd. **Values:** clear, resume, logout, prompt_input_exit, bypass_permissions_disabled, other. `"matcher": "logout"`

### Matches compaction trigger
**Events:** PreCompact, PostCompact. **Values:** manual, auto. `"matcher": "auto"`

### Matches notification type
**Events:** Notification. **Values:** permission_prompt, idle_prompt, auth_success, elicitation_dialog. `"matcher": "permission_prompt"`

### Matches config source
**Events:** ConfigChange. **Values:** user_settings, project_settings, local_settings, policy_settings, skills. `"matcher": "project_settings"`

### Matches error type
**Events:** StopFailure. **Values:** rate_limit, authentication_failed, billing_error, invalid_request, server_error, max_output_tokens, unknown. `"matcher": "rate_limit"`

### Matches load reason
**Events:** InstructionsLoaded. **Values:** session_start, nested_traversal, path_glob_match, include, compact. `"matcher": "session_start"`

### Matches MCP server name
**Events:** Elicitation, ElicitationResult. **Values:** User-defined from `.mcp.json` or settings. `"matcher": "github"`

### Matches path pattern
**Events:** CwdChanged, FileChanged. **Values:** basename-only for FileChanged (not full paths); directory paths for CwdChanged.

### Matches slash command name
**Events:** UserPromptExpansion. **Values:** the command name (e.g., `review`, `my-skill`). `"matcher": "review"`

### No matcher support
**Events:** UserPromptSubmit, Stop, TaskCompleted, TaskCreated, TeammateIdle, WorktreeCreate, WorktreeRemove, PermissionDenied, PostToolBatch, Setup. (Always fire; `matcher` ignored.)

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

Same format for all settings.json scopes.

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
          once: true   # fire only once per lifecycle (skills/agents frontmatter only)
---
```

`once: true` limits the hook to a single firing per skill/agent lifecycle. Only valid in frontmatter, not in settings.json.

Frontmatter hooks fire both when the agent runs as a subagent and when run as a main-thread agent via the `--agent` flag.

### Async hooks

Set `"async": true` to run in background (fire-and-forget). Use for long-running operations.

Set `"asyncRewake": true` instead to wake Claude after the async hook completes — differs from pure `async` which is fire-and-forget.

### Conditional hooks

Set `"if": "pattern"` on a hook to conditionally activate it using the same permission rule syntax as allow/deny rules. Example: `"if": "Bash(git log *)"` activates the hook only for matching Bash calls.

```json
{
  "type": "command",
  "command": "my-script.sh",
  "if": "Edit(/src/**)"
}
```

## Hook Sources and Scope Behavior

**Sources and their lifetimes:**

| Source | Format | Active when |
|--------|--------|-------------|
| Managed policy (`managed-settings.json` or `managed-settings.d/*.json`) | JSON | Always |
| `~/.claude/settings.json` (user) | JSON | Always |
| `.claude/settings.json` (project) | JSON | Always (in that project) |
| `.claude/settings.local.json` (local) | JSON | Always (in that project) |
| Plugin package (`<plugin-dir>/hooks/hooks.json`) | JSON | While plugin is enabled |
| Skill frontmatter | YAML | While skill is executing |
| Agent frontmatter | YAML | While subagent is running |

`/hooks` labels each with its origin: `[User]`, `[Project]`, `[Local]`, `[Plugin]`, `[Session]` (registered in memory for the current session only), or `[Built-in]` (internal Claude Code hooks). Plugin hooks use `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` environment variables.

**Where to define:** settings.json for always-apply rules; skill/agent frontmatter for lifecycle-specific rules (e.g., PreToolUse on read-only skills).

**Merge:** All matching hooks run in parallel. Same command across scopes deduplicated; different strings both run.

**Kill switches:** `disableAllHooks` (any scope), `allowManagedHooksOnly` (managed only).

## PreToolUse as Tool Enforcement

PreToolUse hooks reliably restrict tools (native mechanisms are broken). See "Hook Input JSON Schemas" for payload.

### Blocking a PreToolUse Hook

**Exit code 2** — blocks the call; stderr becomes the feedback message shown to Claude.

```bash
echo "Destructive SQL blocked" >&2; exit 2
```

**JSON `permissionDecision`** — documented (`{"hookSpecificOutput": {"permissionDecision": "allow"|"deny"|"defer"}}`) but not reliably enforced (#4669, #18312). Use exit code 2. `defer` pauses for external processing (process exits with `stop_reason: "tool_deferred"`, resume with `claude -p --resume <session-id>`).

**Precedence:** Hook `allow` does NOT bypass `deny` rules. Deny-first enforced.

*Other events block differently: UserPromptSubmit/Stop=exit 2; Prompt/Agent hooks=`{"ok": false}`.*

### Patterns

**Allowlist:** `jq -r '.tool_name' | grep -qE '^(Read|Grep|Glob)$' || exit 2`

**Denylist:** `jq -r '.tool_name' | grep -qE '^(Bash|Write|Agent)$' && exit 2`

**Scoped to skill/subagent:** Define hook in frontmatter (runs only during that lifecycle).

**Global:** If in settings.json, fires for all tool calls. No built-in subagent field — use external state file written by SubagentStart hook.

## Hook Constraints by Event (verified 2026-04-06)

### ConfigChange
- Payload includes `config_source` and `config_file_path`
- **Cannot safely modify settings.json** — writing back to the watched file creates an infinite loop. Use for validation/audit only.
- Does NOT support `type: "agent"` hooks — command and prompt only
- Unconfirmed: whether plugin installation specifically triggers it

### FileChanged
- Matcher is **basename-only** — cannot target a directory path like `~/.claude/plugins/cache/`
- Does NOT support `type: "agent"` hooks
- Observational only — cannot block changes

### SessionStart
- Fires on: startup, resume, /clear, compact
- Does NOT support `type: "agent"` hooks — command only
- Runs before plugins are fully loaded (GitHub #19491) — may cause timing issues for plugin-detection use cases
- **CAN safely modify settings.json** (not the same file being watched)
- `asyncRewake: true` exits with code 2 to wake Claude after async completion — potentially useful post-detection, but behavior on SessionStart specifically is unconfirmed

### Agent hooks (type: "agent")
- Only supported on: PreToolUse, PermissionRequest, UserPromptSubmit, Elicitation, ElicitationResult
- NOT available on: ConfigChange, FileChanged, or SessionStart

## Gotchas

- **All matching hooks run in parallel** — no execution order guarantee; one hook cannot prevent another from firing.
- **PostToolUse cannot undo actions** — tool already ran; can send feedback or replace the output Claude sees via `hookSpecificOutput.updatedToolOutput`.
- **Stop fires after every response** — check `"stop_hook_active": true/false` to avoid infinite loops.
- **Command hook stdout must be valid JSON** (or empty with exit 0).
- **Stdin consumed once** — store in variable if read.
- **Profile echo breaks JSON** — wrap with `if [[ $- == *i* ]]`.
- **Managed deny rules override everything**, including hook-approved actions.
- **PreToolUse blocks but doesn't approve** — exit 2 blocks; exit 0 doesn't bypass `permissions.deny`.
- **Any matching block hook blocks the call** — permissive hooks can't override.
- **No subagent identity in PreToolUse input** — scope per-agent restrictions via frontmatter hooks.
- **MCP tools prefixed** — e.g., `mcp__github__create_issue`; match with `matcher: "mcp__github__.*"`.

## Hook Input JSON Schemas

All events receive JSON on stdin with common fields: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`. Event-specific examples:

**PreToolUse:** `tool_name`, `tool_input` (all arguments), `tool_use_id`. Hook can return `additionalContext` to inject information to the model alongside the tool result.

**PostToolUse:** `tool_name`, `tool_input`, `tool_response` (result), `tool_use_id`, `duration_ms` (tool execution time, excluding permission prompts and PreToolUse hooks). Hook can return `hookSpecificOutput.updatedToolOutput` to replace the tool output seen by Claude (applies to all tools, not just MCP).

**PostToolUseFailure:** Same fields as PostToolUse plus `duration_ms`.

**SubagentStart:** `agent_id`, `agent_type` (Explore/Plan/general-purpose).

**SubagentStop:** `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active` (bool).

See https://code.claude.com/docs/en/hooks for full reference.

## Environment Variables

- `CLAUDE_PROJECT_DIR` — Project root for relative paths
- `CLAUDE_ENV_FILE` — File for SessionStart env var injection
- `CLAUDE_SESSION_ID` — Unique session identifier
- `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` — Override SessionEnd hook timeout (default: 1.5s)

Use `/hooks` to view all hooks grouped by event.

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
| **UserPromptSubmit** | User submits a prompt | Yes (default timeout 30s) |
| **UserPromptExpansion** | Slash command expands | Yes |
| **PreToolUse** | Before any tool executes | Yes |
| **PermissionRequest** | Permission dialog appears | Yes |
| **PermissionDenied** | Auto mode classifier denies a tool call. hookSpecificOutput supports `retry: true` to retry. | No |
| **PostToolUse** | After tool succeeds | Yes (decision:'block'; continueOnBlock feeds reason back to Claude) |
| **PostToolUseFailure** | After tool fails | No |
| **PostToolBatch** | After a parallel tool batch; can block before next model call | Yes |
| **Stop** | Claude finishes responding | Yes (capped at 8 consecutive blocks) |
| **StopFailure** | Turn ends due to API error | No |
| **SubagentStart** | Subagent spawned | No |
| **SubagentStop** | Subagent finishes | Yes (forces continuation) |
| **Notification** | Claude needs input or permission | No |
| **InstructionsLoaded** | CLAUDE.md or rules loaded; includes agent_id/agent_type for subagents | No (observability only) |
| **PreCompact** | Before context compaction | Yes (exit code 2 or decision:block) |
| **PostCompact** | After compaction completes | No |
| **ConfigChange** | Config file changes during session | Yes |
| **TaskCreated** | Task created via TaskCreate | Yes |
| **TaskCompleted** | Task marked complete | Yes |
| **TeammateIdle** | Agent Teams teammate about to idle | Yes |
| **WorktreeCreate** | Git worktree created; hook must return worktree path on stdout (HTTP: hookSpecificOutput.worktreePath) | Yes |
| **WorktreeRemove** | Worktree removed | No |
| **Elicitation** | MCP server requests user input | Yes |
| **ElicitationResult** | User responds to elicitation; can intercept before sent back | Yes |
| **CwdChanged** | Working directory changes | No |
| **FileChanged** | Watched file changes on disk | No |
| **Setup** | Triggered by `--init`, `--init-only`, or `--maintenance` CLI flags (no matcher support) | No |

## Hook Types

**Command:** Shell script. JSON in/out. Exit 0=allow, 2=block. Timeout 600s. Optional `"shell"` field: `"bash"` or `"powershell"`. Use `args: string[]` exec form to spawn without a shell — path placeholders in args never need quoting.

**HTTP:** POST JSON to URL, same response format. Supports `headers`/`allowedEnvVars`. Default timeout 600s.

**MCP tool:** Calls an MCP tool directly. Fields: `server`, `tool`, `input` (supports `${path}` substitution). Timeout 600s.

**Prompt:** Single-turn LLM call. Response: `{"ok": true/false, "reason": "..."}`. Haiku, 30s timeout. Semantic validation. Optional `"model"` field to override.

**Agent:** Multi-turn subagent with Read/Grep/Glob/Bash. Same response format. 60s timeout, up to 50 turns. For validation requiring filesystem inspection.

## JSON Output Fields

These fields may be returned from any hook handler (where applicable to the event):

- `continue`: if false, Claude stops processing
- `stopReason`: shown to user when continue is false
- `suppressOutput`: hide hook stdout from transcript
- `systemMessage`: warning shown to user
- `terminalSequence`: terminal escape sequences (OSC 0/1/2/9/99/777, BEL) — emits desktop notifications, window titles, and bells without a controlling terminal
- `additionalContext`: passed to Claude's context (inside hookSpecificOutput)

Hook output over 50K characters is saved to disk with a file path and preview injected into context instead.

## Matching

`matcher` filters which events a hook fires on. What it matches depends on the event. Omit or set to `""` or `'*'` to match all.

**Syntax:**
- Letters, digits, `_`, `|` only: exact string or `|`-separated list (e.g., `'Bash'`, `'Edit|Write'`)
- Contains any other character: treated as a JavaScript regex (e.g., `'mcp__github__.*'`)

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

Same format for all settings.json scopes (user `~/.claude/settings.json`, project `.claude/settings.json`, local `.claude/settings.local.json`).

### Common Hook Fields

- `type` (required): `command` / `http` / `mcp_tool` / `prompt` / `agent`
- `if`: conditional activation using permission rule syntax (e.g., `"Bash(git *)"`)
- `timeout`: seconds before cancel (default 600 for command/http/mcp_tool; 30 for prompt; 60 for agent)
- `statusMessage`: custom spinner message
- `args`: string array — exec form that spawns command directly without a shell; path placeholders (`${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`) never need quoting in this form
- `continueOnBlock`: true (PostToolUse only — feeds rejection reason back to Claude and continues turn instead of hard-blocking)
- `once`: run once per session then removed (skill/agent frontmatter only)

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

**JSON `permissionDecision`** — `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"|"deny"|"ask"|"defer", "permissionDecisionReason": "..."}}`. Values:
- `"allow"` — skip the permission prompt. Does NOT bypass deny rules — deny-first is always enforced.
- `"deny"` — block the tool call.
- `"ask"` — Claude Code displays an interactive yes/no permission prompt to the user with the `permissionDecisionReason` shown. If user approves, the tool runs; if user declines, it's blocked. The prompt is labeled with the hook source (`[User]`/`[Project]`/`[Plugin]`/etc).
- `"defer"` — for headless/SDK use; headless sessions pause and resume with `claude -p --resume <session-id>`.

Precedence when multiple PreToolUse hooks return different decisions: `deny` > `defer` > `ask` > `allow`.

Use `"ask"` when the hook wants user confirmation (cleaner UX than exit-code-2-with-retry-window). Use exit code 2 only when blocking with a feedback message for Claude (the model), not the user.

**Satisfying AskUserQuestion:** PreToolUse hooks can satisfy an `AskUserQuestion` tool call by returning `updatedInput` alongside `permissionDecision: 'allow'`.

*Other events block differently: UserPromptSubmit/Stop=exit 2; Prompt/Agent hooks=`{"ok": false}`.*

### Patterns

**Allowlist:** `jq -r '.tool_name' | grep -qE '^(Read|Grep|Glob)$' || exit 2`

**Denylist:** `jq -r '.tool_name' | grep -qE '^(Bash|Write|Agent)$' && exit 2`

**Scoped to skill/subagent:** Define hook in frontmatter (runs only during that lifecycle).

**Global:** If in settings.json, fires for all tool calls. No built-in subagent field — use external state file written by SubagentStart hook.

## Hook Constraints by Event

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
- Hook output can include `watchPaths` (files to monitor for FileChanged), `initialUserMessage` (inject a first message), and `additionalContext` (inject context into Claude)
- `CLAUDE_ENV_FILE` available for env var injection

### Agent hooks (type: "agent")
- Only supported on: PreToolUse, PermissionRequest, UserPromptSubmit, Elicitation, ElicitationResult
- NOT available on: ConfigChange, FileChanged, SessionStart, SubagentStart, or Setup — use a command-type hook instead

## Gotchas

- **All matching hooks run in parallel** — no execution order guarantee; one hook cannot prevent another from firing.
- **PostToolUse cannot undo actions** — tool already ran; can send feedback or replace the output Claude sees via `hookSpecificOutput.updatedToolOutput`.
- **Stop fires after every response** — check `"stop_hook_active": true/false` to avoid infinite loops. Consecutive blocks capped at 8 (override: `CLAUDE_CODE_STOP_HOOK_MAX_BLOCKS` env var).
- **Command hook stdout must be valid JSON** (or empty with exit 0).
- **Stdin consumed once** — store in variable if read.
- **Profile echo breaks JSON** — wrap with `if [[ $- == *i* ]]`.
- **Managed deny rules override everything**, including hook-approved actions.
- **PreToolUse blocks but doesn't approve** — exit 2 blocks; exit 0 doesn't bypass `permissions.deny`.
- **Any matching block hook blocks the call** — permissive hooks can't override.
- **No subagent identity in PreToolUse input** — scope per-agent restrictions via frontmatter hooks.
- **MCP tools prefixed** — e.g., `mcp__github__create_issue`; match with `matcher: "mcp__github__.*"`.

## Hook Input JSON Schemas

All events receive JSON on stdin with common fields: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, `effort.level`. `$CLAUDE_EFFORT` is also set as an environment variable. Event-specific fields:

**PreToolUse:** `tool_name`, `tool_input` (all arguments), `tool_use_id`. Hook can return `additionalContext` to inject information to the model alongside the tool result, or `updatedInput` to modify the tool input.

**PostToolUse:** `tool_name`, `tool_input`, `tool_response` (result), `tool_use_id`, `duration_ms` (tool execution time, excluding permission prompts and PreToolUse hooks). Hook can return `hookSpecificOutput.updatedToolOutput` to replace the tool output seen by Claude (applies to all tools, not just MCP).

**PostToolUseFailure:** Same fields as PostToolUse plus `duration_ms`.

**Stop / SubagentStop:** Includes `background_tasks` and `session_crons` fields.

**SubagentStart:** `agent_id`, `agent_type` (Explore/Plan/general-purpose).

**SubagentStop:** `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active` (bool).

See https://code.claude.com/docs/en/hooks for full reference.

## Environment Variables

- `CLAUDE_PROJECT_DIR` — Project root for relative paths
- `CLAUDE_PLUGIN_ROOT` — Plugin installation directory (available in plugin hooks)
- `CLAUDE_PLUGIN_DATA` — Plugin persistent data directory (available in plugin hooks)
- `CLAUDE_ENV_FILE` — File for env var injection; available in SessionStart, FileChanged, CwdChanged
- `CLAUDE_CODE_SESSION_ID` — Unique session identifier
- `CLAUDE_EFFORT` — Effort level for the current turn (mirrors `effort.level` in hook input JSON)
- `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` — Override SessionEnd hook timeout (default: 1.5s)
- `CLAUDE_CODE_STOP_HOOK_MAX_BLOCKS` — Override the maximum consecutive Stop hook blocks (default: 8)

Use `/hooks` to view all hooks grouped by event. Sources labeled: User / Project / Local / Plugin / Session / Built-in.

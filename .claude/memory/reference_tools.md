---
name: Tools, MCP, and permissions
description: Built-in tools list with subagent access flags, custom tools via MCP servers, permission system (deny > ask > allow), deferred tool loading
type: reference
---

## Built-in Tools

| Tool | Purpose | Permission | Subagent access |
|------|---------|-----------|-----------------|
| **Read** | Read files, images, PDFs, notebooks | No | Yes |
| **Write** | Create or overwrite files | Yes | Yes |
| **Edit** | Targeted string replacements in files | Yes | Yes |
| **Bash** | Execute shell commands | Yes | Yes |
| **Glob** | Fast file pattern matching (native macOS/Linux: replaced by embedded `bfs` via Bash — faster, no separate tool round-trip) | No | Yes |
| **Grep** | Regex content search (native macOS/Linux: replaced by embedded `ugrep` via Bash — faster, no separate tool round-trip) | No | Yes |
| **Agent** | Spawn subagents with isolated context | No | **No** (flat hierarchy) |
| **Skill** | Execute a skill in main conversation | Yes | **No** (main only) |
| **TodoWrite** | Manage session task checklist; available in non-interactive mode and Agent SDK | No | **No** (main only) |
| **WebFetch** | Fetch content from URLs | Yes | Yes |
| **WebSearch** | Perform web searches | Yes | Yes |
| **NotebookEdit** | Modify Jupyter notebook cells | Yes | Yes |
| **AskUserQuestion** | Ask user for clarification (disabled when `--channels` active) | No | Yes |
| **SendMessage** | Send a message to a named agent (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | No | Yes |
| **ToolSearch** | Discover and load deferred MCP tools (only when tool search enabled) | No | **No** (main session only) |
| **EnterPlanMode / ExitPlanMode** | Switch to/from planning mode | No / Yes | Yes |
| **EnterWorktree / ExitWorktree** | Manage git worktrees for isolation; `EnterWorktree` accepts a `path` param | No | **No** (not available to subagents) |
| **ListMcpResourcesTool / ReadMcpResourceTool** | Access MCP server resources | No | Yes |
| **Cron (Create/Delete/List)** | Schedule recurring or one-shot prompts within a session | No | Yes |
| **Task (Create/Get/List/Stop/Update)** | Manage background tasks | No | Yes |
| **PushNotification** | Send mobile push notifications | No | Yes |
| **Monitor** | Stream events from background processes (not on Bedrock/Vertex/Foundry; unavailable when `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` set) | Yes | Yes |
| **PowerShell** | Execute PowerShell commands; auto-enabled on Windows without Git Bash; opt-in with `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`; requires `pwsh` on Linux/macOS | Yes | Yes |
| **LSP** | Code intelligence (go-to-definition, find-references, hover) — inactive until code intelligence plugin installed | No | Yes |
| **TeamCreate / TeamDelete** | Manage agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | No | Yes |

## Bash Tool Notes

- **`cd` carry-over**: `cd` persists between Bash calls in the main session (within project dir or additional dirs). Subagent Bash sessions never carry over. Disable with `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`.
- **Environment variables**: do NOT persist between Bash calls. Activate virtualenv/conda before launching Claude Code. Persist env vars via `CLAUDE_ENV_FILE` or SessionStart hook.
- **Deny rule wrappers**: deny rules match commands wrapped in `env`, `sudo`, `watch`, `ionice`, and `setsid`.
- **Multi-line commands**: when the first line of a multi-line command is a comment, the full command is shown in the transcript.
- **`gh` rate limits**: when `gh` commands hit GitHub's API rate limit, Claude surfaces a hint in the tool response.

## PowerShell Tool Notes

- On Windows without Git Bash: enabled automatically.
- Enable elsewhere: `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` (env or settings `env` block). Requires PowerShell 7+ (`pwsh` on PATH) on Linux/macOS/WSL.
- `defaultShell: "powershell"` in settings routes interactive `!` commands through PowerShell.
- `shell: "powershell"` on individual command hooks runs that hook in PowerShell.

## Agent Tool Notes

`--print` mode honors the agent's `tools:` and `disallowedTools:` frontmatter.

## LSP Tool Notes

Inactive until code intelligence plugin installed. Provides: jump to definition, find references, type info, symbols, implementations, call hierarchies. Reports type errors/warnings after each file edit automatically.

## Monitor Tool Notes

Not available on Amazon Bedrock, Google Vertex AI, Microsoft Foundry. Unavailable when `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is set. Uses same permission rules as Bash.

## Custom Tools via MCP

**MCP (Model Context Protocol)** is the only path for users to add genuinely new tools. MCP servers provide tools that appear alongside built-ins.

- **Configuration**: `.mcp.json` (project scope, shareable via git) or `~/.claude.json` (user scope)
- **Transport**: stdio, HTTP, or SSE (SSE deprecated; see `reference_mcp.md` for details)
- **Deferred loading**: when MCP tool descriptions exceed ~10K tokens total, they lazy-load via `ToolSearch` instead of consuming context upfront. Threshold: load upfront if tools fit within 10% of context window, else defer. Enabled by default; control via `ENABLE_TOOL_SEARCH`.
- **Subagent scoping**: define MCP servers inline in subagent `mcpServers` frontmatter so only subagents that need a server pay the context cost.

Users cannot add native tools without building an MCP server.

## Permission System

Permissions are tiered: **deny > ask > allow**. First matching rule wins.

Configured in `settings.json`:
```json
{
  "permissions": {
    "allow": ["Bash(npm run *)", "Edit(/src/**/*.ts)"],
    "deny": ["Read(.env*)", "Bash(git push *)"]
  }
}
```

MCP tools use the pattern `mcp__servername__toolname` or `mcp__servername__*`.

Permission modes: `default`, `acceptEdits`, `plan` (read-only), `auto` (background safety classifier, configurable), `dontAsk`, `bypassPermissions` (containers only).

**Read-only command exemption:** Read-only commands (ls, cat, grep, find read-only forms, git status/log/diff, etc.) never prompt in any permission mode.

**`Agent(AgentName)` rule syntax:** Allow or deny specific named subagents: `"allow": ["Agent(my-reviewer)"]` or `"deny": ["Agent(destructive-agent)"]`.

PreToolUse hooks extend the permission system with custom validation logic.

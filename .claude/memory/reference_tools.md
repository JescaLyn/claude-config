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
| **Glob** | Fast file pattern matching | No | Yes |
| **Grep** | Regex content search (ripgrep) | No | Yes |
| **Agent** | Spawn subagents with isolated context | No | **No** (flat hierarchy) |
| **Skill** | Execute a skill in main conversation | Yes | **No** (main only) |
| **TodoWrite** | Manage session task checklist | No | **No** (main only) |
| **WebFetch** | Fetch content from URLs | Yes | Yes |
| **WebSearch** | Perform web searches | Yes | Yes |
| **NotebookEdit** | Modify Jupyter notebook cells | Yes | Yes |
| **AskUserQuestion** | Ask user for clarification | No | Yes |
| **ToolSearch** | Discover and load deferred MCP tools | No | Yes |
| **EnterPlanMode / ExitPlanMode** | Switch to/from planning mode | No / Yes | Yes |
| **EnterWorktree / ExitWorktree** | Manage git worktrees for isolation | No | Yes |
| **ListMcpResourcesTool / ReadMcpResourceTool** | Access MCP server resources | No | Yes |
| **Cron (Create/Delete/List)** | Schedule recurring or one-shot prompts | No | Yes |
| **Task (Output/Stop)** | Manage background tasks | No | Yes |

## Custom Tools via MCP

**MCP (Model Context Protocol)** is the only path for users to add genuinely new tools. MCP servers provide tools that appear alongside built-ins.

- **Configuration**: `.mcp.json` (project scope, shareable via git) or `~/.claude.json` (user scope)
- **Transport**: stdio, HTTP, SSE, or WebSocket
- **Deferred loading**: when MCP tools exceed ~10% of context window, they lazy-load via `ToolSearch` instead of consuming context upfront. This activates automatically.
- **Subagent scoping**: define MCP servers inline in subagent `mcpServers` frontmatter so only subagents that need a server pay the context cost.

Users cannot create native tools (tools in Claude's built-in tool list) without building an MCP server.

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

Permission modes: `default`, `acceptEdits`, `plan` (read-only), `dontAsk`, `bypassPermissions` (containers only).

PreToolUse hooks extend the permission system with custom validation logic.

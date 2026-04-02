---
name: MCP servers and tools
description: Model Context Protocol — .mcp.json format, transport types (stdio/HTTP/SSE), deferred loading, resources, elicitation, subagent scoping, permissions, approval flow, env var expansion, known bugs
type: reference
---

## What MCP Is

MCP (Model Context Protocol) is the only path for users to add genuinely new tools. MCP servers expose tools, resources, and prompts that appear alongside built-ins.

## Configuration Locations

| Scope | Location | Shared? | Purpose |
|-------|----------|---------|---------|
| **Project** | `.mcp.json` at repo root | Yes (git-tracked) | Team-shared servers |
| **User** | `~/.claude.json` | No | Personal servers across all projects |

`claude mcp add` writes to `~/.claude.json` by default. The docs call this "local" scope (`--scope local`), but it's user-level — don't confuse it with `.claude/settings.local.json` which is project-local. There is no project-local MCP config file.

Precedence: User > Project. A same-named server in `~/.claude.json` overrides the `.mcp.json` definition.

## .mcp.json Format

Flat object — each key is a server name, value is its configuration:

```json
{
  "my-stdio-server": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "package-name@latest"],
    "env": { "API_KEY": "${API_KEY}" },
    "cwd": "/optional/working/dir"
  },
  "my-http-server": {
    "type": "http",
    "url": "https://api.example.com/mcp/",
    "headers": {
      "Authorization": "Bearer ${API_TOKEN}"
    }
  },
  "my-oauth-server": {
    "type": "http",
    "url": "https://mcp.slack.com/mcp",
    "oauth": {
      "clientId": "YOUR_CLIENT_ID",
      "callbackPort": 3118
    }
  }
}
```

### Environment Variable Expansion

Supported in `command`, `args`, `env`, `url`, `headers`:
- `${VAR}` — expands to env var
- `${VAR:-default}` — fallback if unset

## Transport Types

| Transport | Type field | Config keys | Use case | Status |
|-----------|-----------|-------------|----------|--------|
| **STDIO** | `"stdio"` | `command`, `args`, `env`, `cwd` | Local servers as child processes | Recommended for local |
| **HTTP (Streamable)** | `"http"` | `url`, `headers`, `oauth` | Remote servers, cloud APIs | Recommended for remote |
| **SSE** | `"sse"` | `url`, `headers` | Legacy remote servers | Deprecated — use HTTP |

STDIO has lowest latency (<5ms). HTTP supports native OAuth. SSE still works but is not recommended for new servers.

CLI shortcuts: `claude mcp add --transport stdio <name> -- <command>`, `claude mcp add --transport http <name> <url>`.

## Deferred (Lazy) Loading

When MCP tool descriptions exceed ~10K tokens total, they switch to deferred loading automatically:
- A `ToolSearch` tool is injected instead of full definitions
- Claude searches by keyword; 3–5 relevant tools load on demand (~3K tokens per query)
- ~85% context savings vs. upfront loading
- Requires Sonnet 4+ or Opus 4+
- No configuration needed — enabled by default

**Subagent limitation**: Subagents cannot use deferred MCP tools even when declared in frontmatter. Workarounds:
- Set `ENABLE_TOOL_SEARCH=false` to force all MCP tools to load upfront (costs more context)
- Keep total MCP tool descriptions under ~10K tokens so deferral doesn't trigger
- Haiku subagents always load tools upfront (no tool search support), so deferral isn't an issue for them

## MCP Resources

Resources are read-only data exposed by MCP servers — use tools for actions, resources for reading existing data. Access via `@` mentions in prompts (e.g., `@github:issue://123`, `@postgres:schema://users`) or programmatically:
- **ListMcpResourcesTool** — enumerate available resources (URIs, descriptions)
- **ReadMcpResourceTool** — read content by URI

**When to use resources vs. tools**: Resources are for structured data that already exists (schemas, issues, docs) — discoverable via `@` autocomplete, lightweight, no computation. Tools are for actions that change state or require logic (create issue, run query, trigger workflow).

**Known limitations**: HTTP server resources are unreliable (#11292). ListMcpResourcesTool lacks pagination (#3141). Resources are less mature than tool functionality.

## Elicitation

Allows MCP servers to request structured user input mid-execution (added 2026-03):
1. Server sends elicitation request with field definitions
2. Claude Code displays interactive form/dialog
3. User provides input; returned to server to continue

Hook events: `Elicitation` (fires on request), `ElicitationResult` (fires after user responds).

## Subagent-Scoped MCP Servers

Define in agent frontmatter to limit which subagents load which servers:

```yaml
---
mcpServers:
  - github
  - database
tools:
  - mcp:github:list_issues
  - mcp:database:query
---
```

**Known limitation**: Scope isolation is incomplete (#25200). Custom agents in `.claude/agents/` cannot access MCP tools at runtime even when declared. The `mcpServers` field selects from globally-configured servers but doesn't fully hide them from parent context.

## Permission Patterns

MCP tools use `mcp__<server>__<tool>` for permissions:

```json
{
  "permissions": {
    "allow": ["mcp__github__list_*", "mcp__datadog__*"],
    "deny": ["mcp__database__drop_*"]
  }
}
```

**Known bug**: Wildcard matching fails silently in some configurations (#13077, #3107). Use explicit tool names when wildcards don't work.

## Project Server Approval Flow

First time a project-scoped server (from `.mcp.json`) is used:
1. Approval prompt appears with three options:
   - "Use this and all future MCP servers in this project" — auto-approves all
   - "Use this MCP server" — one-time approval
   - "Continue without using this MCP server" — skip
2. Individual tool calls still require permission if not in `permissions.allow`
3. Reset with `claude mcp reset-project-choices`

## MCP Settings

| Setting | Type | Effect |
|---------|------|--------|
| `enableAllProjectMcpServers` | Boolean | Auto-approve ALL project servers (discouraged) |
| `enabledMcpjsonServers` | String array | Whitelist specific servers |
| `disabledMcpjsonServers` | String array | Blacklist specific servers |

## Known Issues

**Last verified: 2026-03-26. Bug status may have changed.**

| Issue | Status | Workaround |
|-------|--------|------------|
| Wildcard permissions fail silently | #13077 | Use explicit tool names |
| HTTP server resources inaccessible | #11292 | Use tools instead of resources |
| Subagent MCP scope isolation incomplete | #25200 | Declare in parent context |
| Deferred tools inaccessible in subagents | Confirmed | `ENABLE_TOOL_SEARCH=false` or keep under ~10K tokens |
| ListMcpResourcesTool lacks pagination | #3141 | Request smaller result sets |

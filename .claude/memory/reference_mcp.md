---
name: MCP servers and tools
description: Model Context Protocol — .mcp.json format, transport types (stdio/HTTP/SSE), deferred loading, resources, elicitation, subagent scoping, permissions, approval flow, env var expansion, known bugs
type: reference
---

## What MCP Is

MCP (Model Context Protocol) is the only path for users to add genuinely new tools. MCP servers expose tools, resources, and prompts that appear alongside built-ins.

## Configuration Locations

| Scope | CLI flag | File | JSON path | Shared? |
|-------|----------|------|-----------|---------|
| `local` (default) | _(none)_ | `~/.claude.json` | `projects["/abs/path"].mcpServers` | No — per-machine, per-project |
| `user` | `-s user` | `~/.claude.json` | top-level `mcpServers` | No — all projects on this machine |
| `project` | `-s project` | `.mcp.json` at repo root | top-level `mcpServers` | Yes — git-tracked, team-shared |

`claude mcp add` writes local scope by default (into `~/.claude.json` under the project entry). Use `-s user` for across-all-projects, `-s project` to commit to the repo.

Precedence: `user` > `local` > `project`. A same-named server in user/local scope overrides the `.mcp.json` definition.

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
    },
    "alwaysLoad": true
  },
  "my-dynamic-auth-server": {
    "type": "http",
    "url": "https://api.example.com/mcp/",
    "headersHelper": "~/.claude/helpers/get-token.sh"
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

CLI shortcuts: `claude mcp add --transport stdio <name> -- <command>`, `claude mcp add --transport http <name> <url>`, `claude mcp add --transport sse <name> <url>` (deprecated).

**Tool description cap**: MCP tool descriptions and server instructions are capped at 2KB to prevent OpenAPI-generated servers from bloating context.

**`headersHelper`**: Alternative to static `headers` — a shell script invoked before each request to generate dynamic auth headers. Use when tokens rotate (e.g. short-lived JWTs). `CLAUDE_CODE_MCP_SERVER_NAME` and `CLAUDE_CODE_MCP_SERVER_URL` are set in the script's environment, allowing one helper to serve multiple servers.

## Automatic Reconnection

HTTP and SSE servers reconnect automatically on connection loss:
- Up to **5 attempts** with exponential backoff (1s base, doubling each attempt)
- After 5 failed attempts, server is marked as failed
- For `--print` mode, use `MCP_CONNECTION_NONBLOCKING=true` to skip the MCP connection wait entirely
- `--mcp-config` server connections are bounded at 5s instead of blocking on the slowest server

**Startup retries**: Servers that hit a transient error during startup auto-retry up to 3 times instead of staying disconnected.

**Parallel connection**: When a subagent or SDK reconfigures MCP servers, all servers connect in parallel — reducing total startup time proportionally to server count.

## Dynamic Tool Updates

Supports `list_changed` notifications — when an MCP server's tool list changes, available capabilities are automatically refreshed without restarting.

## Deferred (Lazy) Loading

When MCP tool descriptions exceed ~10K tokens total, they switch to deferred loading automatically:
- A `ToolSearch` tool is injected instead of full definitions
- Only tool **names** consume context until a tool is actually used
- Claude searches by keyword; 3–5 relevant tools load on demand (~3K tokens per query)
- ~85% context savings vs. upfront loading
- Requires Sonnet 4+ or Opus 4+
- No configuration needed — enabled by default
- Control with `ENABLE_TOOL_SEARCH=auto` (threshold-based: load upfront if tools fit within 10% of context, else defer), `true` (always defer), or `false` (always load upfront)
- `auto:N` syntax sets a custom threshold (N = context window percentage, 0–100)
- Per-server override: set `alwaysLoad: true` in a server's config to skip deferral for that server
- `resources/templates/list` deferred to first `@`-mention — reduces startup context cost
- Disabled by default on Vertex AI (opt in with `ENABLE_TOOL_SEARCH`)
- ToolSearch surfaces tools from servers that connect after session start (nonblocking mode)

**Subagent limitation**: Subagents cannot use deferred MCP tools even when declared in frontmatter. Workarounds:
- Set `ENABLE_TOOL_SEARCH=false` to force all MCP tools to load upfront (costs more context)
- Keep total MCP tool descriptions under ~10K tokens so deferral doesn't trigger
- Haiku subagents always load tools upfront (no tool search support), so deferral isn't an issue for them

## MCP Resources

Resources are read-only data exposed by MCP servers — use tools for actions, resources for reading existing data. Access via `@` mentions in prompts (e.g., `@github:issue://123`, `@postgres:schema://users`) or programmatically:
- **ListMcpResourcesTool** — enumerate available resources (URIs, descriptions)
- **ReadMcpResourceTool** — read content by URI

**When to use resources vs. tools**: Resources are for structured data that already exists (schemas, issues, docs) — discoverable via `@` autocomplete, lightweight, no computation. Tools are for actions that change state or require logic (create issue, run query, trigger workflow).

**Known limitations**: HTTP server resources are unreliable (#11292). ListMcpResourcesTool lacks pagination (#3141).

## Elicitation

Allows MCP servers to request structured user input mid-execution:
1. Server sends elicitation request with field definitions
2. Claude Code displays interactive form/dialog
3. User provides input; returned to server to continue

Hook events: `Elicitation` (fires on request), `ElicitationResult` (fires after user responds).

## Hooks and MCP Tools

Hooks can invoke MCP tools directly:

```json
{
  "type": "mcp_tool",
  "server": "my-server",
  "tool": "my-tool",
  "input": { "key": "value" }
}
```

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
| `allowManagedMcpServersOnly` | Boolean | Managed MCP: restrict to managed servers only |
| `allowedMcpServers` | Object array `[{ "serverName": "..." }]` | Managed MCP: permitted servers |
| `deniedMcpServers` | Object array `[{ "serverName": "..." }]` | Managed MCP: blocked servers |

## Managed MCP

Enterprise/org-controlled MCP configuration lives in `managed-mcp.json` (separate from `managed-settings.json`) in system directories. Supports `allowManagedMcpServersOnly`, `allowedMcpServers`, and `deniedMcpServers` policies.

## Secret Management for MCP Servers

**Never store credentials in configuration files.** They're too visible (git-tracked `.mcp.json`, readable by Claude in `~/.claude.json`).

### Recommended: Keychain + Wrapper Script

**Setup (one-time per secret):**

```bash
# 1. Store secret in Keychain
security add-generic-password -a "service-id" -s "key-name" -w
```

```bash
# 2. Create wrapper script
cat > ~/.claude/helpers/start-service.sh << 'EOF'
#!/bin/bash
export API_KEY="$(security find-generic-password -a "service-id" -s "key-name" -w)"
exec /path/to/service
EOF
```

```bash
# 3. Register with Claude Code
chmod +x ~/.claude/helpers/start-service.sh
claude mcp add -s user service-name -- ~/.claude/helpers/start-service.sh
```

### Comparison of Credential Approaches

| Method | Secure | TTY-free | Per-MCP | Notes |
|--------|--------|----------|---------|-------|
| **Keychain + wrapper** | ✓ | ✓ | ✓ | Recommended |
| Pass + GPG | ✓ | ✗ | ✓ | Fails in subprocess (no TTY) |
| Plain env vars | ✗ | ✓ | ✗ | Visible in shell history |
| `.env` file | ~ | ✓ | ✓ | Risk if accidentally committed |
| `-e` flag (plaintext in config) | ✗ | ✓ | ✓ | Claude can read from `~/.claude.json` |

### Anti-patterns

- **`-e` flag:** `claude mcp add -e API_KEY=sk-xxx` stores key plaintext in `~/.claude.json` (Claude can read it with the Read tool)
- **Inline shell substitution:** `sh -c 'KEY=$(security ...) exec service'` is fragile across Claude Code versions; use a wrapper script instead
- **`pass` + GPG:** Requires TTY interaction, fails in subprocess context (no terminal available)
- **Shell environment:** Keys in `.bashrc`/`.zshrc` are visible in shell history and not scoped per-MCP

**After `claude mcp add`:** start a new session, or run `/mcp` in an active session to reload.

## Environment Variables

| Variable | Effect |
|----------|--------|
| `MCP_TIMEOUT` | Server startup timeout in ms (e.g. `MCP_TIMEOUT=10000`) |
| `MCP_TOOL_TIMEOUT` | Per-tool call timeout in ms |
| `MAX_MCP_OUTPUT_TOKENS` | Raise the 10,000 token warning limit for MCP tool output |
| `MCP_CONNECTION_NONBLOCKING=true` | Skip MCP connection wait in `-p` mode |
| `ENABLE_TOOL_SEARCH` | `auto` (default), `true`, `false`, or `auto:N` |
| `ENABLE_CLAUDEAI_MCP_SERVERS=false` | Opt out of claude.ai MCP servers |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` | Strip Anthropic/cloud credentials from subprocess envs (Bash, hooks, MCP stdio) |

## Large Tool Output

By default, Claude Code warns when MCP tool output exceeds 10,000 tokens. To pass larger results (e.g. DB schemas) without truncation, MCP tools can annotate their response with `_meta["anthropic/maxResultSizeChars"]` (up to 500K chars). This bypasses the token-based persist layer for that call.

`MAX_MCP_OUTPUT_TOKENS` env var raises the warning threshold globally.

## Additional CLI Commands

```bash
claude mcp add-from-claude-desktop   # import servers from Claude Desktop config
claude mcp add-json <name> <json>    # add server from inline JSON string
claude mcp reset-project-choices     # reset per-project server approval decisions
```

Debug flag: `--mcp-debug` for verbose MCP server error output.

## Plugin MCP Servers

Use `${CLAUDE_PLUGIN_ROOT}` for bundled files and `${CLAUDE_PLUGIN_DATA}` for persistent state in plugin-provided MCP server configs.

## OAuth

Use `/mcp` to authenticate with remote servers requiring OAuth 2.0. Supports:
- Dynamic Client Registration
- Client ID Metadata Document (CIMD / SEP-991) for servers without DCR
- RFC 9728 Protected Resource Metadata discovery for finding authorization server
- Pre-configured credentials: `claude mcp add --client-id <id> --client-secret <secret>`
- Custom metadata URL: `oauth.authServerMetadataUrl` config option for non-standard discovery (e.g. ADFS)
- `--callback-port` to fix the redirect URI port for pre-registered apps
- Manual URL paste fallback: if the automatic localhost redirect fails, paste the callback URL to complete auth
- Step-up authorization: servers can request elevated scopes via `403 insufficient_scope`; re-consent is triggered automatically

## Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| Wildcard permissions fail silently | #13077 | Use explicit tool names |
| HTTP server resources inaccessible | #11292 | Use tools instead of resources |
| Subagent MCP scope isolation incomplete | #25200 | Declare in parent context |
| Deferred tools inaccessible in subagents | Confirmed | `ENABLE_TOOL_SEARCH=false` or keep under ~10K tokens |
| ListMcpResourcesTool lacks pagination | #3141 | Request smaller result sets |

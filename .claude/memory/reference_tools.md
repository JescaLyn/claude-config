---
name: Tools, MCP, and permissions
description: Built-in tools list with permission requirements, per-tool notes, custom tools via MCP servers, permission system (deny > ask > allow), deferred tool loading
type: reference
---

## Built-in Tools

| Tool | Purpose | Permission |
|------|---------|-----------|
| **Agent** | Spawn subagents with isolated context | No |
| **AskUserQuestion** | Ask user for clarification (disabled when `--channels` active) | No |
| **Bash** | Execute shell commands | Yes |
| **CronCreate** | Schedule recurring or one-shot prompt within a session | No |
| **CronDelete** | Cancel a scheduled task | No |
| **CronList** | List scheduled tasks | No |
| **Edit** | Targeted string replacements in files | Yes |
| **EnterPlanMode** | Switch to plan mode | No |
| **EnterWorktree** | Create/enter git worktree | No |
| **ExitPlanMode** | Present plan and exit plan mode | Yes |
| **ExitWorktree** | Exit worktree, return to original directory | No |
| **Glob** | Fast file pattern matching | No |
| **Grep** | Regex content search (ripgrep-based) | No |
| **ListMcpResourcesTool** | List MCP server resources | No |
| **LSP** | Code intelligence (definitions, references, errors) — inactive until code intelligence plugin installed | No |
| **Monitor** | Stream events from background processes | Yes |
| **NotebookEdit** | Modify Jupyter notebook cells | Yes |
| **PowerShell** | Execute PowerShell commands | Yes |
| **PushNotification** | Send desktop/phone notifications | No |
| **Read** | Read files, images, PDFs, notebooks | No |
| **ReadMcpResourceTool** | Read a specific MCP resource by URI | No |
| **RemoteTrigger** | Create/run Routines on claude.ai | No |
| **ScheduleWakeup** | Reschedule the next /loop iteration | No |
| **SendMessage** | Send a message to a named agent teammate (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | No |
| **ShareOnboardingGuide** | Upload ONBOARDING.md and return a share link | Yes |
| **Skill** | Execute a skill in main conversation | Yes |
| **TaskCreate** | Create a task in the task list | No |
| **TaskGet** | Get task details | No |
| **TaskList** | List all tasks | No |
| **TaskOutput** | Get output from a background task | No |
| **TaskStop** | Kill a background task | No |
| **TaskUpdate** | Update task status or details | No |
| **TeamCreate** | Create an agent team | No |
| **TeamDelete** | Delete an agent team | No |
| **TodoWrite** | Write structured to-do items | No |
| **ToolSearch** | Discover and load deferred MCP tools | No |
| **WaitForMcpServers** | Wait for connecting MCP servers (when tool search disabled) | No |
| **WebFetch** | Fetch URL content (processed by fast model) | Yes |
| **WebSearch** | Web search (up to 8 backend searches per call) | Yes |
| **Write** | Create or overwrite files | Yes |

## Bash Tool Notes

- **`cd` carry-over**: `cd` persists between Bash calls in the main session (within project dir or additional dirs). Subagent Bash sessions never carry over. Disable with `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`.
- **Environment variables**: do NOT persist between Bash calls. Activate virtualenv/conda before launching Claude Code. Persist env vars via `CLAUDE_ENV_FILE` or SessionStart hook.
- **Timeout**: default 2 min; max 10 min via timeout param.
- **Output cap**: 30,000 chars (override: `BASH_MAX_OUTPUT_LENGTH`, ceiling 150,000).
- **Session ID**: `CLAUDE_CODE_SESSION_ID` is available in the Bash subprocess environment, matching the `session_id` passed to hooks.
- **Background processes**: use `run_in_background:true` for long-running processes.
- **Deny rule wrappers**: deny rules match commands wrapped in `env`, `sudo`, `watch`, `ionice`, and `setsid`.
- **Multi-line commands**: when the first line of a multi-line command is a comment, the full command is shown in the transcript.
- **Read-only command exemption**: read-only commands (ls, cat, grep, find read-only forms, git status/log/diff, etc.) never prompt in any permission mode.
- **`gh` rate limits**: when `gh` commands hit GitHub's API rate limit, Claude surfaces a hint in the tool response.
- **No-match exit codes**: a "no matches" result (exit code 1) from `egrep`, `fgrep`, `git grep`, or `git diff` is not reported as a command failure.

## PowerShell Tool Notes

- On Windows without Git Bash: enabled automatically as the primary shell.
- Enabled by default on Bedrock, Vertex, and Foundry (Windows). Opt out with `CLAUDE_CODE_USE_POWERSHELL_TOOL=0`.
- Enable on Linux/macOS/WSL: `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` (env or settings `env` block). Requires PowerShell 7+ (`pwsh` on PATH).
- Windows PS7 detection: PowerShell 7 installed via Microsoft Store, MSI without PATH, or `.NET global tool` is found automatically.
- Passes `-ExecutionPolicy Bypass` by default. Opt out with `CLAUDE_CODE_POWERSHELL_RESPECT_EXECUTION_POLICY=1`.
- `defaultShell: "powershell"` in settings routes interactive `!` commands through PowerShell.
- `shell: "powershell"` on individual command hooks runs that hook in PowerShell.

## Edit Tool Notes

- Exact string replacement — no regex or fuzzy matching.
- Must read the file first in the same conversation. `head`/`tail` file views also satisfy the read-before-edit check.
- `old_string` must appear exactly once, or use `replace_all:true`.

## Read Tool Notes

- Returns file contents with line numbers.
- Handles images (PNG/JPG), PDFs (`pages` param, max 20 pages/request), and `.ipynb` notebooks.
- Large files: paginated with `offset`/`limit`.
- Whole-file reads that exceed the token limit return a truncated first page with a "PARTIAL view" notice rather than an error.

## Glob Tool Notes

- Capped at 100 results.
- Respects `.gitignore` by default.
- On macOS/Linux native builds, Glob and Grep are replaced by embedded `bfs` and `ugrep` available through the Bash tool — faster searches without a separate tool round-trip. Windows and npm-installed builds use the standalone tools.

## Grep Tool Notes

- Uses ripgrep regex syntax.
- Modes: `files_with_matches` (default), `content`, `count`.
- Respects `.gitignore`.
- On macOS/Linux native builds, replaced by embedded `ugrep` available through the Bash tool — faster searches without a separate tool round-trip. Windows and npm-installed builds use the standalone tool.

## WebFetch Tool Notes

- Fetches URL, converts HTML to Markdown, runs prompt via fast model.
- Lossy by design; 15-min cache; redirects to a different host are not followed automatically.
- First-time domain use prompts for permission. Add `WebFetch(domain:example.com)` to allow list.

## WebSearch Tool Notes

- Up to 8 backend searches per call; returns titles and URLs only.
- Follow up with WebFetch to read page contents.
- No specifier in permission rules — allow as `WebSearch`.

## Monitor Tool Notes

- Not available on Amazon Bedrock, Google Vertex AI, or Microsoft Foundry.
- Unavailable when `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is set.
- Uses same permission rule format as Bash.

## Agent Tool Notes

`--print` mode honors the agent's `tools:` and `disallowedTools:` frontmatter.

`subagent_type` matching is case- and separator-insensitive (e.g. `"Code Reviewer"` resolves to `code-reviewer`).

## LSP Tool Notes

Inactive until code intelligence plugin installed. Provides: jump to definition, find references, type info, symbols, implementations, call hierarchies. Reports type errors/warnings after each file edit automatically.

## ToolSearch Tool Notes

Deferred tools (WebSearch, WebFetch, and large MCP tool sets) are lazy-loaded via `ToolSearch` to avoid consuming context upfront. Available to skills with `context:fork` and other subagents on first turn. Disabled by default on Vertex AI (opt in with `ENABLE_TOOL_SEARCH`).

## Custom Tools via MCP

**MCP (Model Context Protocol)** is the only path for users to add genuinely new tools. MCP servers provide tools that appear alongside built-ins.

- **Configuration**: `.mcp.json` (project scope, shareable via git) or `~/.claude.json` (user scope)
- **Transport**: stdio, HTTP, or SSE (SSE deprecated; see `reference_mcp.md` for details)
- **Deferred loading**: when MCP tool descriptions exceed ~10K tokens total, they lazy-load via `ToolSearch` instead of consuming context upfront. Threshold: load upfront if tools fit within 10% of context window, else defer. Enabled by default; disabled by default on Vertex AI. Control via `ENABLE_TOOL_SEARCH`.
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

**`Agent(AgentName)` rule syntax:** Allow or deny specific named subagents: `"allow": ["Agent(my-reviewer)"]` or `"deny": ["Agent(destructive-agent)"]`.

PreToolUse hooks extend the permission system with custom validation logic.

## Permission Rule Formats

| Format | Applies to |
|--------|-----------|
| `Bash(npm run *)` | Bash, Monitor |
| `PowerShell(Get-ChildItem *)` | PowerShell |
| `Read(~/secrets/**)` | Read, Grep, Glob, LSP |
| `Edit(/src/**)` | Edit, Write, NotebookEdit |
| `Skill(deploy *)` | Skill |
| `Agent(Explore)` | Agent |
| `WebFetch(domain:example.com)` | WebFetch |
| `WebSearch` | WebSearch (no specifier) |

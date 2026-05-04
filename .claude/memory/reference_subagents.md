---
name: Subagents
description: Built-in agents, custom agent definitions, frontmatter fields, model resolution, invocation methods, foreground/background, persistent memory, tool access, spawning workarounds for known bugs
type: reference
---

## Built-In Subagents

| Name | Model | Tools | Purpose |
|---|---|---|---|
| Explore | Haiku | read-only | Codebase search |
| Plan | inherits | read-only | Plan mode |
| general-purpose | inherits | all | Complex tasks |
| statusline-setup | Sonnet | — | Status line config |
| Claude Code Guide | Haiku | — | Claude Code help |

## Managing Subagents

`/agents` opens a tabbed interface (Running tab + Library tab). Library: view all, create (guided or Claude-generated), edit, delete. Live instances show a `● N running` indicator next to the agent type.

`claude agents` — list all agents from CLI without starting an interactive session.

## Invocation Methods

- Natural language: "Use the X subagent to…"
- @-mention: `@"subagent-name (agent)"` — guarantees it runs
- Session-wide: `claude --agent <name>` or `"agent"` key in `.claude/settings.json`
- Plugin subagent: `claude --agent <plugin-name>:<agent-name>`

## Foreground vs Background

- **Foreground**: blocks main conversation; permission prompts pass through.
- **Background**: runs concurrently. Claude Code pre-approves permissions before launch. Set `background: true` in frontmatter to always run as background. Press `Ctrl+B` to background a running task.
- Disable all background tasks: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.

## Disabling Specific Subagents

```json
{"permissions": {"deny": ["Agent(Explore)", "Agent(my-custom-agent)"]}}
```

## Agent Discovery Priority

When the same agent name appears in multiple locations, resolution order (highest wins):

1. Managed settings
2. `--agents` CLI flag (current session)
3. `.claude/agents/` (current project)
4. `~/.claude/agents/` (all projects)
5. Plugin's `agents/` directory (lowest)

Project agents discovered by walking up from cwd. Directories added with `--add-dir` are not scanned.

## Frontmatter Fields

Required: `name`, `description`

Optional:
- `tools` (allowlist), `disallowedTools` (denylist) — if both set, denylist applied first
- `model` — `sonnet`/`opus`/`haiku`/full model ID/`inherit` (default: `inherit`)
- `permissionMode` — `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan`
- `maxTurns`, `effort` — cap turns or set reasoning effort. Set `effort: low` on Haiku agents for mechanical work; without it, Haiku still incurs thinking tokens. See `reference_thinking.md`.
- `skills` — full content injected at startup (not just made available). Cannot preload skills with `disable-model-invocation: true`. Source prefix required: `from-user` (`~/.claude/skills/`), `from-project` (`.claude/skills/`), `from-plugin` (`<plugin>/skills/`). Example:
  ```yaml
  skills:
    - from-user: deploy
    - from-project: test-suite
    - from-plugin: formatter@my-plugin
  ```
- `mcpServers` — define inline (scoped) or reference by name (reuses global config)
- `hooks`, `memory`
- `background: true` — always run as background task
- `color` — `red`/`blue`/`green`/`yellow`/`purple`/`orange`/`pink`/`cyan`
- `isolation: worktree` — subagent gets isolated git worktree copy; auto-cleaned if no changes
- `initialPrompt` — auto-submitted as first user turn when agent runs as main session

**Plugin subagents** do NOT support `hooks`, `mcpServers`, or `permissionMode` frontmatter (security restriction).

## Model Resolution Order

1. `CLAUDE_CODE_SUBAGENT_MODEL` env var (highest)
2. Per-invocation `model` parameter on the Agent call
3. Subagent definition's `model` frontmatter field
4. Main conversation's model (lowest / default)

**Permission inheritance:** Subagents inherit permission context from the main conversation. If parent uses `bypassPermissions` or `acceptEdits`, that takes precedence. If parent uses `auto` mode, subagent inherits `auto` and the `permissionMode` frontmatter is ignored.

## Memory Field

`memory` scopes in frontmatter:
- `user` → `~/.claude/agent-memory/<name>/`
- `project` → `.claude/agent-memory/<name>/`
- `local` → `.claude/agent-memory-local/<name>/`

When memory is enabled: system prompt includes instructions + first 200 lines or 25 KB of MEMORY.md. Read/Write/Edit tools auto-enabled.

## Tool Access

- Restrict with `tools:` (allowlist) or `disallowedTools:` (denylist) in frontmatter. If both set, denylist applies first.
- **`tools:` IS enforced at runtime** when the agent is spawned natively (i.e., its name is a valid `subagent_type`).
- **The general-purpose workaround bypasses tool restrictions.** When spawning via `Agent(subagent_type: "general-purpose", ...)`, the agent gets all general-purpose tools regardless of what the original agent file declares. Use PreToolUse hooks for hard enforcement when using general-purpose.
- Subagents cannot call skills programmatically, but skills can be preloaded into their context via the `skills` frontmatter field.
- MCP tools are inherited by default. Scope with `mcpServers` frontmatter.
- Skill `allowed-tools` restricts the skill's own main-context calls only — does not propagate to spawned subagents.

## Spawning Custom Agents

Two known bugs affect custom agent spawning:

1. **Discovery is unreliable** (#11205). Agent files may not be discovered at session start, especially in VS Code (#24439). Discovery failure produces an explicit error listing available agents — not silent.
2. **Body content not injected** (#13627, CLOSED NOT_PLANNED). Even when discovery works, the markdown body is not passed to the spawned subagent. The agent gets the correct model and tools but generic behavior.

Because of Bug 2, **always use the general-purpose workaround** for custom agents with meaningful prompt content:

1. **Read** `.claude/agents/<name>.md` with the Read tool.
2. **Extract** the `model` field from the YAML frontmatter.
3. **Strip** the frontmatter.
4. **Assemble** the prompt: agent body first, then runtime arguments.
5. **Call** the Agent tool:

```
Agent(
  subagent_type: "general-purpose",
  model: <from frontmatter>,
  prompt: "<agent body>\n\nYour task: <value>"
)
```

**Tradeoff:** General-purpose workaround loses `tools:` restrictions. Use PreToolUse hooks or `--agents` CLI flag for hard tool enforcement.

**Alternative: `--agents` CLI flag.** Defining agents inline at session start via `claude --agents '{...}'` avoids both bugs — discovery is guaranteed and the `prompt` field is injected correctly. Agents defined this way also enforce `tools:` restrictions. Downside: requires session setup and JSON agent definitions.

**Parallel spawning:** Read all agent files first, then issue all Agent calls in a single message.

**The `run-agent` skill** (`~/.claude/skills/run-agent/SKILL.md`) automates steps 1–4 above. Useful for one-off spawns from the main conversation; cannot run in parallel, so orchestrators needing concurrent execution must use the Agent tool directly.

**ToolSearch blocked for custom agents** (#47598, OPEN). Custom agents in `.claude/agents/` cannot use ToolSearch. Workaround: `ENABLE_TOOL_SEARCH=false` forces upfront loading, or keep MCP tool descriptions under ~10K tokens.

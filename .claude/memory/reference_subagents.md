---
name: Subagents
description: Built-in agents, custom agent definitions, frontmatter fields, model resolution, invocation methods, context isolation (always isolated by default), fork mode (CLAUDE_CODE_FORK_SUBAGENT), foreground/background, persistent memory, tool access, spawning workarounds for known bugs
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

## Context Isolation — Subagents Are Always Isolated

**By default, every subagent invocation runs in a fresh, isolated context window.** It does NOT inherit the parent conversation's messages, system prompt, tools, or model state. The subagent only sees: its own system prompt (the agent definition's markdown body), the prompt passed in by `Agent(prompt: ...)`, and basic environment details (cwd, etc.).

From the docs: "Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions" and "Each subagent invocation creates a new instance with fresh context."

**There is no `context: fork` frontmatter field for subagents.** That field is skills-only. Setting it on an agent file is a no-op.

**Implication for `model:` downgrade**: setting `model: haiku|sonnet` on a subagent is always safe — the parent conversation is never squeezed into the subagent's smaller context window because the subagent doesn't see the parent conversation at all. (Contrast with skills, where main-context model downgrade triggers parent auto-compaction.)

## Fork Subagents — Experimental Inverse of Isolation

`CLAUDE_CODE_FORK_SUBAGENT=1` env var enables **fork mode** (Claude Code v2.1.117+, experimental).

A **fork** is a special subagent that *inherits the entire conversation so far* instead of starting fresh: same system prompt, tools, model, and message history as the main session. The fork's own tool calls stay out of the parent conversation; only its final result returns. Use when a named subagent would need too much background to be useful, or for parallel exploration from the same starting point.

**Three behavior changes when enabled:**

1. Claude spawns a fork whenever it would otherwise use the **general-purpose** subagent. Named subagents (Explore, custom agents) still spawn isolated.
2. Every subagent spawn runs in the background. Set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` to keep them synchronous.
3. The `/fork` command spawns a fork (overriding its default `/branch` alias).

**Manual invocation:** `/fork <directive>` starts a fork on demand. Fork name derived from the first words of the directive. The fork appears in a panel below the prompt input, runs in the background, and its result arrives in the main conversation when it finishes.

**Prompt cache:** A fork's system prompt + tool definitions are identical to the parent, so its first request reuses the parent's prompt cache. This makes forking cheaper than spawning a fresh general-purpose subagent for tasks that need the same context.

**Worktree isolation:** When the Agent tool spawns a fork, it can pass `isolation: worktree` so the fork's file edits go to a separate git worktree.

**Important:** "Fork" is overloaded in Claude Code and means **opposite things** depending on which surface you're configuring:

| Surface | `fork` semantics |
|---|---|
| Skill `context: fork` frontmatter | Run the skill ISOLATED in a subagent (no parent history) |
| Subagent `CLAUDE_CODE_FORK_SUBAGENT=1` env | Run the subagent WITH parent history (drops isolation) |

Skill `context: fork` adds isolation; subagent fork mode removes isolation. Don't confuse them.

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

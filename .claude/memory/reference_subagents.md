---
name: Subagents
description: Agent definition reference — built-in agents, custom agent files (.claude/agents/), all frontmatter fields, model resolution order, invocation methods, context isolation mechanics, fork mode (CLAUDE_CODE_FORK_SUBAGENT), foreground/background, persistent memory, tool access, and spawning bugs/workarounds. Use this to understand what a subagent is and how to define one; see reference_subagent_pipelines.md for orchestration patterns and multi-agent coordination.
type: reference
---

## Built-In Subagents

| Name | Model | Tools | Purpose |
|---|---|---|---|
| Explore | Haiku | read-only (Glob/Grep/Read/LSP) | Codebase search |
| Plan | inherits | read-only | Plan mode |
| general-purpose | inherits | all | Complex tasks |
| statusline-setup | Sonnet | — | Status line config |
| Claude Code Guide | Haiku | — | Claude Code help |

## Agent File Location

Agent files are stored as `~/.claude/agents/<agent-name>.md` (personal/global) or `.claude/agents/<agent-name>.md` (project-scoped).

## Managing Subagents

`/agents` opens a tabbed interface (Running tab + Library tab). Library: view all, create (guided or Claude-generated), edit, delete. Live instances show a `● N running` indicator next to the agent type.

`claude agents` — list all agents from CLI without starting an interactive session. Accepts `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, and `--dangerously-skip-permissions`; these apply to the dashboard and to background sessions.

## Invocation Methods

- Natural language: "Use the X subagent to…"
- @-mention: `@"subagent-name (agent)"` — guarantees it runs
- Session-wide: `claude --agent <name>` or `"agent"` key in `.claude/settings.json`
- Plugin subagent: `claude --agent <plugin-name>:<agent-name>`

## Foreground vs Background

- **Foreground**: blocks main conversation; permission prompts pass through. Press `Ctrl+B` to move a running foreground task to background.
- **Background** (`isolate: true` in frontmatter): runs concurrently; no permission prompts; tools needing approval are auto-denied; async. Completion notifications include elapsed duration (e.g. "Agent completed · 3h 2m 5s").
- Pinned background sessions (`Ctrl+T` in `claude agents`) stay alive when idle and are restarted in place to apply Claude Code updates. They preserve the model and effort level set after waking from idle. Sessions shed under memory pressure are non-pinned first.
- Empty idle background sessions left over from `←` are automatically retired by the daemon after 5 minutes.
- Background sessions support `/resume` and appear alongside interactive sessions in session lists.
- Renaming a background session with `Ctrl+R` updates the attached session's banner immediately.
- Disable all background tasks: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.

## Background Session Worktree Behavior

By default, background sessions isolate edits in a git worktree. Set `worktree.bgIsolation: "none"` in settings to let background sessions edit the working copy directly without requiring `EnterWorktree`.

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
- `type` — `general-purpose` (default), `explore`, `plan`, `coder`, `research`
- `system-prompt` — inline system prompt string (alternative to markdown body)
- `tools` (allowlist), `disallowedTools` (denylist) — if both set, denylist applied first
- `model` — `sonnet`/`opus`/`haiku`/full model ID/`inherit` (default: `inherit`)
- `permissionMode` — `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan`
- `maxTurns`, `effort` — cap turns or set reasoning effort. Set `effort: low` on Haiku agents for mechanical work; without it, Haiku still incurs thinking tokens. See `reference_thinking.md`.
- `skills` / `preloadSkills` — full content injected at startup (not just made available). Cannot preload skills with `disable-model-invocation: true`. Source prefix required: `from-user` (`~/.claude/skills/`), `from-project` (`.claude/skills/`), `from-plugin` (`<plugin>/skills/`). Example:
  ```yaml
  skills:
    - from-user: deploy
    - from-project: test-suite
    - from-plugin: formatter@my-plugin
  ```
- `preloadScripts` — scripts injected at startup alongside preloaded skills
- `mcpServers` — define inline (scoped) or reference by name (reuses global config)
- `hooks` — fires when running as a main-thread agent via `--agent`. Stop/SubagentStop hook input includes `background_tasks` and `session_crons` fields.
- `memory`
- `isolate` — `true`: always run as background task (no permission prompts, auto-denied if approval needed, async); `worktree`: subagent gets isolated git worktree copy, auto-cleaned if no changes
- `color` — `red`/`blue`/`green`/`yellow`/`purple`/`orange`/`pink`/`cyan`
- `additionalDirectories` — extra directories the subagent can access
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

**There is no `context: fork` frontmatter field for subagents.** That field is skills-only. Setting it on an agent file is a no-op.

**Implication for `model:` downgrade**: setting `model: haiku|sonnet` on a subagent is always safe — the parent conversation is never squeezed into the subagent's smaller context window because the subagent doesn't see the parent conversation at all. (Contrast with skills, where main-context model downgrade triggers parent auto-compaction.)

## Fork Subagents — Inverse of Isolation

`CLAUDE_CODE_FORK_SUBAGENT=1` env var enables **fork mode**. Works in both interactive and non-interactive sessions (SDK, `claude -p`).

A **fork** is a special subagent that *inherits the entire conversation so far* instead of starting fresh: same system prompt, tools, model, and message history as the main session. The fork's own tool calls stay out of the parent conversation; only its final result returns. Use when a named subagent would need too much background to be useful, or for parallel exploration from the same starting point.

**Three behavior changes when enabled:**

1. Claude spawns a fork whenever it would otherwise use the **general-purpose** subagent. Named subagents (Explore, custom agents) still spawn isolated.
2. Every subagent spawn runs in the background and shows permission prompts (unlike regular background tasks which auto-deny). Set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` to keep them synchronous.
3. The `/fork` command spawns a fork (overriding its default `/branch` alias).

**Manual invocation:** `/fork <directive>` starts a fork on demand. Fork name derived from the first words of the directive. The fork appears in a panel below the prompt input, runs in the background, and its result arrives in the main conversation when it finishes.

**Prompt cache:** A fork's system prompt + tool definitions are identical to the parent, so its first request reuses the parent's prompt cache. This makes forking cheaper than spawning a fresh general-purpose subagent for tasks that need the same context.

**Worktree isolation:** When the Agent tool spawns a fork, it can pass `isolate: worktree` so the fork's file edits go to a separate git worktree.

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
- **`tools:` restrictions are enforced at runtime** when the agent is spawned natively (i.e., its name is a valid `subagent_type`).
- **Using `subagent_type: "general-purpose"` bypasses tool restrictions** — the subagent gets all general-purpose tools regardless of the agent file's `tools:` declaration. This is why the correct pattern uses the agent's registered name as `subagent_type` (see Spawning Custom Agents).
- Subagents can invoke skills via the Skill tool and find project, user, and plugin skills. Skills can also be preloaded into their context via the `skills` frontmatter field.
- MCP tools are inherited by default. Scope with `mcpServers` frontmatter.
- Skill `allowed-tools` restricts the skill's own main-context calls only — does not propagate to spawned subagents.
- `--dangerously-skip-permissions` does not prompt for writes to `.claude/skills/`, `.claude/agents/`, or `.claude/commands/`.

## Spawning Custom Agents

Agent body content is not injected when spawning via `subagent_type` — the markdown body is silently ignored. Tool restrictions (`tools:`, `disallowedTools:`) are enforced as a hard capability constraint, not a prompt instruction. Use the agent's registered name as `subagent_type` and include the body manually in the `prompt`:

1. **Read** `~/.claude/agents/<name>.md` (or `.claude/agents/<name>.md`) with the Read tool.
2. **Extract** the `model` and `name` fields from YAML frontmatter.
3. **Strip** the frontmatter — keep only the markdown body.
4. **Call** the Agent tool:

```
Agent(
  subagent_type: "<name from frontmatter>",   ← enforces tools: restriction
  model: <from frontmatter>,
  prompt: "<agent body>\n\nYour task: <value>"  ← supplies instructions
)
```

**Do NOT use `subagent_type: "general-purpose"`** — that loses all tool restrictions from the agent definition.

**Discovery failure is explicit, not silent.** If `subagent_type` doesn't resolve, Claude Code errors and lists available agents; it does not silently fall back to general-purpose. Discovery from `~/.claude/agents/` works for most users; VS Code issues (#24439) exist but aren't universal.

**`subagent_type` matching is case- and separator-insensitive:** `"Code Reviewer"` resolves to `code-reviewer`.

**The `run-agent` skill** (`~/.claude/skills/run-agent/SKILL.md`) automates these steps. Cannot run in parallel; orchestrators needing concurrent execution must use the Agent tool directly.

**Alternative: `--agents` CLI flag.** JSON agent definitions passed at session start enforce both body and tools natively. Downside: requires session setup and can't be done from inside a skill.

**Parallel spawning:** Read all agent files first, then issue all Agent calls in a single message.

**ToolSearch blocked for custom agents** (#47598). Custom agents in `.claude/agents/` cannot use ToolSearch. Workaround: `ENABLE_TOOL_SEARCH=false` forces upfront loading, or keep MCP tool descriptions under ~10K tokens.

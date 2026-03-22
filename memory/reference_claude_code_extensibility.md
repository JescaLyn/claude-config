---
name: Claude Code extensibility model
description: How commands, skills, subagents, and hooks differ in invocation model, scope, and when to use each
type: reference
---

## Commands vs Skills vs Subagents vs Hooks

| Concept | What it is | Who invokes it | Where defined |
|---------|-----------|---------------|---------------|
| **Commands** | User-facing slash commands | User types `/name` | `.claude/commands/name.md` |
| **Skills** | Reusable prompt templates Claude can call programmatically | Claude (via Skill tool) or user (`/name`) | `.claude/skills/name/SKILL.md` |
| **Subagents** | Isolated agents with custom prompts, tools, models | Claude (via Agent tool) or user via `@agent-name` | `.claude/agents/name.md` |
| **Hooks** | Deterministic shell/HTTP automation on lifecycle events | System (event-driven, automatic) | `settings.json` |

### Commands
- **User-initiated only.** The user types `/command-name` to invoke.
- Custom commands have been merged into skills. Both `.claude/commands/name.md` and `.claude/skills/name/SKILL.md` create a `/name` slash command.
- Commands are the entry point for user-facing workflows.
- Support `model` frontmatter to override the session model (see Model Overrides below).

### Skills
- **Agent-callable.** Claude invokes them via the Skill tool. Can also be user-invoked as slash commands.
- Invocation control via frontmatter:
  - Default: both user (`/name`) and Claude (Skill tool, auto-triggered by description match)
  - `disable-model-invocation: true`: user-only, Claude cannot call it
  - `user-invocable: false`: Claude-only, no slash command exposed
- Support `$ARGUMENTS`, `$0`, `$1` placeholders for parameterized invocation.
- Support shell substitution (`` !`command` ``). **Arguments are interpolated before shell commands run** (confirmed by testing), so `` !`cat $0` `` works with skill arguments.
- Can run in forked context (`context: fork`) for isolation.
- Skills run in the conversation context (not as isolated subprocesses). Cannot run in parallel.
- Support `model` frontmatter to override the session model (see Model Overrides below).

### Subagents
- **Programmatic isolation.** Run in separate context windows with their own system prompt, tools, and model.
- The Agent tool's `subagent_type` only accepts built-in types (general-purpose, Explore, Plan, etc.).
- Custom agents in `.claude/agents/` define prompt, model, and tools via frontmatter, but **cannot be directly referenced as subagent_type values**. The workaround is spawning `general-purpose` and passing the agent's prompt content.
- **Can run in parallel** via multiple Agent calls in a single message.
- Best for: task isolation, parallel execution, model/tool scoping.
- Support `model` frontmatter to override the session model (see Model Overrides below).

### Hooks
- **System-driven, deterministic.** Fire automatically on lifecycle events (PreToolUse, PostToolUse, Stop, SessionStart, SubagentStart/Stop, etc.).
- Not instructions for Claude. They enforce rules, format code, send notifications, or block operations.
- Defined in settings files, not as standalone markdown.
- Types: command (shell), http, prompt (single-turn LLM), agent (multi-turn subagent).

## Model Overrides

**All three** (commands, skills, subagents) support a `model` frontmatter field that overrides the session model when the command/skill/subagent runs.

```yaml
---
model: haiku
---
```

- Valid values: `sonnet`, `opus`, `haiku`, or a full model ID (e.g., `claude-opus-4-6`).
- Subagents also accept `inherit` (the default, meaning use the session model).
- When set, the specified model is used instead of whatever model the Claude Code session is configured to use.
- This applies regardless of whether the skill/command is invoked by the user or by Claude.

## When to use what

- **User needs to trigger a workflow** -> Skill with slash command (default or `disable-model-invocation: true`)
- **Claude/orchestrator needs reusable prompt logic** -> Skill with `user-invocable: false`
- **Need isolated execution or parallel spawning** -> Subagent (Agent tool)
- **Need deterministic automation on events** -> Hook
- **DRY wrapper for custom agent spawning** -> Skill that inlines agent file via shell substitution

## Known gap (as of 2026-03)

Custom `.claude/agents/` files cannot be used as `subagent_type` values in the Agent tool. The workaround is spawning `general-purpose` with the custom agent's prompt inlined. A skill can DRY this by using shell substitution to read the agent file at invocation time, avoiding both repetition and the agent self-reading its own file.

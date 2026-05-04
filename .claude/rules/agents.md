# Agents

## Direct Dispatch

Use for a single well-scoped task — no phases, no parallel branches.

- **Named agent exists** → `run-agent` skill (checks `.claude/agents/` then `~/.claude/agents/`, or any explicit path)
- **No named agent** → `Agent(subagent_type: "general-purpose", ...)` with a self-contained prompt

For multi-phase or parallel work, use an agentic pipeline — see `rules/agentic-pipelines.md`.

## Context Forking

When spawning an agent, ask: can it succeed with only its explicit data handoff?

- **Yes** → set `context: fork` on the agent definition. Saves tokens; agent doesn't inherit parent conversation history.
- **No** → don't fork. Agent needs outer context, reasoning chains, or prior decisions to avoid redoing work. Inheriting context is cheaper than correcting uninformed decisions.

Examples:
- Fork: analysis agents that receive all needed data (file paths, structured input) in the prompt
- Don't fork: agents that update a running ledger or need prior findings to maintain coherence

Note: `context: fork` on a **skill** also works — the skill runs as an isolated subagent. Skills with `context: fork` cannot spawn further agents (flat hierarchy).

## Save Useful Agents

Save broadly applicable subagent prompts to `~/.claude/agents/`. Only save non-default configs (non-sonnet model or restricted tools). Check existing agents first — don't duplicate.

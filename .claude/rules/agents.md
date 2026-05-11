# Agents

## Direct Dispatch

Use for a single well-scoped task — no phases, no parallel branches.

- **Named agent exists** → `run-agent` skill (checks `.claude/agents/` then `~/.claude/agents/`, or any explicit path)
- **No named agent** → `Agent(subagent_type: "general-purpose", ...)` with a self-contained prompt

For multi-phase or parallel work, use an agentic pipeline — see `rules/agentic-pipelines.md`.

## Keep Agent Prompts Self-Contained

Subagents start with no parent conversation history. Every `Agent(prompt: ...)` must include the data, file paths, prior decisions, and goal context the subagent needs to succeed without parent reasoning. Treat the prompt as briefing a smart colleague who just walked in.

If a subagent genuinely cannot work without parent conversation, restructure the task so the orchestrator does the context-dependent reasoning and hands the subagent a smaller self-contained job. Fork mode (`CLAUDE_CODE_FORK_SUBAGENT=1`) is the escape hatch but rarely the right answer.

See `memory/reference_subagents.md` for full isolation/fork mechanics.

## Save Useful Agents

Save broadly applicable subagent prompts to `~/.claude/agents/`. Only save non-default configs (non-sonnet model or restricted tools). Check existing agents first — don't duplicate.

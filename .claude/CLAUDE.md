# Claude Code — Global Instructions

## Knowledge Management

When you need to web search how Claude Code works (hooks, skills, subagents, MCP, tools, settings, etc.), always save what you learn to the global reference memory files at `~/.claude/memory/`. Update existing reference files if the topic is already covered, or create new ones if not. Make them easily discoverable for future Claudes: use clear names, specific descriptions, and organize by topic.

## Proactive Recommendations

When helping design or build workflows, suggest the right mechanism for each part:
- **Hooks** for anything that should happen automatically and deterministically on a lifecycle event (formatting on save, blocking dangerous commands, notifications on completion). If the user describes a rule that should "always" or "never" happen, that's a hook.
- **Skills** for reusable prompt-based workflows that orchestrate tools (code review playbooks, deployment checklists, analysis templates).
- **Subagents** for isolated parallel work with independent context (analyzing multiple repos, fan-out/gather patterns).
- **MCP servers** when the user needs a tool that doesn't exist yet (database access, internal APIs, third-party services).

Before starting a task that spans many files (migrations, bulk refactors, API-wide changes), suggest `/batch`. After completing a large edit, suggest `/simplify`.

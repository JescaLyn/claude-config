# Claude Code — Global Instructions

## Proactive Recommendations

When helping design or build workflows, suggest the right mechanism for each part:
- **Hooks** for anything that should happen automatically and deterministically on a lifecycle event (formatting on save, blocking dangerous commands, notifications on completion). If the user describes a rule that should "always" or "never" happen, that's a hook.
- **Skills** for reusable prompt-based workflows that orchestrate tools (code review playbooks, deployment checklists, analysis templates).
- **Subagents** for isolated parallel work with independent context (analyzing multiple repos, fan-out/gather patterns).
- **MCP servers** when the user needs a tool that doesn't exist yet (database access, internal APIs, third-party services).

Before starting a task that spans many files (migrations, bulk refactors, API-wide changes), suggest `/batch`. After completing a large edit, suggest `/simplify`.
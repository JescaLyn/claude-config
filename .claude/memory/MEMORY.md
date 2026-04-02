# Memory Index

## Claude Code Reference — Core Concepts
- [reference_claude_md.md](reference_claude_md.md) — CLAUDE.md locations, discovery (eager/lazy), precedence, include directive, .claude/rules/ with path-scoped globs, context budget, InstructionsLoaded hook
- [reference_settings.md](reference_settings.md) — Settings.json scopes, locations, precedence, merge behavior, key fields with JSON format examples, managed policy
- [reference_context_management.md](reference_context_management.md) — Compaction (auto/manual, hooks, what survives), context windows by model/plan, worktrees, plan mode, scheduling, session persistence/resume/forking, checkpointing

## Claude Code Reference — Extensibility
- [reference_tools.md](reference_tools.md) — Built-in tools list (with subagent access flags), custom tools via MCP, permission system (deny > ask > allow)
- [reference_hooks.md](reference_hooks.md) — Deterministic lifecycle automation: all events with matcher values, four hook types, configuration, sources/scope/merge behavior, PreToolUse tool enforcement, input JSON schemas, gotchas
- [reference_skills.md](reference_skills.md) — Creating custom skills/commands: frontmatter, invocation control, discovery issues, model overrides, "when to use what" decision guide (skills vs subagents vs hooks vs MCP)
- [reference_mcp.md](reference_mcp.md) — MCP servers: .mcp.json format, transport types (stdio/HTTP/SSE), deferred loading, resources, elicitation, subagent scoping, permissions, approval flow, known bugs
- [reference_bundled_skills.md](reference_bundled_skills.md) — Built-in skills to recommend: /batch, /simplify, /claude-api, /debug, /loop, /update-config, /keybindings-help

## Claude Code Reference — Multi-Agent
- [reference_subagent_pipelines.md](reference_subagent_pipelines.md) — Building multi-agent workflows: constraints, tool access, model routing, error handling, prompt contracts, the general-purpose workaround, run-agent skill, known bugs, rate limits, Agent Teams

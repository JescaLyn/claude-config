# Memory Index

## Claude Code Reference — Core Concepts
- [reference_claude_md.md](reference_claude_md.md) — CLAUDE.md discovery, precedence, path-scoped rules, context budget, InstructionsLoaded hook
- [reference_settings.md](reference_settings.md) — Settings precedence, merge behavior, key fields and JSON examples
- [reference_context_management.md](reference_context_management.md) — Compaction, context windows, worktrees, plan mode, persistence

## Claude Code Reference — Extensibility
- [reference_hooks.md](reference_hooks.md) — Deterministic automation on lifecycle events; all events with matcher values, five hook types, configuration, sources/scope/merge behavior, PreToolUse tool enforcement, input JSON schemas, per-event constraints, gotchas
- [reference_skills.md](reference_skills.md) — Custom skill creation, invocation control, skill-to-skill composition, model overrides, known bugs
- [reference_mcp.md](reference_mcp.md) — MCP servers, .mcp.json format, transport types, deferred loading, permissions, known bugs
- [reference_tools.md](reference_tools.md) — Built-in tools, subagent access flags, MCP custom tools, permission system, deferred tool loading
- [reference_bundled_skills.md](reference_bundled_skills.md) — Bundled skills and built-in commands; /batch, /simplify, /claude-api, /debug, /loop, /update-config, /fewer-permission-prompts, /keybindings-help
- [reference_permissions.md](reference_permissions.md) — 6 permission modes, auto mode config, Bash hardening, read-only exemptions, Agent(AgentName) syntax, sandbox domains

## Claude Code Reference — Agentic Pipelines
- [reference_subagents.md](reference_subagents.md) — Built-in agents, custom agent definitions, frontmatter fields, model resolution, invocation methods, foreground/background, persistent memory, tool access, spawning workarounds for known bugs
- [reference_subagent_pipelines.md](reference_subagent_pipelines.md) — Hard constraints, concurrency/throughput, queuing modes, model routing, prompt contracts, error handling, patterns, context forking, cost management, Agent Teams, known bugs

## Claude Code Reference — Internals & Plugins
- [reference_claude_code_session_names.md](reference_claude_code_session_names.md) — Session names NOT in OTel; stored in ~/.claude/; correlate via session.id; cross-machine gap
- [reference_claude_code_feedback.md](reference_claude_code_feedback.md) — Use `/feedback` to submit bugs/features to Anthropic
- [reference_plugins.md](reference_plugins.md) — What each installed plugin does, its overhead cost, when to enable per project, how to automate new-plugin detection via SessionStart hooks
- [reference_thinking.md](reference_thinking.md) — Effort levels, defaults by plan, all controls (keyboard/ultrathink//effort/settings/frontmatter), viewing output

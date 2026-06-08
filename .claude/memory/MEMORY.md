# Memory Index

## Core Concepts
- [reference_claude_md.md](reference_claude_md.md) — CLAUDE.md discovery, precedence, path-scoped rules, context budget, InstructionsLoaded hook
- [reference_settings.md](reference_settings.md) — Settings.json scopes, locations, precedence, merge behavior, key fields, managed policy
- [reference_context_management.md](reference_context_management.md) — Compaction (auto/manual, hooks, what survives), context windows, worktrees, plan mode, scheduling, session persistence/resume/forking, checkpointing
- [reference_hook_output_behavior.md](reference_hook_output_behavior.md) — No hook can write persistent user-visible terminal text while allowing inference to continue (intentional design); full channel breakdown with confirmed behavior

## Extensibility
- [reference_hooks.md](reference_hooks.md) — Deterministic automation on lifecycle events — all events with matcher values, five hook types, config, source/scope/merge, PreToolUse enforcement, JSON schemas, per-event constraints, gotchas
- [reference_skills.md](reference_skills.md) — Custom skill creation, frontmatter fields, invocation control, skill discovery issues, and model overrides
- [reference_mcp.md](reference_mcp.md) — MCP servers — .mcp.json format, transport types, deferred loading, resources, elicitation, subagent scoping, approval flow, env vars, known bugs
- [reference_tools.md](reference_tools.md) — Built-in tools (per-tool permissions), MCP custom tools, permission system (deny > ask > allow), deferred tool loading
- [reference_builtin_commands.md](reference_builtin_commands.md) — Hardcoded Claude Code CLI commands (/clear, /compact, /config, /help, /model, /skills, etc.) — cannot be overridden by skills
- [reference_bundled_skills.md](reference_bundled_skills.md) — Bundled skills shipped with Claude Code: /batch, /claude-api, /debug, /loop, /update-config, /fewer-permission-prompts, /keybindings-help, /effort, /theme, /reload-plugins, /init, /review, /code-review, /security-review, /run, /run-skill-generator, /schedule, /verify, /claude-code-guide, /statusline-setup
- [reference_permissions.md](reference_permissions.md) — 6 permission modes, auto mode classifier config, Bash hardening, read-only exemptions, Agent(AgentName) syntax, sandbox domains, managed-only fields

## Agentic Pipelines
- [reference_subagents.md](reference_subagents.md) — Agent definition reference — frontmatter fields, model resolution, context isolation, fork mode (CLAUDE_CODE_FORK_SUBAGENT), tool access, spawning bugs; see reference_subagent_pipelines.md for orchestration
- [reference_subagent_pipelines.md](reference_subagent_pipelines.md) — Agentic pipeline orchestration — hard constraints, concurrency, queuing, model routing, prompt contracts, error handling, effort table, patterns, cost management, rate limits, Agent Teams; see reference_subagents.md for agent definitions

## Claude Code Internals
- [reference_claude_code_session_names.md](reference_claude_code_session_names.md) — User-set session names in ~/.claude/sessions/; auto-generated in JSONL; resolution priority
- [reference_claude_code_feedback.md](reference_claude_code_feedback.md) — Bug reports and feedback submission to Anthropic

## Plugins & UI
- [reference_plugins.md](reference_plugins.md) — Plugin catalog — overhead, when to enable per project, new-plugin detection via SessionStart hooks
- [reference_thinking.md](reference_thinking.md) — Effort levels, defaults by plan, all controls ($CLAUDE_EFFORT in hooks/skills), viewing thinking output

# Claude Code Config

Suggested Claude Code configuration to give Claude global knowledge of extensibility concepts -- subagents, skills, tools, hooks, etc.

## Structure

```
.claude/
├── CLAUDE.md               # Global instructions loaded into every session
├── memory/                 # Persistent reference files loaded as context
│   ├── MEMORY.md           # Index of all memory files
│   ├── reference_skills.md
│   ├── reference_hooks.md
│   ├── reference_tools.md
│   ├── reference_settings.md
│   ├── reference_subagent_pipelines.md
│   └── reference_bundled_skills.md
└── skills/
    └── run-agent/          # Skill: spawn a custom agent from .claude/agents/
        └── SKILL.md
```

## What's in here

### CLAUDE.md — Global instructions

Loaded into every Claude Code session. Contains two directives:

- **Knowledge management**: When Claude researches how Claude Code works, it saves findings to the global memory files in `~/.claude/memory/` so future sessions inherit the knowledge.
- **Proactive recommendations**: Claude suggests the right mechanism when designing workflows — hooks for deterministic automation, skills for reusable prompt workflows, subagents for parallel isolated work, MCP servers for new tool capabilities.

### Reference memory

Detailed reference files Claude can consult without web searching. Covers:

| File | Contents |
|------|----------|
| `reference_skills.md` | Creating skills/commands, frontmatter fields, invocation control, known bugs |
| `reference_hooks.md` | All lifecycle events, hook types, matcher patterns, configuration, gotchas |
| `reference_tools.md` | Built-in tools, subagent access flags, MCP tools, permission system |
| `reference_settings.md` | Settings scopes, locations, precedence, key fields |
| `reference_subagent_pipelines.md` | Multi-agent workflows, model routing, error handling, known bugs |
| `reference_bundled_skills.md` | Built-in skills to recommend: /batch, /simplify, /loop, etc. |

### Skills

**`/run-agent`** — Internal skill (not user-invocable) that spawns a custom agent defined in `.claude/agents/`. Reads the agent file, extracts the model override from frontmatter, and calls the Agent tool with the full prompt inlined. Use this instead of manually reading agent files when orchestrating multi-agent workflows.

## How it works

Claude Code loads `CLAUDE.md` from `~/.claude/` at session start. The memory files in `~/.claude/memory/` are loaded as context via the auto-memory system. Skills in `~/.claude/skills/` are discovered and made available as slash commands.

To use this config, symlink or copy `.claude/` to `~/.claude/` (or clone directly as your `~/.claude/` directory).

## Decision guide

When to use each mechanism:

- **Hook** — something that must happen automatically on a lifecycle event (format on save, block a dangerous command, notify on completion). If the rule uses "always" or "never", it's a hook.
- **Skill** — a reusable prompt-based workflow the user or Claude invokes (code review checklist, deployment playbook, analysis template).
- **Subagent** — isolated parallel work with independent context (analyzing multiple repos, fan-out/gather patterns).
- **MCP server** — a tool capability that doesn't exist yet (database access, internal APIs, third-party services).

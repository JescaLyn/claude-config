# Claude Code Config

Global Claude Code configuration that gives Claude persistent knowledge of its own extensibility — skills, subagents, agentic pipelines, hooks, settings, permissions, tools, MCP, plugins, context management, thinking, and more.

## What's Included

### Memory (`memory/`)

Reference files that load into Claude's context at session start and persist across conversations. Covers every major Claude Code extensibility surface:

- **CLAUDE.md** — discovery, precedence, path-scoped rules, context budget, InstructionsLoaded hook
- **Hooks** — lifecycle events, hook types, input schemas, blocking behavior, gotchas
- **Skills** — frontmatter fields, invocation control, discovery, model overrides, skill orchestration
- **Subagents** — agent definitions, context isolation, fork mode, tool access, spawning bugs
- **Agentic pipelines** — orchestration patterns, concurrency, model routing, error handling, rate limits
- **MCP** — configuration format, transport types, deferred loading, OAuth, subagent scoping
- **Settings** — all settings.json fields, scopes, precedence, merge behavior
- **Permissions** — permission modes, auto mode classifier, Bash hardening, sandbox configuration
- **Tools** — built-in tools with per-tool notes, permission rule formats
- **Context management** — compaction, context windows, worktrees, plan mode, scheduling, prompt cache
- **Thinking** — effort levels, all controls, `$CLAUDE_EFFORT` in hooks and skills
- **Built-in commands** — hardcoded CLI commands that cannot be overridden by skills
- **Bundled skills** — prompt-based skills that ship with Claude Code, with trigger guidance
- **Plugins** — plugin manifest capabilities, CLI commands, per-project enablement, known bugs

### Rules (`rules/`)

Global behavioral constraints loaded into every session:

| Rule | What it enforces |
|------|-----------------|
| `agents.md` | When to use direct dispatch vs pipelines; skill `context: fork`; saving named agents |
| `agentic-pipelines.md` | When to use pipelines; skill selection; execution protocol; failure handling |
| `knowledge-workflow.md` | Check memory before answering Claude Code questions; save learnings back to memory |
| `no-silent-failures.md` | Log all failures before continuing; never silently filter null or empty states |

### Skills (`skills/`)

| Skill | What it does |
|-------|-------------|
| `/run-agent` | Spawn a named agent from `.claude/agents/` or `~/.claude/agents/` with its body inlined; accepts bare names, relative, or absolute paths |
| `/run-agentic-pipeline` | Plan and execute a multi-agent pipeline end-to-end |
| `/plan-agentic-pipeline` | Design a pipeline without executing; saves as a reusable skill if the task is recurring |
| `/refresh-claude-code-reference` | Fetch current Claude Code docs and changelog, then update all reference memory files |

### Hooks (`hooks/`)

Lifecycle automation wired in `settings.json`:

| Hook | Event | What it does |
|------|-------|-------------|
| `check-slash-conflict.sh` | PreToolUse (Write, Bash) | Blocks creation of skills or commands that conflict with built-ins, bundled skills, or cross-scope customs; prompts for confirmation before allowing |
| `guard-skill-model.sh` | PreToolUse (Skill) | In long sessions, upgrades non-forked `model: sonnet` skills to the 1M context variant; warns before running `model: haiku` (no 1M variant available) |
| `restore-skill-model.sh` | PostToolUse (Skill) | Restores the original model field after `guard-skill-model.sh` temporarily patches it |

### Agents (`agents/`)

| Agent | Model | What it does |
|-------|-------|-------------|
| `agentic-pipeline-planner` | Sonnet | Designs multi-agent pipeline plans from a task description; called by `/plan-agentic-pipeline` and `/run-agentic-pipeline` |

## Get Started

Claude Code loads rules from `~/.claude/rules/`, memory from `~/.claude/memory/`, and skills from `~/.claude/skills/` at session start.

### Option A: Use as your Claude config

If you don't have an existing `~/.claude/` directory (or want to replace it):

```sh
# Clone directly as ~/.claude
git clone <repo-url> ~/.claude

# Or symlink from an existing checkout
ln -s /path/to/claude-config/.claude ~/.claude
```

### Option B: Copy into an existing Claude config

If you already have a `~/.claude/` directory, copy the contents in:

```sh
# Copy memory files (reference materials for Claude Code features)
cp -r claude-config/.claude/memory/* ~/.claude/memory/

# Copy rules (global behaviors and constraints)
cp -r claude-config/.claude/rules/* ~/.claude/rules/

# Copy skills (custom slash commands)
cp -r claude-config/.claude/skills/* ~/.claude/skills/

# Copy agents (custom agent definitions)
cp -r claude-config/.claude/agents/* ~/.claude/agents/

# Copy hooks (lifecycle automation scripts)
cp -r claude-config/.claude/hooks/* ~/.claude/hooks/
```

Then wire the hooks by merging the `hooks` block from `claude-config/.claude/settings.json` into your `~/.claude/settings.json`. The hooks reference `$HOME/.claude/hooks/`, so the scripts must live there.

If you already have a `MEMORY.md`, merge the entries from this repo's version into yours rather than overwriting it — it's an index that points to the other memory files.

# Claude Code Config

Global Claude Code configuration that gives Claude persistent knowledge of its own extensibility — subagents, skills, tools, hooks, settings, MCP, and context management.

## Setup

Clone or symlink `.claude/` to `~/.claude/`:

```sh
# Option 1: clone directly as ~/.claude
git clone <repo-url> ~/.claude

# Option 2: symlink from an existing checkout
ln -s /path/to/claude-config/.claude ~/.claude
```

Claude Code loads rules from `~/.claude/rules/` and memory files from `~/.claude/memory/` at session start. No further configuration needed.

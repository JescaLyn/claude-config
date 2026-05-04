# Claude Code Config

Global Claude Code configuration that gives Claude persistent knowledge of its own extensibility — subagents, skills, tools, hooks, settings, MCP, and context management.

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

# Copy agents (agent capability cards and identity)
cp -r claude-config/.claude/agents/* ~/.claude/agents/

# Copy skills (custom slash commands)
cp -r claude-config/.claude/skills/* ~/.claude/skills/
```

If you already have a `MEMORY.md`, merge the entries from this repo's version into yours rather than overwriting it — it's an index that points to the other memory files.

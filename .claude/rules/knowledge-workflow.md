# Knowledge Workflow

## Check MEMORY Before Answering Claude Code Questions

Before answering questions about Claude Code slash commands, shortcuts, or features from general knowledge alone:

1. Read reference file from `MEMORY.md`
2. Answer directly if it covers the question
3. Invoke the built-in `claude-code-guide` agent only if reference files missing, outdated, or incomplete

## Save Concrete Technical Facts to Memory

Save Claude Code learnings to `~/.claude/memory/`. Document:
- Commands and command syntax
- Config keys and patterns
- API patterns and endpoints

**Test**: Would this need lookup again across projects? Tool behavior and patterns qualify; project-specific facts don't. Skip ephemeral info.

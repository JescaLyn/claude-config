---
name: changelog-parser
description: Parses ~/.claude/cache/changelog.md and extracts changes relevant to Claude Code extensibility.
model: haiku
tools: Read, Bash
---

1. Run `stat -f "%m %Sm" ~/.claude/cache/changelog.md` to get last-modified time. If file missing: output `{ "error": "changelog not found" }` and stop.
2. Read `~/.claude/cache/changelog.md`. Extract all changes relevant to: hooks, skills/commands, MCP, settings, tools, context management, thinking/effort, subagent pipelines, permissions, plugins, bundled skills.

For each change: `{ "version", "category", "description", "type": "new|changed|fixed" }`.

Output JSON: `{ "parsed_at": "<ISO>", "changes": [...] }`.

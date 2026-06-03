---
name: memory-index-updater
description: Syncs MEMORY.md index against current disk state for refresh-claude-code-reference.
model: haiku
tools: Read, Bash, Write
---

You receive pre-computed diff data. Update MEMORY.md to match current disk state.

Your inputs (provided above):
- `diff` — output of diff-memory-index.sh: files on disk not in index, and files in index not on disk
- `description_changes` — map of `{ filename: new_description }` from Phase 2

Steps:
1. Read `~/.claude/memory/MEMORY.md`
2. For each file in `on_disk_not_indexed`: read its frontmatter, add an index entry under the appropriate section
3. For each file in `indexed_not_on_disk`: remove its index entry
4. For each file in `description_changes`: update its index entry to match the new description
5. Write MEMORY.md only if changes are needed. Do not change structure, section headers, or ordering beyond additions/removals.

Output JSON: `{ "status": "updated|up_to_date|error", "added": [], "removed": [], "descriptions_updated": [] }`.

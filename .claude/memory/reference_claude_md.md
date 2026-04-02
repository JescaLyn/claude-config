---
name: CLAUDE.md and instruction loading
description: CLAUDE.md locations, discovery/loading behavior (eager vs lazy), precedence, include directive, .claude/rules/ with path-scoped globs, context budget, InstructionsLoaded hook, what belongs where
type: reference
---

## All Locations

| Scope | Location | Loaded | Shared? |
|-------|----------|--------|---------|
| **Managed policy** | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md`; Linux/WSL: `/etc/claude-code/CLAUDE.md`; Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` | Eager, cannot exclude | Org-deployed |
| **User global** | `~/.claude/CLAUDE.md` | Eager | No |
| **User rules** | `~/.claude/rules/*.md` (recursive) | Eager (or lazy if `paths:` frontmatter) | No |
| **Project root** | `./CLAUDE.md` (preferred) or `./.claude/CLAUDE.md` | Eager | Yes (git) |
| **Project rules** | `./.claude/rules/*.md` (recursive) | Eager (or lazy if `paths:` frontmatter) | Yes (git) |
| **Nested subdirectory** | `subdir/CLAUDE.md` or `subdir/.claude/CLAUDE.md` | Lazy (on access) | Yes (git) |

If both `./CLAUDE.md` and `./.claude/CLAUDE.md` exist, `./CLAUDE.md` takes precedence.

## Discovery and Loading

### Eager loading (session start)
- Walks up from cwd, loading CLAUDE.md at each ancestor level
- Loads user global `~/.claude/CLAUDE.md`
- Loads managed policy (always, cannot exclude)
- Loads all `.claude/rules/*.md` files **without** `paths:` frontmatter

### Lazy loading (during session)
- **Nested traversal**: CLAUDE.md files in subdirectories below cwd load when Claude accesses files in that directory
- **Path-scoped rules**: `.claude/rules/*.md` with `paths:` frontmatter load when Claude accesses a matching file
- **Include expansion**: Files referenced via `@path/to/file` load when the importing file loads

### Reloading
- After `/compact`: all instruction files re-load fresh (load reason: `compact`)

## Precedence

All applicable CLAUDE.md files load and merge — Claude sees all of them in context. When instructions conflict, this authority hierarchy applies:

**Managed > Project > User**

Managed wins because it's enforced org policy (cannot be excluded). Project wins over User because it's scoped to the codebase you're working in. Rules files from all scopes also merge (concatenated).

### Exclusion Mechanism

Use `claudeMdExcludes` in `.claude/settings.local.json` to skip specific files:

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/path/to/parent/.claude/rules/**"
  ]
}
```

Cannot exclude managed policy. Patterns match absolute file paths via glob syntax.

### Additional Directories

The `--add-dir /path/to/other/repo` CLI flag gives Claude read/write access to directories outside the main project. By default, CLAUDE.md files in those extra directories are NOT loaded (you may add a directory just to read files, not to adopt its instructions). Set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` in your shell environment or in `settings.json` `env` field to opt into loading them.

## The Include Directive

Syntax: `@path/to/file` anywhere in a CLAUDE.md or rules file.

- Relative paths resolve relative to the importing file (not cwd)
- Absolute and tilde paths work: `@~/.claude/shared-rules.md`
- Max nesting depth: 5 hops
- Circular imports detected and prevented
- First-use triggers an approval dialog (security measure against prompt injection)
- Load reason in hooks: `include`; hook input includes `parent_file_path`

## Path-Scoped Rules (.claude/rules/)

Rules files with `paths:` frontmatter load on demand when matching files are accessed:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "tests/**/*.test.{ts,tsx}"
---

# API Rules
- All endpoints must include input validation
```

Supported glob patterns: `**/*.ts`, `src/**/*`, `*.md`, `{src,lib}/**/*.ts`, `src/**/*.{ts,tsx}`.

At startup, Claude Code reads the frontmatter of every `.md` file in `.claude/rules/` (recursively, including subdirectories) but only loads the body content of files without `paths:` frontmatter. Path-scoped rule bodies stay deferred until a matching file is accessed. Symlinks are followed (with circular detection).

Guideline: ~100–150 lines per rule file, one topic each.

## Context Budget

- CLAUDE.md files load in full regardless of length (no truncation)
- Auto-memory (`MEMORY.md`) truncates after 200 lines
- Skill descriptions get ~1% of context window (fallback: 8,000 characters); each entry capped at 250 characters. When budget is exceeded, descriptions are truncated (not dropped). Override with `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var. Skills with `disable-model-invocation: true` are excluded from the budget entirely.
- **Target**: under 200–500 lines for core CLAUDE.md
- Longer files reduce adherence and consume tokens on every turn

### Reducing context overhead
1. Split detailed instructions into `.claude/rules/` with `paths:` frontmatter
2. Move workflow-specific instructions to skills (load on-demand)
3. Use `@` imports for reference content
4. Run `/context` to inspect what's consuming space
5. Run `/mcp` to check per-server context costs

## InstructionsLoaded Hook

Fires when any CLAUDE.md or rules file loads. **Observability only — cannot block or modify loading.**

| Matcher | Fires when |
|---------|------------|
| `session_start` | Eager load at session start |
| `nested_traversal` | Accessing subdirectory with instructions |
| `path_glob_match` | File matches a rule's `paths:` glob |
| `include` | File includes another via `@` |
| `compact` | Re-load after `/compact` |

Hook input includes: `file_path`, `memory_type` (`"User"`, `"Project"`, `"Local"`, `"Managed"`), `load_reason`, `globs` (for path matches), `trigger_file_path` (for lazy loads), `parent_file_path` (for includes).

## What Belongs Where

| Need | Mechanism | Why |
|------|-----------|-----|
| Guide Claude's behavior, conventions, context | CLAUDE.md / rules | Advisory instructions Claude reads; always loaded |
| Persist knowledge across sessions | Memory (`~/.claude/memory/`) | Only MEMORY.md index loaded at startup (~200 lines); individual files loaded on demand when relevant |
| Enforce permissions, sandbox, tool access | settings.json | Hard enforcement by the client |
| Automate on lifecycle events | Hooks | Deterministic, runs outside Claude |
| Reusable workflow playbooks | Skills | Load on-demand, save context |
| Genuinely new tool capabilities | MCP servers | Extend Claude's tool set |

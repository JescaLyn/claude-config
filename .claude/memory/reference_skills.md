---
name: Creating and using skills
description: How to create custom skills/commands, frontmatter fields, invocation control, skill discovery issues, and model overrides
type: reference
---

## Commands and Skills Are the Same System

Commands have been merged into skills. Both paths work:
- `.claude/commands/foo.md` creates `/foo`
- `.claude/skills/foo/SKILL.md` creates `/foo`

If both exist with the same name, the skill takes precedence. There is no behavioral difference between a command file and a skill file with no frontmatter. Skills add optional features:
- **Directory structure** for supporting files (templates, examples, scripts)
- **Frontmatter** to control invocation, model, effort, tool access
- **Progressive loading**: only descriptions load at startup; full content loads on-demand

Use `.claude/skills/` for new work. `.claude/commands/` still works but is the legacy path.

## Invocation Control

| Frontmatter | User can invoke | Claude can invoke |
|-------------|----------------|-------------------|
| (defaults — no frontmatter) | Yes | Yes |
| `disable-model-invocation: true` | Yes | **No** |
| `user-invocable: false` | **No** (hidden from `/` menu) | Yes |

**Key frontmatter fields**: `name`, `description`, `disable-model-invocation`, `user-invocable`, `argument-hint`, `allowed-tools`, `model`, `effort`, `context` (set to `fork` for isolated execution), `agent` (which subagent type when `context: fork`).

Arguments via `$ARGUMENTS`, `$0`, `$1` placeholders. Shell substitution via `` !`command` `` (arguments interpolated before shell runs).

## Skill Discovery and the "Overlooking" Problem

Claude discovers skills via description matching, not explicit registration. Known issues:
- Skills failing to load from `~/.claude/skills/` (GitHub #25072)
- Skills loaded into context but `/skills` showing "No skills found" (GitHub #14851)
- Claude not invoking available skills when it should (GitHub #9716)

**Mitigations**:
- **Description quality is the primary lever.** Write descriptions that match what users naturally say. Include keywords.
- **System-reminder mechanism** lists available skills by name and description at session start. This helps but doesn't guarantee invocation.
- **Context budget**: skill descriptions get ~2% of context window (~16KB min). If you exceed this, some skills are excluded; `/context` will warn.
- **No way to force invocation.** Hooks can't make Claude use a skill. CLAUDE.md mentions help as reminders but invocation remains a judgment call.
- **Test with realistic requests**, not just the skill name. Iterate on descriptions until auto-invocation works reliably.

## Model Overrides

Skills, commands, and subagents all support a `model` frontmatter field that overrides the session model. Valid values: `sonnet`, `opus`, `haiku`, or a full model ID. Subagents also accept `inherit` (the default).

## When to Use What

- **User needs to trigger a workflow** -> Skill with slash command (default or `disable-model-invocation: true`)
- **Claude/orchestrator needs reusable prompt logic** -> Skill with `user-invocable: false`
- **Need isolated execution or parallel spawning** -> Subagent (Agent tool)
- **Need deterministic automation on events** -> Hook (see `reference_hooks.md` for full guide)
- **Need genuinely new tool capabilities** -> MCP server

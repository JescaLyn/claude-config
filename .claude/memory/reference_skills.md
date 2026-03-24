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
| `disable-model-invocation: true` | **No** (broken) | **No** |
| `user-invocable: false` | **No** (hidden from `/` menu) | Yes |

There is currently **no working way to make a skill user-only** (user yes, Claude no). `disable-model-invocation: true` was intended for this but blocks both user and Claude invocation (#26251, closed NOT_PLANNED). Do not use it. If you need to discourage Claude from auto-invoking, omit the field and write a description that a user would recognize but Claude is unlikely to pattern-match against. For example, instead of `description: "Review code for quality issues"` (which Claude would match any time code review comes up), use `description: "Run my team's code review checklist — invoke with /review"` — the specific action framing and explicit invocation hint target human readers without triggering Claude's auto-invocation on generic code review requests.

**Key frontmatter fields**: `name`, `description`, `disable-model-invocation`, `user-invocable`, `argument-hint`, `allowed-tools`, `model`, `effort`, `context` (set to `fork` for isolated execution), `agent` (which subagent type when `context: fork`).

**Known bug:** `allowed-tools` is not enforced at runtime. See the "`allowed-tools` Bug" section below for details and workarounds.

Arguments via `$ARGUMENTS`, `$0`, `$1` placeholders. Shell substitution via `` !`command` `` (arguments interpolated before shell runs).

## Skill Discovery and the "Overlooking" Problem

**Last verified: 2026-03-22. Bug status may have changed — check GitHub before relying on this.**

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

## `allowed-tools` Bug

**Last verified: 2026-03-22. Bug status may have changed — check GitHub before relying on this.**

The `allowed-tools` frontmatter field is parsed but **not enforced at runtime** (bugs #14956, #18837, unresolved as of 2026-03). A skill declaring `allowed-tools: [Read, Grep, Glob]` will still have access to all tools available in the conversation context.

This is a skill-specific bug — agent `tools:` restrictions work correctly when spawning native subagent types. The distinction matters:
- **Skill** `allowed-tools` → broken, no enforcement
- **Agent** `tools:` → works for native spawning, bypassed by the general-purpose workaround

**Workarounds:**
- **PreToolUse hooks** can reject tool calls that a skill shouldn't make. This is the most reliable enforcement mechanism.
- **Prompt instructions** ("You may only use Read and Grep") reduce unwanted tool use but are not hard constraints.
- If the skill runs in a forked context (`context: fork`), it becomes a subagent and the agent `tools:` field applies instead — but only for native spawning, not general-purpose.

## Model Overrides

Skills, commands, and subagents all support a `model` frontmatter field that overrides the session model. Valid values: `sonnet`, `opus`, `haiku`, or a full model ID. Subagents also accept `inherit` (the default).

## When to Use What

- **User needs to trigger a workflow** -> Skill with slash command (default invocation settings)
- **Claude/orchestrator needs reusable prompt logic** -> Skill with `user-invocable: false`
- **Need isolated execution or parallel spawning** -> Subagent (Agent tool)
- **Need deterministic automation on events** -> Hook (see `reference_hooks.md` for full guide)
- **Need genuinely new tool capabilities** -> MCP server

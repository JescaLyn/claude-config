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

## Skill Storage Locations

- **Enterprise**: Managed settings
- **Personal**: `~/.claude/skills/<skill-name>/SKILL.md`
- **Project**: `.claude/skills/<skill-name>/SKILL.md`
- **Plugin**: `<plugin>/skills/<skill-name>/SKILL.md`

## Invocation Control

| Frontmatter | User can invoke | Claude can invoke | Preloaded into subagents |
|-------------|----------------|-------------------|--------------------------|
| (defaults — no frontmatter) | Yes | Yes | Yes |
| `disable-model-invocation: true` | Yes (via `/skill`) | **No** | **No** |
| `user-invocable: false` | **No** (hidden from `/` menu) | Yes | Yes |

`disable-model-invocation: true` — only the user can invoke, description NOT in context, and skill content is NOT preloaded into subagents. Use when you want a user-only command that Claude won't auto-invoke and that shouldn't consume subagent context.

`user-invocable: false` — only Claude can invoke (hidden from slash menu), description always in context. Use for orchestration primitives that Claude should call but users shouldn't.

**Key frontmatter fields**: `name`, `description`, `argument-hint`, `arguments` (positional args for `$name` substitution), `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context` (isolated execution — see `context: fork` below), `agent` (subagent type when `context: fork`), `hooks`, `paths` (glob pattern or YAML list of globs limiting when skill activates), `shell` ("bash" (default) or "powershell" for `` !`command` `` blocks).

**String substitutions**: `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `$name`, `${CLAUDE_SESSION_ID}`, `${CLAUDE_SKILL_DIR}` (absolute path to the skill's directory), `${CLAUDE_EFFORT}` (current effort level).

Shell substitution: `` !`command` `` runs after argument interpolation. For multi-line shell output, use a fenced code block opened with ` ```! `. Disable shell execution with `disableSkillShellExecution: true` in settings.

**Cost gotcha — shell-substitution-only skills still run inference.** When a user invokes `/skill` whose body is just `` !`bash script.sh` ``, the substitution runs and the resulting bash output becomes a user message that the model still responds to. Without an explicit `model:` field, that inference falls back to the main session model (e.g. Opus). For pure dashboard / script-echo skills, set `model: haiku` + `effort: low` to keep the response cheap. `disable-model-invocation: true` does NOT skip this — it only blocks Claude's auto-invocation.

## Skill Discovery and the "Overlooking" Problem

Claude discovers skills via description matching, not explicit registration. Known issues:
- Skills failing to load from `~/.claude/skills/` (GitHub #25072, closed stale — fix unverified)
- Skills loaded into context but `/skills` showing "No skills found" (GitHub #14851, closed)
- Claude not invoking available skills when it should (GitHub #9716, **OPEN**, 69+ comments; also #51099 — Opus 4.7 ignoring skills)

**Mitigations**:
- **Description quality is the primary lever.** Write descriptions that match what users naturally say. Include keywords.
- **System-reminder mechanism** lists available skills by name and description at session start. This helps but doesn't guarantee invocation.
- **Context budget**: skill descriptions get 1% of context window, capped at 1,536 characters per entry. Exceeding the budget excludes some skills; `/context` will warn.
- **No way to force invocation.** Hooks can't make Claude use a skill. CLAUDE.md reminders help but invocation remains a judgment call.
- **Test with realistic requests**, not just the skill name. Iterate on descriptions until auto-invocation works reliably.

## `/skills` UI

The `/skills` panel includes a type-to-filter search box for finding skills by name. Pressing Enter pre-fills `/<skill-name>` in the prompt rather than closing the dialog.

## Live Change Detection

Skills created or modified in `~/.claude/skills/` or `.claude/skills/` take effect immediately within the current session — no restart needed. `--dangerously-skip-permissions` does not prompt for writes to `.claude/skills/`, `.claude/agents/`, or `.claude/commands/`.

## Skill Content on Compaction

When the conversation is compacted, the first 5,000 tokens of each previously-invoked skill are re-attached to the compacted context. All re-attached skill content shares a 25,000-token budget. Skills invoked before auto-compaction are not re-executed against the next user message.

## Behavioral Notes

### `context: fork`

`context: fork` and `agent:` frontmatter fields are supported. Skills with `context: fork` run in an isolated subagent context without conversation history. The `agent:` field specifies which subagent type (built-in: Explore, Plan, general-purpose; or custom from `.claude/agents/`), defaulting to `general-purpose`.

Plugin skills honor `context: fork` and `agent:`. Deferred tools (WebSearch, WebFetch, etc.) are available to `context: fork` subagents on their first turn.

### `allowed-tools`

Restricts the skill's own main-context calls only — does not propagate into subagents the skill spawns. For cross-context enforcement, use `settings.json` PreToolUse hooks (fire in all contexts including subagents).

## Model Overrides

Skills, commands, and subagents all support a `model` frontmatter field that overrides the session model. Valid values: `sonnet`, `opus`, `haiku`, or a full model ID. Subagents also accept `inherit` (the default).

### Hidden cost: model downgrade to Haiku or Sonnet risks context overflow (skills only)

Effective context windows per model: Opus 4.7 → 1M (auto), Opus 4.6 → 1M (auto), Sonnet 4.6 → **200K by default** (1M requires opt-in), Haiku 4.5 → 200K. A skill's `model:` override switches the session model **for the current turn only** — the session model resumes on the next prompt. But if the current conversation already exceeds the skill model's window, the harness must compact before the skill can run.

This applies to any Opus session past ~150K tokens when a non-forked Haiku or Sonnet skill is invoked — both default to 200K. Mitigation: `context: fork` for self-contained skills (most cost-optimization skills); explicit `model: claude-sonnet-4-6[1m]` in frontmatter for Sonnet skills that need parent context. Haiku has no 1M variant — compaction is unavoidable if invoked in an overflowed session.

**Subagents (`.claude/agents/`) do NOT have this problem.** They're inherently isolated — `Agent()` spawns a fresh subagent context that doesn't inherit parent conversation history, so a downgraded subagent model never squeezes the parent. Set `model:` freely on agents.

### Design rule: pair `model: haiku` with `context: fork`

If a skill's value comes from running a cheaper model on a self-contained input (review a diff, draft a commit message, summarize, classify), it almost always shouldn't need the parent conversation. Set both:

```yaml
model: haiku
context: fork
```

`context: fork` runs the skill in a fresh subagent context, so the smaller window is irrelevant — and you avoid the context overflow risk entirely. Without `fork`, `model: haiku` in a long session is a landmine.

If a skill genuinely needs parent conversation context (orchestration, follow-up work informed by prior decisions), **don't downgrade the model** — let it inherit. Either let it run on the parent's model, or spawn `Agent(model: haiku, ...)` for the cheap parts and stay on the parent model for the orchestrator.

### Usage habit

- **Long iterative Opus sessions**: past ~150K tokens, non-forked `model: haiku` and `model: sonnet` skills risk compaction. For Sonnet, use `model: claude-sonnet-4-6[1m]` in the frontmatter to prevent it. For Haiku, save state first or use a forked haiku skill.
- **Routine cost-sensitive batch work**: run Haiku as the *parent* model from the start. Then Haiku skills never trigger context overflow.
- **Quick / short sessions** (under ~150K tokens): both Haiku and Sonnet skills are harmless.
- **When auditing skills**: any `model: haiku` without `context: fork` is suspect — safe only when sessions stay short. `model: sonnet` without `context: fork` carries the same overflow risk (same 200K default). Agents (`.claude/agents/`) are never subject to this — inherently isolated.

## Skill Orchestration: Full Multi-Agent Pipelines

**Skills are full orchestrators.** Because skills run in main conversation context, they have access to the `Agent()` tool and can spawn multiple agents in parallel, collect results, validate output quality, and dispatch conditional follow-up work. This is how `/custom-review` works: stages → spawn reviewer → conditionally dispatch fixes → propose commit message.

**Hierarchy:** Skills (main context) CAN spawn agents; those agents cannot spawn further agents. See `reference_subagent_pipelines.md` for detailed subagent constraints.

**Example orchestration pattern:**
```
Skill invocation (main context):
  1. Spawn Agent(phase-1-a), Agent(phase-1-b), Agent(phase-1-c) in parallel
  2. Collect all results
  3. Validate outputs, gate on quality
  4. Spawn Agent(phase-2) with aggregated phase-1 data
  5. Return final assembled result
```

## Skill-to-Skill Composition

Skills run in main context and have access to the Skill tool, so a SKILL.md can include "then invoke /other-skill" and Claude will use the Skill tool to do so.

Subagents spawned via Agent() do not have the Skill tool. To pass skill logic into a subagent, use the `skills:` frontmatter field to preload skill content as static instructions.

## Known Bugs — ToolSearch Regression

**GitHub #47598 (OPEN).** Custom agents (`.claude/agents/`) lost access to `MCPSearch` (formerly `ToolSearch`), blocked by a hardcoded `CUSTOM_AGENT_DISALLOWED_TOOLS` list. This breaks access to deferred MCP tools in custom agents. **Workaround:** Set `ENABLE_TOOL_SEARCH=false` to force all MCP tools to load upfront (context cost), or keep total MCP tool descriptions under ~10K tokens so deferral doesn't trigger. Note: `MCPSearch` auto-mode is on by default when MCP tool descriptions exceed 10% of the context window.

## When to Use What

- **User needs to trigger a workflow** -> Skill with slash command (default invocation settings)
- **Claude/orchestrator needs reusable prompt logic** -> Skill with `user-invocable: false`
- **User-only command, never auto-invoked, not in subagent context** -> Skill with `disable-model-invocation: true`
- **Skill needs to invoke another skill** -> Include "then invoke /skill-name" in SKILL.md body; works from main context
- **Need full multi-agent orchestration (parallel fan-out, gating, sequential phases)** -> Skill that spawns multiple Agent() calls and gates on results
- **Need isolated work without orchestration overhead** -> Raw Agent() call from main context (one agent, per-task)
- **Need deterministic automation on events** -> Hook (see `reference_hooks.md` for full guide)
- **Need genuinely new tool capabilities** -> MCP server

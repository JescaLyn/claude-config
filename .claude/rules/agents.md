# Agents

## Direct Dispatch

Use for a single well-scoped task — no phases, no parallel branches.

- **Named agent exists** → `run-agent` skill (checks `.claude/agents/` then `~/.claude/agents/`, or any explicit path)
- **No named agent** → `Agent(subagent_type: "general-purpose", ...)` with a self-contained prompt

For multi-phase or parallel work, use an agentic pipeline — see `rules/agentic-pipelines.md`.

## Subagent Isolation

Named and custom agents are always isolated — `Agent(subagent_type: "my-agent")` starts a fresh context with no parent conversation history. There is no `context: fork` field for agent definitions; setting it on an AGENT.md file is a no-op.

General-purpose subagents are forks by default and inherit parent context. This affects unspecified/automatic subagent delegation, not explicit named-agent calls.

The design question for subagents is not "fork or not" — it's: **is the prompt self-contained enough for the subagent to succeed without knowing what came before?** Make sure the prompt includes all needed data (file paths, structured input, prior decisions).

## Skill Isolation: `context: fork`

`context: fork` is a **skill-only** frontmatter field. By default, skills run in the parent context (inheriting conversation history). `context: fork` makes a skill run as an isolated subagent — no parent history, flat hierarchy.

Use `context: fork` on a skill when:
- The skill is fully self-contained (all needed data fits in the prompt)
- You want to save tokens by not passing conversation history
- You're pairing with `model: haiku` (always pair these — a non-forked Haiku skill in a long session overflows)

Do not use `context: fork` on a skill that spawns further `Agent()` calls — forked skills cannot spawn subagents (flat hierarchy constraint).

## Save Useful Agents

Save a named agent when it needs non-default config: a specific model, tool restrictions, or a non-default `permissionMode`. For inline one-off tasks, use `Agent(subagent_type: "general-purpose", prompt: "...")` instead.

- **`~/.claude/agents/`** — global; useful across projects
- **`.claude/agents/`** — project-scoped; specific to one codebase

Check existing agents before creating one — don't duplicate.

---
name: Custom agent invocation pattern
description: How to spawn custom agents from .claude/agents/ — the general-purpose workaround, frontmatter extraction, prompt assembly, and parallel spawning
type: reference
---

## The Problem

Custom agents in `.claude/agents/<name>.md` define their prompt, model, and tools via frontmatter. But `subagent_type` in the Agent tool only accepts built-in types — custom agent names are not valid values. (See `reference_claude_code_extensibility.md` for the full conceptual model.)

## The Pattern

Every custom agent spawn follows the same steps:

1. **Read** `.claude/agents/<name>.md` with the Read tool.
2. **Extract** the `model` field from the YAML frontmatter.
3. **Strip** the frontmatter (opening `---`, key-value fields, closing `---`).
4. **Assemble** the prompt: the markdown body from step 3, followed by runtime arguments.
5. **Call** the Agent tool:

```
Agent(
  subagent_type: "general-purpose",
  model: <from frontmatter>,
  prompt: "<agent body>\n\nYour task: <value>"
)
```

Runtime arguments go after the agent body. Conventions vary by project:
- repo-analysis uses `Your task: <value>` plus optional extra context lines
- flowsearch uses `## Runtime Arguments` with a bulleted list

Either works. The key constraint is that the agent's own prompt body comes first, unmodified, and runtime arguments are appended.

## Parallel Spawning

When spawning multiple agents of the **same type** (e.g., 5 source-ingest runs), read the agent file once and reuse the prompt body across all Agent calls. Only the runtime arguments vary.

When spawning agents of **different types** in parallel (e.g., crossref-planner + corpus-index-builder), read both agent files first, then issue all Agent calls in a single message.

## The `run-agent` Skill

The `run-agent` skill (`~/.claude/skills/run-agent/SKILL.md`) automates steps 1–4 above — it reads the agent file and inlines the prompt. Useful for one-off spawns from the main conversation. But skills run in conversation context and **cannot run in parallel**, so orchestrators that need concurrent agent execution must implement the pattern manually via the Agent tool.

## What Orchestrator Commands Need

A command that dispatches custom agents (like `/analyze-repos` or `/flowsearch`) needs:
- Access to the `Agent`, `Read`, and `Bash` tools (at minimum)
- An "Agent Spawning" or equivalent section documenting the pattern above
- The `model: haiku` frontmatter (dispatchers do mechanical work, not analysis)
- Explicit instructions to use `subagent_type: "general-purpose"` — without this, the dispatcher will try to use the agent name as `subagent_type` and it will silently fall back to a built-in agent with different instructions

## Quirks

- The `run-agent` skill takes the agent name as its argument (no `.md` extension, no path). Passing `--help` or invalid names makes it try to read `.claude/agents/--help.md`.
- Agent files' `tools` frontmatter field defines what tools the agent *should* have, but when spawning via `general-purpose`, the spawned agent gets the full general-purpose toolset. The tools field is informational for the orchestrator, not enforced.
- Subagents cannot spawn other subagents. If an agent needs sub-dispatch, it must be a skill or command instead.

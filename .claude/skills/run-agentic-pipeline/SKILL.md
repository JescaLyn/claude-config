---
name: run-agentic-pipeline
description: "Run a complex task end-to-end using agentic pipeline orchestration. Plans then executes. Use when task has parallel independent work, multiple phases, or user says 'use agents/subagents'. Triggers on: 'spawn agents', 'use subagents', 'agentic pipeline', independent parallel branches."
user-invocable: true
model: sonnet
---

## Task

$ARGUMENTS

## Steps

### 1. Inventory + complexity

```bash
bash ~/.claude/skills/plan-agentic-pipeline/scripts/plan-agents.sh "$ARGUMENTS"
```

### 2. Plan

Invoke `/run-agent agentic-pipeline-planner` with task:
```
TASK: $ARGUMENTS

AVAILABLE_AGENTS: <script output>

TEMPLATE: <pipeline template if provided, else omit>
```
Parse the JSON plan from planner output before proceeding.

### 3. Execute phases

For each phase in `plan.phases` (in order):

- **Spawn agents in parallel** — one `Agent()` call per agent in the phase, all in one message. Pass each agent's `model` from the plan (`effort` is frontmatter-only, not a call parameter). Pass `isolation: "worktree"` on each call if agents in this phase write to overlapping file paths; skip it if they are read-only or write to disjoint paths.
- **Collect all outputs** before starting the next phase.
- **Validate each output**: non-empty, matches expected `output_format`. On failure, retry once with narrower scope. Log: `"Agent <name> failed in phase <phase>: <error>; retrying with narrower scope."` If retry fails, log and continue with partial output.
- **Pass phase outputs** as context into the next phase's agent prompts.

Execution constraints:
- Run at maximum concurrency — Claude Code queues excess automatically. Scale back only if 429s appear.
- On 429: halve concurrency, wait for retry-after, then resume.
- If >50% of agents in a phase fail: halt immediately and surface failure details to user.
- On any agent status failure: spot-check expected output files before treating as truly failed (subagents can report "failed" even when work completed).

### 4. Save pipeline (if reusable)

If `plan.reusable` is true, save to `~/.claude/skills/<plan.name>/SKILL.md`:
- Frontmatter: `name`, `description`, `user-invocable: true`, `model: sonnet`
- Body: phase structure parameterized via `$ARGUMENTS`
- No agent prompts inline — reference agents by name

### 5. Return results

Assemble and return outputs from all phases. Include: summary of what each phase produced, any partial failures logged, and pipeline save path if applicable.

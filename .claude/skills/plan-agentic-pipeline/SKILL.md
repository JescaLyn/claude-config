---
name: plan-agentic-pipeline
description: "Plan a multi-agent pipeline for a complex task. Spawns isolated planner agent, returns structured plan. Saves as pipeline skill if reusable."
user-invocable: true
model: sonnet
---

## Task

$ARGUMENTS

## Steps

1. **Run inventory script.**
   ```bash
   bash ~/.claude/skills/plan-agentic-pipeline/scripts/plan-agents.sh "$ARGUMENTS"
   ```
   Captures: available agents, saved pipeline skills, complexity tier.

2. **Spawn planner agent** via `/run-agent agentic-pipeline-planner` with task:
   ```
   TASK: $ARGUMENTS

   AVAILABLE_AGENTS: <script output>

   TEMPLATE: <pipeline template if provided, else omit>
   ```

3. **If `plan.reusable` is true**, save the pipeline as an invocable skill:
   - Path: `~/.claude/skills/<plan.name>/SKILL.md`
   - Frontmatter: `name`, `description`, `user-invocable: true`, `model: sonnet`
   - Body: phase structure with `$ARGUMENTS` as the parameterization point
   - No agent prompts inline — reference agents by name

4. **Return plan summary** to user: phase structure, agent count, model tiers, reusability decision.

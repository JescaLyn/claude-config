# Agentic Pipelines

## When to Use a Pipeline

- Task has parallel independent work
- Multiple distinct phases with handoffs
- Cross-cutting concerns (review + fix + commit, analyze + generate + validate)
- More than 2 interdependent steps
- User says: "agents", "subagents", "spawn agents", "parallel", "orchestrate", "coordinate"

For a single well-scoped task needing isolated context, use **direct dispatch** instead — see below.

## Pipeline Skill Selection

1. **Exact skill match** → invoke that skill directly with `$ARGUMENTS`
2. **Near-match needing structural change** → invoke `/run-agentic-pipeline` with existing pipeline as template
3. **Arguments mismatch only** → invoke existing pipeline with adjusted `$ARGUMENTS`
4. **No match** → invoke `/run-agentic-pipeline` fresh

Never orchestrate ad-hoc when `/run-agentic-pipeline` covers the case.

## Direct Dispatch

Use when the task is a single well-scoped job — no phases, no parallel branches.

- **Named agent exists** → `run-agent` skill from `~/.claude/agents/`
- **No named agent** → `Agent(subagent_type: "general-purpose", ...)` with a self-contained prompt

## Skill Reference

- `/plan-agentic-pipeline` — design pipeline only; saves as skill if reusable
- `/run-agentic-pipeline` — plan + execute end-to-end (default choice)
- `/saved-pipeline-name` — invoke a previously saved pipeline skill directly
- `/run-agent` — spawn a named agent from `~/.claude/agents/`

## Execution Protocol

1. Issue all Agent calls per phase in parallel
2. Collect results before next phase
3. Feed phase output into next phase as orchestration notes describe
4. If subagent fails or returns empty, log it (agent, task, error), then retry once with narrower scope
5. Save reusable agents to `~/.claude/agents/`, reusable pipelines as skills to `~/.claude/skills/`

## Scaling: Mega-Bundling vs One-Per-Item

When a phase has many independent items (N > concurrency cap), do **not** spawn N agents. Bundle them: each agent processes ⌈N / cap⌉ items sequentially. Spawn `cap` mega-agents in parallel.

**How:** Pass tasks as `BUNDLE: <item-1>, <item-2>, ...`. Agent loops internally, writes per-item outputs, returns a manifest. Cap per-agent bundle size (e.g., 5–15 items) so a single agent can't run forever.

## Failure Categorization

Agents return a structured `STATUS:` line. Orchestrator categorizes at three layers:

- **Per-item:** `RATE_LIMITED` / `TOOL_ERROR` / `EMPTY` → log and continue.
- **Per-batch:** if rate-limited > 25% of batch → sleep 60–90s, halve concurrency for next batch, restore on a clean batch.
- **Pipeline-wide halt:** `STATUS: HALT` or raw `authentication_error` / `quota_exceeded` / `model not found` → abort, surface exact error.

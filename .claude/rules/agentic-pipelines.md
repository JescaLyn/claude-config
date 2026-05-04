# Agentic Pipelines

## When to Use a Pipeline

- Task has parallel independent work
- Multiple distinct phases with handoffs
- Cross-cutting concerns (review + fix + commit, analyze + generate + validate)
- More than 2 interdependent steps
- User says: "agents", "subagents", "spawn agents", "parallel", "orchestrate", "coordinate"

For a single well-scoped task, use **direct dispatch** — see `rules/agents.md`.

## Pipeline Skill Selection

1. **Exact skill match** → invoke that skill directly with `$ARGUMENTS`
2. **Near-match needing structural change** → invoke `/run-agentic-pipeline` with existing pipeline as template
3. **Arguments mismatch only** → invoke existing pipeline with adjusted `$ARGUMENTS`
4. **No match** → invoke `/run-agentic-pipeline` fresh

Never orchestrate ad-hoc when `/run-agentic-pipeline` covers the case.

## Skill Reference

- `/plan-agentic-pipeline` — design pipeline only; saves as skill if reusable
- `/run-agentic-pipeline` — plan + execute end-to-end (default choice)
- `/saved-pipeline-name` — invoke a previously saved pipeline skill directly
- `/run-agent` — spawn a named agent; checks `.claude/agents/` then `~/.claude/agents/`, or any explicit path

## Execution Protocol

1. Issue all Agent calls per phase in parallel — no artificial cap; Claude Code queues excess automatically. Scale back only if 429s appear.
2. Collect results before next phase.
3. Feed phase output into next phase as orchestration notes describe.
4. If subagent fails or returns empty, log it (agent, task, error), then retry once with narrower scope.
5. Save reusable pipelines as skills to `~/.claude/skills/`.

## Scaling: One-Per-Item vs Mega-Bundling

**Default: spawn one agent per item.** This is maximum concurrency — minimum wall-clock time.

Bundle only when N exceeds ~20. Choose bundle count so that: (a) no more than 20 agents run concurrently, and (b) each bundle stays under max-bundle-size (5–15 items) to bound agent runtime. For N ≤ 20: one agent per item. For N > 20: `bundle_count = ceil(N / max-bundle-size)`, capped at 20 unless max-bundle-size forces more.

**How:** Pass tasks as `BUNDLE: <item-1>, <item-2>, ...`. Agent loops internally, writes per-item outputs, returns a manifest.

## Failure Handling

- **Per-item retryable errors** → log and continue. Retry once with narrower scope.
- **>25% of batch rate-limited** → halve concurrency, wait for retry-after header, then resume.
- **Auth/quota/model errors** → abort immediately, surface exact error to user.
- **Status failure with complete-looking output** → spot-check output files before treating as failed. Subagents can report "failed" even when work completed.

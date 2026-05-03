---
name: Building agentic pipelines
description: Hard constraints, concurrency/throughput, queuing modes, model routing, prompt contracts, error handling, effort config, patterns (mega-agent bundling, dispatch-evaluate-refine, quality loop, frozen snapshot), context forking, cost management, known bugs, rate limits, Agent Teams
type: reference
---

## Hard Constraints

- **Flat hierarchy**: subagents cannot spawn subagents. One orchestrator + N workers only. Skills and main-context agents are orchestrators; spawned subagents are workers. See `reference_skills.md` for skill orchestration patterns.
- **Each subagent gets its own context window**, independent of the parent. Size is model and plan dependent (200K default for Sonnet/Opus, 1M for Opus on Max/Team/Enterprise).
- **Startup overhead**: each subagent loads CLAUDE.md, MCP schemas (connected in parallel), and system prompt. Reduce by stripping unused MCP servers and irrelevant context.
- **Subagents cannot communicate with each other.** All coordination routes through the orchestrator. (Exception: Agent Teams research preview — see "Agent Teams" section.)
- **Agentic pipelines consume significantly more tokens** than single-agent sessions.
- **Unavailable tools**: `Agent` (flat hierarchy), `Skill` (main-conversation-only), `TodoWrite` (main-conversation-only). All other tools inherited by default.

## Concurrency & Throughput

**Default strategy:** Build pipelines to run at maximum capacity. Do not artificially limit concurrency based on community estimates. Claude Code queues excess tasks automatically; dispatch agents aggressively and let the system manage queue. Validated on Max 20x; lower-tier subscribers should scale back if 429s appear.

**Real-world validation** (Max 20x subscription):
- **20 concurrent agents** executed successfully with 0 timeouts and 100% success rate
- Tested at scale with mega-agent bundling (10-30 items per agent) to maintain continuous token flow

**Rate limits exist but unencountered.** Limits are subscription-tier dependent and opaque (5-hour rolling window, weekly active-hours cap). Use `/usage` to monitor.

## Queuing Modes

- **Dynamic queue-pulling** (at the concurrency cap with many queued tasks): starts new tasks as slots free. A slow task does not block other slots.
- **Explicit batch mode** (orchestrator sends a fixed number of Agent calls per message, below the cap): all tasks in a batch must complete before the next batch starts. Wall-clock time = slowest task in the batch.

Choose dynamic when tasks vary in duration. Choose explicit batches when you need gate validation between phases.

## Model Routing

Sonnet, Opus, and Haiku have separate rate limit pools at the model family level. Versions within a family share a pool (e.g., Opus 4.6 and Opus 4.5 share the Opus pool). Routing subagents across families lets you draw from independent pools in parallel.

- **Haiku**: file walks, grep, dependency scanning, config extraction, structured data extraction, any deterministic read-only work
- **Sonnet**: code analysis, security review, structured reasoning, multi-step extraction
- **Opus**: synthesis, judgment, credibility assessment, final report generation. Use sparingly; significantly more expensive than Sonnet.

## Error Handling

1. **Validate subagent output before consuming it.** Check non-empty, expected format, requested information present. Do not assume success.
2. **On failure:** retry once with narrower scope. If retry fails, log and skip.
3. **On rate limit errors (429):** reduce parallelism by half, switch remaining work to sequential, wait before resuming. Do not retry immediately.

**Retryable per-item errors (raw text):** `rate_limit_exceeded`, `429`, `overloaded_error`, `529`, `Stream idle timeout`, `5xx` — log and continue.
**Pipeline-wide halt (raw text):** `authentication_error`, `401`, `quota_exceeded`, `402`, `invalid_request_error.*model not found` — abort, surface exact error.
4. **Keep return payloads lean.** Return decisions and findings, not logs. Enforce output format in the prompt: "Return ONLY [format]. No explanation, no markdown, no preamble."

## Prompt Contracts

Every subagent prompt must specify:
1. **Exact task scope** — what to do, what files/paths to examine
2. **Output format** — JSON schema, markdown template, or explicit structure
3. **Output length constraint** — scale to task type. For extraction/scanning workers: "respond in under 500 tokens." For synthesis/report agents: set a word ceiling appropriate to the task.
4. **Explicit exclusions** — tell the subagent what is out of scope to prevent it from wandering

## Subagent Frontmatter Fields

Key fields for custom agent configs (`.claude/agents/<name>.md`):

- `tools`: Restrict tool access (e.g., `tools: Read Grep Edit`)
- `model`: Route by task complexity (`haiku` for mechanical, `sonnet` for analytical, `opus` for synthesis)
- `effort`: Per-agent effort override (see Effort Configuration below)
- `skills`: Preload skills into the subagent. Sources: `from-user` (global `~/.claude/skills/`) or `from-project` (`.claude/skills/`).

## Effort Configuration

See `reference_thinking.md` for levels, defaults by plan, and Haiku limitations.

- Set `effort: low` for mechanical/extraction work regardless of model.
- Set `effort: medium` for analytical work. Only go higher if quality visibly suffers.
- Reserve `effort: high` or `max` for final synthesis where reasoning depth directly affects output quality.
- In `settings.json` the key is `effortLevel`; in subagent/skill frontmatter it is `effort`.

## Patterns

### Mega-Agent Bundling (Production-Validated Pattern)

When processing many items (50+ repos, 100+ files, 1000+ tasks), avoid one-agent-per-item. Instead, bundle items into agents:
- Each agent processes 10-30 items sequentially within its context window
- Spawn multiple bundled agents in parallel (up to concurrency cap)
- Each agent loads system prompt, CLAUDE.md, MCP schemas once; processes all bundled items with that context

**Context efficiency:** Bundling amortizes startup overhead. One agent processing 40 repos = 1× startup cost (shared across 40 items). Forty individual agents = 40× startup cost. Bundling is more context-efficient than individual agents, not less. Stream idle timeouts are prevented by maintaining continuous token flow over 5-10 minute duration per agent.

**Example:** 118 repos, 3 concurrent Opus analyzers = each handles 39-40 repos = 3× startup cost. One-per-item = 118 agents = 118× startup cost, hits concurrency cap or timeout.

**When to use:** Large datasets (50+), multi-model parallel phases, timeout-risk environments. **When NOT to use:** Small batches (<10 items), when items require isolation for security/privacy, when items are computationally independent with no shared context.

### DISPATCH-EVALUATE-REFINE Loop

Use for agents that need iterative exploration or refinement without upfront context waste.

**Sequence:**
1. DISPATCH: Fan out work or execute initial pass (reconnaissance, initial retrieval, first draft)
2. EVALUATE: Collect results, assess coverage, identify gaps
3. REFINE: Dispatch targeted follow-up work on exactly those gaps
4. Repeat EVALUATE-REFINE up to 3 cycles
5. Finalize and write output

**Why:** Prevents expensive broad sweeps upfront when targeted exploration would suffice.

### Quality Loop (Reviewer Feedback)

Use for outputs that must meet a quality bar.

**Sequence:**
1. Spawn initial agent (writer, analyzer, coder)
2. Spawn reviewer agent with clear pass/fail criteria
3. If PASS → finalize, if FAIL → revise with specific gaps in context
4. Re-review. Max 2 review cycles.
5. Exit on PASS or max cycles.

**Criteria format:** Structured PASS/FAIL + gap list (e.g., "FAIL: missing architecture section; too few concrete examples; <500 words").

**Why:** Catches shallow output early. Explicit gap feedback is more efficient than generic re-do requests.

### Frozen Snapshot State

Use when multiple parallel agents need access to shared state that may be written by the orchestrator.

**Problem:** Agent A reads shared file → Orchestrator updates it → Agent B reads it → Agent C reads inconsistent state.

**Solution:** Read once at dispatch time. Pass all needed state as prompt context, not file references.

**Trade-off:** Less fresh data, but eliminates race conditions. Use when pipeline moves data sequentially through stages.

## Context Forking

**Question: does the agent need outer context to do its job correctly?**

- **Can the agent succeed with only its explicit data handoff?** → Fork. Saves tokens.
- **Does it need outer conversation context, reasoning chains, or prior decisions to avoid redoing work?** → Don't fork. Inheriting context is cheaper than allowing the agent to make uninformed decisions and requiring re-work.

The criterion is total token cost, not local scope. Forking is only an optimization if it doesn't cause the agent to make mistakes that require correction later.

**Examples:**
- ✅ Fork: plan-agents generates structured plan → phase-1 agent reads plan → phase-2 agent reads phase-1 output. Each has what it needs in its handoff; no prior context needed.
- ❌ Don't fork: flowsearch evidence-weigher must reference prior findings and reasoning to update a Bayesian ledger correctly. Without that context, it would start fresh and miss coherence.

**Worktree isolation:** Use `isolation: worktree` in frontmatter to give a subagent an isolated git worktree copy of the repo. The worktree is auto-cleaned if no changes are made. For external builds, forked subagents can be enabled via `CLAUDE_CODE_FORK_SUBAGENT=1`.

## Cost Management

- Use `/usage` before and after pipeline execution. Log the delta.
- Use `/compact` and `/clear` between pipeline runs to prevent context accumulation.
- If Haiku subagents are failing and being re-run on Sonnet, track whether model routing is actually saving budget.
- Strip unused MCP servers before pipeline runs. Define MCP servers inline in the subagent's `mcpServers` frontmatter field rather than globally.

## Known Issues and Rate Limits

### Subscription Rate Limits

Rate limits are subscription-tier dependent. They govern requests per minute (RPM), input tokens per minute (ITPM), and output tokens per minute (OTPM). Build pipelines to maximize concurrency—test at full capacity and scale back only if limits are hit.

**If you encounter a rate limit error:**
- Look for HTTP 429 status code or messages like "API Error: Rate limit reached", "You've hit your session limit", or "You've hit your weekly limit"
- The error includes a `retry-after` header indicating wait time
- Reduce parallelism by half, switch remaining work to sequential, wait for the retry-after duration, then resume
- Retry once to confirm if the limit persists

**Real-world validation:** Max 20x subscription tested with 20 concurrent agents, 0 timeouts, 100% success rate. Lower tiers may need to reduce parallelism faster.

### Known Bugs

**`classifyHandoffIfNeeded` false failures.** Confirmed across multiple GitHub issues (#23307, #24181, #22087, #22573, #22312, #22544, #22469). Subagents report "failed" even when all work completed successfully. Occurs after task completion, not during. Workaround: spot-check expected output files, git log, and returned content. If spot-checks pass, treat as success.

**Custom agent discovery failures.** Agents in `.claude/agents/` are not reliably discovered at session start. Agents do not hot-reload mid-session. Discovery failure produces an explicit error, not silent degradation.

**Custom agent body not injected** (#13627, CLOSED NOT_PLANNED). Even when discovery works, the markdown body of agent files is not passed to spawned subagents. The agent gets correct model and tools but generic behavior. This is why the general-purpose workaround is required (see "Spawning Custom Agents" above).

**Skill discovery failures.** Skills may fail to load from `~/.claude/skills/` (#25072), show "No skills found" despite correct config (#14851), or not be invoked when relevant (#9716). Mitigations in `reference_skills.md`.

**ToolSearch blocked for custom agents.** Custom agents in `.claude/agents/` cannot use `ToolSearch` (#47598, OPEN). This blocks deferred MCP tool access. Workaround: `ENABLE_TOOL_SEARCH=false` forces upfront loading, or keep MCP tool descriptions under ~10K tokens.

### Agent Teams

Available in research preview (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Teammates can message each other, claim tasks from a shared list, and coordinate without routing through the orchestrator. Use `SendMessage({to: agentId})` to resume stopped agents. Consumes significantly more tokens than standard subagents. Known limitations: no session resumption for in-process teammates, task status lag, one team per session, no nested teams. Use subagents when tasks are independent and report-back-only; use Agent Teams when subtasks need inter-agent communication.

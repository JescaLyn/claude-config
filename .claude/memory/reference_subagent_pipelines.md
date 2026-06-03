---
name: Building agentic pipelines
description: Agentic pipeline orchestration — hard constraints (flat hierarchy, no subagent-to-subagent), concurrency/throughput, queuing modes, model routing by task type, self-contained prompt contracts, error handling, effort config table, patterns (mega-agent bundling, dispatch-evaluate-refine, quality loop, frozen snapshot), worktree isolation, cost management, rate limits, Agent Teams. Use this to design and run multi-agent workflows; see reference_subagents.md for agent definition and frontmatter reference.
type: reference
---

## Hard Constraints

- **Flat hierarchy**: subagents cannot spawn subagents. One orchestrator + N workers only. Skills and main-context agents are orchestrators; spawned subagents are workers. See `reference_skills.md` for skill orchestration patterns.
- **Each subagent gets its own context window**, independent of the parent. Size is model and plan dependent (200K default for Sonnet/Opus, 1M for Opus on Max/Team/Enterprise).
- **Startup overhead**: each subagent loads CLAUDE.md, MCP schemas (connected in parallel), and system prompt. Reduce by stripping unused MCP servers and irrelevant context. Subagents inherit MCP tools from dynamically-injected servers (servers added at runtime, not just those configured at session start).
- **Subagents cannot communicate with each other.** All coordination routes through the orchestrator. (Exception: Agent Teams research preview — see "Agent Teams" section.)
- **`subagent_type` matching** is case- and separator-insensitive (e.g., `'Code Reviewer'` resolves to `'code-reviewer'`).
- **Agent identity** is tracked via `agent_id` and `parent_agent_id` in OTEL spans and API request headers (`x-claude-code-agent-id` / `x-claude-code-parent-agent-id`).
- **Agentic pipelines consume significantly more tokens** than single-agent sessions.
- **Unavailable tools**: `Agent` (flat hierarchy), `TodoWrite` (main-conversation-only). All other tools inherited by default. Subagents can use the `Skill` tool and will find project, user, and plugin skills correctly.
- **Stall timeout**: subagents that stall mid-stream fail with a clear error after 10 minutes instead of hanging silently.

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

- **Haiku + `effort: low`**: file walks, grep, dependency scanning, config extraction, structured data extraction, any deterministic read-only work. Always pair with `effort: low` — without it, Haiku still runs extended thinking and wastes tokens on mechanical work.
- **Sonnet + `effort: medium`**: code analysis, security review, structured reasoning, multi-step extraction.
- **Opus + `effort: high`**: synthesis, judgment, credibility assessment, final report generation. Use sparingly; significantly more expensive than Sonnet.

## Error Handling

1. **Validate subagent output before consuming it.** Check non-empty, expected format, requested information present. Do not assume success.
2. **On failure:** retry once with narrower scope. If retry fails, log and skip.
3. **On rate limit errors (429):** reduce parallelism by half, switch remaining work to sequential, wait before resuming. Do not retry immediately.

**Retryable per-item errors (raw text):** `rate_limit_exceeded`, `429`, `overloaded_error`, `529`, `Stream idle timeout`, `5xx` — log and continue.
**Pipeline-wide halt (raw text):** `authentication_error`, `401`, `quota_exceeded`, `402`, `invalid_request_error.*model not found` — abort, surface exact error.
4. **Keep return payloads lean.** Return decisions and findings, not logs. Enforce output format in the prompt: "Return ONLY [format]. No explanation, no markdown, no preamble."

**Parallel tool call isolation:** A failing Bash call cancels its siblings. Read, WebFetch, Glob, and other read-only shell commands do not cascade — a failing read-only call leaves sibling calls running. When `gh` commands hit GitHub's API rate limit, the Bash tool surfaces a backoff hint so agents can pause instead of retrying blindly.

## Prompt Contracts

Every subagent prompt must specify:
1. **Exact task scope** — what to do, what files/paths to examine
2. **Output format** — JSON schema, markdown template, or explicit structure
3. **Output length constraint** — scale to task type. For extraction/scanning workers: "respond in under 500 tokens." For synthesis/report agents: set a word ceiling appropriate to the task.
4. **Explicit exclusions** — tell the subagent what is out of scope to prevent it from wandering

## Foreground vs Background Execution

- **Foreground** (default): shows permission prompts; runs synchronously.
- **Background** (`isolate: true`): no prompts; tools requiring user approval are auto-denied; runs asynchronously.

**Background session lifecycle:** Pinned sessions (`Ctrl+T` in `claude agents`) stay alive when idle, are restarted in place to apply Claude Code updates, and are shed under memory pressure only after non-pinned sessions. Completion notifications include elapsed duration (e.g., "Agent completed · 3h 2m 5s"). Empty idle background sessions left over from navigation are automatically retired by the daemon after 5 minutes. Rename a background session with `Ctrl+R`; the attached session's banner updates immediately.

**`worktree.bgIsolation: "none"` setting:** Lets background sessions edit the working copy directly without `EnterWorktree`, for repos where worktrees are impractical.

## Subagent Frontmatter Fields

Agent files live at `~/.claude/agents/<agent-name>.md` (personal) or `.claude/agents/<agent-name>.md` (project). Key frontmatter fields:

**Tool inheritance rules:** Setting `tools` gives the subagent *only* those tools. Setting `disallowedTools` removes specific tools from the full inherited set. If both are set, `disallowedTools` takes precedence. If neither is set, the subagent inherits all parent tools.

- `tools`: Restrict tool access to a specific list (e.g., `tools: Read Grep Edit`)
- `disallowedTools`: Remove specific tools from the inherited set
- `permissionMode`: Override to a stricter permission mode for this subagent
- `model`: Route by task complexity — see Model Routing section above
- `effort`: Per-agent effort override (see Effort Configuration below)
- `maxTurns`: Bound execution length (default unlimited)
- `preloadSkills`: Inject skills at startup. Sources: `from-user` (global `~/.claude/skills/`) or `from-project` (`.claude/skills/`)
- `preloadScripts`: Inject scripts at startup

Built-in agent types: `general-purpose` (inherits all parent tools), `coder`, `explore` (read-only: Glob/Grep/Read/LSP only), `plan` (design approach, same tools as Explore), `research`.

Parent deny rules always apply regardless of subagent frontmatter.

## Effort Configuration

See `reference_thinking.md` for levels, defaults by plan, and Haiku limitations.

| Task type | Model | Effort |
|-----------|-------|--------|
| File walks, grep, extraction, config parsing | `haiku` | `low` |
| Code analysis, reasoning, multi-step extraction | `sonnet` | `medium` |
| Synthesis, judgment, final reports | `opus` | `high` |

- `effort: low` suppresses thinking entirely. Omit it and Haiku still incurs thinking tokens on mechanical work.
- The table shows default pairings. `effort: low` applies to any mechanical task regardless of model.
- Only raise above `medium` if output quality visibly suffers.
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

## Prompt Self-Containment (Subagents Are Always Isolated)

Subagents in Claude Code are inherently isolated — `Agent()` creates a fresh context every time. The subagent never sees the parent conversation. So the design question isn't "fork or not fork"; it's **"is my prompt self-contained enough for the subagent to succeed?"**

For pipeline design, every Agent prompt must include:
- All file paths, structured input, and prior outputs the subagent will reference
- The orchestrator's framing of the goal (not just the local task)
- Constraints, format expectations, and what "done" looks like

**Examples:**
- ✅ Self-contained: plan-agents generates structured plan → phase-1 agent receives plan + task spec → phase-2 agent receives plan + phase-1 output. Each subagent's prompt carries everything it needs.
- ❌ Insufficient: spawning an "evidence-weigher" with just a new claim, expecting it to remember prior weighing decisions. Without explicit handoff of the prior ledger state in the prompt, it starts fresh and breaks coherence. Fix by passing the ledger snapshot in the prompt.

**When a subagent genuinely needs parent conversation history** (rare): enable fork mode with `CLAUDE_CODE_FORK_SUBAGENT=1`. A fork is a subagent that inherits the parent's full conversation, system prompt, tools, and model — the opposite of normal subagent isolation. Works in non-interactive sessions (SDK and `claude -p`). Forks replace the general-purpose subagent type when fork mode is on. See `reference_subagents.md` for full mechanics.

**Worktree isolation:** Pass `isolate: worktree` to `Agent()` (or set in frontmatter) to give a subagent an isolated git worktree copy of the repo. Auto-cleaned if no changes are made; stale worktrees left behind by interrupted parallel runs are also automatically cleaned up. Useful for parallel agents that might write to overlapping paths.

## Cost Management

- Use `/usage` before and after pipeline execution. Log the delta.
- Set `effort: low` on all Haiku agents. Without it in frontmatter, Haiku inherits the session effort level and incurs thinking tokens even for file walks.
- Use `/compact` and `/clear` between pipeline runs to prevent context accumulation.
- If Haiku subagents are failing and being re-run on Sonnet, track whether model routing is actually saving budget.
- Strip unused MCP servers before pipeline runs. Define MCP servers inline in the subagent's `mcpServers` frontmatter field rather than globally.

## Known Issues and Rate Limits

### Subscription Rate Limits

Rate limits are subscription-tier dependent. They govern requests per minute (RPM), input tokens per minute (ITPM), and output tokens per minute (OTPM). Build pipelines to maximize concurrency — test at full capacity and scale back only if limits are hit.

**If you encounter a rate limit error:**
- Look for HTTP 429 status code or messages like "API Error: Rate limit reached", "You've hit your session limit", or "You've hit your weekly limit"
- The error includes a `retry-after` header indicating wait time
- Reduce parallelism by half, switch remaining work to sequential, wait for the retry-after duration, then resume
- Retry once to confirm if the limit persists

**Real-world validation:** Max 20x subscription tested with 20 concurrent agents, 0 timeouts, 100% success rate. Lower tiers may need to reduce parallelism faster.

### Known Bugs

**`classifyHandoffIfNeeded` false failures.** Confirmed across multiple GitHub issues (#23307, #24181, #22087, #22573, #22312, #22544, #22469). Subagents report "failed" even when all work completed successfully. Occurs after task completion, not during. Workaround: spot-check expected output files, git log, and returned content. If spot-checks pass, treat as success.

**Custom agent discovery failures.** Agents in `.claude/agents/` are not reliably discovered at session start. Agents do not hot-reload mid-session. Discovery failure produces an explicit error, not silent degradation.

**Custom agent body not injected.** The markdown body of agent files is silently ignored when spawning via `subagent_type`. Read the agent file, strip the frontmatter, and include the body manually in the `Agent()` prompt. Use the agent's registered name as `subagent_type` to preserve tool restrictions. See `reference_subagents.md` → Spawning Custom Agents.

**Skill discovery in main context.** Skills may fail to load from `~/.claude/skills/` (#25072) or show "No skills found" despite correct config (#14851) in the main conversation context. Subagents using the `Skill` tool correctly find project, user, and plugin skills. Mitigations in `reference_skills.md`.

**ToolSearch blocked for custom agents.** Custom agents in `.claude/agents/` cannot use `ToolSearch` (#47598). This blocks deferred MCP tool access. Workaround: `ENABLE_TOOL_SEARCH=false` forces upfront loading, or keep MCP tool descriptions under ~10K tokens.

### Agent Teams

Available in research preview (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Teammates can message each other, claim tasks from a shared list, and coordinate without routing through the orchestrator. Use `SendMessage({to: agentId})` to resume stopped agents. `CLAUDE_CODE_SUBAGENT_MODEL` applies to teammate processes. Consumes significantly more tokens than standard subagents. Known limitations: no session resumption for in-process teammates, task status lag, one team per session, no nested teams. Use subagents when tasks are independent and report-back-only; use Agent Teams when subtasks need inter-agent communication.

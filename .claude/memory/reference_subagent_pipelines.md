---
name: Building multi-agent pipelines
description: Everything needed to build subagent workflows — constraints, tool access, model routing, error handling, prompt contracts, effort config, the general-purpose workaround, run-agent skill, cost management, known bugs, rate limits, Agent Teams
type: reference
---

## Hard Constraints

- **Max concurrent subagents**: not officially documented. Community estimates range from 3-10 depending on subscription plan. Do not implement your own queue; excess tasks queue automatically.
- **Flat hierarchy**: subagents cannot spawn subagents. One orchestrator + N workers only. (Confirmed in official docs.)
- **Each subagent gets its own context window**, independent of the parent (confirmed in official docs). Size depends on model and plan: 200K default for Sonnet/Opus, 1M for Opus on Max/Team/Enterprise plans. Haiku uses its standard window.
- **Startup overhead**: each subagent loads CLAUDE.md, MCP schemas, and system prompt. No official token count; stripping unused MCP servers and irrelevant context reduces overhead.
- **Subagents cannot communicate with each other.** All coordination routes through the orchestrator.
- **Multi-agent workflows consume significantly more tokens** than single-agent sessions (no official multiplier; depends heavily on task).
- **Unavailable tools**: `Agent` (flat hierarchy), `Skill` (main-conversation-only), `TodoWrite` (main-conversation-only). All other tools inherited by default.

## Subagent Tool Access

- Restrict with `tools:` (allowlist) or `disallowedTools:` (denylist) in frontmatter. If both set, denylist applies first. Both are officially documented.
- **`tools:` IS enforced at runtime** when the agent is spawned natively (i.e., its name is a valid `subagent_type`). It is a structural filter on tool definitions, not a prompt hint.
- **The general-purpose workaround bypasses tool restrictions.** When spawning via `Agent(subagent_type: "general-purpose", ...)`, the agent gets all general-purpose tools regardless of what the original agent file declares. This is the key tradeoff: general-purpose gives you custom prompt injection but loses tool enforcement. Use PreToolUse hooks for hard enforcement when using general-purpose.
- Subagents cannot call skills programmatically, but skills can be preloaded into their context via the `skills` frontmatter field (injected as instructions, not invoked via Skill tool).
- MCP tools are inherited by default. Scope with `mcpServers` frontmatter: define servers inline (scoped to that subagent) or reference by name (reuses existing config).
- **Skill `allowed-tools` is currently broken** (bugs #14956, #18837, unresolved as of 2026-03). It appears in frontmatter reference but is not enforced at execution time. This is a skill-specific bug; agent `tools:` works correctly for native spawning.

**Hooks for pipelines:** Use PreToolUse hooks to enforce tool restrictions on general-purpose subagents. Use prompt/agent hooks for semantic validation (e.g., checking subagent output quality before the orchestrator consumes it). Use SubagentStop hooks to post-process or log results. Full hooks reference in `reference_hooks.md`.

## Spawning Custom Agents

Custom agents in `.claude/agents/` have two known issues that affect how they must be spawned:

1. **Discovery is unreliable** (#11205, canonical open bug). Agent files may not be discovered at session start, especially in VS Code (#24439). Discovery failure produces an explicit error listing available agents — it is not silent.
2. **Body content not injected** (#13627, closed NOT_PLANNED). Even when discovery works and the agent name is a valid `subagent_type`, the markdown body (custom prompt) is not passed to the spawned subagent. The agent gets the correct model and tools but generic behavior.

Because of Bug 2, **always use the general-purpose workaround** for custom agents that have meaningful prompt content:

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

Runtime arguments go after the agent body. The agent's own prompt body comes first, unmodified.

**Tradeoff:** The general-purpose workaround gives you custom prompt injection but loses the agent file's `tools:` restrictions (the spawned agent gets all general-purpose tools). If tool enforcement matters, add PreToolUse hooks or use the `--agents` CLI flag (see below).

**Alternative: `--agents` CLI flag.** Defining agents inline at session start via `claude --agents '{...}'` avoids both bugs — discovery is guaranteed and the `prompt` field is injected correctly. Agents defined this way also enforce `tools:` restrictions. Downside: requires session setup and JSON agent definitions, not `.md` files.

**Parallel spawning:** When spawning multiple agents of the same type, read the agent file once and reuse the prompt body across all Agent calls. When spawning different types in parallel, read all agent files first, then issue all Agent calls in a single message.

**The `run-agent` skill** (`~/.claude/skills/run-agent/SKILL.md`) is a user-created skill that automates steps 1–4 above via shell substitution. Useful for one-off spawns from the main conversation. Skills run in conversation context and cannot run in parallel, so orchestrators needing concurrent execution must use the Agent tool directly.

**For automated dispatchers** (commands that dispatch agents without human oversight): always use the general-purpose workaround. Do not attempt native `subagent_type` spawning — the dispatcher cannot detect Bug 2's silent prompt loss, and Bug 1's discovery failures vary by session.

## Queuing Modes

- **Dynamic queue-pulling** (at the concurrency cap with many queued tasks): starts new tasks as slots free. A slow task does not block other slots.
- **Explicit batch mode** (orchestrator sends a fixed number of Agent calls per message, below the cap): all tasks in a batch must complete before the next batch starts. Wall-clock time = slowest task in the batch.

Choose dynamic when tasks vary in duration. Choose explicit batches when you need gate validation between phases.

## Model Routing

Sonnet, Opus, and Haiku have separate rate limit pools at the model family level (officially documented). However, versions within a family share a pool (e.g., Opus 4.6 and Opus 4.5 share the Opus pool). Routing subagents across families lets you draw from independent pools in parallel.

- **Haiku**: file walks, grep, dependency scanning, config extraction, structured data extraction, any deterministic read-only work
- **Sonnet**: code analysis, security review, structured reasoning, multi-step extraction
- **Opus**: synthesis, judgment, credibility assessment, final report generation. Use sparingly; significantly more expensive than Sonnet.

## Error Handling

1. **Validate subagent output before consuming it.** Check non-empty, expected format, requested information present. Do not assume success.
2. **On failure, retry once with a narrower task scope** (fewer files, smaller input, simpler question). If the retry also fails, log the failure and continue without that output. Do not retry more than once.
3. **On rate limit errors (429):** reduce parallelism by half, switch remaining work to sequential, wait before resuming. Do not retry immediately.
4. **Keep return payloads lean.** Return decisions and findings, not logs. Enforce output format in the prompt: "Return ONLY [format]. No explanation, no markdown, no preamble."

## Prompt Contracts

Every subagent prompt must specify:
1. **Exact task scope** — what to do, what files/paths to examine
2. **Output format** — JSON schema, markdown template, or explicit structure
3. **Output length constraint** — scale to task type. For extraction/scanning workers: "respond in under 500 tokens." For synthesis/report agents: set a word ceiling appropriate to the task.
4. **Explicit exclusions** — tell the subagent what is out of scope to prevent it from wandering

## Effort Configuration

The `effort` frontmatter field controls adaptive thinking depth (Opus 4.6, Sonnet 4.6). Options: `low`, `medium`, `high`, `max` (Opus only). Haiku 4.5 does not support extended thinking. Confirmed in official docs.

- Set `effort: low` for mechanical/extraction work regardless of model.
- Set `effort: medium` for analytical work. Only go higher if quality visibly suffers.
- Reserve `effort: high` or `max` for final synthesis where reasoning depth directly affects output quality.
- In `settings.json` the key is `effortLevel`; in subagent/skill frontmatter it is `effort`.

## Cost Management

- Use `/cost` before and after pipeline execution. Log the delta.
- Use `/compact` and `/clear` between pipeline runs to prevent context accumulation.
- If Haiku subagents are failing and being re-run on Sonnet, track whether model routing is actually saving budget.
- Strip unused MCP servers before pipeline runs. Define MCP servers inline in the subagent's `mcpServers` frontmatter field rather than globally.

## Known Issues and Rate Limits

**Last verified: 2026-03-22. Content in this section is volatile — verify before acting on it.**

### Subscription Rate Limits (community-estimated, not official)

Limits are opaque, usage-based, governed by a 5-hour rolling window plus a weekly active-hours cap. Cannot be inspected programmatically. Use `/stats` to check usage patterns.

**Pro ($20/mo):** 3 Sonnet, 4-5 Haiku, 0-1 Opus in parallel. Do not plan around Opus on Pro.
**Max 5x ($100/mo):** 4-5 Sonnet, 6-8 Haiku, 1-2 Opus. Parallel fan-out with synthesis gate is viable.
**Max 20x ($200/mo):** 5-6 Sonnet, 8-10 Haiku, 2-3 Opus.

When in doubt, start conservative and scale up.

### Known Bugs

**`classifyHandoffIfNeeded` false failures.** Confirmed across multiple GitHub issues (#23307, #24181, #22087, #22573, #22312, #22544, #22469). Subagents report "failed" even when all work completed successfully. Occurs after task completion, not during. Workaround: spot-check expected output files, git log, and returned content. If spot-checks pass, treat as success.

**Custom agent discovery failures** (#11205, canonical open bug; duplicates: #8256, #5289, #9366, #4547, #5185, #8697, #18212, #20931). Agents in `.claude/agents/` are not reliably discovered at session start. VS Code extension does not recognize custom agents at all (#24439). Agents do not hot-reload mid-session (#5738). Discovery failure produces an explicit error, not silent degradation.

**Custom agent body not injected** (#13627, closed NOT_PLANNED). Even when discovery works, the markdown body of agent files is not passed to spawned subagents. The agent gets correct model and tools but generic behavior. This is why the general-purpose workaround is required (see "Spawning Custom Agents" above).

**Skill `allowed-tools` not enforced** (#14956, #18837). The `allowed-tools` field in skill frontmatter is parsed but has no runtime effect. See `reference_skills.md`.

**Skill discovery failures.** Skills may fail to load from `~/.claude/skills/` (#25072), show "No skills found" despite correct config (#14851), or not be invoked when relevant (#9716). Mitigations in `reference_skills.md`.

### Experimental: Agent Teams

**Last verified: 2026-03-22. Feature is in research preview — status may have changed.**

Available in research preview (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, Claude Code v2.1.32+). Teammates can message each other, claim tasks from a shared list, and coordinate without routing through the orchestrator. Model mixing is supported (no longer Opus-only; any model can be assigned per teammate). Consumes significantly more tokens than standard subagents. Known limitations: no session resumption with in-process teammates, task status can lag, one team per session, no nested teams, lead is fixed. Use subagents when tasks are independent and report-back-only; use Agent Teams when subtasks need inter-agent communication.

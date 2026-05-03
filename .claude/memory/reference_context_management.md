---
name: Context management and session lifecycle
description: Compaction (auto/manual, hooks, what survives), context windows by model/plan, worktrees, plan mode, scheduling (/loop, /schedule, cron tools), /clear vs /compact, session persistence/resume/forking, checkpointing
type: reference
---

## What Claude Sees vs. Doesn't

HTML block comments (`<!-- ... -->`) are stripped from all instruction files (CLAUDE.md, rules, agents, skills) before injection to the model. Visible when reading files with the Read tool, invisible to Claude during normal operation. Useful for annotating files with metadata or maintainer notes.

## Context Compaction

### /compact
Summarizes conversation history, replacing full transcript with a condensed version (~5–10% of original). A 70K-token conversation compresses to ~4K tokens.

- Run with focus: `/compact focus on X` to prioritize preserving specific context
- CLAUDE.md and rules re-load fresh after compaction (load reason: `compact`)
- Key intent, direction, and conclusions preserved; detailed tool outputs and early instructions may be lost

### Auto-compaction
Triggers automatically when context fills up. Clears older tool outputs first, then summarizes if needed. Circuit breaker stops retrying after 3 consecutive failures.

**Skill reattachment after compaction**: the most recently invoked skills are re-attached automatically — first 5,000 tokens each, 25,000-token combined budget. Skill character budget scales with context window (2% of context), so larger context windows surface more skill descriptions without truncation.

**Best practice**: put persistent rules in CLAUDE.md, not conversation history — they survive compaction.

### Hooks

Hook output over 50K characters is saved to disk with a file path + preview instead of being injected directly into context.

| Hook | Matcher values | Can block? | Key input fields |
|------|---------------|------------|------------------|
| **PreCompact** | `manual`, `auto` | Yes (exit code 2 cancels compaction) | `trigger`, `custom_instructions` |
| **PostCompact** | `manual`, `auto` | No | `trigger`, `compact_summary` |
| **SessionStart** | `compact` | No | `source: "compact"` — fires when session resumes after compaction; can inject `additionalContext` via `hookSpecificOutput` |
| **InstructionsLoaded** | (no matcher) | No | Fires when CLAUDE.md or `.claude/rules/*.md` files are loaded into context |

## /clear vs /compact

| Aspect | /clear | /compact |
|--------|--------|----------|
| **Effect** | Wipes all conversation history | Summarizes and condenses |
| **Context preserved** | None | Intent, key conclusions (~5–10%) |
| **Token footprint after** | Near-zero | ~4K from a 70K conversation |
| **Cost** | Free (immediate) | Spends tokens on summarization |
| **When to use** | Fresh start, context pollution | Long sessions, retain learnings |

## Context Windows

| Model | Default | Extended |
|-------|---------|----------|
| **Opus 4.7** | 200K | 1M (Max, Team, Enterprise, API) |
| **Opus 4.6** | 200K | 1M (Max, Team, Enterprise, API) |
| **Sonnet 4.6** | 200K | 1M (Max plan; extra usage on Pro/API) |
| **Haiku 4.5** | 200K | N/A |

On Max/Team/Enterprise plans, Opus auto-upgrades to 1M with no configuration. Use `/context` to inspect current usage. Set `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` to opt out of 1M context support.

## Git Worktrees

### CLI flag
`claude --worktree` (or `-w`) starts Claude in an isolated worktree at `<repo>/.claude/worktrees/<name>` with branch `worktree-<name>`. Auto-named if omitted.

### Cleanup behavior
- **No changes made**: worktree and branch removed automatically on exit
- **Changes exist**: Claude prompts to keep or remove; keeping preserves directory and branch

### Sparse checkout
`worktree.sparsePaths` setting limits checkout to specified directories in large monorepos, using git sparse-checkout. Example: `worktree.sparsePaths: ["src/api", "packages/auth"]`.

### Subagent isolation
`isolation: "worktree"` on the Agent tool (or agent definition) gives each subagent its own worktree for parallel work without file conflicts. Auto-cleaned when subagent finishes without changes. Worktrees left behind after interrupted parallel runs are also cleaned up automatically.

### Worktree hooks
- **WorktreeCreate**: fires when worktree created; can provide custom creation logic (supports non-git VCS)
- **WorktreeRemove**: fires on cleanup

### /batch and worktrees
`/batch` uses worktree isolation internally — spawns 5–30 parallel agents in isolated worktrees, each opening a PR.

## Plan Mode

Read-only permission mode: Claude reads files, runs exploratory shell commands, asks questions, writes plans — but cannot edit source code.

**Activate**: `Shift+Tab` (cycle modes), `claude --permission-mode plan`, or prefix with `/plan`.

**When to use**: multi-step implementation planning, code exploration before changes, iterating on direction before committing to edits.

Permission prompts for Bash/network still appear as in default mode — plan mode only restricts file edits.

**"Clear context" on plan accept**: hidden by default. Restore with `"showClearContextOnPlanAccept": true` in settings.

## Scheduling

### Session-scoped: /loop
`/loop [interval] [prompt]` — runs a prompt on a recurring interval while the session stays open.

- Interval syntax: `30m`, `2h`, `5m check status`; defaults to 10 minutes
- Can loop over other commands: `/loop 20m /review-pr 1234`
- Session-scoped: closing terminal cancels everything
- No catch-up for missed fires; fires once when idle
- **3-day expiry**: recurring tasks auto-delete after 3 days
- **Jitter**: up to 10% of period late (capped at 15 min)

### Underlying tools
- **CronCreate**: schedule task (5-field cron expression, prompt, recurrence flag)
- **CronList**: list all tasks with IDs
- **CronDelete**: cancel by ID
- Limit: 50 scheduled tasks per session

### Cloud-scheduled: /schedule (Routines)
Runs on Anthropic-managed cloud infrastructure. Manage at `claude.ai/code/routines`.

**Three trigger types:**
- **Schedule**: cron-based; hourly/daily/weekdays/weekly presets; custom cron via `/schedule update`; minimum 1-hour interval
- **API trigger**: per-routine HTTP endpoint + bearer token; POST to `/fire` endpoint with optional `text` body; returns session ID + URL. Under `experimental-cc-routine-2026-04-01` beta header.
- **GitHub trigger**: reacts to `pull_request` or `release` events; requires Claude GitHub App on repo; filter by author, title, labels, draft state, branch, or regex.

Available on Pro, Max, Team, Enterprise with Claude Code on web enabled. Research preview status. Runs without permission prompts — scope via repositories, environment, and connectors.

**Features:** exit confirmation for one-shot tasks; `/resume` can restart scheduled tasks; stuck task notifications after ~45s.

### Desktop-scheduled
Via Claude desktop app; minimum 1-minute interval; requires app running.

## Session Persistence and Resume

### Storage
Sessions saved as `.jsonl` files in `~/.claude/projects/`, organized by directory hash. Default cleanup: 30 days (`cleanupPeriodDays` setting).

`cleanupPeriodDays` now also covers `~/.claude/tasks/`, `~/.claude/shell-snapshots/`, and `~/.claude/backups/` — not just session files.

**`cleanupPeriodDays: 0`** is now rejected with a validation error (previously silently disabled transcript persistence). Use `99999` to preserve indefinitely.

### Resume commands
- `claude --continue` — most recent conversation in current directory (also finds sessions that added the current dir via `/add-dir`)
- `claude --resume` — interactive picker
- `claude --resume session-name` — by name/ID
- `claude --from-pr 123` — sessions linked to a PR

`/resume` and `--resume` on large sessions offer to summarize stale sessions before re-reading them. Large session load is significantly faster (up to 67% on 40MB+ sessions).

### /recap
Provides a context summary when returning to a session after being away. Configurable in `/config`; invoke manually with `/recap`. Force-enable with `CLAUDE_CODE_ENABLE_AWAY_SUMMARY` env var if telemetry is disabled.

### Naming
- At startup: `claude -n auth-refactor`
- During session: `/rename auth-refactor`
- From picker: navigate to session, press `R`

### Forking
`claude --continue --fork-session` or `claude --resume abc123 --fork-session` — new session ID, full history preserved, original unchanged. Useful for trying different approaches.

### Session picker shortcuts
`↑↓` navigate, `→←` expand/collapse, `Enter` select, `P` preview, `R` rename, `/` search, `A` toggle all projects, `B` filter to current branch, `Esc` exit.

### Independence
Each new session starts with fresh context — no history from previous sessions. Cross-session persistence via auto-memory (first 200 lines of MEMORY.md) and CLAUDE.md.

Session-scoped permissions are NOT inherited on resume.

## Checkpointing

Every file edit is snapshotted before applying. Local to session, separate from git. Press `Esc` twice to rewind, or ask Claude to undo. Only covers file changes — not remote system actions.

## Context Monitoring

**Startup token budget** (approximate, before first prompt):
| Component | Tokens | Notes |
|-----------|--------|-------|
| System prompt | ~4,200 | Auto-loaded, invisible |
| Auto memory (MEMORY.md) | ~680 | First 200 lines / 25KB |
| Environment info | ~280 | Auto-loaded |
| MCP tool definitions | ~120 | Deferred by default via `ToolSearch`; `ENABLE_TOOL_SEARCH=auto` loads upfront when within 10% of context; `=false` loads all upfront |
| Skill descriptions | ~450 | Auto-loaded at startup |
| **Total** | **~8K+** | Before first prompt |

- `/context` — inspect what's consuming context space
- `/mcp` — per-server context costs
- `/usage` — token usage and spend (merged from `/cost` and `/stats`; both still work as shortcuts to the relevant tab)
- MCP tool definitions: deferred by default, loaded on demand via `ToolSearch`
- Skills: descriptions visible at session start; full content loads only on invocation; re-attached after auto-compaction (5K tokens/skill, 25K combined budget)
- Subagents get independent context windows — their work doesn't bloat parent

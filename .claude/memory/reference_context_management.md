---
name: Context management and session lifecycle
description: Compaction (auto/manual, hooks, what survives), context windows by model/plan, worktrees, plan mode, scheduling (/loop, /schedule, cron tools), /clear vs /compact, session persistence/resume/forking, checkpointing
type: reference
---

## Context Compaction

### /compact
Summarizes conversation history, replacing full transcript with a condensed version (~5–10% of original). A 70K-token conversation compresses to ~4K tokens.

- Run with focus: `/compact focus on X` to prioritize preserving specific context
- CLAUDE.md and rules re-load fresh after compaction (load reason: `compact`)
- Key intent, direction, and conclusions preserved; detailed tool outputs and early instructions may be lost

### Auto-compaction
Triggers automatically when context fills up. Clears older tool outputs first, then summarizes if needed.

**Best practice**: put persistent rules in CLAUDE.md, not conversation history — they survive compaction.

### Hooks

| Hook | Matcher values | Can block? | Key input fields |
|------|---------------|------------|------------------|
| **PreCompact** | `manual`, `auto` | No (can perform side effects) | `trigger`, `custom_instructions` |
| **PostCompact** | `manual`, `auto` | No | `trigger`, `compact_summary` |
| **SessionStart** | `compact` | No | `source: "compact"` — fires when session resumes after compaction; can inject `additionalContext` via `hookSpecificOutput` |

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
| **Opus 4.6** | 200K | 1M (Max, Team, Enterprise, API) |
| **Sonnet 4.6** | 200K | 1M (Max, Team, Enterprise, API) |
| **Haiku 4.5** | 200K | N/A |

On Max/Team/Enterprise plans, Opus auto-upgrades to 1M with no configuration. Use `/context` to inspect current usage.

## Git Worktrees

### CLI flag
`claude --worktree` (or `-w`) starts Claude in an isolated worktree at `<repo>/.claude/worktrees/<name>` with branch `worktree-<name>`. Auto-named if omitted.

### Cleanup behavior
- **No changes made**: worktree and branch removed automatically on exit
- **Changes exist**: Claude prompts to keep or remove; keeping preserves directory and branch

### Subagent isolation
`isolation: "worktree"` on the Agent tool gives each subagent its own worktree for parallel work without file conflicts. Auto-cleaned when subagent finishes without changes.

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

### Cloud-scheduled: /schedule
Runs on Anthropic infrastructure via claude.ai/code:
- Survives machine restarts
- Minimum 1-hour interval
- Configurable repository/branch permissions
- MCP integrations via connectors

### Desktop-scheduled
Via Claude desktop app; minimum 1-minute interval; requires app running.

## Session Persistence and Resume

### Storage
Sessions saved as `.jsonl` files in `~/.claude/projects/`, organized by directory hash. Default cleanup: 30 days (`cleanupPeriodDays` setting).

**Known bug**: `cleanupPeriodDays: 0` disables transcript writing entirely (#23710). Use `99999` to preserve indefinitely.

### Resume commands
- `claude --continue` — most recent conversation in current directory
- `claude --resume` — interactive picker
- `claude --resume session-name` — by name/ID
- `claude --from-pr 123` — sessions linked to a PR

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

- `/context` — inspect what's consuming context space
- `/mcp` — per-server context costs
- `/cost` — token usage and spend
- Skills load descriptions only at startup; full content loads on invocation
- Subagents get independent context windows — their work doesn't bloat parent

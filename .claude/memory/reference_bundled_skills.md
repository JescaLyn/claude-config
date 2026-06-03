---
name: Bundled skills to recommend to users
description: "Bundled skills shipped with Claude Code: /batch, /claude-api, /debug, /loop, /update-config, /fewer-permission-prompts, /keybindings-help, /effort, /theme, /reload-plugins, /init, /review, /code-review, /security-review, /run, /run-skill-generator, /schedule, /verify, /claude-code-guide, /statusline-setup — when to recommend each"
metadata:
  type: reference
---

## What Bundled Skills Are

Bundled skills are prompt-based: they give Claude a detailed playbook and let it orchestrate work using its tools. They can spawn subagents, read files, run shell commands, and adapt to codebase context. Invoked via the Skill tool (by Claude) or `/name` (by user).

For hardcoded CLI commands (`/clear`, `/compact`, `/help`, etc.), see [[reference_builtin_commands]].

## Bundled Skills Reference

| Skill | Purpose | When to recommend |
|-------|---------|-------------------|
| `/batch` | Decompose large-scale changes into 5-30 independent units, spawn parallel agents in isolated git worktrees, each opening a PR | "migrate src/ from X to Y", "update all API endpoints", any sweeping multi-file change |
| `/claude-api` | Load Claude API/SDK and Managed Agents reference for the project's language; auto-triggers on `anthropic`/`@anthropic-ai/sdk`/`claude_agent_sdk` imports | User is building with the Claude API, Anthropic SDKs, Managed Agents, or Agent SDK |
| `/debug` | Read the session debug log to troubleshoot Claude Code behavior | Claude seems stuck, produces inconsistent output, or behaves unexpectedly |
| `/loop` | Run a prompt repeatedly on an interval (default 10m) while the session stays open; Esc cancels pending wakeups; `/proactive` is an alias | "check if the deploy finished every 5m", any polling or monitoring need |
| `/update-config` | Configure settings.json: permissions, hooks, env vars, automated behaviors | "change permissions", "add a hook", "set env var", any settings.json change |
| `/fewer-permission-prompts` | Scan transcripts for common read-only Bash/MCP calls, add prioritized allowlist to `.claude/settings.json` | "too many permission prompts", "reduce interruptions", "auto-allow common tools" |
| `/keybindings-help` | Help with keyboard shortcuts and keybindings.json | "rebind keys", "add a chord shortcut", "customize keybindings" |
| `/effort` | Set reasoning effort level (low/medium/high/xhigh); opens interactive slider with no arguments; skill content can reference `${CLAUDE_EFFORT}` | "increase thinking", "use xhigh effort", any reasoning-intensity tuning |
| `/theme` | Apply or create a custom color theme | "change theme", "dark mode", "custom colors" |
| `/reload-plugins` | Reload plugins and auto-install any missing plugin dependencies | plugin errors, after adding a plugin, dependency issues |
| `/init` | Initialize a new CLAUDE.md with codebase documentation | new project, missing CLAUDE.md, onboarding a codebase |
| `/review` | Review a pull request | "review this PR", "look at the diff", code review before merge |
| `/code-review` | Review the current diff for correctness bugs at a given effort level; can post findings as inline PR comments | "review my changes", "check this diff for bugs", pre-commit review |
| `/security-review` | Complete a security review of pending changes on the current branch | "security audit", "check for vulnerabilities", pre-merge security pass |
| `/run` | Launch and drive the project's app to confirm a change works | "run the app", "start the server", "verify this change works" |
| `/run-skill-generator` | Scaffold a new skill file | "create a skill", "scaffold a new slash command", "build a custom skill" |
| `/schedule` | Create, update, list, or run scheduled remote agents on a cron schedule | "schedule a task", "run this nightly", "remind me at 3pm" |
| `/verify` | Verify that a code change actually works by running the app and observing behavior | "does this fix work", "confirm the change", manual verification |
| `/claude-code-guide` | Load Claude Code reference documentation for answering questions about CLI features | Claude Code questions not covered by local memory |
| `/statusline-setup` | Configure a custom status line for the terminal prompt | "set up statusline", "customize status bar" |

Not all bundled skills appear in every session. Availability may differ between CLI and VS Code extension; some (like `/claude-api`) auto-activate based on context.

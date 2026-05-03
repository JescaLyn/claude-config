---
name: Bundled skills to recommend to users
description: "Bundled skills and built-in commands: /batch, /simplify, /claude-api, /debug, /loop, /update-config, /fewer-permission-prompts, /keybindings-help, /effort, /theme, /reload-plugins — when to recommend each"
type: reference
---

## Bundled Skills vs Built-in Commands

**Built-in commands** (`/clear`, `/compact`, `/config`, `/usage`, `/help`, `/model`, `/context`, `/memory`, `/permissions`, `/settings`, `/hooks`, `/skills`, etc.) are fixed-logic operations hardcoded into the CLI. They cannot be customized and do not use the Skill tool. `/skills` has a type-to-filter search box. `--dangerously-skip-permissions` skips write prompts for `.claude/skills/`, `.claude/agents/`, and `.claude/commands/`.

**Bundled skills** are prompt-based: they give Claude a detailed playbook and let it orchestrate work using its tools. They can spawn subagents, read files, run shell commands, and adapt to codebase context. Invoked via the Skill tool (by Claude) or `/name` (by user).

## Bundled Skills Reference

| Skill | Purpose | When to recommend |
|-------|---------|-------------------|
| `/batch` | Decompose large-scale changes into 5-30 independent units, spawn parallel agents in isolated git worktrees, each opening a PR | "migrate src/ from X to Y", "update all API endpoints", any sweeping multi-file change |
| `/simplify` | Spawn 3 review agents in parallel to check recently changed files for reuse, quality, and efficiency issues, then apply fixes | After significant code changes; Claude may auto-offer this |
| `/claude-api` | Load Claude API/SDK reference for the project's language; auto-triggers on `anthropic`/`@anthropic-ai/sdk`/`claude_agent_sdk` imports | User is building with the Claude API, Anthropic SDKs, or Agent SDK |
| `/debug` | Read the session debug log to troubleshoot Claude Code behavior | Claude seems stuck, produces inconsistent output, or behaves unexpectedly |
| `/loop` | Run a prompt repeatedly on an interval (default 10m) while the session stays open | "check if the deploy finished every 5m", any polling or monitoring need |
| `/update-config` | Configure settings.json: permissions, hooks, env vars, automated behaviors | "change permissions", "add a hook", "set env var", any settings.json change |
| `/fewer-permission-prompts` | Scan transcripts for common read-only Bash/MCP calls, add prioritized allowlist to `.claude/settings.json` | "too many permission prompts", "reduce interruptions", "auto-allow common tools" |
| `/keybindings-help` | Help with keyboard shortcuts and keybindings.json | "rebind keys", "add a chord shortcut", "customize keybindings" |
| `/effort` | Set reasoning effort level (low/medium/high/xhigh); opens interactive slider with no arguments; skill content can reference `${CLAUDE_EFFORT}` | "increase thinking", "use xhigh effort", any reasoning-intensity tuning |
| `/theme` | Apply or create a custom color theme | "change theme", "dark mode", "custom colors" |
| `/reload-plugins` | Reload plugins and auto-install any missing plugin dependencies | plugin errors, after adding a plugin, dependency issues |

Not all bundled skills appear in every session. Availability may differ between CLI and VS Code extension; some (like `/claude-api`) auto-activate based on context.

---
name: Built-in CLI commands reference
description: Hardcoded Claude Code CLI commands (/clear, /compact, /config, /help, /model, /skills, etc.) — fixed operations that cannot be overridden by skills
metadata:
  type: reference
---

## What Built-in Commands Are

Built-in commands are fixed-logic operations hardcoded into the Claude Code CLI. They cannot be customized, overridden by a skill, or invoked via the Skill tool. `/skills` has a type-to-filter search box.

For prompt-based skills that ship with Claude Code, see [[reference_bundled_skills]].

## Known Built-in Commands

| Command | Purpose |
|---------|---------|
| `/add-dir` | Add a directory to the current session's context |
| `/bg` | Detach session to background; preserves `--mcp-config`, `--settings`, `--add-dir`, `--plugin-dir`, and permission mode |
| `/clear` | Clear the conversation |
| `/code-review` | Review the current diff for correctness bugs at a chosen effort level (e.g., `/code-review high`); pass `--comment` to post findings as inline GitHub PR comments |
| `/compact` | Compact context (summarize and compress) |
| `/config` | Open Claude Code settings |
| `/context` | Show context window usage |
| `/diff` | Show a diff view; scrollable with arrow keys, `j`/`k`, `PgUp`/`PgDn`, `Space`, `Home`/`End` |
| `/doctor` | Diagnose configuration issues, including plugin conflicts |
| `/exit` / `/quit` | End the session |
| `/fast` | Toggle fast mode (Opus with faster output); toggle again to disable |
| `/feedback` | Submit a bug or feature request to Anthropic |
| `/help` | Show help |
| `/hooks` | View and manage hooks |
| `/login` | Authenticate |
| `/logout` | Sign out |
| `/memory` | Manage memory files |
| `/model` | Change the active model for the current session only; press `d` in the model picker to set a default for new sessions |
| `/permissions` | View and manage tool permissions |
| `/plugin` | Browse, install, enable, disable, and uninstall plugins; shows projected context cost per plugin in the marketplace browse pane, and LSP servers a plugin provides in the details pane |
| `/resume` | Resume a session; background sessions appear with `bg` label and keep their model |
| `/settings` | Open settings panel |
| `/skills` | Browse available skills (includes type-to-filter search) |
| `/status` | Show session and connection status |
| `/upgrade` | Upgrade Claude Code |
| `/usage` | Show token/cost usage |
| `/usage-credits` | Show usage credits; `/extra-usage` also works |
| `/version` | Show Claude Code version |
| `/web-setup` | Configure web/GitHub App integration; warns before replacing an existing GitHub App connection |

`--dangerously-skip-permissions` skips write prompts for `.claude/skills/`, `.claude/agents/`, and `.claude/commands/`.

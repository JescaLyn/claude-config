---
name: run-agent
description: Spawn a custom agent from .claude/agents/ with its prompt inlined. Falls back to ~/.claude/agents/ for global agents. Accepts any path (absolute, relative, or bare name). Use instead of manually reading agent files.
user-invocable: false
---

Spawn an Agent using the configuration below.

Resolve the agent file path:
- If `$0` starts with `/`, `./`, or `../` — use it as-is (explicit path, e.g. a skill's nested agent)
- Otherwise — check `.claude/agents/$0.md` first (project agent), then `~/.claude/agents/$0.md` (global agent)

**Agent file:** (resolved path above)
**Model:** !`case "$0" in /*|./*|../*) f="$0";; *) f=".claude/agents/$0.md"; [ -f "$f" ] || f="$HOME/.claude/agents/$0.md";; esac; awk '/^---$/{n++; next} n==1 && /^model:/{print $2; exit}' "$f"`
**Agent name:** !`case "$0" in /*|./*|../*) f="$0";; *) f=".claude/agents/$0.md"; [ -f "$f" ] || f="$HOME/.claude/agents/$0.md";; esac; awk '/^---$/{n++; next} n==1 && /^name:/{print $2; exit}' "$f"`

Call the Agent tool with:
- `subagent_type`: the agent name shown above — this enforces the agent's `tools:` restrictions; the body is injected manually via the prompt below
- `model`: the model shown above
- `run_in_background`: use the value the caller specified, or false if not specified
- `prompt`: the AGENT PROMPT block below, verbatim

===== BEGIN AGENT PROMPT =====
!`case "$0" in /*|./*|../*) f="$0";; *) f=".claude/agents/$0.md"; [ -f "$f" ] || f="$HOME/.claude/agents/$0.md";; esac; awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$f"`

Your task: $1
===== END AGENT PROMPT =====

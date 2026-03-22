---
name: run-agent
description: Spawn a custom agent from .claude/agents/ with its prompt inlined. Use instead of manually reading agent files.
user-invocable: false
---

Spawn an Agent using the configuration below.

**Agent file:** .claude/agents/$0.md
**Model:** !`awk '/^---$/{n++; next} n==1 && /^model:/{print $2; exit}' .claude/agents/$0.md`

Call the Agent tool with:
- `subagent_type`: "general-purpose"
- `model`: the model shown above
- `run_in_background`: use the value the caller specified, or false if not specified
- `prompt`: the AGENT PROMPT block below, verbatim

===== BEGIN AGENT PROMPT =====
!`awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' .claude/agents/$0.md`

Your task: $1
===== END AGENT PROMPT =====

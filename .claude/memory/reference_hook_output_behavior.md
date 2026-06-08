---
name: reference_hook_output_behavior
description: Hook output visibility — no hook mechanism can write persistent user-visible terminal text while allowing inference to continue; this is intentional architectural design
metadata:
  type: reference
---

**No hook mechanism can produce persistent, user-visible terminal text while allowing inference to continue. This is intentional architectural design** (confirmed by deep research: docs + 16 sources including GitHub issues #47117, #61152).

## Channel breakdown

| Channel | Behavior |
|---------|----------|
| stdout (PreToolUse / PostToolUse) | Goes to debug log only — not user-visible, not injected into Claude context |
| stdout (SessionStart / UserPromptSubmit / UserPromptExpansion) | Injected into Claude's context as `<system-reminder>` — machine-visible only, never shown in terminal |
| stderr | Silently dropped on exit 0. On non-zero exit, first line appears as a hook error notice in the transcript — not a viable intentional channel |
| `systemMessage` | Appears as a greyed-out annotation on the tool call block (`⎿  PreToolUse:Skill says: ...`), invisible in focus mode. Silently dropped entirely for PreToolUse/PostToolUse without `hookSpecificOutput` |
| `decision: block` + reason | Produces visible terminal output but halts inference entirely |
| `/dev/tty` | Fails with "Device not configured" — hooks run without a controlling terminal |
| `terminalSequence` | Routes escape sequences through Claude Code's terminal, but restricted to OSC 0/1/2/9/99/777 and BEL only — no arbitrary text |

## Open feature request

GitHub issue #61152 requests an `updatedAssistantMessage` hook field to inject visible text into the assistant response stream. Not yet implemented.

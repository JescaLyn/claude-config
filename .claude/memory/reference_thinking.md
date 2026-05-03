---
name: Extended thinking controls
description: Effort levels (low/medium/high/xhigh/max) with defaults by plan, all controls (keyboard/ultrathink//effort/settings/frontmatter), viewing thinking output
type: reference
---

## Effort Levels

| Level | Description | Default for |
|-------|-------------|-------------|
| `low` | Minimal thinking; mechanical/extraction work | — |
| `medium` | Moderate thinking; analytical tasks | Free tier (Opus 4.6 / Sonnet 4.6) |
| `high` | Deep reasoning; code analysis, multi-step work | Pro/Max (Opus 4.6 / Sonnet 4.6) |
| `xhigh` | Between high and max | **Default for Opus 4.7**; other models fall back to `high` |
| `max` | Extended thinking; critical synthesis and judgment | Session-only; Opus models only |

**Supported models:** Opus 4.7, Opus 4.6, Sonnet 4.6. Haiku 4.5 does not support extended thinking.

## Adaptive Reasoning

Adaptive reasoning makes extended thinking optional per step — Claude responds faster for routine prompts and reserves deeper thinking for complex ones.

- **Opus 4.7:** Always uses adaptive reasoning; `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` does not apply
- **Opus 4.6 / Sonnet 4.6:** Adaptive reasoning enabled by default for Pro/Max users; set `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` to revert to fixed thinking budget (`MAX_THINKING_TOKENS`)

## Controls

**Precedence (highest to lowest):** env var > frontmatter > command/setting > default

| Mechanism | Scope | Notes |
|-----------|-------|-------|
| `CLAUDE_CODE_EFFORT_LEVEL` env var | Session | Highest precedence; overrides all other methods |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` env var | Session | Set to `1` to revert to fixed thinking budget (Opus 4.6/Sonnet 4.6 only) |
| `MAX_THINKING_TOKENS` env var | Session | Set to `0` to disable thinking; other values apply only when adaptive thinking is disabled |
| `alwaysThinkingEnabled` in settings.json | Persistent | Enable thinking by default; saved via `/config` |
| `effort:` in skill/agent frontmatter | Per-skill | Overrides session default; overridden by env var |
| `Option+T` / `Alt+T` | Toggle on/off | Conflicts with iTerm2 "New Tab"; rebind via `/keybindings` |
| `ultrathink` in prompt | Single turn | Triggers max thinking for that turn; rainbow text confirms recognition |
| `/effort [level]` | Session | No argument opens interactive slider |
| `effortLevel` in settings.json | Persistent | Default effort level for the session |
| `showThinkingSummaries` in settings.json | Persistent | Display thinking summaries inline (disabled by default) |

## Viewing Thinking Output

- `Ctrl+O` — toggles verbose mode (gray italic thinking text)
- `showThinkingSummaries: true` in settings.json — show summaries inline (disabled by default)
- Progress indicators during extended thinking: rotating hints, "still thinking", "almost done thinking"

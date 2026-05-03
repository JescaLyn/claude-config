---
name: Claude Code session names — storage and resolution
description: User-set session names in ~/.claude/sessions/; auto-generated in JSONL; resolution priority
type: reference
---

Claude Code auto-generates or accepts session names (via `-n` flag, `/rename` command, or Plan Mode). These appear in the session picker (`/resume`) and prompt bar.

## Storage

**User-set names** (from `/rename claude-monitor-build`):
- Stored in `~/.claude/sessions/<pid>.json` with a `name` field
- **Temporary per-process:** Only exists while that session is running
- PID-based files, not directly correlatable to session IDs without parsing
- Example: `{"pid":43909,"sessionId":"bf9aefc7-...",... ,"name":"claude-monitor-build"}`

**Auto-generated names** (slugs like "jazzy-swimming-rocket"):
- Stored in `~/.claude/projects/<path-hash>/<sessionId>.jsonl` as `slug` field
- Persists after session closes
- Can be read offline
- Example in JSONL: `{"type":"summary","sessionId":"...","slug":"jazzy-swimming-rocket",...}`

## Resolving Session Names

When building session name resolution (e.g., for dashboards):

1. **`~/.claude/sessions/*.json`** — match by `sessionId`, extract `name`. Only works while session is active.

2. **JSONL fallback** — search `~/.claude/projects/*/<sessionId>.jsonl` for `slug` field. Works for any session.

**Priority:** User-set name (from sessions/) > auto-generated slug (from JSONL) > null

## Implementation Notes

- Cache results per sessionId to avoid repeated file I/O
- Use `AND name IS NULL` guards when auto-populating to avoid overwriting user-set names
- Sessions dir approach is Mac-only (temporary files); JSONL fallback is cross-platform
- Cross-machine sync requires forwarding session names from remote via satellite

## OTel and Telemetry

**Session names are NOT in OTel telemetry.** The OTel stream includes `session.id` but no human-readable label.

**Cross-machine limitation:** Local session name lookup only works when hub and Claude Code are on the same machine (both reading `~/.claude/`).

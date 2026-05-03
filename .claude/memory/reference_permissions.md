---
name: Permission system reference
description: 6 permission modes, auto mode classifier config, Bash hardening rules, read-only command exemptions, Agent(AgentName) syntax, sandbox domains, managed-only fields — full permission system reference
type: reference
---

## Tiered Approval Model

| Tool type | Example | Approval required | Don't-ask-again behavior |
|-----------|---------|-------------------|--------------------------|
| Read-only | File reads, Grep | No | N/A |
| Bash commands | Shell execution | Yes | Permanently per project dir + command |
| File modification | Edit/write | Yes | Until session end |

## Permission Modes

| Mode | Description |
|------|-------------|
| `default` | Prompts on first use per tool type |
| `acceptEdits` | Auto-accepts file edits and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`) for working dir / `additionalDirectories` |
| `plan` | Read-only: no edits, no state changes; Bash/network still prompt |
| `auto` | Background safety classifier; research preview |
| `dontAsk` | Auto-denies unless pre-approved via allow rules |
| `bypassPermissions` | Skips all prompts; writes to `.claude/`, `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.git/`, `.vscode/`, and shell config files bypass prompts; catastrophic removal commands still prompt (containers/CI only) |

Set via `permissions.defaultMode` in settings.json or `--permission-mode` CLI flag.

## Auto Mode Classifier

Auto mode runs a background safety classifier before each tool call. Configurable via settings:

```json
{
  "autoMode": {
    "environment": "development",
    "allow": ["$defaults", "Read", "Grep", "Glob"],
    "soft_deny": ["$defaults", "Bash(rm *)"]
  }
}
```

**`$defaults` sentinel:** Include `"$defaults"` in `autoMode.allow`, `autoMode.soft_deny`, or `autoMode.environment` to add custom rules _alongside_ the built-in list instead of replacing it.

CLI subcommands: `claude auto-mode defaults`, `claude auto-mode config`, `claude auto-mode critique`.

`permissions.disableAutoMode: "disable"` in managed settings blocks auto mode entirely.

The `PermissionDenied` hook fires when the auto mode classifier denies a call.

## Allow / Deny / Ask Rules

```json
{
  "permissions": {
    "allow": ["Bash(npm run *)", "Edit(/src/**/*.ts)", "mcp__github__list_*"],
    "deny": ["Read(.env*)", "Bash(git push *)", "mcp__database__drop_*"],
    "ask": ["Write(/config/**)", "Bash(curl *)"]
  }
}
```

**Precedence:** deny > ask > allow. First matching rule wins. Deny at any scope blocks globally — cannot be overridden by allow at another scope.

**Wildcard behavior:**
- Space before `*` enforces a word boundary: `Bash(ls *)` matches `ls -la` but NOT `lsof`
- No space matches as prefix: `Bash(ls*)` matches both `ls -la` and `lsof`
- `:*` suffix is equivalent to a trailing wildcard

**Compound commands** (`&&`, `||`, `;`, `|`, `|&`, `&`, newlines): each subcommand is evaluated independently against permission rules.

**Path examples:** `Bash(npm run *)`, `Read(./.env)`, `WebFetch(domain:example.com)`

**Agent(AgentName) syntax:** Allow or deny specific named subagents:
```json
{ "allow": ["Agent(my-safe-reviewer)"], "deny": ["Agent(risky-agent)"] }
```

**Skill rules:** Allow or deny specific skills by name or prefix:
- `Skill(commit)` — exact skill name
- `Skill(deploy *)` — prefix match

**Symlink handling:** allow rules require both symlink and target to match; deny rules block if either matches.

## Bash Hardening

Key changes that affect pattern-based rules:

- `find -exec` and `find -delete` are **not covered** by `Bash(find *)` wildcard rules — they always prompt regardless of allow rules
- **Process wrappers stripped before matching:** `timeout`, `time`, `nice`, `nohup`, `stdbuf`, bare `xargs` — the inner command is what gets matched
- **Deny rules match wrapped commands:** `env`, `sudo`, `watch`, `ionice`, `setsid` wrappers are stripped before matching deny rules — the inner command is evaluated
- **exec wrappers always prompt** (cannot be pre-approved): `watch`, `setsid`, `ionice`, `flock`
- Backslash-escaped flag bypass, compound command bypass, env-var prefix bypass, `/dev/tcp`/`/dev/udp` redirect bypass: all patched
- macOS `/private/{etc,var,tmp,home}` paths treated as dangerous removal targets

## PreToolUse Hooks and Permissions

PreToolUse hooks run **before** the permission prompt, not after. Key behaviors:
- A blocking hook (exit 2) stops execution before permission rules are evaluated
- Hook decisions do **not** bypass permission deny/ask rules — a hook allowing a call still goes through permission checks
- Hook runs → permission check → tool execution (if both pass)

## Read-Only Command Exemptions

These read-only commands **never prompt** in any permission mode:

`ls`, `cat`, `echo`, `grep`, `find` (read-only forms), `git status`, `git log`, `git diff`, `git show`, `git branch --list`, `pwd`, `which`, `type`, `env`, `printenv`, `head`, `tail`, `wc`, `sort`, `uniq`, `diff`, `stat`

Unquoted globs on fully read-only commands are also exempt.

## Sandbox + autoAllowBashIfSandboxed

When both `sandbox: true` and `autoAllowBashIfSandboxed: true` are set, sandboxed Bash commands run without prompting even if the permission rules include `ask: Bash(*)`. The sandbox itself is the safety boundary.

## Sandbox Configuration

```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["/tmp", "./dist"],
      "denyWrite": ["./node_modules"],
      "allowRead": ["./"],
      "denyRead": ["./.env"]
    },
    "network": {
      "allowedDomains": ["registry.npmjs.org"],
      "deniedDomains": ["internal.corp.example.com"],
      "allowLocalBinding": true
    }
  }
}
```

`sandbox.network.deniedDomains` blocks specific domains even if they would otherwise be allowed.

## `--dangerously-skip-permissions`

Bypasses permission prompts entirely. Writes to `.claude/`, `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.git/`, `.vscode/`, and shell config files are allowed without prompting. Catastrophic removal commands (`rm -rf`, etc.) still prompt. Use in containers/CI only.

## PowerShell

PowerShell tool commands can be auto-approved in permission mode, matching Bash behavior. Allow/deny rules apply the same way.

## Managed-Only Fields

Only work in managed scope (cannot be set by users):

- `disableBypassPermissionsMode` — prevents entering bypassPermissions mode
- `allowManagedPermissionRulesOnly` — prevents users from adding their own allow/deny rules
- `allowManagedHooksOnly` — suppresses non-managed hooks
- `allowManagedMcpServersOnly` — prevents user MCP server additions
- `permissions.disableAutoMode: "disable"` — blocks auto mode

Managed settings delivered via `managed-settings.json` or `managed-settings.d/*.json` drop-in directory.

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

Rules are evaluated: deny → ask → allow. First matching rule wins. A bare tool name (e.g. `Bash`) removes the tool from context entirely. A scoped rule (e.g. `Bash(rm *)`) leaves the tool available but blocks matching calls.

## Permission Modes

| Mode | Description |
|------|-------------|
| `default` | Prompts on first use per tool type |
| `acceptEdits` | Auto-accepts file edits and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`) for working dir / `additionalDirectories` |
| `plan` | Read-only; no source file edits |
| `auto` | Background safety classifier; available for Max subscribers using Opus 4.7 |
| `dontAsk` | Auto-denies unless pre-approved via allow rules |
| `bypassPermissions` | Skips all prompts; removals targeting `/`, `$HOME`, or other critical system directories still prompt (containers/CI only) |

Set via `permissions.defaultMode` in settings.json or `--permission-mode` CLI flag. Background sessions launched via `/bg` or `←←` preserve the current permission mode, and `--dangerously-skip-permissions` persists across retire→wake cycles. Sessions dispatched from `claude agents` honor `permissions.defaultMode` and accept `--permission-mode` to override it. When `--agent <name>` is used, the agent definition's `permissionMode` is honored for built-in agents. Shift+Tab in attached agent sessions cycles through permission modes including auto mode.

## Auto Mode Classifier

Auto mode runs a background safety classifier before each tool call. The permission dialog explains when a `permissions.ask` rule caused a prompt. Configurable via settings:

```json
{
  "autoMode": {
    "environment": "development",
    "allow": ["$defaults", "Read", "Grep", "Glob"],
    "soft_deny": ["$defaults", "Bash(rm *)"],
    "hard_deny": ["Bash(curl * | sh)", "Bash(rm -rf /)"]
  }
}
```

**`$defaults` sentinel:** Include `"$defaults"` in `autoMode.allow`, `autoMode.soft_deny`, or `autoMode.environment` to add custom rules _alongside_ the built-in list instead of replacing it.

**`hard_deny`:** Rules that block unconditionally regardless of user intent or allow exceptions. Unlike `soft_deny`, no classifier override or user approval can bypass a `hard_deny` match.

CLI subcommands: `claude auto-mode defaults`, `claude auto-mode config`, `claude auto-mode critique`.

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

Key behaviors affecting pattern-based rules:

- **Process wrappers stripped before matching:** `timeout`, `time`, `nice`, `nohup`, `stdbuf`, bare `xargs`, `env`, `sudo`, `watch`, `ionice`, `setsid`, and similar exec wrappers — the inner command is what gets matched
- **`Bash(find:*)` allow rules do not auto-approve `find -exec` or `find -delete`** — these forms require explicit approval regardless of a `find` allow rule
- Env-var assignment bypass blocked: bare variable assignments to non-allowlisted env vars are not auto-approved
- macOS `/private/{etc,var,tmp,home}` paths treated as dangerous removal targets

## PreToolUse Hooks and Permissions

PreToolUse hooks run **before** the permission prompt. Key behaviors:
- A blocking hook (exit 2) takes precedence over allow rules and stops execution
- Hook `allow` decisions do **not** override deny permission rules — deny rules still apply after a hook allows
- `PermissionRequest` hook `updatedInput` is re-checked against deny rules
- `setMode:'bypassPermissions'` in hook output respects `disableBypassPermissionsMode`

## Read-Only Command Exemptions

These read-only commands **never prompt** in any permission mode:

`ls`, `cat`, `echo`, `grep`, `find` (read-only forms), `git status`, `git log`, `git diff`, `git show`, `git branch --list`, `pwd`, `which`, `type`, `env`, `printenv`, `head`, `tail`, `wc`, `sort`, `uniq`, `diff`, `stat`, `fmt`, `comm`, `cmp`, `numfmt`, `expr`, `test`, `printf`, `getconf`, `seq`, `tsort`, `pr`

Unquoted globs on fully read-only commands are also exempt.

## Sandbox + autoAllowBashIfSandboxed

When both `sandbox: true` and `autoAllowBashIfSandboxed: true` are set, sandboxed Bash commands run without prompting even if the permission rules include `ask: Bash(*)`. The sandbox itself is the safety boundary. Auto mode and bypass-permissions mode also auto-approve sandbox network access prompts.

## Sandbox Configuration

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "filesystem": {
      "allowWrite": ["/tmp", "./dist"],
      "denyWrite": ["./node_modules"],
      "allowRead": ["./"],
      "denyRead": ["./.env"]
    },
    "network": {
      "allowedDomains": ["registry.npmjs.org"],
      "deniedDomains": ["internal.corp.example.com"],
      "allowLocalBinding": true,
      "allowMachLookup": true,
      "enableWeakerNetworkIsolation": false
    }
  }
}
```

- `sandbox.network.deniedDomains` blocks specific domains even if they would otherwise be allowed by a broader `allowedDomains` wildcard.
- `sandbox.failIfUnavailable` exits with an error when sandbox is enabled but cannot start, instead of running unsandboxed.
- `sandbox.network.allowMachLookup` (macOS) enables mach lookup for network operations.
- `sandbox.network.enableWeakerNetworkIsolation` (macOS only) allows Go programs like `gh`, `gcloud`, and `terraform` to verify TLS certificates when using a custom MITM proxy with `httpProxyPort`.

## Subprocess Sandboxing

Setting `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` enables subprocess sandboxing with PID namespace isolation on Linux. `CLAUDE_CODE_SCRIPT_CAPS` limits per-session script invocations as an additional cap.

## `--dangerously-skip-permissions`

Bypasses permission prompts for writes to `.claude/`, `.git/`, `.vscode/`, and shell config files. Does not prompt for writes to `.claude/skills/`, `.claude/agents/`, `.claude/commands/`. Use in containers/CI only.

## Agent Isolation

Agent definitions support `isolate: worktree` to run the agent in an isolated git worktree, keeping its file changes separate from the main working tree.

## PowerShell

PowerShell tool commands can be auto-approved in permission mode, matching Bash behavior. Allow/deny rules apply the same way, including prefix/wildcard rules (e.g. `PowerShell(dotnet.exe build *)`) for native executables and scripts.

PowerShell passes `-ExecutionPolicy Bypass` by default. To respect the system execution policy instead, set `CLAUDE_CODE_POWERSHELL_RESPECT_EXECUTION_POLICY=1`. The PowerShell tool is enabled by default on Windows for Bedrock, Vertex, and Foundry users; disable with `CLAUDE_CODE_USE_POWERSHELL_TOOL=0`.

## Settings Precedence

1. Managed settings
2. Command line arguments
3. Local project settings
4. Shared project settings
5. User settings

Deny at any level blocks allow at other levels. A default allow paired with a project-level deny still blocks.

## Managed-Only Fields

Only work in managed scope (cannot be set by users):

- `disableBypassPermissionsMode` — prevents entering bypassPermissions mode
- `disableAutoMode` — blocks auto mode
- `allowManagedPermissionRulesOnly` — prevents users from adding their own allow/deny rules
- `allowManagedHooksOnly` — suppresses non-managed hooks
- `allowManagedMcpServersOnly` — prevents user MCP server additions
- `allowedChannelPlugins` — restricts which channel plugins are permitted
- `blockedMarketplaces` — blocks specific plugin marketplaces
- `channelsEnabled` — controls channel availability
- `strictKnownMarketplaces` — enforces known-marketplace restriction
- `strictPluginOnlyCustomization` — restricts customization to plugins only
- `wslInheritsWindowsSettings` — WSL sessions inherit Windows-side settings
- `sandbox.bwrapPath` — custom bubblewrap binary path (Linux/WSL)
- `sandbox.socatPath` — custom socat binary path (Linux/WSL)
- `sandbox.filesystem.allowManagedReadPathsOnly` — restricts filesystem read paths to managed allowlist
- `sandbox.network.allowManagedDomainsOnly` — restricts network to managed domain allowlist

Managed settings take highest precedence and are delivered via `managed-settings.json` or `managed-settings.d/*.json` drop-in directory.

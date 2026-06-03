---
name: Settings system
description: Settings.json scopes, locations, precedence, merge behavior, key fields, managed policy — the configuration layer that hooks, permissions, and tools all reference
type: reference
---

## Settings Scopes

| Scope | Location | Shared? | Purpose |
|-------|----------|---------|---------|
| **Managed** | Server-managed (admin console), MDM/OS policies, or `managed-settings.json` | Deployed by IT | Enterprise enforcement |
| **User** | `~/.claude/settings.json` | No | Personal defaults across all projects |
| **Project** | `.claude/settings.json` | Yes (git-tracked) | Team-shared config |
| **Local** | `.claude/settings.local.json` | No (gitignored) | Personal overrides for this project |

Managed file locations: macOS `/Library/Application Support/ClaudeCode/managed-settings.json`, Linux/WSL `/etc/claude-code/`, Windows `C:\Program Files\ClaudeCode\`. Also supports a `managed-settings.d/` drop-in directory for distributing settings as separate fragment files (merged alphabetically).

MDM/OS-level policy delivery also supported: macOS plist `com.anthropic.claudecode`, Windows registry `HKLM\SOFTWARE\Policies\ClaudeCode`.

## Precedence

For **scalar values** (model, effort, etc.), more specific wins:

**Managed > CLI args > Local > Project > User**

CLI args are session-only overrides. Common flags: `--model`, `--effort`, `--permission-mode`, `--allowedTools`, `--disallowedTools`, `--add-dir`, `--mcp-config`, `--settings` (load additional settings from file/JSON). Cannot override managed settings.

For **array values** (permissions, sandbox paths, hooks), all scopes **merge — arrays are concatenated and deduplicated**. A deny rule in any scope cannot be overridden by an allow in another. Hooks from all scopes run in parallel (see `reference_hooks.md` for hook-specific hierarchy).

This means:
- Permissions: deny at any scope blocks globally. Allow/deny/ask rules from all scopes combine.
- Hooks: all matching hooks from all sources fire. Suppression is controlled by `disableAllHooks` and `allowManagedHooksOnly`, not by scope override (see `reference_hooks.md` "Hook Sources and Scope Behavior").
- Sandbox paths: all `allowWrite`/`denyWrite`/`allowRead`/`denyRead` paths merge.

## Key Settings Fields

### Permissions & Security
- `permissions.allow`, `permissions.deny`, `permissions.ask` — tool permission rules (see `reference_tools.md`)
- `permissions.defaultMode` — `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`
- `autoMode.*` — configures the `auto` mode classifier: `autoMode.environment`, `autoMode.allow`, `autoMode.soft_deny`, `autoMode.hard_deny`
  - `autoMode.allow` and `autoMode.soft_deny` support the `$defaults` sentinel, which expands to the built-in default rule set
  - `autoMode.hard_deny` — rules that block unconditionally regardless of user intent
- `permissions.additionalDirectories` — extra working directories
- `disableAutoMode` — blocks auto mode (top-level field, not nested under `permissions`)
- `disableBypassPermissionsMode` — (managed only) prevent bypassing permissions
- `skipDangerousModePermissionPrompt` — suppress the confirmation prompt when entering bypass/dangerous mode

### Hooks
- `hooks` — lifecycle automation config (see `reference_hooks.md`)
- `allowedHttpHookUrls` — whitelist URLs for HTTP hooks
- `disableAllHooks` — disable all hooks and status line
- `allowManagedHooksOnly` — (managed only) suppress non-managed hooks

### Model & Effort
- `model` — override default model; `/model` selections persist across restarts even when a project pins a different model
- `availableModels` — restrict which models can be selected
- `effortLevel` — persist across sessions: `low`, `medium`, `high`, `xhigh` (Opus 4.7), `max`. Default is `high` for API-key, Bedrock/Vertex/Foundry, Team, Enterprise users.
- `alwaysThinkingEnabled` — enable extended thinking by default (boolean)
- `modelOverrides` — map Anthropic model IDs to provider-specific IDs

### Environment
- `env` — environment variables applied to subprocesses (Bash tool, hooks, MCP stdio servers); values must be strings. Color-control vars like `NO_COLOR`/`FORCE_COLOR` apply to subprocesses only and do not affect Claude Code's own UI.
- `apiKeyHelper` — script to generate auth values (runs in `/bin/sh`, must output API key to stdout)

### Sandbox
- `sandbox.enabled`, `sandbox.autoAllowBashIfSandboxed`
- `sandbox.failIfUnavailable` — fail startup if sandbox cannot be initialized
- `sandbox.excludedCommands` — commands excluded from sandboxing
- `sandbox.filesystem.*` — read/write path allowlists and denylists
- `sandbox.network.*` — domain allowlists, proxy config, Unix sockets, `sandbox.network.deniedDomains` (block specific domains)
- `sandbox.bwrapPath`, `sandbox.socatPath` — (managed only, Linux/WSL) specify custom bubblewrap and socat binary locations

### MCP Servers
- `enableAllProjectMcpServers` — auto-approve MCP servers from `.mcp.json`
- `enabledMcpjsonServers` / `disabledMcpjsonServers` — per-server approval
- `allowAllClaudeAiMcps` — (managed only) load claude.ai cloud MCP connectors alongside `managed-mcp.json`

### Plugins
- `enabledPlugins` — toggle plugins on/off
- `extraKnownMarketplaces` — add custom plugin sources
- `strictKnownMarketplaces` — (managed only) restrict installs to approved sources
- `blockedMarketplaces` — (managed only) block specific sources; enforced on install, update, refresh, and autoupdate

### UI & Display
- `outputStyle`, `statusLine`, `language`
- `spinnerTipsEnabled`, `spinnerVerbs`
- `tui` — terminal UI renderer: `"fullscreen"` or `"default"`
- `viewMode` — output verbosity: `"default"`, `"verbose"`, or `"focus"`
- `showTurnDuration` — show turn duration messages (boolean)
- `showThinkingSummaries` — show/hide thinking block summaries (boolean, disabled by default)
- `autoScrollEnabled` — disable conversation auto-scroll in fullscreen mode (boolean)
- `prUrlTemplate` — custom URL template for the footer PR badge (instead of github.com)
- `companyAnnouncements` — messages shown at startup (managed scope only)

### Voice
- `voice` — push-to-talk dictation config object: `{enabled: true, mode: "tap"}`; dictation respects the `language` setting

### Git & Attribution
- `attribution.commit`, `attribution.pr` — custom attribution text
- `includeGitInstructions` — include built-in commit/PR workflow instructions in system prompt (boolean; also controllable via `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` env var)

### Agents
- `agent` — run the main thread as a named subagent

### Worktrees
- `worktree.baseRef` — `'fresh'` (default) or `'head'`; controls branch point for worktrees
- `worktree.bgIsolation` — `'none'` lets background sessions edit the working copy directly without `EnterWorktree`
- `worktree.symlinkDirectories` — directories to symlink in worktrees
- `worktree.sparsePaths` — directories for git sparse-checkout in worktrees

### Updates
- `autoUpdatesChannel` — `"stable"` or `"latest"`
- `minimumVersion` — floor version; prevents downgrades below this version

### File Picker
- `respectGitignore` — respect `.gitignore` in the `@`-mention file picker (boolean)
- `defaultShell` — `"bash"` or `"powershell"` (shell selection)
- `editorMode` — `"normal"` or `"vim"` to control input prompt editor mode

### Network & Fetch
- `skipWebFetchPreflight` — skip the WebFetch domain safety preflight check (boolean)

### Skills
- `skillOverrides` — control skill visibility
- `skillListingBudgetFraction` — context budget fraction for skill descriptions
- `maxSkillDescriptionChars` — per-skill description character cap (default 1536)
- `disableSkillShellExecution` — disable `` !`command` `` shell preprocessing in skills from user/project/plugin sources (bundled/managed skills unaffected)

### Access Control
- `strictPluginOnlyCustomization` — restrict all customization (skills, hooks, rules) to plugins/managed only
- `forceLoginMethod` — `'claudeai'` or `'console'` to lock login method
- `forceLoginOrgUUID` — require login to a specific org
- `forceRemoteSettingsRefresh` — (managed only) block startup until remote settings fetch completes; exits if fetch fails (fail-closed)

### Memory
- `autoMemoryEnabled` — enable/disable auto memory
- `autoMemoryDirectory` — custom memory storage location (user/local/policy scopes only — NOT project settings, security restriction)

### Other
- `cleanupPeriodDays` — cleanup period for `~/.claude/tasks/`, `~/.claude/shell-snapshots/`, and `~/.claude/backups/` (default 30; setting `0` is rejected with a validation error)
- `plansDirectory` — where plan files live (default `~/.claude/plans`)

## ~/.claude.json Keys

Global config for OAuth, MCP configs, and per-project state:
- `autoConnectIde` — auto-connect to IDE on start (default false)
- `autoInstallIdeExtension` — auto-install VS Code extension (default true)
- `externalEditorContext` — prepend previous response when opening external editor (default false)
- `teammateDefaultModel` — default model for agent team teammates

## Environment Variables

- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` — strip Anthropic and cloud provider credentials from subprocess environments (Bash tool, hooks, MCP stdio servers)
- `ENABLE_PROMPT_CACHING_1H` — opt into 1-hour prompt cache TTL on API key, Bedrock, Vertex, and Foundry

## JSON Format Examples

Settings whose structure isn't obvious from the key name. For `hooks` and `permissions` JSON, see `reference_hooks.md` and `reference_tools.md` respectively.

```json
{
  "env": {
    "DEBUG": "true",
    "DATABASE_URL": "postgres://localhost/mydb"
  },
  "model": "claude-sonnet-4-6",
  "effortLevel": "medium",
  "availableModels": ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"],
  "apiKeyHelper": "op read 'op://vault/anthropic/api-key'",
  "attribution": {
    "commit": "Generated by Claude Code",
    "pr": "\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)"
  },
  "voice": { "enabled": true, "mode": "tap" },
  "tui": "fullscreen",
  "viewMode": "verbose",
  "autoMode": {
    "soft_deny": ["$defaults", "Bash(rm*)"]
  },
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "autoAllowBashIfSandboxed": true,
    "filesystem": {
      "allowWrite": ["/tmp", "./dist"],
      "denyWrite": ["./node_modules"],
      "allowRead": ["./"],
      "denyRead": ["./.env"]
    },
    "network": {
      "allowedDomains": ["registry.npmjs.org", "api.github.com"],
      "allowLocalBinding": true
    }
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["memory", "github"],
  "disabledMcpjsonServers": ["experimental-server"]
}
```

## Managed-Only Fields

These settings only work in the managed scope:
- `disableBypassPermissionsMode`, `allowManagedPermissionRulesOnly`
- `allowManagedHooksOnly`, `allowManagedMcpServersOnly`
- `allowedMcpServers`, `deniedMcpServers`
- `allowAllClaudeAiMcps`
- `sandbox.network.allowManagedDomainsOnly`, `sandbox.filesystem.allowManagedReadPathsOnly`
- `sandbox.bwrapPath`, `sandbox.socatPath` (Linux/WSL)
- `strictKnownMarketplaces`, `blockedMarketplaces`, `pluginTrustMessage`
- `channelsEnabled`, `allowedChannelPlugins`
- `allowManagedChannelPlugins` (alias pattern; same enforcement scope)
- `wslInheritsWindowsSettings`
- `forceRemoteSettingsRefresh`
- `parentSettingsBehavior` — `'first-wins' | 'merge'`; opts SDK `managedSettings` (parent tier) into the policy merge

## Viewing and Modifying

- `/config` (alias: `/settings`) opens the settings UI; settings (theme, editor mode, verbose, etc.) persist to `~/.claude/settings.json` and participate in the full precedence stack
- `/status` shows active settings sources and their origins
- `/update-config` skill for modifying settings.json programmatically
- `/permissions` for viewing and modifying permission rules

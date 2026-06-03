---
name: Claude Code plugins reference
description: What each installed plugin does, its overhead cost, when to enable it per project, and how to automate new-plugin detection via SessionStart hooks
type: reference
---

# Claude Code Plugins

Plugins live at `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/`. Enable/disable in `~/.claude/settings.json` under `enabledPlugins`.

**Note:** Plugins are not MCP servers. The `mcp__claude_ai_*` tools are platform integrations tied to claude.ai, not local config.

**Where plugins are actually installed:** `~/.claude/plugins/cache/<marketplace>/<plugin-name>/<version>/` — NOT in `~/.claude/plugins/marketplaces/.../plugins/`. The marketplace directory is source/registry metadata; the cache is what actually runs. Always check the cache when auditing plugin content.

## Plugin Reference

| Plugin | What it does | Overhead | Enable when... |
|--------|-------------|----------|----------------|
| **frontend-design** | Guides distinctive UI/UX with intentional aesthetic choices | Low (41-line skill) | Working on any UI/frontend |
| **code-review** | 5 parallel Sonnet agents for PR review with confidence scoring | Medium (on-demand) | Doing PR reviews on a team project |
| **code-simplifier** | Refines code for clarity and consistency | Low (52-line agent) | Refactoring or cleanup sprints |
| **feature-dev** | 7-phase structured feature workflow with 6-9 parallel agents | High (on-demand only) | Building a new feature end-to-end |
| **skill-creator** | Creates and benchmarks skills with eval automation | High (479-line skill) | Building new Claude Code skills |
| **ralph-loop** | Continuous self-referential loops via stop-hook | Low (18 lines) | Tasks needing iterative self-correction |
| **security-guidance** | Pre-edit hook warning on security anti-patterns | Medium-High (runs on every edit) | Security-sensitive codebases |
| **claude-code-setup** | Analyzes codebases and recommends automations | Medium (288-line skill) | Onboarding a new project |
| **superpowers** | 14 workflow skills: TDD, systematic debugging, brainstorming, parallel agents, git worktrees, plans, code review, verification | Medium (14 skills + 85-line contributor CLAUDE.md loaded at session start) | Any serious development project |
| **chrome-devtools-mcp** | MCP server + 4 skills (chrome-devtools, a11y-debugging, debug-optimize-lcp, troubleshooting) for browser automation, debugging, performance, and accessibility auditing via Chrome DevTools | High — launches a Chrome process; MCP server adds ~35 tools per session | Web development: debugging page behavior, automating browser interactions, a11y audits, Core Web Vitals / LCP optimization |

## Plugin manifest capabilities

### Skills
Plugins surface skills in two ways:
- `skills/` subdirectory containing individual skill files — invoked as `/plugin-name:skill-name`
- Root-level `SKILL.md` (no `skills/` subdirectory) — the plugin itself is surfaced as a single skill, invoked as `/plugin-name`

### Agents
Plugin-shipped agents support `effort`, `maxTurns`, and `disallowedTools` in their frontmatter. Output styles support the `keep-coding-instructions` frontmatter field.

### Monitors
Plugins can ship monitors, declared under `"experimental": { "monitors": [...] }` in the manifest. Top-level `monitors` declarations still load but `claude plugin validate` warns on them. Monitors auto-arm at session start or when a skill from that plugin is invoked.

### Executables
Plugins can ship executables under a `bin/` directory. These are available as bare commands from the Bash tool without a full path.

### User configuration
Plugins support `manifest.userConfig` to prompt for configuration at enable time. Fields marked `sensitive: true` are stored in the keychain or a protected credentials file.

### MCP servers
Plugin MCP servers with unset config variables display a 'config issue' message with a fix hint rather than silently failing.

### Source types
The `git-subdir` source type points to a subdirectory within a git repo, allowing plugins to live alongside other content in a repo. Marketplace git URLs without a `.git` suffix (Azure DevOps, AWS CodeCommit) are supported. npm sources support custom registries and specific version pinning.

## Plugin CLI commands

| Command | What it does |
|---------|-------------|
| `claude plugin install <name>@<marketplace>` | Installs a plugin; auto-refreshes the marketplace and retries before reporting not found |
| `claude plugin install --plugin-url <url>` | Fetches a plugin `.zip` archive from a URL for the current session only |
| `claude plugin disable <name>` | Refuses if another enabled plugin depends on the target; provides a copy-pasteable disable-chain hint |
| `claude plugin enable <name>` | Force-enables transitive dependencies automatically |
| `claude plugin prune` | Removes orphaned auto-installed plugin dependencies |
| `claude plugin uninstall --prune` | Uninstalls and cascades to remove now-orphaned dependencies |
| `claude plugin validate` | Validates manifest; accepts `$schema`, `version`, and `description` at the top level of `marketplace.json` and `$schema` in `plugin.json`; warns on top-level `monitors`/`themes` (use `experimental` key instead) |
| `claude plugin tag` | Creates release git tags for plugins with version validation |

**`--plugin-dir`** accepts a directory path or a `.zip` archive. To specify multiple directories, repeat the flag — `--plugin-dir path1 --plugin-dir path2`. In headless `--output-format stream-json`, `init.plugin_errors` covers both `--plugin-dir` load failures and dependency demotions.

## Dependency management

Plugins pinned by another plugin's version constraint auto-update to the highest git tag that satisfies the constraint.

## Environment variables

| Variable | What it does |
|----------|-------------|
| `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` | Clone GitHub plugin sources over HTTPS instead of SSH — use in environments without a GitHub SSH key |
| `CLAUDE_CODE_PLUGIN_SEED_DIR` | Pre-seed plugins from a local directory; accepts multiple directories separated by `:` (Unix) or `;` (Windows) |

## Security

`blockedMarketplaces` enforces both `hostPattern` and `pathPattern` entries.

## VSCode

VSCode has native plugin management support. Use the VSCode Claude Code extension UI to install, enable, and disable plugins without editing JSON directly.

## Installed plugins list

The installed plugins list supports search — type to filter by name or description.

## Per-project plugin enablement

Plugins are **disabled globally by default** to manage overhead. Enable them per-project by adding `enabledPlugins` to the project's `.claude/settings.json`. Settings merge user → project → local.

- Setting a plugin to `true` in project settings enables it even if absent globally.
- `settings.local.json` plugin entries are silently ignored unless the key also exists in `settings.json`.
- When the key exists in both scopes, project `false` should override global `true`. However the merge is buggy when `enabledPlugins` is absent from the global scope — child entries are silently dropped. **Workaround:** always keep `enabledPlugins` as a key in global `~/.claude/settings.json` (all values `false`), then project overrides work reliably.

## claudeMdExcludes

- Applies **only to User, Project, and Local memory types** — confirmed does NOT apply to plugin cache CLAUDE.md files
- Cannot be used to suppress a plugin's contributor guidelines or any plugin-provided CLAUDE.md
- To suppress a plugin's CLAUDE.md overhead, the only option is to disable the plugin itself
- Tilde (`~`) does NOT expand in patterns — use absolute paths

## Recommendations by project type

**General development (default):** Keep all disabled. Enable on demand.

**New project setup:** `claude-code-setup` to get hook/skill recommendations, then disable.

**Frontend/UI project:** `frontend-design`, optionally `code-simplifier`.

**Security-sensitive codebase:** `security-guidance` (accept the per-edit overhead).

**Building Claude tooling:** `skill-creator`, `claude-code-setup`.

**Feature sprint:** `feature-dev` for the duration, then disable.

**PR workflow:** `code-review` when reviewing PRs, disable otherwise.

## Disabling plugins

Remove the entry from `enabledPlugins` in `~/.claude/settings.json`, or set to `false`. Use the `/update-config` skill for guided edits.

## Automating new-plugin detection

**No plugin lifecycle hooks exist** (no PostInstall/PreInstall). Until then, detection requires a workaround.

### Viable: SessionStart command hook
A bash script on SessionStart can:
1. List dirs in `~/.claude/plugins/cache/claude-plugins-official/`
2. Compare against keys in `~/.claude/settings.json` `enabledPlugins`
3. For new entries: add `"plugin@claude-plugins-official": false` via jq (disables by default)
4. Add a stub row to `reference_plugins.md`: `| **plugin** | NEEDS ANALYSIS | Unknown | Run /update-plugin-registry |`
5. Output `{"systemMessage": "New plugin detected: X. Run /update-plugin-registry to analyze."}`

Use `"matcher": "startup"` on the SessionStart hook to fire only on true startup, not resume/compact.

### Potentially viable: asyncRewake on SessionStart
Exit code 2 on an asyncRewake hook wakes Claude after the hook completes — could auto-trigger analysis. Behavior on SessionStart specifically is unconfirmed.

### Not achievable without agent hooks
- Automatic quality analysis of a plugin's purpose and recommendation criteria
- Writing a complete `reference_plugins.md` entry without human-in-the-loop

**Recommended design:** SessionStart command hook for detect/disable/stub/notify + `/update-plugin-registry` skill run manually (or auto-triggered via asyncRewake) to write the full entry.

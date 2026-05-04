---
name: refresh-claude-code-reference
description: Refresh all Claude Code reference files in ~/.claude/memory/ from current docs and changelog.
user-invocable: true
model: sonnet
---

## Phase 1 — Research (parallel)

Run all three in a single message (2 Agent calls + 1 Bash call):

**Agent: docs-fetcher** (haiku, WebFetch + Read)

Fetch current Claude Code documentation. Fetch these pages; for each, extract full text content:
1. https://code.claude.com/docs/en/hooks
2. https://code.claude.com/docs/en/skills
3. https://code.claude.com/docs/en/mcp
4. https://code.claude.com/docs/en/settings
5. https://code.claude.com/docs/en/tools
6. https://code.claude.com/docs/en/context-management
7. https://code.claude.com/docs/en/thinking
8. https://code.claude.com/docs/en/subagents
9. https://code.claude.com/docs/en/permissions

If a URL 404s, try two variants in order: (1) remove `/en/`, (2) try `/reference/` prefix. After 2 failed variants, log and continue.

Output JSON: `{ "fetched_at": "<ISO>", "pages": [{ "url", "status": "ok|error", "content": "<text, max 4000 chars>" }], "fetch_errors": ["<url: reason>"] }`. Keep total output under 12000 tokens.

---

**Agent: changelog-parser** (haiku, Read + Bash)

1. Run `stat -f "%m %Sm" /Users/jessicaterry/.claude/cache/changelog.md` to get last-modified time. If file missing: output `{ "error": "changelog not found" }` and stop.
2. Read `/Users/jessicaterry/.claude/cache/changelog.md`. Extract all changes relevant to: hooks, skills/commands, MCP, settings, tools, context management, thinking/effort, subagent pipelines, permissions, plugins, bundled skills.

For each change: `{ "version", "category", "description", "type": "new|changed|fixed" }`.

Output JSON: `{ "parsed_at": "<ISO>", "changelog_mtime": "<date from stat>", "changes": [...] }`.

---

**memory-inventory** (script)

Run via Bash tool:

```bash
bash ~/.claude/skills/refresh-claude-code-reference/scripts/memory-inventory.sh
```

Outputs JSON: `{ "files": [{ "path", "filename", "name", "type", "description" }], "memory_md_content" }`. Capture it.

---

Collect all three results before proceeding.

**Changelog staleness check:** Compute the age of `changelog_mtime` against today. If older than 30 days, warn the user: "Changelog cache last updated <date> — may be stale. Consider refreshing it before proceeding." Ask if they want to continue or abort.

## Phase 2 — Architecture check (sequential, two-step)

### Step 2a — Quick pre-check (haiku)

Using only the memory-inventory output (filenames and descriptions — no file reads), answer: does the current set of reference files have any obvious structural problems? Look for:
- Two files whose descriptions are nearly synonymous or heavily overlapping
- A file whose description suggests it covers two unrelated use cases
- A file whose description no longer matches its name

Output: `{ "restructure_warranted": true|false, "signals": ["<one-liner per signal>"] }`.

If `restructure_warranted` is false: filter `memory-inventory.files` to `type == "reference"`, use their `path` values as `files_to_update`, set `structural_changes: []` and `description_changes: {}`, and proceed to Phase 3.

### Step 2b — Full review (sonnet, only if Step 2a returned `restructure_warranted: true`)

**Agent: architecture-reviewer** (sonnet, Read + Bash + Write)

You have the memory-inventory output and the signals from Step 2a. **Operate only on files where `type` is `reference`.** Do not read, modify, or delete files of any other type — those are out of scope.

Read all in-scope reference files. For each signal from Step 2a, decide whether to act:
- Merge: combine two files, preserving all content, updating frontmatter
- Split: divide one file, ensuring each part has a coherent single scope
- Rename/redescribe: update frontmatter only, no content move needed

Execute decided changes. Delete source files only after all content is confirmed moved.

Output: `{ "structural_changes": [{ "action": "merge|split|redescribe", "files_affected": [], "reason": "<one-liner>" }], "files_to_update": ["<all reference files now on disk>"], "description_changes": { "<filename>": "<new description if changed>" } }`.

If signals don't hold up on closer inspection: output `{ "structural_changes": [], "files_to_update": ["<current reference file list>"], "description_changes": {} }`.

---

Collect result before proceeding to Phase 3.

## Phase 3 — Update reference files (parallel)

**Orchestrator: before spawning agents**, build a `file → docs_pages` mapping. For each file in `files_to_update`, match its `description` keywords against the fetched docs pages (by URL path segment and topic keywords). Assign each page to its best-matching file. Log any docs pages that match no file — these are potential reference gaps.

**Orchestrator: when spawning each update agent**, inline into its prompt:
- The matched docs page content under `## Relevant docs`
- All changelog entries under `## Changelog`

Filter before inlining — pass only the matched docs pages, not all pages. If a file's matched docs content is empty (no pages matched or all fetched with errors), set that file's status to `error: "no docs context available"` without spawning an agent.

Spawn one agent per file in a single message.

**Agent: update-<filename>** (sonnet, Read + Write)

Your prompt contains inlined context:
- `## Relevant docs` — fetched docs pages matched to this file's topic
- `## Changelog` — all changelog entries

1. Read the target file.
2. Compare it against the relevant docs and changelog. Identify what is outdated, missing, or incorrect.
3. If changes are needed: rewrite with updated content. Apply the polish rules below in this same pass — do not leave them for a later step.
4. If already current: skip writing.

**Update rules:**
- State current behavior only. Do not add version annotations or changelog history.
- Keep forward-looking compatibility notes ("requires v2.0+", "Max plan only") — these are current state, not history.

**Polish rules (apply in the same pass):**
- Remove backward-looking language: "fixed in v2.x.y", "as of version…", "previously…", "was…but now…".
- Remove patchy accumulation: bolted-on footnotes, redundant caveats, "note: this also applies to X" asides that should be woven into the main text.
- Merge accreted paragraphs about the same feature into a single unified description.
- Do not add new information. Do not remove accurate current-state facts.

Preserve YAML frontmatter exactly. Output: `{ "file": "<name>", "status": "updated|up_to_date|error", "changes": ["<one-liner>"] }`.

---

Collect all results. Log any agent that returned `status: "error"` with its full output. Retry once with narrower scope. If >50% fail, halt and surface to user.

If docs-fetcher reported more than 2 fetch errors: run Phase 3 agents in batches of 3 rather than all-parallel.

Log any docs pages that were not assigned to any file — surface in Final Output as potential gaps.

## Phase 4 — Update MEMORY.md index (sequential)

**Agent: memory-index-updater** (haiku, Read + Bash + Write)

Inputs from prior phases:
- `files_to_update` list and `description_changes` map from Phase 2
- Phase 3 results (which files were written or created)

1. Read `/Users/jessicaterry/.claude/memory/MEMORY.md`
2. Run `ls /Users/jessicaterry/.claude/memory/*.md` to verify current disk state
3. Compare:
   - Files on disk but not indexed → read frontmatter, add entry
   - Files indexed but not on disk → remove entry
   - Files in `description_changes` → update their index entry to match new description
4. Write MEMORY.md only if changes needed. Do not change structure, section headers, or ordering beyond additions/removals.

Output: `{ "status": "updated|up_to_date|error", "added": [], "removed": [], "descriptions_updated": [] }`.

---

## Final Output

Report to user in this order:
1. **Changelog staleness** — date of cache, warning if stale
2. **Structural changes (Phase 2)** — files merged, split, or deleted with reasoning; or "none needed"
3. **Docs gaps** — any fetched docs pages that matched no reference file
4. **Updated files** — list with one-liner per change
5. **Already current** — list of unchanged files
6. **Errors** — any failures with reason
7. **MEMORY.md** — updated or unchanged

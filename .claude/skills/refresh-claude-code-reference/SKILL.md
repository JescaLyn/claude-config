---
name: refresh-claude-code-reference
description: Refresh all Claude Code reference files in ~/.claude/memory/ from current docs and changelog.
user-invocable: true
model: sonnet
---

## Phase 1 — Research (parallel)

Run all four in a single message (2 Agent calls + 2 Bash calls):

**docs-fetcher** — read `~/.claude/skills/refresh-claude-code-reference/agents/docs-fetcher.md` and spawn as Agent (haiku, WebFetch + Read). Self-contained; no additional input needed.

---

**changelog-parser** — read `~/.claude/skills/refresh-claude-code-reference/agents/changelog-parser.md` and spawn as Agent (haiku, Read + Bash). Self-contained; no additional input needed.

---

**inventory-memory** (script)

```bash
bash ~/.claude/skills/refresh-claude-code-reference/scripts/inventory-memory.sh
```

Outputs JSON: `{ "files": [{ "path", "filename", "name", "type", "description" }], "memory_md_content" }`. Capture it.

---

**check-changelog-staleness** (script)

```bash
bash ~/.claude/skills/refresh-claude-code-reference/scripts/check-changelog-staleness.sh
```

Outputs JSON: `{ "mtime_date", "age_days", "is_stale", "warning" }`. Capture it.

---

Collect all four results before proceeding.

If `is_stale` is true: warn the user with the `warning` string. Ask if they want to continue or abort.

## Phase 2 — Architecture check (sequential, two-step)

### Quick pre-check (haiku)

Using only the inventory-memory output (filenames and descriptions — no file reads), answer: does the current set of reference files have any obvious structural problems? Look for:
- Two files whose descriptions are nearly synonymous or heavily overlapping
- A file whose description suggests it covers two unrelated use cases
- A file whose description no longer matches its name

Output: `{ "restructure_warranted": true|false, "signals": ["<one-liner per signal>"] }`.

If `restructure_warranted` is false: filter `inventory-memory.files` to `type == "reference"`, use their `path` values as `files_to_update`, set `structural_changes: []` and `description_changes: {}`, and proceed to Phase 3.

### Full review (sonnet, only if pre-check returned `restructure_warranted: true`)

Read `~/.claude/skills/refresh-claude-code-reference/agents/architecture-reviewer.md`. Spawn as Agent (sonnet, Read + Bash + Write), prepending to its prompt:

```
## Input: inventory-memory output
<inventory-memory JSON>

## Input: structural signals from the quick pre-check
<signals list>
```

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

First, run the index diff script:

```bash
bash ~/.claude/skills/refresh-claude-code-reference/scripts/diff-memory-index.sh
```

Then read `~/.claude/skills/refresh-claude-code-reference/agents/memory-index-updater.md` and spawn as Agent (haiku, Read + Bash + Write), prepending to its prompt:

```
## Inputs
diff: <diff-memory-index.sh output JSON>
description_changes: <description_changes map from Phase 2>
```

## Final Output

Report to user in this order:
1. **Changelog staleness** — `mtime_date` from check-changelog-staleness.sh, warning if stale
2. **Structural changes (Phase 2)** — files merged, split, or deleted with reasoning; or "none needed"
3. **Docs gaps** — any fetched docs pages that matched no reference file
4. **Updated files** — list with one-liner per change
5. **Already current** — list of unchanged files
6. **Errors** — any failures with reason
7. **MEMORY.md** — updated or unchanged

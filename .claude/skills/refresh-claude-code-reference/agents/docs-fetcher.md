---
name: docs-fetcher
description: Fetches current Claude Code documentation pages for refresh-claude-code-reference.
model: haiku
tools: WebFetch, Read
---

Fetch current Claude Code documentation. For each URL below, fetch the page and extract full text content.

URLs to fetch:
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

#!/usr/bin/env bash
set -euo pipefail
# Diff disk state against MEMORY.md index entries.
# Usage: diff-memory-index.sh [memory-dir]
# Output JSON: { "on_disk_not_indexed": [...], "indexed_not_on_disk": [...] }

MEMORY_DIR="${1:-$HOME/.claude/memory}"
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"

if [[ ! -f "$MEMORY_INDEX" ]]; then
  echo '{"error": "MEMORY.md not found"}' >&2
  exit 1
fi

python3 - "$MEMORY_DIR" "$MEMORY_INDEX" <<'PYEOF'
import sys, os, re, json

memory_dir = sys.argv[1]
index_path = sys.argv[2]

on_disk = set()
for fname in os.listdir(memory_dir):
    if fname.endswith('.md') and fname != 'MEMORY.md':
        on_disk.add(fname)

indexed = set()
with open(index_path) as f:
    for line in f:
        m = re.search(r'\[([^\]]+)\]\(([^)]+\.md)\)', line)
        if m:
            indexed.add(m.group(2))

print(json.dumps({
    "on_disk_not_indexed": sorted(on_disk - indexed),
    "indexed_not_on_disk": sorted(indexed - on_disk)
}, indent=2))
PYEOF

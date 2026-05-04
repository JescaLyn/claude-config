#!/usr/bin/env bash
set -euo pipefail
# Inventory ~/.claude/memory/ — outputs JSON for refresh-claude-code-reference.
# JSON shape: { "files": [{ "path", "filename", "name", "type", "description" }], "memory_md_content": "" }

MEMORY_DIR="$HOME/.claude/memory"

if [[ ! -d "$MEMORY_DIR" ]]; then
  echo '{"error": "memory directory not found", "files": [], "memory_md_content": ""}' >&2
  exit 1
fi

python3 - "$MEMORY_DIR" <<'PYEOF'
import sys, os, json

memory_dir = sys.argv[1]

def extract_frontmatter(path):
    fields = {"name": "", "type": "", "description": ""}
    try:
        with open(path) as f:
            count = 0
            for line in f:
                line = line.rstrip()
                if line == "---":
                    count += 1
                    if count == 2:
                        break
                    continue
                if count == 1:
                    for key in fields:
                        if line.startswith(key + ":"):
                            fields[key] = line[len(key)+1:].strip().strip('"')
    except Exception as e:
        sys.stderr.write(f"Warning: could not parse {path}: {e}\n")
    return fields

files = []
try:
    for fname in sorted(os.listdir(memory_dir)):
        if not fname.endswith(".md") or fname == "MEMORY.md":
            continue
        fpath = os.path.join(memory_dir, fname)
        fm = extract_frontmatter(fpath)
        files.append({
            "path": fpath,
            "filename": fname,
            "name": fm["name"],
            "type": fm["type"],
            "description": fm["description"]
        })
except Exception as e:
    sys.stderr.write(f"Error listing memory dir: {e}\n")
    sys.exit(1)

memory_md = ""
mpath = os.path.join(memory_dir, "MEMORY.md")
try:
    with open(mpath) as f:
        memory_md = f.read()
except Exception as e:
    sys.stderr.write(f"Warning: could not read MEMORY.md: {e}\n")

print(json.dumps({"files": files, "memory_md_content": memory_md}, indent=2))
PYEOF

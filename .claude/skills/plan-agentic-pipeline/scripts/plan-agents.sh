#!/bin/bash

# plan-agents.sh - Steps 1 & 3 of the plan-agentic-pipeline skill
# Step 1: Inventory agents & saved pipeline skills
# Step 3: Estimate complexity from $ARGUMENTS

set -euo pipefail

AGENTS_DIR="$HOME/.claude/agents"
SKILLS_DIR="$HOME/.claude/skills"

# Helper: Extract YAML frontmatter field
extract_frontmatter() {
    local file="$1"
    local field="$2"

    # Extract between --- markers, find field: value (handle quotes), trim whitespace
    sed -n '/^---$/,/^---$/p' "$file" | \
    grep "^${field}:" | \
    sed -e 's/^[^:]*: *//' -e 's/"//g' | \
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | \
    head -1
}

# Step 1: Inventory agents & saved pipeline skills
inventory_agents() {
    local agents_json="[]"

    if [[ -d "$AGENTS_DIR" ]]; then
        while IFS= read -r agent_file; do
            local name description model
            name=$(extract_frontmatter "$agent_file" "name")
            description=$(extract_frontmatter "$agent_file" "description")
            model=$(extract_frontmatter "$agent_file" "model")

            # Default model to sonnet if not specified
            model="${model:-sonnet}"

            if [[ -n "$name" ]]; then
                agents_json=$(echo "$agents_json" | jq \
                    --arg n "$name" \
                    --arg d "$description" \
                    --arg m "$model" \
                    '. += [{"name": $n, "description": $d, "model": $m}]')
            fi
        done < <(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" -type f)
    fi

    echo "$agents_json"
}

# Step 1: Inventory saved pipeline skills
inventory_pipelines() {
    local pipelines_json="[]"

    if [[ -d "$SKILLS_DIR" ]]; then
        while IFS= read -r skill_file; do
            local name description
            name=$(extract_frontmatter "$skill_file" "name")
            description=$(extract_frontmatter "$skill_file" "description")

            if [[ -n "$name" ]]; then
                pipelines_json=$(echo "$pipelines_json" | jq \
                    --arg n "$name" \
                    --arg d "$description" \
                    '. += [{"name": $n, "description": $d}]')
            fi
        done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name "SKILL.md" -type f)
    fi

    echo "$pipelines_json"
}

# Step 3: Estimate complexity from arguments
estimate_complexity() {
    local arguments="$1"

    # Keywords to count
    local keywords="agent phase parallel adaptive routing cross-cutting"
    local count=0
    local found_keywords_json="[]"

    # Convert to lowercase for case-insensitive matching (using tr for portability)
    local args_lower
    args_lower=$(echo "$arguments" | tr '[:upper:]' '[:lower:]')

    # Count keyword occurrences
    for keyword in $keywords; do
        local occurrences
        occurrences=$(echo "$args_lower" | grep -o "$keyword" | wc -l | tr -d ' ')
        if (( occurrences > 0 )); then
            count=$((count + occurrences))
            found_keywords_json=$(echo "$found_keywords_json" | jq \
                --arg kw "$keyword" \
                --arg cnt "$occurrences" \
                ". += [{\"keyword\": \$kw, \"count\": (\$cnt | tonumber)}]")
        fi
    done

    # Check for "adaptive" or "cross-cutting" (automatic complex classification)
    local is_complex=false
    if echo "$args_lower" | grep -qE "(adaptive|cross-cutting)" || (( count >= 4 )); then
        is_complex=true
    fi

    local complexity="simple"
    [[ "$is_complex" == true ]] && complexity="complex"

    # Build estimated agent count (rough heuristic: ~1-2 per phase, ~1-2 for routing, 1 for synthesis)
    local phase_count
    phase_count=$(echo "$args_lower" | grep -o "phase" | wc -l | tr -d ' ')
    local agent_count_estimate=$((phase_count * 2 + 2))  # 2 agents per phase + 2 for overhead
    [[ $agent_count_estimate -lt 1 ]] && agent_count_estimate=1

    jq -n \
        --arg complexity "$complexity" \
        --argjson keywords "$found_keywords_json" \
        --argjson agent_count "$agent_count_estimate" \
        '{complexity: $complexity, keywords_found: $keywords, agent_count_estimate: $agent_count}'
}

# Main execution
main() {
    local arguments="${1:-}"

    # Step 1: Inventory
    local agents
    agents=$(inventory_agents)
    local pipelines
    pipelines=$(inventory_pipelines)

    # Step 3: Estimate complexity
    local complexity_data
    complexity_data=$(estimate_complexity "$arguments")

    # Merge and output JSON
    jq -n \
        --argjson agents "$agents" \
        --argjson pipelines "$pipelines" \
        --argjson complexity "$complexity_data" \
        '{agents: $agents, pipelines: $pipelines, complexity: $complexity}'
}

main "$@"

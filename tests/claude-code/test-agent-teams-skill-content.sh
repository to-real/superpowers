#!/usr/bin/env bash
# Test: Agent Teams skill content guards
# Verifies Team Mode wording, gates, ordering, and fallback rules in skill docs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILED=0

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILED=$((FAILED + 1))
}

assert_contains_file() {
    local file="$1"
    local pattern="$2"
    local name="$3"

    if grep -Eq "$pattern" "$file"; then
        pass "$name"
    else
        fail "$name"
    fi
}

assert_order_in_file() {
    local file="$1"
    local pattern_a="$2"
    local pattern_b="$3"
    local name="$4"

    local line_a
    local line_b
    line_a=$(grep -nE "$pattern_a" "$file" | head -1 | cut -d: -f1 || true)
    line_b=$(grep -nE "$pattern_b" "$file" | head -1 | cut -d: -f1 || true)

    if [ -z "$line_a" ] || [ -z "$line_b" ]; then
        fail "$name"
        return
    fi

    if [ "$line_a" -lt "$line_b" ]; then
        pass "$name"
    else
        fail "$name"
    fi
}

echo "=== Test: Agent Teams skill content guards ==="
echo ""

WRITING_PLANS="$REPO_ROOT/skills/writing-plans/SKILL.md"
PARALLEL_AGENTS="$REPO_ROOT/skills/dispatching-parallel-agents/SKILL.md"
SUBAGENT_DEV="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
EXECUTING_PLANS="$REPO_ROOT/skills/executing-plans/SKILL.md"
REQUEST_REVIEW="$REPO_ROOT/skills/requesting-code-review/SKILL.md"

echo "Test 1: Capability gates are documented..."
assert_contains_file "$WRITING_PLANS" "Capability gate before offering options" "writing-plans has capability gate section"
assert_contains_file "$SUBAGENT_DEV" "Team Mode capability gate" "subagent-driven-development has capability gate section"
assert_contains_file "$PARALLEL_AGENTS" "Capability gate" "dispatching-parallel-agents has capability gate section"
echo ""

echo "Test 2: Team Mode is conditional..."
assert_contains_file "$WRITING_PLANS" "If available, offer Team-Based mode as Option 3" "writing-plans offers Team-Based conditionally"
assert_contains_file "$WRITING_PLANS" "When team primitives are unavailable" "writing-plans has non-team branch"
echo ""

echo "Test 3: Review gate ordering is explicit..."
assert_contains_file "$SUBAGENT_DEV" "Only after spec pass, dispatch code quality reviewer teammate" "team review gate is explicit"
assert_order_in_file "$SUBAGENT_DEV" "Dispatch spec compliance reviewer teammate" "Only after spec pass, dispatch code quality reviewer teammate" "spec review appears before code quality review"
echo ""

echo "Test 4: Fallback rules are present..."
assert_contains_file "$WRITING_PLANS" "Fallback rule" "writing-plans has fallback rule"
assert_contains_file "$PARALLEL_AGENTS" "Fallback rule" "dispatching-parallel-agents has fallback rule"
assert_contains_file "$SUBAGENT_DEV" "Fallback rule" "subagent-driven-development has fallback rule"
assert_contains_file "$EXECUTING_PLANS" "Fallback rule" "executing-plans has fallback rule"
echo ""

echo "Test 5: Team task-state source of truth is explicit..."
assert_contains_file "$SUBAGENT_DEV" 'use shared `TaskList` only' "subagent-driven-development uses TaskList only in team mode"
assert_contains_file "$EXECUTING_PLANS" 'Team mode: `TaskList` is the source of truth' "executing-plans defines TaskList source of truth"
assert_contains_file "$REQUEST_REVIEW" "TaskList" "requesting-code-review references TaskList in team mode"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "=== FAILED: $FAILED checks failed ==="
    exit 1
fi

echo "=== All Agent Teams content guard checks passed ==="

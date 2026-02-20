#!/usr/bin/env bash
# Integration Test: Agent Teams workflow
# Validates Team Mode selection, review gate ordering, and fallback behavior.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Integration Test: Agent Teams workflow"
echo "========================================"
echo ""

# Gate: only run when Agent Teams experimental mode is enabled.
if [ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" != "1" ]; then
    echo "SKIP: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not set to 1"
    echo "Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to run this test."
    exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "SKIP: claude CLI not found in PATH"
    exit 0
fi

FAILED=0
SKIPPED=0

create_team_test_project() {
    local project_dir
    project_dir=$(create_test_project)

    mkdir -p "$project_dir/src" "$project_dir/test" "$project_dir/docs/plans"

    cat > "$project_dir/package.json" <<'EOF'
{
  "name": "agent-teams-test-project",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF

    cat > "$project_dir/docs/plans/implementation-plan.md" <<'EOF'
# Agent Teams Integration Test Plan

This plan is used to validate team-aware execution behavior.

## Task 1: Create Add Function

Create `src/add.js` exporting function `add(a, b)` returning `a + b`.

Add tests in `test/add.test.js` for:
- add(2, 3) = 5
- add(0, 0) = 0

Verification: `npm test`

## Task 2: Create Multiply Function

Create `src/multiply.js` exporting function `multiply(a, b)` returning `a * b`.

Add tests in `test/multiply.test.js` for:
- multiply(2, 3) = 6
- multiply(0, 5) = 0

Verification: `npm test`
EOF

    git -C "$project_dir" init --quiet
    git -C "$project_dir" config user.email "test@test.com"
    git -C "$project_dir" config user.name "Test User"
    git -C "$project_dir" add .
    git -C "$project_dir" commit -m "Initial commit" --quiet

    echo "$project_dir"
}

find_latest_session_file() {
    local working_dir="$1"
    local escaped
    escaped=$(echo "$working_dir" | sed 's/\//-/g' | sed 's/^-//')
    local session_dir="$HOME/.claude/projects/$escaped"

    find "$session_dir" -name "*.jsonl" -type f -mmin -90 2>/dev/null | sort -r | head -1
}

run_claude_capture() {
    local prompt="$1"
    local project_dir="$2"
    local output_file="$3"
    local timeout_seconds="${4:-1800}"

    cd "$SCRIPT_DIR/../.." && timeout "$timeout_seconds" claude -p "$prompt" --allowed-tools=all --add-dir "$project_dir" --permission-mode bypassPermissions 2>&1 | tee "$output_file"
}

echo "=== Scenario 1: Team mode execution preference ==="
echo ""

PROJECT_A=$(create_team_test_project)
OUTPUT_A="$PROJECT_A/claude-output-team.txt"
trap "cleanup_test_project '$PROJECT_A'; cleanup_test_project '${PROJECT_B:-}'" EXIT

PROMPT_A="Change to directory $PROJECT_A and execute docs/plans/implementation-plan.md using subagent-driven-development.

If team primitives are available, use Team Mode.
If team primitives are unavailable, explicitly fall back to standard Task mode.
Do not skip review gates: spec compliance review must happen before code quality review.
Begin now."

if run_claude_capture "$PROMPT_A" "$PROJECT_A" "$OUTPUT_A" 1800; then
    :
else
    echo "  [FAIL] Claude execution failed in Scenario 1"
    FAILED=$((FAILED + 1))
fi

SESSION_A=$(find_latest_session_file "$SCRIPT_DIR/../..")
if [ -z "$SESSION_A" ]; then
    echo "  [FAIL] Could not find session transcript for Scenario 1"
    FAILED=$((FAILED + 1))
else
    echo "Analyzing session: $(basename "$SESSION_A")"

    echo "Test 1: Skill invocation..."
    if grep -q '"name":"Skill".*"skill":"superpowers:subagent-driven-development"' "$SESSION_A"; then
        echo "  [PASS] subagent-driven-development skill invoked"
    else
        echo "  [FAIL] subagent-driven-development skill not invoked"
        FAILED=$((FAILED + 1))
    fi

    echo "Test 2: Team mode selected only when available..."
    team_tool_count=$(grep -Ec '"name":"(TeamCreate|Teammate|SendMessage|TaskCreate|TaskUpdate|TaskList|TaskGet)"' "$SESSION_A" || true)
    standard_task_count=$(grep -Ec '"name":"Task"' "$SESSION_A" || true)
    fallback_mentions=$(grep -Eic 'fall back|fallback|team primitives.*unavailable|switching to standard' "$OUTPUT_A" || true)

    if [ "$team_tool_count" -gt 0 ]; then
        echo "  [PASS] Team primitives used ($team_tool_count calls)"
    elif [ "$standard_task_count" -gt 0 ] && [ "$fallback_mentions" -gt 0 ]; then
        echo "  [PASS] Explicit fallback to standard Task mode observed"
    else
        echo "  [FAIL] Neither Team Mode usage nor explicit fallback was observed"
        FAILED=$((FAILED + 1))
    fi

    echo "Test 3: Review gate ordering..."
    spec_line=$(grep -nE 'spec compliance|spec reviewer' "$SESSION_A" | head -1 | cut -d: -f1 || true)
    quality_line=$(grep -nE 'code quality reviewer|code quality' "$SESSION_A" | head -1 | cut -d: -f1 || true)
    if [ -n "$spec_line" ] && [ -n "$quality_line" ] && [ "$spec_line" -lt "$quality_line" ]; then
        echo "  [PASS] Spec review appears before code quality review"
    else
        echo "  [FAIL] Could not confirm spec-before-quality ordering"
        FAILED=$((FAILED + 1))
    fi
fi

echo ""
echo "=== Scenario 2: Fallback path when team call fails (best effort) ==="
echo ""

PROJECT_B=$(create_team_test_project)
OUTPUT_B="$PROJECT_B/claude-output-fallback.txt"

PROMPT_B="Change to directory $PROJECT_B and execute Task 1 from docs/plans/implementation-plan.md.

Try Team Mode first, but intentionally use an invalid team configuration to force a team-tool failure.
If a team call fails, explicitly say you are falling back to standard Task mode, then continue and finish Task 1.
Do not stop on the team-tool failure."

if run_claude_capture "$PROMPT_B" "$PROJECT_B" "$OUTPUT_B" 900; then
    :
else
    echo "  [WARN] Claude execution failed in Scenario 2 before fallback verification"
    SKIPPED=$((SKIPPED + 1))
fi

SESSION_B=$(find_latest_session_file "$SCRIPT_DIR/../..")
if [ -n "$SESSION_B" ]; then
    team_failure_seen=$(grep -Eic 'team.*(failed|failure|error|invalid)|TeamCreate.*(failed|error)' "$OUTPUT_B" || true)
    fallback_seen=$(grep -Eic 'fall back|fallback|switching to standard|standard Task mode' "$OUTPUT_B" || true)
    standard_task_seen=$(grep -Ec '"name":"Task"' "$SESSION_B" || true)

    if [ "$team_failure_seen" -gt 0 ]; then
        if [ "$fallback_seen" -gt 0 ] && [ "$standard_task_seen" -gt 0 ]; then
            echo "  [PASS] Team failure observed and fallback to standard Task mode confirmed"
        else
            echo "  [FAIL] Team failure observed but fallback behavior not confirmed"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  [SKIP] Could not induce a team primitive failure in this environment"
        SKIPPED=$((SKIPPED + 1))
    fi
else
    echo "  [SKIP] No transcript found for Scenario 2"
    SKIPPED=$((SKIPPED + 1))
fi

echo ""
echo "========================================"
echo " Agent Teams Integration Summary"
echo "========================================"
echo "Failed:  $FAILED"
echo "Skipped: $SKIPPED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "STATUS: FAILED"
    exit 1
fi

echo "STATUS: PASSED"
exit 0

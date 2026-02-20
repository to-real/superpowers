#!/usr/bin/env bash
# Verification script for Agent Teams minimal E2E test
# Validates that the calculator project was implemented correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh" 2>/dev/null || true

PROJECT_DIR="${1:-}"
FAILED=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=$((FAILED + 1)); }
skip() { echo "  [SKIP] $1"; }

if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    echo "Usage: $0 <project-directory>"
    echo "Example: $0 /tmp/calculator-test"
    exit 1
fi

echo "=== Verifying Calculator Test Project ==="
echo "Project: $PROJECT_DIR"
echo ""

# Navigate to project
cd "$PROJECT_DIR"

# Test 1: File structure exists
echo "Test 1: File structure..."
for file in src/add.js src/multiply.js src/index.js test/add.test.js test/multiply.test.js; do
    if [ -f "$file" ]; then
        pass "$file exists"
    else
        fail "$file missing"
    fi
done
echo ""

# Test 2: Module exports exist
echo "Test 2: Module exports..."
if node -e "import('./src/add.js').then(m => { if (typeof m.add === 'function') process.exit(0) else process.exit(1) })" 2>/dev/null; then
    pass "add.js exports add function"
else
    fail "add.js does not export add function"
fi

if node -e "import('./src/multiply.js').then(m => { if (typeof m.multiply === 'function') process.exit(0) else process.exit(1) })" 2>/dev/null; then
    pass "multiply.js exports multiply function"
else
    fail "multiply.js does not export multiply function"
fi

if node -e "import('./src/index.js').then(m => { if (typeof m.add === 'function' && typeof m.multiply === 'function') process.exit(0) else process.exit(1) })" 2>/dev/null; then
    pass "index.js exports both add and multiply"
else
    fail "index.js does not export both functions"
fi
echo ""

# Test 3: Input validation
echo "Test 3: Input validation..."
if node -e "import('./src/add.js').then(m => { try { m.add('2', 3); process.exit(1); } catch(e) { process.exit(0); } })" 2>/dev/null; then
    pass "add() validates input types"
else
    fail "add() does not validate input types"
fi

if node -e "import('./src/multiply.js').then(m => { try { m.multiply('2', 3); process.exit(1); } catch(e) { process.exit(0); } })" 2>/dev/null; then
    pass "multiply() validates input types"
else
    fail "multiply() does not validate input types"
fi
echo ""

# Test 4: Tests exist and pass
echo "Test 4: Test suite..."
if command -v node >/dev/null 2>&1; then
    if npm test >/dev/null 2>&1; then
        pass "All tests pass (npm test)"
    else
        fail "Tests failed (npm test)"
        echo "       Run 'npm test' in project to see details"
    fi
else
    skip "node not found, cannot run tests"
fi
echo ""

# Test 5: Git state
echo "Test 5: Git state..."
if git rev-parse --git-dir >/dev/null 2>&1; then
    pass "Git repository initialized"
    if [ -n "$(git status --porcelain)" ]; then
        pass "Project has changes (implementation done)"
    else
        fail "No changes detected (implementation may not have run)"
    fi
else
    skip "Not a git repository"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed!"
    exit 0
else
    echo "$FAILED check(s) failed"
    exit 1
fi

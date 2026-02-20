#!/usr/bin/env bash
# Setup script for Agent Teams minimal E2E test
# Creates a ready-to-use calculator-test project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_BASE="${TEST_BASE:-/tmp}"

PROJECT_NAME="${1:-calculator-test}"
PROJECT_DIR="$TEST_BASE/$PROJECT_NAME"

echo "=== Creating Agent Teams E2E Test Project ==="
echo "Location: $PROJECT_DIR"
echo ""

# Clean up existing directory if present
if [ -d "$PROJECT_DIR" ]; then
    echo "Removing existing directory..."
    rm -rf "$PROJECT_DIR"
fi

# Create directory structure
mkdir -p "$PROJECT_DIR/docs/plans"
mkdir -p "$PROJECT_DIR/src"
mkdir -p "$PROJECT_DIR/test"

# Create package.json
cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "calculator-test",
  "version": "1.0.0",
  "description": "Minimal test project for Agent Teams integration",
  "type": "module",
  "scripts": {
    "test": "node --test"
  },
  "keywords": ["test", "calculator"],
  "author": "",
  "license": "MIT"
}
EOF

# Create implementation plan
cat > "$PROJECT_DIR/docs/plans/calculator-implementation.md" << 'EOF'
# Calculator Module Implementation Plan

## Task 1: Add Function

Create `src/add.js` exporting a function `add(a, b)` that returns the sum of `a` and `b`.

Requirements:
- Must validate both inputs are numbers
- Must throw TypeError if validation fails
- Must return the numeric sum

Create `test/add.test.js` with tests for:
- add(2, 3) returns 5
- add(-1, 1) returns 0
- add(0, 0) returns 0
- add("2", 3) throws TypeError
- add(2, "3") throws TypeError

Verification: `npm test`

## Task 2: Multiply Function

Create `src/multiply.js` exporting a function `multiply(a, b)` that returns the product of `a` and `b`.

Requirements:
- Must validate both inputs are numbers
- Must throw TypeError if validation fails
- Must return the numeric product

Create `test/multiply.test.js` with tests for:
- multiply(2, 3) returns 6
- multiply(-2, 3) returns -6
- multiply(0, 5) returns 0
- multiply("2", 3) throws TypeError
- multiply(2, "3") throws TypeError

Verification: `npm test`

## Task 3: Index Export

Create `src/index.js` that re-exports `add` and `multiply` from their respective modules.

Requirements:
- Named export `add` from `./add.js`
- Named export `multiply` from `./multiply.js`
- No additional logic or validation

Verification: Import from `src/index.js` and verify both functions are available.
EOF

# Create README for the test project
cat > "$PROJECT_DIR/README.md" << 'EOF'
# Calculator Test Project

Minimal test project for validating Agent Teams integration.

## Purpose

This project is designed to test Agent Teams functionality with:
- 3 independent implementation tasks
- Clear parallel execution opportunities (Tasks 1 & 2)
- A sequential dependency task (Task 3)

## Usage

### For Manual Testing

```bash
npm install  # if dependencies are added
npm test
```

### For Agent Teams Testing

Use the following prompt:

```
Use subagent-driven-development to execute docs/plans/calculator-implementation.md.

If Team Mode is available, use Team Mode.
Verify that:
1. Team is created correctly
2. Independent tasks (1 & 2) execute in parallel
3. Review gates execute in order (spec → quality)
4. Team is cleaned up properly
```

## Expected Structure After Implementation

```
src/
├── add.js       # add(a, b) function with validation
├── multiply.js  # multiply(a, b) function with validation
└── index.js     # exports { add, multiply }

test/
├── add.test.js
└── multiply.test.js
```
EOF

# Initialize git
cd "$PROJECT_DIR"
git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"
git add .
git commit -m "Initial commit: Calculator test project" --quiet

echo ""
echo "=== Test project created successfully ==="
echo ""
echo "Project location: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
echo "  # Then invoke Claude Code with:"
echo '  claude -p "Use subagent-driven-development to execute docs/plans/calculator-implementation.md. If Team Mode is available, use it."'
echo ""

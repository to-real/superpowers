# Agent Teams Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add capability-gated Agent Teams integration to existing Superpowers execution skills while preserving current subagent behavior by default.

**Architecture:** Extend current execution skills with explicit Team Mode branches (capability-gated + opt-in), enforce review gates via team task state, and add tests for mode selection and gating.

**Tech Stack:** Markdown skill specs, Claude Code tool model, shell-based integration tests.

---

### Task 1: Add Team Mode option in planning handoff

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

**Step 1: Add capability detection guidance in Execution Handoff**

Update handoff text to include a capability gate check before execution options are shown.

**Step 2: Add Team-Based option (conditional)**

Add Option 3 only when team primitives are available; keep Options 1-2 unchanged.

**Step 3: Add fallback rule**

Document: if team tool calls fail, immediately fall back to Subagent-Driven flow.

**Step 4: Verify wording is unambiguous**

Run: `Select-String -Path skills/writing-plans/SKILL.md -Pattern 'Team-Based|capability|fallback'`
Expected: Team mode is explicitly conditional and fallback is documented.

---

### Task 2: Extend parallel dispatch skill with Team Mode

**Files:**
- Modify: `skills/dispatching-parallel-agents/SKILL.md`

**Step 1: Add Team Mode section**

Document when to use team orchestration vs standard Task-based dispatch.

**Step 2: Add explicit team dispatch pattern**

Include create -> assign -> collect -> integrate -> shutdown sequence.

**Step 3: Add standalone detection note**

Clarify where capability detection happens and what to do when this skill is used standalone.

**Step 4: Verify mode branching text**

Run: `Select-String -Path skills/dispatching-parallel-agents/SKILL.md -Pattern 'Team Mode|Task|fallback|capability'`
Expected: Both standard and team paths are documented with no ambiguity.

---

### Task 3: Add Team Mode branch to subagent-driven-development

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`

**Step 1: Update when-to-use decision tree**

Add branch for Team Mode selection when capabilities exist + user opts in.

**Step 2: Define team lifecycle and state tracking**

Document create-once/reuse/delete lifecycle and `TaskList` as source of truth in team mode.

**Step 3: Encode hard review gates**

Make the ordering non-optional: spec review must pass before code quality review starts.

**Step 4: Add team-specific red flags**

Include disallowing parallel implementers on coupled tasks and disallowing gate bypass.

**Step 5: Verify review-gate ordering text**

Run: `Select-String -Path skills/subagent-driven-development/SKILL.md -Pattern 'spec|code quality|TaskList|Team|Never'`
Expected: Spec-before-quality ordering is explicit and non-skippable.

---

### Task 4: Add within-batch Team Mode to executing-plans

**Files:**
- Modify: `skills/executing-plans/SKILL.md`

**Step 1: Add team preflight section**

Document team capability check and user choice before batch execution.

**Step 2: Define batch-level team behavior**

Allow parallel execution of independent tasks within a batch, preserving checkpoint reporting.

**Step 3: Clarify lifecycle strategy**

Use one explicit lifecycle strategy (create once, reuse across batches, delete at end).

**Step 4: Clarify tracking source**

Document `TaskList` as team-mode tracking source to avoid split-brain with `TodoWrite`.

**Step 5: Verify lifecycle wording**

Run: `Select-String -Path skills/executing-plans/SKILL.md -Pattern 'TeamCreate|TeamDelete|TaskList|batch|checkpoint'`
Expected: One consistent lifecycle policy with clear checkpoint behavior.

---

### Task 5: Add team-aware review collaboration guidance

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md`
- Optional modify: `skills/requesting-code-review/code-reviewer.md`

**Step 1: Add team-mode review path**

Document reviewer assignment and feedback routing in team context.

**Step 2: Preserve existing subagent path**

Ensure no regression in current Task-based review instructions.

**Step 3: Verify dual-path clarity**

Run: `Select-String -Path skills/requesting-code-review/SKILL.md -Pattern 'team|subagent|review'`
Expected: Team and subagent review flows are both explicit.

---

### Task 6: Add fast tests for Team Mode wording and gate rules

**Files:**
- Create: `tests/claude-code/test-agent-teams-skill-content.sh`
- Modify: `tests/claude-code/run-skill-tests.sh`

**Step 1: Create content-level assertions**

Check for:
- capability gate language
- conditional Team Mode offering
- spec-before-quality ordering
- fallback instructions

**Step 2: Integrate into fast test runner**

Add script to default fast test set.

**Step 3: Verify local shell syntax**

Run: `bash -n tests/claude-code/test-agent-teams-skill-content.sh`
Expected: no syntax errors.

---

### Task 7: Add optional integration test for Team Mode

**Files:**
- Create: `tests/claude-code/test-agent-teams-integration.sh`
- Modify: `tests/claude-code/run-skill-tests.sh`

**Step 1: Add opt-in env guard**

Skip test unless Agent Teams experimental mode is enabled.

**Step 2: Validate critical behavior**

Assert:
- Team Mode selected only when available
- review gate ordering preserved
- fallback path works when team calls fail

**Step 3: Wire into `--integration` suite**

Add script under integration test group.

**Step 4: Verify shell syntax**

Run: `bash -n tests/claude-code/test-agent-teams-integration.sh`
Expected: no syntax errors.

---

### Task 8: Update user-facing documentation and release notes

**Files:**
- Modify: `README.md`
- Modify: `RELEASE-NOTES.md`
- Optional modify: `docs/README.codex.md`

**Step 1: Add concise Team Mode description**

Document this as optional and capability-gated.

**Step 2: Add migration expectations**

State that existing workflows still work unchanged.

**Step 3: Verify docs consistency**

Run: `Select-String -Path README.md,RELEASE-NOTES.md -Pattern 'Team Mode|Agent Teams|fallback|optional'`
Expected: messaging is consistent and non-breaking.

---

### Task 9: End-to-end verification before merge

**Files:**
- Verify all modified/created files

**Step 1: Run fast suite**

Run: `cd tests/claude-code && ./run-skill-tests.sh`
Expected: all fast tests pass.

**Step 2: Run integration suite in team-capable environment**

Run: `cd tests/claude-code && ./run-skill-tests.sh --integration`
Expected: team tests pass or are explicitly skipped when unavailable.

**Step 3: Spot-check changed skills**

Run:
- `Get-Content skills/writing-plans/SKILL.md`
- `Get-Content skills/subagent-driven-development/SKILL.md`
- `Get-Content skills/dispatching-parallel-agents/SKILL.md`
- `Get-Content skills/executing-plans/SKILL.md`

Expected: no conflicting lifecycle instructions, no ambiguous mode-selection text.

**Step 4: Prepare PR summary**

Include:
- what changed
- why this is backward compatible
- what tests were run and results

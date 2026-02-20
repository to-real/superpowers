---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute tasks in batches, report for review between batches.

**Core principle:** Batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

## Team Mode Preflight (Optional)

Before Step 1, check whether team primitives are available:
- `TeamCreate`
- `SendMessage`
- Shared `TaskList` tools

If available, ask whether to use Team Mode for within-batch parallel execution.

**Team lifecycle policy (explicit):**
- Run `TeamCreate` once before the first batch
- Reuse the same team across all batches
- Run `TeamDelete` only after the final batch completes

**Task tracking policy:**
- Standard mode: `TodoWrite` is the source of truth
- Team mode: `TaskList` is the source of truth
- Do not maintain both in parallel for the same run

**Fallback rule:**
- If team primitives fail repeatedly, fall back to standard sequential execution for remaining tasks

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns:
   - Standard mode: Create `TodoWrite` and proceed
   - Team mode: Initialize team task state in `TaskList` and proceed (no `TodoWrite`)

### Step 2: Execute Batch
**Default: First 3 tasks**

Standard mode (existing behavior), for each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

Team mode (within-batch parallelism):
1. Identify independent tasks in the current batch
2. Create/assign one team task per independent item (`TaskCreate`)
3. Execute those tasks in parallel and track progress in shared `TaskList`
4. Wait for all batch tasks to finish
5. Run batch verifications as specified
6. Update batch state in `TaskList`

### Step 3: Report
When batch complete:
- Show what was implemented
- Show verification output
- Show current checkpoint state (`TodoWrite` in standard mode, `TaskList` in team mode)
- Say: "Ready for feedback."

### Step 4: Continue
Based on feedback:
- Apply changes if needed
- Execute next batch
- In team mode, keep using the same team for the next batch
- Repeat until complete

### Step 5: Complete Development

After all tasks complete and verified:
- If team mode was used, clean up team resources (`TeamDelete`)
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Between batches: just report and wait
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent
- In team mode, use `TaskList` as single source of truth
- Never track the same team-mode tasks in both `TaskList` and `TodoWrite`

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:finishing-a-development-branch** - Complete development after all tasks

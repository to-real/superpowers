# Agent Teams Integration Design (Superpowers)

**Date:** 2026-02-20
**Status:** Proposed
**Owner:** Superpowers maintainers

## Goal

Integrate Anthropic Agent Teams into Superpowers without breaking existing subagent workflows, so users can choose between:

1. Subagent-driven execution (current default)
2. Parallel session execution (current)
3. Team-based execution (new, capability-gated)

## Scope

In scope:
- Team-aware execution paths in existing execution skills
- Unified team capability detection + fallback behavior
- Team task lifecycle and review gates
- Test coverage for team mode behavior

Out of scope:
- Replacing subagent workflows entirely
- Hard dependency on Agent Teams for non-Claude-Code platforms
- New mandatory skills for all users

## Current Gaps

1. Skills are Task-centric and not team-context aware
2. No canonical mapping between subagent tools and team primitives
3. No single source of truth for team task state
4. Review gates (spec before quality) are prose-only and can be skipped
5. No regression tests for team-mode behavior

## Options Considered

### Option A: Extend existing skills with capability-gated Team Mode (Recommended)

What it means:
- Keep current skills (`writing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `executing-plans`)
- Add a Team Mode branch only when team primitives are available and user opts in
- Keep current behavior unchanged otherwise

Pros:
- Backward compatible
- Lowest migration cost
- Minimal cognitive overhead for current users

Cons:
- Skill docs become longer
- Requires careful wording to avoid ambiguity

### Option B: Add a new standalone `team-driven-development` skill

Pros:
- Clear separation
- Cleaner skill text per mode

Cons:
- More skills to maintain
- Higher discovery/selection complexity
- Duplication risk with existing workflows

### Option C: Platform adapter only (no skill changes)

Pros:
- Minimal doc edits

Cons:
- Misses Superpowers' main value: workflow discipline in skill text
- Behavior becomes implicit and harder to test

## Decision

Adopt **Option A** in a phased rollout.

Rationale:
- Preserves existing successful workflows
- Allows controlled introduction with fallbacks
- Minimizes risk across Codex/OpenCode/Claude Code environments

## Target Architecture

### 1. Capability Gate

Team Mode is allowed only when all required team primitives are available.

Canonical gate (abstract):
- Team creation primitive available (`TeamCreate` or `Teammate` equivalent)
- Messaging primitive available (`SendMessage`)
- Shared task primitive available (`TaskList` + create/update/get equivalents)

Fallback rule:
- If gate fails or user declines Team Mode, continue with existing Task/subagent flow.

### 2. Execution Mode Selection

In `writing-plans` handoff:
- Always show Subagent-Driven and Parallel Session
- Show Team-Based only when capability gate passes
- Require explicit user opt-in for Team-Based

### 3. Team Lifecycle

Lifecycle (recommended default):
1. Create team once at run start
2. Reuse team across tasks/batches in same run
3. Delete team at end of run

Force-recreate conditions:
- Team creation fails repeatedly
- Team state becomes inconsistent
- Tool errors indicate corrupted task state

### 4. Task State Source of Truth

- Subagent mode: `TodoWrite`
- Team mode: shared `TaskList`

Rule:
- Do not maintain both as active state trackers in team mode.

### 5. Review Gates as Hard Workflow

Per implementation task in Team Mode:
1. Implementer reports completion
2. Spec reviewer validates against requirements
3. Only after spec pass, code quality reviewer runs
4. Task marked done only when both pass

## Risks and Mitigations

1. Ambiguous detection rules
- Mitigation: one canonical gate pattern reused across all skills

2. Workflow drift (model skips review)
- Mitigation: explicit non-skippable gate language + test assertions

3. Cross-platform regressions
- Mitigation: strict fallback to current flow when team primitives missing

4. Token/context growth
- Mitigation: keep team sections concise and reference shared wording

## Success Criteria

1. Existing non-team workflows behave unchanged
2. Team mode appears only when capabilities exist
3. Team mode enforces spec-before-quality review ordering
4. Team mode can recover/fallback cleanly on tool failure
5. New tests prevent regression on mode selection and review gating

## Rollout Plan

Phase 1: Skills text changes (gated Team Mode)
Phase 2: Team-focused tests (fast + integration)
Phase 3: Docs + release notes
Phase 4: Optional: evaluate standalone team skill based on usage data

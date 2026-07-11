# Phase 1 Overnight Failure Report

**Status:** Stopped at approved repair limit

**Recorded:** 2026-07-10 22:36:09 CDT

**Branch:** `feature/phase-1-playable-slice`

**Branch base:** `9b20be7`

**Blocked implementation head:** `ae7c277`

## Completed Work

Task 1, domain values and balance configuration, completed at `a7b3740` and passed independent review.

Verification after Task 1:

- Focused tests: 2 passed, 0 failed.
- Complete suite: 39 passed, 0 failed.

## Blocked Work

Task 2, deterministic combat and encounter transitions, did not pass independent review after both authorized repair cycles.

Commits:

- `cd823d2` - initial deterministic combat simulation.
- `095570f` - repair cycle 1, continuous timing repair.
- `ae7c277` - repair cycle 2, loop-progress repair.

Latest implementation verification:

- Focused `GameSimulationTests`: 12 passed, 0 failed.
- Complete suite: 51 passed, 0 failed.

Passing tests were not sufficient for acceptance because the final Terra review found unresolved timing-model defects outside the covered examples.

## Repair History

### Initial Review

The initial nanosecond normalization could lose valid elapsed time, fire events early, break chunk equivalence, and loop forever for accepted sub-nanosecond attack intervals.

### Repair Cycle 1

The first repair removed global nanosecond normalization, validated timers before mutation, and added sub-nanosecond and exact-order tests.

Re-review found:

- A `1e-20` repeating interval could still leave a one-second remaining budget unchanged and loop forever.
- An ULP residue clamp could fire a one-second attack at `1.0.nextDown` and create false ties.

### Repair Cycle 2

The second repair added candidate-copy rollback, a 100,000-event budget, strict adjacent-ULP ordering, and `Decimal` subtraction.

The decisive re-review found three unresolved Important issues:

1. `Decimal` cannot represent the full accepted finite `Double` range. Very small finite values can become `NaN`, causing countdowns to reach zero and attacks to fire incorrectly.
2. Repeated `Decimal` to `Double` round-tripping can break chunk equivalence at sub-nanosecond deadlines. One `1.2e-9` advance can fire while three `0.4e-9` advances leave a positive residue.
3. A per-call event budget makes outcomes depend on call chunking: one dense call can fail while equivalent smaller calls succeed. It can also perform substantial synchronous work before rejecting.

## Stop Decision

The approved overnight contract permits at most two focused repair cycles for a failing gate. Both cycles were used on the same Task 2 timing gate, so execution stopped.

- Tasks 3-10 were not started.
- The feature branch was not pushed.
- Nothing was merged into `main`.
- The worktree and all commits were preserved at `/Users/n3kr0/Projects/TBH/.worktrees/phase-1-playable-slice`.

## Evidence

Durable local evidence is stored in the ignored worktree ledger and reports:

- `.superpowers/sdd/progress.md`
- `.superpowers/sdd/task-2-report.md`
- `.superpowers/sdd/review-a7b3740..ae7c277.diff`

## Safest Next Action

Revise the simulation-time representation before resuming Task 2. The next design pass should choose one explicit deterministic time domain and supported range, then define chunk-invariance and event-density behavior within that domain. Patching additional `Double` or `Decimal` boundary cases onto the current loop is not recommended.

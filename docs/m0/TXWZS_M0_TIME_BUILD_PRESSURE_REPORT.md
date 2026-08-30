# TXWZS M0 Time, Construction, and Level Pressure Report

## Verdict

`PASS_LOCAL_ONLY_PENDING_FOUNDER_REVIEW`

The conditionally authorized M0 slice is implemented in an isolated worktree.
It is not merged, pushed, deployed, or presented as a frozen overall MVP.

## Canonical repository gate

| Field | Result |
| --- | --- |
| Canonical repository | `/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0` |
| Source branch | `codex/product-successor-inner-city-r0` |
| Source HEAD | `0b1c3b5b5e15c564105c0c745efab274110c9240` |
| Source status | clean before worktree creation; remained untouched |
| Isolated worktree | `/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0` |
| Candidate branch | `codex/txwzs-m0-time-build-pressure-r0` |
| Canonical evidence | `REPOSITORY_ROLE.md`, `docs/ops/REPOSITORY_IDENTITY_LOCK.md`, `CURRENT_STATE.md`, history, and runnable R3B tests |

The empty requested working directory and older reconstructed/restore candidates
were rejected as mutation roots. The product-successor repository is the sole
active mutable successor and descends from the documented canonical source.

## Baseline

- Godot `4.5.1.stable.official.f62fdbde1` was found at the repository's local
  tool location; no engine upgrade or dependency installation was performed.
- Existing dynamically discovered smoke runners: `44/44 PASS` before changes.
- Editor parse/import and the formal `blank_map`, Blackstone MVP, and C0 scenes
  passed headless smoke before changes.
- The source repository remained clean; all mutations occurred in the isolated
  candidate worktree.

## Implemented scope

- Reused the existing authoritative strategic clock with pause and 1x/2x/4x.
- Added deterministic 1000 ms construction ticks and cumulative incremental
  resource deduction through `NationState`.
- Added explicit missing-resource pause/resume without deleting or restarting
  the order.
- Added exactly three construction priorities with stable placement-ID
  tie-breaking.
- Added a persistent current-mainline object with day-7 deadline and five
  monotonic pressure stages.
- Added pressure modifiers, committed permanent losses, security mitigation,
  and 25% minimum channels for food, basic repair, medical care, basic training,
  and war supply.
- Kept battle attempt restore outside persistent mainline ownership.
- Upgraded campaign snapshot schema to 4 with V2/V3 migration and exact V4
  roundtrip coverage.
- Reused the existing HUD and building detail panel for deadline, pressure,
  security, missing-material feedback, progress/payment, and priority.

## Acceptance evidence

`tests/run_m0_time_build_pressure_smoke.gd` covers all eight required scenarios:

1. unified time ratios and global pause;
2. incremental progress/payment and pause stability;
3. missing-resource block and automatic resume;
4. deterministic high/normal/low priority competition;
5. all five monotonic pressure stages without automatic city loss;
6. security mitigation and all anti-softlock floors;
7. battle-attempt retry isolation from persistent mainline state;
8. V4 exact roundtrip and safe V3 migration without duplicate payment.

The final full suite is `45/45 PASS`, including road placement, construction,
battle settlement, national resource convergence, early V1 compatibility,
V5 cold-process persistence, army, training, city switching, and UI contracts.

## Visual evidence

- [Default running 1440x900](evidence/01-default-running-1440x900.png)
- [Default running 1280x720](evidence/02-default-running-1280x720.png)
- [Paused order with zero progress](evidence/03-paused-order-no-progress-1440x900.png)
- [Missing-material blocked order](evidence/04-blocked-missing-material-1440x900.png)
- [Overdue pressure stage](evidence/05-overdue-pressure-stage-1440x900.png)

All five were captured from native Godot Metal rendering and inspected. Key
text is readable at both target resolutions; the compact HUD does not overlap
the right rail, and construction detail states remain visible. A continuous
video was not recorded because no reliable native recording chain was available;
the deterministic scenario runner and static captures are the declared
substitute, as permitted by the instruction.

## Compatibility and trade-offs

- Immediate zero-duration roads preserve their existing atomic placement cost.
  Timed buildings use M0 incremental payment.
- The legacy S1A.1 early-city snapshot cannot represent sub-day construction
  progress after its old calendar completion day. It remains covered for its
  representable day-1-to-day-6 fixtures; authoritative campaign persistence is
  V4 and preserves the exact M0 state.
- Pressure numbers are prototype data and need Founder playtesting; architecture
  and lifecycle are validated, tuning is not claimed final.
- `BattleAttemptState` is the minimum non-persistent retry boundary. No new
  battle retry UX or combat behavior was added.

## Verification commands

- All `tests/run_*_smoke.gd` runners under Godot headless: `45/45 PASS`.
- M0 focused runner: `PASS`.
- V5 campaign persistence including three cold processes: `PASS`.
- Godot editor import/parse: `PASS`.
- Formal headless scene smokes: `PASS`.
- Native visual capture fixture: `PASS`.
- `git diff --check`: `PASS`.

## Rollback

No source repository state or remote state was modified. Rollback is to delete
or abandon the isolated worktree and branch. No user save, cache, deployment,
or remote branch must be repaired.

## Unverified / excluded

- Founder player-journey acceptance is not issued by this engineering run.
- Continuous native video is not recorded.
- Final balance, final art, war expansion, population simulation, equipment,
  trade, technology redesign, city security AI, push, merge, and deployment are
  excluded.

# Macro March R0 Engineering Report

## Scope

This local candidate implements a playable outer-city movement greybox only:
Blackstone City, Northwatch Garrison, Reedbank Garrison, two selectable
Blackstone-to-Northwatch roads, and a branch-road block/recovery scenario. It
does not implement enemy-city attack, siege victory, surrender, occupation,
energy, abilities, road construction, replenishment, 3D assets, or a second
army in transit.

## Ownership and transaction result

`ArmyRegistry` schema 2 owns the one durable macro order, including the
stable army identity, order identity, endpoint IDs, selected road polyline,
exact formation snapshots, fee, logical movement progress, and
`MARCHING`/`BLOCKED`/`STATIONED` phase. `GarrisonState` removes the selected
formation records exactly; it does not call its total-count compatibility
removal. `ConstructionController` retains food spending, full roster/registry
rollback, and runtime persistence checkpoint ownership.

The temporary food rule is the existing expedition formula
`ceil(committed soldiers / maintenance_units_per_food)`. It is documented as
an R0 reuse, not a final marching or siege-supply balance decision.

## Verification

| Check | Result |
| --- | --- |
| `run_macro_march_r0_smoke.gd` | PASS, 14 assertions: formal entry isolation, draft and route-condition zero-write failures, distinct routes, exact formations, payment idempotence, pause/speed, block/recovery, arrival, second order, and in-memory restore. |
| `run_macro_march_r0_persistence_smoke.gd` | PASS: three real Godot processes with an isolated `--txwzs-v5-save-dir`; blocked → restored/resumed/arrived → cold-restored stationed. |
| `run_v5_army_state_smoke.gd` | PASS. |
| `run_r1e_expedition_causality_smoke.gd` | PASS, 50 assertions. |
| Godot editor import; blank-map and C0 headless smoke | PASS. |

## Media status

A real candidate Godot window was started from the isolated worktree and
visually inspected during preflight. A different user Godot window remained in
the desktop controller's focus and the available UI API could not safely switch
to the candidate without moving/minimizing the user's window. Therefore the
required three real mouse-input screenshots and 45–90 second system-input
recording are **not provided**. No tests, direct controller calls, or generated
images are represented as those media artifacts.

## Candidate status

`MACRO_MARCH_ENGINEERING=PARTIAL_REAL_INPUT_MEDIA_NOT_PROVIDED`

`SIEGE_VICTORY_ACCEPTED=NO`

`FOUNDER_ACCEPTED=NO`

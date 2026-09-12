# Wartime Defense Spike-Trap GUI Evidence

Run date: 2026-09-12
Godot: `4.5.1.stable.official.f62fdbde1`
Candidate: route-local defensive-facility implementation in this change.

## Command and result

```text
save_dir=$(mktemp -d /tmp/txwzs-wartime-defense-spike-trap-gui.XXXXXX)
Godot --path . --rendering-driver opengl3 \
  --script res://tests/run_wartime_defense_graphical_smoke.gd \
  -- --txwzs-v5-save-dir="$save_dir" \
     --txwzs-wartime-defense-evidence-dir=docs/milestones/field-tactics-r2/evidence/20260912-wartime-defense-spike-trap

OpenGL API 4.1 Metal - Compatibility - Apple M4
PASS: visible defense planning
PASS: plan controls do not cover the battle routes at 1152x648, 1280x720, or 1920x1080
PASS: formal confirmation and construction
PASS: visible battle tick interrupts a barricade before completion
PASS: interrupted-work status and repair controls stay outside the side route
PASS: visible battle tick triggers a completed spike trap once at route arrival
PASS: visible formal gate repair starts saved time without covering the routes
PASS: true tick repair
WARTIME_DEFENSE_GRAPHICAL_SMOKE PASS assertions=12
```

The runner enters C0 through the normal Blackstone city entry, uses the visible
route and facility-plan controls, confirms through the formal request, and
captures a rendered frame after each UI refresh. It uses an isolated V5 save
directory and does not access a retained candidate save.

The current candidate reserves a left-bottom action rail for the plan, focused
facility status, and repair controls. The battle canvas retains an explicit
gap above that rail, so construction/repair feedback no longer sits on top of
the side-route geometry. This is a presentation-only layout adjustment: route
coordinates, battle ticks, resource transactions, and save ownership are
unchanged.

## Captures

- `wartime-defense-01-plan-engine-gui.png`: selected side-route plan with the
  visible watch platform, arrow tower, barricade, and spike-trap buttons.
- `wartime-defense-02-construction-engine-gui.png`: the confirmed request
  before construction ticks begin.
- `wartime-defense-03b-construction-interrupted-engine-gui.png`: an enemy
  arrival interrupts the unfinished barricade before it can project a block.
- `wartime-defense-03d-facility-repair-crew-engine-gui.png`: the visible
  facility-repair control has bound the selected `北门先锋` as its saved repair
  crew; the recent-action panel names that same formation and the barricade is
  still `REPAIRING`, not prematurely active.
- `wartime-defense-03c-spike-trap-triggered-engine-gui.png`: a completed trap
  triggers at the actual selected-route objective, writes one enemy-HP damage
  event, and is consumed.
- `wartime-defense-03-damaged-gate-engine-gui.png` through
  `wartime-defense-05-gate-repaired-engine-gui.png`: route-driven gate damage
  and the saved two-tick repair lifecycle in the same run.

## Evidence boundary

This is graphical **Godot engine GUI-event and root-viewport evidence**. To
keep the capture short, the runner places a controlled invader at the selected
route's actual objective immediately before one ordinary production tick. The
trap damage, facility consumption, event, and UI projection are still produced
by `BattleSession`; no enemy HP or facility phase is directly edited. The
separate R0 smoke proves source eligibility, exact one-time damage, and
snapshot recovery without retriggering. This is not native macOS mouse input,
realtime player-feel validation, or proof of a complete defensive campaign.
Player acceptance remains **OPEN**.

## Construction-detachment regression (same candidate)

```text
Godot --headless --path . --script tests/run_wartime_defense_r0_smoke.gd
PASS: 施工分队退出会中断未完工设施，并在活动战时快照恢复后保留真实分队身份
WARTIME_DEFENSE_R0_SMOKE PASS

Godot --headless --path . --script tests/run_wartime_defense_persistence_smoke.gd \
  -- --txwzs-v5-save-dir="$isolated_save_dir"
WARTIME_DEFENSE_PERSISTENCE_SMOKE PASS assertions=18
```

The construction detachment is a real committed battle squad, saved by
`BattleSession` as `construction_squad_id`; it is not a new specialist or
hidden roster. The focused smoke removes that squad from active work, observes
the saved `INTERRUPTED` record and `CONSTRUCTION_CREW_LOST` event, then restores
the same record. The graphical capture above still covers the established
enemy-arrival interruption; it does not claim native-mouse proof for the new
crew-loss message.

The same formal C0 plan regression asserts all three visibly selected defense
works preserve squad `1` as their construction detachment. A direct submission
using uncommitted squad `999` is rejected by the Controller before it changes
wood, the saved plan, or the battle request.
The same regression upgrades a schema-1 plan without a construction identity
to schema 2, then verifies first active-session construction binds the legacy
facility to a real committed squad exactly once.

## Explicit repair-crew regression (same candidate)

```text
Godot --headless --path . --script tests/run_wartime_defense_r0_smoke.gd
PASS: 维修只接受玩家选定的真实存活编队；无效编队不会暗中回退或改变工事
WARTIME_DEFENSE_R0_SMOKE PASS
```

The C0 repair action now asks the active session whether its currently selected
committed squad can perform the repair **before** submitting a wood transaction.
The focused lifecycle check rejects foreign squad `999` without changing the
damaged facility, then begins the repair with the explicit living squad and
checks both the saved `construction_squad_id` and `REPAIR_STARTED.squad_id`.
This is a headless authority/lifecycle check; the existing GUI captures show
the repair control and `wartime-defense-03d-facility-repair-crew-engine-gui.png`
is the distinct Godot-GUI selected-crew frame. It remains GUI-event evidence,
not native macOS mouse input.

## Repair interruption regression (same candidate)

The focused lifecycle smoke also moves a real invader to an active repair
route on an ordinary attack tick. It verifies that the barricade becomes
`INTERRUPTED`, contributes no route protection, and restores with the same
construction crew identity. This closes the prior loophole where a facility in
`REPAIRING` was not a valid invader target. The graphically captured repair
state is intentionally taken before this targeted interruption fixture; no
claim is made that the capture itself is a long real-time playthrough.

The isolated L→M worker pair was also run directly against one temporary V5
directory in this candidate:

```text
WARTIME_DEFENSE_DISK_WORKER_L PASS
WARTIME_DEFENSE_DISK_WORKER_M PASS
```

L follows the formal C0 repair button, then an ordinary reached-route battle
tick interrupts the saved repair. M is a fresh Godot process that reopens that
same directory and asserts the persisted `INTERRUPTED` phase, crew identity,
and absent barricade projection. This is a true isolated-process save chain.
The aggregate runner has five isolated-directory checks and 13 worker checks,
so it reports 18 real assertions rather than a hard-coded total. In this
candidate, the same A→M worker order was also launched directly: all 13
completion markers were present. The direct run is recorded as independent
process evidence; it does not make the nested `OS.execute` runner's missing
desktop-shell output look like a native-mouse or full-playthrough capture.

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
PASS: formal confirmation and construction
PASS: visible battle tick interrupts a barricade before completion
PASS: visible battle tick triggers a completed spike trap once at route arrival
PASS: visible formal gate repair starts saved time
PASS: true tick repair
WARTIME_DEFENSE_GRAPHICAL_SMOKE PASS assertions=6
```

The runner enters C0 through the normal Blackstone city entry, uses the visible
route and facility-plan controls, confirms through the formal request, and
captures a rendered frame after each UI refresh. It uses an isolated V5 save
directory and does not access a retained candidate save.

## Captures

- `wartime-defense-01-plan-engine-gui.png`: selected side-route plan with the
  visible watch platform, arrow tower, barricade, and spike-trap buttons.
- `wartime-defense-02-construction-engine-gui.png`: the confirmed request
  before construction ticks begin.
- `wartime-defense-03b-construction-interrupted-engine-gui.png`: an enemy
  arrival interrupts the unfinished barricade before it can project a block.
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
WARTIME_DEFENSE_PERSISTENCE_SMOKE PASS assertions=14
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

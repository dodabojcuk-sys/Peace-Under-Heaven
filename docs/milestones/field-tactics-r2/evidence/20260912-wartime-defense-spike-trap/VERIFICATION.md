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

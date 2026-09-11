# Wartime Defense Gate Repair GUI Evidence

Run date: 2026-09-12
Godot: `4.5.1.stable.official.f62fdbde1`
Candidate: gate-repair implementation at `c50893b` plus this graphical runner.

## Command and result

```text
Godot --path . --rendering-driver opengl3 \
  --script res://tests/run_wartime_defense_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=/tmp/txwzs-wartime-defense-gate-repair-graphical-v5-rerun \
     --txwzs-wartime-defense-evidence-dir=docs/milestones/field-tactics-r2/evidence/20260912-wartime-defense-gate-repair

OpenGL API 4.1 Metal - Compatibility - Apple M4
PASS: visible defense planning
PASS: formal confirmation and construction
PASS: visible formal gate repair starts saved time
PASS: true tick repair
WARTIME_DEFENSE_GRAPHICAL_SMOKE PASS assertions=4
```

The runner starts from the normal Blackstone city entry, uses the visible C0
route and facility controls, then confirms the same battle request before the
battle begins. It uses an isolated V5 directory and does not touch a retained
candidate save.

## Captures

- `wartime-defense-01-plan-engine-gui.png`: side-route watch platform, arrow
  tower and barricade plan, with the enabled confirmation control.
- `wartime-defense-02-construction-engine-gui.png`: the same request after
  formal confirmation, before the battle starts construction ticks.
- `wartime-defense-03-damaged-gate-engine-gui.png`: a real route-driven gate
  damage state and its visible repair action.
- `wartime-defense-04-gate-repair-engine-gui.png`: the saved two-tick repair
  state; the gate still reads `9730/10000` and the action reads `0/2`.
- `wartime-defense-05-gate-repaired-engine-gui.png`: the same target after two
  real battle ticks, restored once to `9850/10000` with completion feedback.

The runner waits a rendered frame after each UI refresh before capture. This
avoids treating the preceding frame as evidence of a changed repair state.

## Evidence boundary

This is graphical **Godot engine GUI-event and root-viewport evidence**. The
route, facility plan and gate-repair controls are visible, enabled controls;
the runner invokes their connected `pressed` signals. The battle is explicitly
advanced by `step_battle_for_test` to keep the isolated capture short. It is
not native macOS mouse input, realtime player-feel validation, or evidence of a
complete defensive campaign.

The separate headless defense smoke and A-to-E independent-process persistence
chain remain the correctness evidence for resource rollback, repair recovery,
and result writeback. Player acceptance remains **OPEN**.

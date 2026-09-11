# Wartime Defense Construction Interruption GUI Evidence

Run date: 2026-09-12
Godot: `4.5.1.stable.official.f62fdbde1`
Candidate: interrupted-construction implementation at `e324567` plus the
graphical smoke extension in this change.

## Command and result

```text
Godot --path . --rendering-driver opengl3 \
  --script res://tests/run_wartime_defense_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=/tmp/txwzs-wartime-defense-interruption-gui \
     --txwzs-wartime-defense-evidence-dir=docs/milestones/field-tactics-r2/evidence/20260912-wartime-defense-construction-interruption

OpenGL API 4.1 Metal - Compatibility - Apple M4
PASS: visible defense planning
PASS: formal confirmation and construction
PASS: visible battle tick interrupts a barricade before completion
PASS: visible formal gate repair starts saved time
PASS: true tick repair
WARTIME_DEFENSE_GRAPHICAL_SMOKE PASS assertions=5
```

The runner enters C0 from the normal Blackstone city entry and uses the visible
route, facility-plan, confirmation, and repair controls. It uses an isolated
V5 directory and does not touch a retained candidate save.

## Captures

- `wartime-defense-01-plan-engine-gui.png`: selected side-route plan and its
  enabled confirmation control.
- `wartime-defense-02-construction-engine-gui.png`: the same confirmed request
  before construction ticks begin.
- `wartime-defense-03b-construction-interrupted-engine-gui.png`: a route
  arrival before the barricade completes. The visible route summary reads
  `拒马：施工受阻 1/3 · 耐久 165/180`, the incident log explains that repair is
  required, and no barricade projection is active.
- `wartime-defense-03-damaged-gate-engine-gui.png` through
  `wartime-defense-05-gate-repaired-engine-gui.png`: the existing route-driven
  gate damage and two-tick repair state in the same isolated run.

The runner waits for a rendered frame after each UI refresh before capture.

## Evidence boundary

This is graphical **Godot engine GUI-event and root-viewport evidence**. To
avoid a long empty approach march, the runner places the invader at the
selected route's actual objective immediately before one ordinary production
attack interval; all resulting construction state, interruption, and UI
projection are still produced by `BattleSession`. It is not native macOS mouse
input, realtime player-feel validation, or proof of a complete defensive
campaign. The separate R0 smoke and H-to-I independent-process chain remain
the correctness evidence for durable interruption and repair recovery. Player
acceptance remains **OPEN**.

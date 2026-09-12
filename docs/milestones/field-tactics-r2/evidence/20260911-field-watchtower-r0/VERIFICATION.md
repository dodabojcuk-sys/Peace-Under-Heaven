# Field Watchtower R0 verification

Run date: 2026-09-11
Godot: `4.5.1.stable.official.f62fdbde1`
Candidate source: local worktree derived from `b9c26a0`

## Commands and results

```text
Godot --headless --path . --editor --quit
PASS: project import and script parse completed without errors

Godot --headless --path . --script res://tests/run_field_watchtower_r0_smoke.gd
FIELD_WATCHTOWER_R0_SMOKE PASS assertions=4

Godot --headless --path . --script res://tests/run_field_watchtower_r0_persistence_smoke.gd
FIELD_WATCHTOWER_R0_WORKER_A PASS
FIELD_WATCHTOWER_R0_WORKER_B PASS
FIELD_WATCHTOWER_R0_WORKER_C PASS
FIELD_WATCHTOWER_R0_PERSISTENCE_SMOKE PASS

Godot --path . --script res://tests/run_field_watchtower_r0_graphical_smoke.gd
FIELD_WATCHTOWER_R0_GRAPHICAL_SMOKE PASS assertions=4

Godot --headless --path . --script res://tests/run_macro_march_r0_smoke.gd
MACRO_MARCH_R0_SMOKE PASS assertions=35

Godot --headless --path . --script res://tests/run_field_tactics_r2_smoke.gd
FIELD_TACTICS_R2_SMOKE PASS assertions=72

Godot --path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd
MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=19
```

## What the checks prove

- A formally completed road project creates the authoritative runtime camp accepted as a tower anchor. A legal, connected camp then accepts one nearby land tower; the engineer travels, then completes work through `ConstructionController` world time; only completion creates an observer.
- Range, water, disconnected camp road and duplicate construction reject before food/project writes. A forced checkpoint failure restores both food and the Field snapshot. Engineer loss while travelling interrupts the project.
- Legacy Field snapshots restore without a free tower. Invalid tower records reject before replacing valid state. A/B/C independent processes prove traveling project recovery, one completion and a stable completed reopen.
- The graphical run uses actual map press/release for engineer selection, camp selection and land placement. It asserts the visible enabled button before exercising its connected action signal, then confirms a single food charge, rendered completed tower and newly `VISIBLE` patrol intel.

## Evidence files

- `watchtower-01-engineer-selected-engine-gui.png`
- `watchtower-02-plan-preview-engine-gui.png`
- `watchtower-03-engineer-travel-engine-gui.png`
- `watchtower-04-complete-and-vision-engine-gui.png`

These are Godot engine GUI-event/viewport captures, not macOS system-mouse recording. The graphical fixture supplies a completed Field camp to focus on the watchtower contract; it does not claim to prove the separate engineering road-to-camp creation flow.

## Still open

Player acceptance, normal-system-input recording and tuning whether a 6-food, 6-second tower produces worthwhile tactical tradeoffs remain open. The old stationed-reinforcement completion screenshot is historical evidence only; it is not reused as watchtower proof.

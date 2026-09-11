# Field Watchtower R0 correctness closeout

Run date: 2026-09-11
Godot: `4.5.1.stable.official.f62fdbde1`
Candidate: `e975da3` plus the correctness-closeout worktree changes.

## Results

```text
Godot --headless --path . --editor --quit
PASS: import and parse completed without errors

Godot --headless --path . --script res://tests/run_field_watchtower_r0_smoke.gd
FIELD_WATCHTOWER_R0_SMOKE PASS assertions=5

Godot --headless --path . --script res://tests/run_field_watchtower_r0_persistence_smoke.gd
FIELD_WATCHTOWER_R0_PERSISTENCE_SMOKE PASS

Godot --path . --script res://tests/run_field_watchtower_r0_graphical_smoke.gd
FIELD_WATCHTOWER_R0_GRAPHICAL_SMOKE PASS assertions=5

Godot --path . --write-movie watchtower-replan-complete-engine-gui.avi --fixed-fps 30 ...
FIELD_WATCHTOWER_R0_GRAPHICAL_SMOKE PASS assertions=5
101 frames at 30 FPS (00:00:03:11)

Godot --headless --path . --script res://tests/run_field_tactics_r2_smoke.gd
FIELD_TACTICS_R2_SMOKE PASS assertions=72

Godot --headless --path . --script res://tests/run_macro_march_r0_smoke.gd
MACRO_MARCH_R0_SMOKE PASS assertions=35

Godot --path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd
MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=19

git diff --check
PASS
```

## Evidence scope

- `watchtower-02-invalid-placement-engine-gui.png` proves a rejected location
  clears the old plan and disables the action.
- `watchtower-03-replanned-preview-engine-gui.png` proves a later legal point
  restores a visible, actionable plan without a prior charge.
- `watchtower-05-complete-and-vision-engine-gui.png` proves the completed
  tower, its rendered node and visibility result are read from Field state.
- `watchtower-replan-complete-engine-gui.avi` is a 101-frame Godot Movie Maker
  recording of engineer selection, invalid re-placement, legal re-placement,
  project start and completion. It uses engine GUI events and a connected
  visible side-panel action signal; it is not macOS system-mouse evidence.

The focused Field test covers pre/post-completion contact ordering, completion
checkpoint rollback/retry, live-project footprint occupancy, and formal V5
restore of the 11-, 14-, and 15-field historical Field snapshots. The separate
A/B/C worker remains the cross-process recovery evidence for traveling,
completed and re-opened tower state.

## Remaining limits

R0 remains a single observer-only construction slice. Numeric balance and
visual tuning are deferred. Player acceptance and native system-input evidence
remain open.

# Verification record

Engine binary:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
4.5.1.stable.official.f62fdbde1
```

## Passing checks for this presentation change

| Command | Result |
| --- | --- |
| `Godot --editor --quit` | PASS: scripts reimported without parse errors. |
| graphical `tests/run_macro_march_low_poly_graphical_smoke.gd` with an isolated V5 save directory | PASS, 11 assertions. It covers 1152x648, 1280x720 and 1920x1080; Camera3D/2D anchors (0--0.22 px), road endpoints/facing, horizontal ground normals, normal UI route input, released engineering preview, normal/bridge active construction, and 2D/3D state neutrality. |
| `tests/run_field_tactics_r2_persistence_smoke.gd` with an isolated V5 save directory | PASS: construction, repair, multi-segment march, camp transfer/return, and temporary-route rebreak cold recovery chains. |
| `Godot --headless --scene res://scenes/blank_map.tscn --quit-after 4` | PASS: formal city scene starts. |
| `git diff --check` | PASS. |

## Current non-presentation blockers observed while checking wider R2 suites

These are not treated as passes and are not attributed to the render-only
change without a separate reproduction/fix:

- `tests/run_field_tactics_r2_smoke.gd` reaches line 887 with an empty
  `blocked_transfer.route_segments` fixture and emits `Can't take value from
  empty array`; later assertions consequently fail. This runner needs its
  temporary-transfer setup repaired before it can validate the wider suite.
- `tests/run_field_tactics_r2_playthrough_smoke.gd` passes the main route, but
  its engineering route reports `ambushes=0` and fails its natural-ambush
  expectation. Reported metrics from that failed execution are not balance or
  player-experience conclusions.

No normal-system-input recording is claimed. The PNGs in this directory use
Godot GUI events and renderer output, so they remain engineering/visual review
evidence rather than a substitute for player operation or acceptance.

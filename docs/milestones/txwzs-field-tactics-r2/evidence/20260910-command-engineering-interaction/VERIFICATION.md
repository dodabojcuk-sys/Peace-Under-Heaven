# Command and engineering interaction verification

## Scope

This checkpoint replaces the superseded 0.5-second hold interaction with an
explicit selected-subject command flow. It does not change ArmyRegistry's order
or formation ownership, ConstructionController's world-time and food
transactions, or FieldTacticsState's road/project persistence.

## Interaction result

- A selected city formation or stationed army can click a legal destination for
  the shortest open authority path.
- A drag starts after eight screen pixels. Crossing a real-road choice marker
  saves that road's identity as a mandatory authority path constraint. If it is
  damaged or unfinished, planning fails without silently taking the other path.
- Engineering retains free polyline planning. An idle engineer defaults to its
  friendly location, may start from another legal point in one press-drag, and
  may continue or undo an uncommitted draft before confirmation.
- Right-click and focus loss clear transient pointer state without food, army,
  road, camp, or project writes.

## Commands and results

Godot executable:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| editor import/parse | PASS |
| `tests/run_macro_march_r0_smoke.gd` with an isolated V5 store | PASS, 30 assertions |
| `tests/run_field_tactics_r2_smoke.gd` with an isolated V5 store | PASS, 70 assertions; includes mandatory-road rejection when the selected road is damaged |
| `tests/run_macro_march_low_poly_graphical_smoke.gd` with an isolated V5 store | PASS, 16 assertions across 1152x648, 1280x720, and 1920x1080 |
| `tests/run_field_tactics_r2_persistence_smoke.gd` with an isolated V5 store | PASS; includes independent-process transfer, waiting, return, and resumed-order recovery |
| `tests/run_field_tactics_r2_playthrough_smoke.gd` with an isolated V5 store | PASS, 3 assertions; Route A: 65.7 seconds / 12 food / 4 army losses; Route B: 92.6 seconds / 36 food / 3 army losses / 1 natural ambush |
| continuous GUI-event recording | PASS: `route_ready=true`, `engineering_ready=true`, `projects=1` |

## Continuous recording

`command-engineering-engine-gui-events.avi` is a 1280x720, 60 FPS, Motion
JPEG, 5.18-second Godot Movie Maker capture. It contains the following
continuous engine GUI-event sequence: formation selection, default destination
draft, cancel, source drag through a road choice point, draft confirmation,
engineering draft, continuation, undo, and confirmation.

- SHA-256: `41b85d9ef1bfc9465e4ab2f891262515ef176af74b059986efc6177ce3984160`
- Source: `tests/capture_macro_march_command_engineering_evidence.gd`
- Boundary: this is engine GUI-event evidence, not macOS system-mouse footage
  and not player hand-feel acceptance.

Player acceptance remains **OPEN**. This recording demonstrates engine GUI
events, not normal macOS system-mouse hand-feel.

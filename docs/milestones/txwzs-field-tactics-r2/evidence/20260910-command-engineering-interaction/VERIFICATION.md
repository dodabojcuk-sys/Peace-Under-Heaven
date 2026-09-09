# Command and engineering interaction verification

## Scope

This checkpoint uses one shared 0.5-second UI-time hold interaction after an
explicit selected-subject command flow. It does not change ArmyRegistry's order
or formation ownership, ConstructionController's world-time and food
transactions, or FieldTacticsState's road/project persistence.

## Interaction result

- A selected city formation or stationed army can click a legal destination for
  the shortest open authority path.
- A hold activates drawing after 0.5 UI seconds. A movement beyond eight pixels
  before that point cancels. Crossing a visible real-road choice marker saves
  that road's identity as a mandatory authority path constraint. If it is
  damaged or unfinished, planning fails without silently taking the other path.
- Engineering retains free polyline planning. Its committed bend samples and
  live endpoint are distinct, so slow turns survive. An idle engineer defaults
  to its friendly location, may start from another legal point, may continue
  an uncommitted draft, and may undo a full continuation stroke before
  confirmation. New-camp bounds and land validation use the same Field preview
  as the eventual transaction.
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
| `tests/run_field_tactics_r2_smoke.gd` with an isolated V5 store | PASS, 71 assertions; includes mandatory-road rejection plus preview/submit rejection of out-of-bounds or water new camps |
| `tests/run_macro_march_low_poly_graphical_smoke.gd` with an isolated V5 store | PASS, 17 assertions across 1152x648, 1280x720, and 1920x1080 |
| `tests/run_field_tactics_r2_persistence_smoke.gd` with an isolated V5 store | PASS; includes independent-process transfer, waiting, return, and resumed-order recovery |
| `tests/run_field_tactics_r2_playthrough_smoke.gd` with an isolated V5 store | PASS, 3 assertions; Route A: 65.7 seconds / 12 food / 4 army losses; Route B: 92.6 seconds / 36 food / 3 army losses / 1 natural ambush |
| continuous GUI-event recording | PASS: ridge route selected, march and engineering each commit once, project starts once |

## Continuous recording

`command-engineering-engine-gui-events.avi` is a 1280x720, 60 FPS, Motion
JPEG, 4.77-second Godot Movie Maker capture. It contains the following
continuous engine GUI-event sequence: formation selection, default destination
draft, cancel, 0.5-second source hold, ridge-road draw and confirmation,
engineer selection, construction-source selection, 0.5-second construction
hold, cross-water plan and confirmation.

- SHA-256: `fab71fe50a9b1a8e6e641d7153028f7be3601d9f5dd429a838ba16a930c4a234`
- Source: `tests/capture_macro_march_command_engineering_evidence.gd`
- Boundary: this is engine GUI-event evidence, not macOS system-mouse footage
  and not player hand-feel acceptance.

Player acceptance remains **OPEN**. This recording demonstrates engine GUI
events, not normal macOS system-mouse hand-feel.

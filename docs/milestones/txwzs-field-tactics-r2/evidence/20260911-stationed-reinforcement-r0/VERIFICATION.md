# Stationed reinforcement R0 verification

## Scope

The R0 sample adds only Silverford's finite, authored four-person local pool.
The controller-level scenario takes Silverford through the normal macro march
and surrender path before replenishing a genuinely stationed army. The
graphical fixture uses a player-control ownership fixture solely to keep the
GUI check focused on the location-detail interaction; it does not claim to be
occupation evidence.

## Commands and results

All commands use Godot `4.5.1.stable.official.f62fdbde1` at:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Command | Result | Evidence scope |
| --- | --- | --- |
| `--headless --path . --script res://tests/run_field_stationed_reinforcement_r0_smoke.gd` | PASS, 5 assertions | Normal Controller occupation, replenish, duplicate rejection, reissue, stable multi-formation allocation, rollback, legacy/strict Field restore. |
| `--headless --path . --script res://tests/run_field_stationed_reinforcement_r0_persistence_smoke.gd` | PASS | Independent A/B/C processes: replenished stationary army, restored reissue, then restored moving order; stock remains zero and membership remains eleven. |
| `--path . --script res://tests/run_field_stationed_reinforcement_r0_graphical_smoke.gd -- --txwzs-v5-save-dir=<isolated-dir> --txwzs-field-reinforcement-evidence-dir=<this-directory>` | PASS, 3 assertions | Engine GUI map click, visible enabled detail controls, selected roster preview, connected action signal and completed authoritative state. |
| `--headless --path . --script res://tests/run_field_supply_r0_smoke.gd` | PASS, 11 assertions | Supply regression including correctly shaped legacy Field fixture. |
| `--headless --path . --script res://tests/run_field_supply_r0_persistence_smoke.gd` | PASS | Existing A/B/C/D independent-process supply recovery regression. |
| `--headless --path . --script res://tests/run_macro_march_r0_smoke.gd` | PASS, 35 assertions | Macro March regression. |
| `--headless --path . --script res://tests/run_field_tactics_r2_smoke.gd` | PASS, 72 assertions | Field R2 regression. |
| `--headless --path . --script res://tests/run_field_tactics_r2_persistence_smoke.gd` | PASS | Existing independent-process road, repair, multi-segment march, and blocked-transfer recovery. |
| `--headless --path . --script res://tests/run_field_tactics_r2_playthrough_smoke.gd` | PASS, 3 assertions | Existing Route A and Route B completion regression. |
| `--path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd -- --txwzs-v5-save-dir=<isolated-dir>` | PASS, 19 assertions | Existing three-resolution low-poly rendering and Macro March GUI regression. |
| `--headless --editor --path . --quit` | PASS | Godot script parse and editor import check. |

The graphical captures are engine-view/GUI-event evidence, not normal macOS
mouse-input proof. Each screenshot is named by its actual state:

- `field-reinforcement-01-location-detail-engine-gui.png`
- `field-reinforcement-02-selected-army-engine-gui.png`
- `field-reinforcement-03-completed-engine-gui.png`

## Boundaries retained

No candidate window or user save was closed or overwritten. Player acceptance
is OPEN. Silverford supply R0 is functionally closed; legacy repair projects
without `repair_initial_durability` retain their documented compatibility
limitation.

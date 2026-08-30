# TXWZS M0 R0 38-File Diff Scope Audit

## Audited Commit

`1312754260313ee12542cb1052f0b5bbe06b5dfa`

The pre-change `git show --stat` and `git show --name-status` both identify 38
files: 1,757 insertions and 128 deletions. No unexplained code file or product
scope expansion was found. R0 remains a reusable engineering base, while its
Founder acceptance remains denied.

## Classification

### Time, construction, resources

- `scripts/construction_controller.gd`
- `scripts/building_selection_controller.gd`
- `scenes/blank_map.tscn`

These implement the authorized clock, incremental payment, missing-material
resume, priority, and HUD projections. The R0A review found contradictory
player-facing read models in these files; that is a repair item, not unexplained
scope.

### Mainline pressure

- `resources/definitions/mainline/m0_first_level_pressure.tres`
- `scripts/content/mainline_pressure_profile.gd`
- `scripts/state/current_mainline_level.gd`
- `scripts/battle/battle_attempt_state.gd`

The battle-attempt value object is a narrow boundary fixture proving retry
cannot restore permanent mainline state. It does not add combat gameplay.

### Save migration

- `scripts/state/v5_campaign_snapshot.gd`

This is the additive schema-4 and V2/V3 migration authority required by R0.

### Tests

- `tests/capture_m0_visual_evidence.gd`
- `tests/run_m0_time_build_pressure_smoke.gd`
- `tests/run_c0_city_time_settlement_smoke.gd`
- `tests/run_p1a_road_logging_smoke.gd`
- `tests/run_p1e_first_war_closed_loop_smoke.gd`
- `tests/run_p1e_first_war_gate_smoke.gd`
- `tests/run_p1f_construction_dataization_smoke.gd`
- `tests/run_r2b_player_road_construction_smoke.gd`
- `tests/run_r2c01_national_resource_convergence_smoke.gd`
- `tests/run_regular_city_spatial_r1_smoke.gd`
- `tests/run_s1a1_early_city_snapshot_smoke.gd`
- `tests/run_v5_campaign_persistence_smoke.gd`
- `tests/run_v5_training_queue_smoke.gd`
- `tests/run_v5_vertical_loop_smoke.gd`

The changed legacy tests only replace superseded full-prepayment and day-7 time
freeze assertions or adapt exact snapshot shapes. No unrelated behavior is
waived.

### Documentation

- `CURRENT_STATE.md`
- `DECISIONS.md`
- `CHANGELOG.md`
- `docs/m0/TXWZS_M0_IMPLEMENTATION_MAP.md`
- `docs/m0/TXWZS_M0_TECH_SPEC.md`
- `docs/m0/TXWZS_M0_TIME_BUILD_PRESSURE_REPORT.md`

### Evidence

- `docs/m0/evidence/01-default-running-1440x900.png`
- `docs/m0/evidence/02-default-running-1280x720.png`
- `docs/m0/evidence/03-paused-order-no-progress-1440x900.png`
- `docs/m0/evidence/04-blocked-missing-material-1440x900.png`
- `docs/m0/evidence/05-overdue-pressure-stage-1440x900.png`

These are valid engineering evidence but do not constitute the newly required
continuous player journey or Founder acceptance.

### Generated import identity files

- `scripts/battle/battle_attempt_state.gd.uid`
- `scripts/content/mainline_pressure_profile.gd.uid`
- `scripts/state/current_mainline_level.gd.uid`
- `tests/capture_m0_visual_evidence.gd.uid`
- `tests/run_m0_time_build_pressure_smoke.gd.uid`

They are Godot-generated script identity companions for newly added scripts.

### Unexplained or unnecessary files

None found.

## Audit Verdict

`R0_38_FILE_SCOPE_AUDIT=PASS`

The audit does not upgrade R0 acceptance. It confirms only that R0A can safely
continue from the exact local base without rewriting history.

## R0A Scope Result

R0A changes only the existing placement authority, building presentation,
context panel, pressure read model, authored Blackstone fixed anchors, tests,
and evidence/reporting needed by the repair instruction. It does not add a
second Save writer, schema version, population, combat, trade, technology,
navigation, final art, push, merge, or deployment path. The five older tests
whose exact UI strings changed were updated to assert the new player-readable
contract; no behavioral failure was waived.

`R0A_UNEXPLAINED_FILES=none`

## Final R0A Diff Inventory

Final staged stat before the local commit: 40 files changed, 2,068 insertions,
149 deletions, plus ten PNG binaries and one AVI binary. The complete
`git diff --cached --name-status` inventory is:

```text
M CHANGELOG.md
M CURRENT_STATE.md
M DECISIONS.md
A docs/m0/TXWZS_M0_R0A_BUILDING_ROAD_UI_REPAIR_REPORT.md
A docs/m0/TXWZS_M0_R0A_PLACEMENT_LEGALITY_MAP.md
A docs/m0/TXWZS_M0_R0A_R0_DIFF_SCOPE_AUDIT.md
A docs/m0/TXWZS_M0_R0A_TECH_SPEC.md
A docs/m0/evidence/r0a/01-building-on-road-invalid-1440x900.png
A docs/m0/evidence/r0a/02-entrance-adjacent-road-valid-1440x900.png
A docs/m0/evidence/r0a/03-construction-panel-1440x900.png
A docs/m0/evidence/r0a/04-missing-material-panel-1440x900.png
A docs/m0/evidence/r0a/05-completed-disconnected-1440x900.png
A docs/m0/evidence/r0a/06-completed-producing-1440x900.png
A docs/m0/evidence/r0a/07-road-through-building-invalid-1440x900.png
A docs/m0/evidence/r0a/08-complex-panel-1280x720.png
A docs/m0/evidence/r0a/09-debug-occupancy-overlay-1440x900.png
A docs/m0/evidence/r0a/10-overdue-pressure-event-1440x900.png
A docs/m0/evidence/r0a/m0-r0a-continuous-player-journey.avi
M scenes/blank_map.tscn
M scripts/building_selection_controller.gd
M scripts/city_layout_profile_resolver.gd
M scripts/city_sandbox/city_grid_rules.gd
M scripts/city_sandbox/road_preview_visual.gd
M scripts/construction_controller.gd
M scripts/content/mainline_pressure_profile.gd
M scripts/graybox_building_visual.gd
M scripts/inner_city_ui_r0.gd
A scripts/placement_debug_overlay_r0a.gd
A scripts/placement_debug_overlay_r0a.gd.uid
A tests/capture_m0_r0a_continuous_journey.gd
A tests/capture_m0_r0a_continuous_journey.gd.uid
A tests/capture_m0_r0a_evidence.gd
A tests/capture_m0_r0a_evidence.gd.uid
M tests/run_building_lifecycle_smoke.gd
M tests/run_building_selection_smoke.gd
A tests/run_m0_r0a_building_road_ui_repair_smoke.gd
A tests/run_m0_r0a_building_road_ui_repair_smoke.gd.uid
M tests/run_p1f_construction_dataization_smoke.gd
M tests/run_r2a_road_lot_entrance_smoke.gd
M tests/run_unified_building_interaction_smoke.gd
```

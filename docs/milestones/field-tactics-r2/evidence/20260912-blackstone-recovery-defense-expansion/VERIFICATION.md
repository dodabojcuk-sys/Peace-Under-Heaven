# Blackstone Recovery and Defense Expansion Verification

## Result

Implementation verification passed for the aggregate population/recovery loop,
location capabilities, fortress, minefields and level-two facility upgrades.
This is not human player acceptance. A single unaccelerated normal-speed
playthrough remains `OPEN`.

## Continuous player-causality coverage

`run_blackstone_invasion_r0_smoke.gd` starts a fresh campaign, activates the
configured Redcliff invasion on day 5, applies a real field interception, lets
the surviving force arrive, enters the existing Blackstone defense instance,
issues real squad advance orders and settles the battle. It then pays for and
advances treatment, reuses the surviving formations, marches over the existing
Blackstone-Northwatch-Redcliff roads, enters the existing macro siege and
occupies Redcliff through its formal result transaction.

After the flow begins, the runner does not edit strength, inventory, control or
outcome. Time is accelerated through formal controller APIs; this is therefore
deterministic integration evidence, not normal-speed player input evidence.

## Focused coverage

- Fresh population conservation across available people, two workforce pools,
  garrison, external armies, specialists, training reservations and wounded.
- Training and treatment costs, active-progress save/restore, capacity handling,
  casualty split and invalid-snapshot rejection before live-state mutation.
- Central capabilities for Blackstone, Silverford and occupied Redcliff.
- Fortress construction, one real stationed garrison, damage absorption and
  persisted assignment.
- Mine route crossing, one-time damage/charge consumption, hidden hostile-mine
  projection, specialist discovery, engineer clearing and cold restoration.
- Facility upgrade cost, active old ability, mid-project restore, level-two
  effect change and durability-ratio preservation.
- 1152x648 city recovery and field-fortress interaction layout.

## Commands executed

```sh
GODOT=/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot

"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5 -- --txwzs-v5-save-dir="$(mktemp -d /tmp/txwzs-recovery-startup.XXXXXX)"

"$GODOT" --headless --path . --script tests/run_blackstone_recovery_r0_smoke.gd
"$GODOT" --headless --path . --script tests/run_field_defense_expansion_r0_smoke.gd
"$GODOT" --headless --path . --script tests/run_blackstone_invasion_r0_smoke.gd
"$GODOT" --headless --path . --script tests/run_inner_city_ui_r0_smoke.gd
"$GODOT" --headless --path . --script tests/run_v5_campaign_persistence_smoke.gd
"$GODOT" --headless --path . --script tests/run_v5_single_unit_garrison_smoke.gd
"$GODOT" --headless --path . --script tests/run_field_watchtower_r0_smoke.gd
"$GODOT" --headless --path . --script tests/run_war_loop_formal_scene_smoke.gd
"$GODOT" --headless --path . --script tests/run_wartime_defense_r0_smoke.gd
"$GODOT" --headless --path . --script tests/run_v5_encounter_writeback_smoke.gd
"$GODOT" --headless --path . --script tests/run_macro_siege_wartime_handoff_smoke.gd
"$GODOT" --headless --path . --script tests/run_macro_siege_wartime_victory_smoke.gd

review_save=$(mktemp -d /tmp/txwzs-recovery-gui.XXXXXX)
"$GODOT" --path . --script tests/run_recovery_defense_expansion_graphical_smoke.gd -- \
  --txwzs-v5-save-dir="$review_save" \
  --txwzs-recovery-defense-evidence-dir="$PWD/docs/milestones/field-tactics-r2/evidence/20260912-blackstone-recovery-defense-expansion"
```

All commands exited zero in the final run. No new `ObjectDB instances leaked`
warning appeared in editor import, startup, focused or affected regression runs.
The earlier audio-exit warning remains a separately tracked historical cleanup
issue; this slice produced no evidence of a persistent runtime accumulation.

## Visual evidence

- `recovery-01-normal-city-population-engine-gui.png`: fresh normal-city
  population, workforce and treatment controls at 1152x648.
- `recovery-02-fortress-detail-engine-gui.png`: persistent external fortress
  identity, durability, garrison scope and upgrade/repair actions at 1152x648.

Both screenshots come from an isolated save root. No player save or existing
candidate window was opened or modified.

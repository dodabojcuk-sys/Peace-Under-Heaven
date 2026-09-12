# War Specialists and Active Support R0 Verification

Date: 2026-09-12

## Environment

- Repository: `/Users/m4-zhi/Documents/codex-workspace/txwzs-field-tactics-r2`
- Branch: `codex/txwzs-field-tactics-r2`
- Starting baseline: `af6899f2a6e31266772aed1d20c10ebd90701ce2`
- Godot: `4.5.1.stable.official.f62fdbde1`
- Binary: `/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`

The new persistence and graphical runners use isolated save directories. The
focused runners create fresh in-memory fixtures. Existing candidate windows and
player saves were not modified or closed.

## Implemented behavior

- The formal war map can acquire/select medic, saboteur, thief and sniper
  specialists and assign a legal map target.
- Specialist actions use real movement/work time and mutate only their existing
  authoritative target: living siege HP, a discovered facility's durability,
  finite enemy-city stock, or a visible patrol's strength.
- Enemy-city theft requires a durable scout report. If capacity disappears
  while cargo is returning, the same cargo waits at Blackstone and retries
  without a second target debit.
- The active C0 screen exposes physician healing and strategist movement,
  attack, protection and domain commands. They consume the shared campaign
  energy and persist their command receipt, scope and expiry battle tick.
- Failed active-support checkpoint publication restores both energy and combat
  state before a retry.

## Evidence and result

| Check | Result |
| --- | --- |
| `tests/run_war_specialists_and_support_r0_smoke.gd` | PASS, 19 assertions covering four field actions, scout-gated theft, battle-handoff exclusion, receiving-capacity change in transit, no resurrection, all five support mechanisms, rollback/non-stacking, exact-duration expiry and session restore |
| `tests/run_war_specialists_support_persistence_smoke.gd` | PASS, 10 assertions across three independent Godot processes and explicit success markers; transit, completion/no replay, active support and energy are checked |
| `tests/run_war_specialists_support_graphical_smoke.gd` | PASS, 6 assertions in Metal; visible map and battle menu actions use engine GUI input/signals |
| `tests/run_field_tactics_r2_smoke.gd` | PASS, 72 assertions |
| `tests/run_macro_march_r0_smoke.gd` | PASS, 35 assertions |
| `tests/run_city_strategy_r0_smoke.gd` | PASS, 18 assertions |
| `tests/run_wartime_inner_city_r0_smoke.gd` | PASS, 37 assertions |
| `tests/run_field_defense_expansion_r0_smoke.gd` | PASS, 7 assertions |
| `tests/run_field_tactics_r2_playthrough_smoke.gd` | PASS, 7 assertions; direct and engineering routes still complete |
| `tests/run_city_strategy_r0_persistence_smoke.gd` | PASS, independent-process strategy restore |
| `tests/run_macro_siege_wartime_persistence_smoke.gd` | PASS, 11 assertions |
| `tests/run_blackstone_recovery_r0_smoke.gd` | PASS, 9 assertions |
| `tests/run_blackstone_invasion_r0_smoke.gd` | PASS, 17 assertions |
| Godot editor import/parse | PASS, exit 0 |
| `git diff --check` | PASS |

Graphical files:

- `field-saboteur-action-engine-gui.png`: visible specialist selection, target,
  task and progress on the field map.
- `battle-official-support-engine-gui.png`: active battle after a visible
  strategist command, with remaining campaign energy and the accepted action.
- `graphical-smoke.log`: complete Metal runner output.

These captures prove engine-rendered state and the connected GUI event/signal
handlers. They do not prove native-pointer ergonomics or an unaccelerated human
playthrough. Player acceptance therefore remains `OPEN`.

## Remaining product gaps

- Broader specialist rosters, progression and balance are not claimed by this
  representative R0.
- The authored hostile lookout provides a real durable sabotage target, but a
  broader enemy facility economy is outside this slice.
- Population growth, age groups, refugees and deeper public-order development
  remain the next city-development group, as previously scoped.

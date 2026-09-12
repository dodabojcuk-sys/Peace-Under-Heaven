# Battle Identity and Continuity Verification

## Outcome

This checkpoint makes the macro-siege and wartime-defense C0 scenes explain and preserve their actual source. It does not add a second army, resource, facility, result, or save owner.

## Player-visible chains

### Macro siege

1. Open the field theatre from the regular city.
2. Select the existing Redcliff siege army and use the visible siege-battle entry.
3. Read the target city, attacking identity, original army, surviving force, external approach road, gate durability, victory condition, and retreat destination.
4. Confirm effectful siege works, select each original squad, advance through normal battle ticks, confirm victory, and return to the field theatre.
5. Observe Redcliff under player control with the same original army stationed there.

Screenshots: `macro-siege-01-effectful-plan-engine-gui.png` through `macro-siege-07-returned-war-zone-engine-gui.png`.

### Wartime defense

1. Select Blackstone Gate in the regular city and press its visible wartime-defense action.
2. Deploy the real garrison across the north and east approaches, place route-specific temporary works, and start the battle.
3. Let enemies advance naturally until a temporary work is damaged; use visible squad, repair, gate-repair, and advance controls.
4. Let normal battle ticks produce victory, confirm the result, and return to the regular city.
5. Observe Blackstone not fallen, surviving city defense, and no second expedition-food charge.

Screenshots: `wartime-defense-continuity-01-city-gate-entry.png` through `wartime-defense-continuity-07-returned-city.png`.

The older focused defense captures in this directory additionally isolate construction interruption, trap triggering, facility repair ownership, and gate repair. Those focused fixtures are not the continuous player journey.

## Verification boundary

- The continuity runners use visible Godot control signals and normal battle ticks. They do not directly edit HP, enemy positions, battle outcomes, or result summaries.
- The macro setup still accelerates the pre-battle field march through existing controller rules before using the visible siege entry; it is not native macOS pointer acceptance.
- The defense continuity starts from the visible regular-city gate action and uses an isolated V5 save directory.
- Screenshots and engine GUI checks are implementation evidence, not real-player feel acceptance. Player acceptance remains **OPEN**.

## Automated checks

Passed on Godot 4.5.1:

- `run_c0_battle_presentation_smoke.gd`
- `run_wartime_inner_city_r0_smoke.gd`
- `run_wartime_defense_r0_smoke.gd`
- `run_macro_siege_wartime_handoff_smoke.gd`
- `run_macro_siege_wartime_persistence_smoke.gd`
- `run_wartime_defense_persistence_smoke.gd` (workers A-M)
- `run_macro_siege_wartime_graphical_smoke.gd`
- `run_wartime_defense_graphical_smoke.gd`
- `run_wartime_defense_continuity_graphical_smoke.gd`
- `run_macro_march_r0_smoke.gd`
- `run_field_tactics_r2_smoke.gd`
- `run_field_tactics_r2_playthrough_smoke.gd`
- `run_regular_city_spatial_r1_smoke.gd`
- Headless editor import and `git diff --check`

The regular-city guard exposed a stale schema-2 fixture that retained the later `war_loop` root key. The fixture now removes that post-schema-2 field before validating migration; production save code was unchanged.

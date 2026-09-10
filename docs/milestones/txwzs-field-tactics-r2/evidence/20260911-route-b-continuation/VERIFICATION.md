# Route B Stationed-Army Continuation

## Scope and root cause

This is a narrow Route B regression repair. Baseline troop dispatch remains
closed, and the earlier simulation-stall investigation remains **NOT
REPRODUCED / NOT DIAGNOSED**.

The old Route B fixture used `_ui_draw_world_route()` plus `_confirm_draft()`.
That was the superseded confirmed-draft path: it never exercised the current
stationed-army gesture of holding a friendly camp, selecting the army in the
object strip, dragging to a target and releasing. It then treated an empty
`current_point_id` as a missing camp. A stationed army instead retains the
reliable facts in `army_id`, `phase`, `target_node_id`, its macro order and its
directed route.

The formal gesture exposed one production boundary too: `ENEMY_CITY` is an
authored geography/appearance kind. Silverford keeps that kind after capture,
but the old source picker rejected it before checking its runtime controller.
`_direct_dispatch_source_at_screen()` now accepts a city only when
`military_controller_faction_id == player`; an unoccupied enemy city remains
ineligible.

`a00b3d3` reproduces the old fixture failure. `0d63180` already has the same
static `ENEMY_CITY` gate and old fixture, so it is recorded as an inspected
historical candidate rather than assumed to be a passing control.

## Formal path and assertions

The rewritten playthrough uses actual `MacroMarchR0` GUI events and scene time:

1. Frame the source and destination with normal minimap/zoom input.
2. Press the friendly camp and wait `DRAW_HOLD_SECONDS + 0.08` through the
   SceneTree timer, not a private `_process()` shortcut.
3. Move into the exact stationed-army strip row, then out to the target to lock
   that same `army_id`.
4. Release at the target.
5. Compare the command snapshot before, after a deliberately invalid
   source-release, and after the valid release.

The target expectation comes from the authored theatre endpoint rather than
the map hit-test under test. A valid continuation must retain the same army,
become `MARCHING`, publish a new `order_id`, use that exact target, and spend
the authority preview's food cost exactly once. The invalid release must leave
the order and food unchanged and clear the gesture/draft.

## Evidence boundary

All evidence here is Godot GUI-event / engine-render evidence. The movie is a
Movie Maker rendering of the formal event chain, not macOS desktop-system
mouse footage and not a player hand-feel acceptance result.

| Artifact | Contents |
| --- | --- |
| `route-b-station-continuation-engine-gui.avi` | 1152×648 Motion JPEG Movie Maker run of both clean routes, including the forest-garrison to Silverford continuation and the captured-Silverford to Redcliff continuation. SHA-256 `020ee32e7eda7cfcd6965c64eed415101c35be181ca9e02b93f7b6c1dee05fbd`. |
| `route-b-station-continuation-engine-gui.log` | Full Route A/B command trace from the movie run. |
| `editor-import.log` | Godot import/script parse result. |
| `macro-march-r0-smoke.log` | Targeted Macro March authority regression. |
| `direct-dispatch-graphical-smoke.log` | Direct-map GUI input/render regression. |
| `low-poly-graphical-smoke.log` | Low-poly graphical rendering/input regression. |
| `field-r2-smoke.log` | Field tactical authority regression. |

## Verification

Godot binary:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

Each run used a fresh `mktemp` V5 save directory. Results:

| Check | Result |
| --- | --- |
| editor import / script parse | PASS |
| `tests/run_macro_march_r0_smoke.gd` | PASS, 30 assertions |
| `tests/run_macro_march_direct_dispatch_graphical_smoke.gd` | PASS, 18 assertions |
| `tests/run_macro_march_low_poly_graphical_smoke.gd` | PASS, 18 assertions |
| `tests/run_field_tactics_r2_smoke.gd` | PASS, 72 assertions |
| `tests/run_field_tactics_r2_playthrough_smoke.gd`, Route A | PASS: 39,400 ms, 12 food spent, 4 army casualties |
| `tests/run_field_tactics_r2_playthrough_smoke.gd`, Route B | PASS: 79,500 ms in Movie Maker, 36 food spent, 3 army casualties, 0 specialist losses, 1 natural ambush |

The Route B trace records the same `army.player.000001` at the forest garrison,
then `macro.order.000002` to Silverford on
`road.forest.silverford.approach`; after Silverford becomes player-controlled,
it records `macro.order.000003` to Redcliff on
`road.redcliff.silverford`. Each confirmed continuation spends 4 food. The
intentional same-source release reports `请选择另一处城池或驻点` and has
`no_side_effect=true`.

No new cross-process claim is made by this checkpoint. Existing persistence
coverage remains unchanged because this repair does not alter ArmyRegistry or
V5 snapshot schema.

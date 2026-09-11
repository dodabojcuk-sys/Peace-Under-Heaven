# Blackstone location capabilities and garrison details

## Scope

This checkpoint adds read-only location information only. It does not change
the ArmyRegistry order/formation owner, ConstructionController world clock and
food transaction owner, FieldTacticsState road/project owner, or the V5 save
schema. Player-visible capability comes from the authored theatre Resource;
runtime city control remains projected from WarLoop and completed engineering
camps remain projected from FieldTacticsState.

## Player path verified

The Macro March contract opens the formal city scene and verifies:

1. Click Silverford while it is enemy-controlled: the panel identifies its
   controller and says it cannot be a player dispatch source; the full snapshot
   is unchanged.
2. March and occupy Redcliff through the existing authority path, then inspect
   its actual stationed army. The panel reports player control and no inner-city
   construction capability; selecting the garrison changes only view focus.
3. Use the normal long-hold strip at the captured city to select that same army
   and release on Silverford. One new order is published and food decreases
   once.
4. Reinspect Redcliff after the army is in transit: its garrison list is empty.
5. Finish an engineer project that creates a new camp. The camp appears only
   after completion, has tactical station/reissue capability but no inner-city
   capability, and survives V5 save/restore along with captured-city control.

The graphical location-entry contract additionally verifies, with world time
paused around every inspection:

1. A fresh press/release on Blackstone with no outgoing army opens its detail
   without changing the full authority snapshot.
2. A selected engineer can inspect Silverford without its old specialist panel
   overwriting the explicit enemy-city detail, then return to Blackstone through
   the visible, enabled `查看所在地点` action with no snapshot side effect.
3. After that enemy inspection, a normal Blackstone hold → formation strip →
   Northwatch release publishes exactly one marching army, charges exactly its
   authority preview food, and replaces the old location view with that army's
   live task copy.
4. After a real engineer project completes, the engineer at its runtime camp
   again exposes the visible location action and opens the engineered-garrison
   detail without changing authority state.

Map interaction in those cases uses real engine GUI `InputEvent` press/release
pairs. The SceneTree graphical runner cannot make synthetic Button mouse events
activate Godot's native `pressed` path; it instead first asserts that the
location Button is in the scene tree, visible and enabled, then exercises its
connected action signal. This is explicit button-action coverage, not
desktop-system-input or player-feel acceptance evidence.

## Commands and results

Godot binary:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| Editor import / parse | PASS: Godot 4.5.1 editor run completed; no script parse errors. |
| `tests/run_macro_march_r0_smoke.gd` | PASS, 35 assertions. Includes all five location-path assertions above. |
| `tests/run_field_tactics_r2_smoke.gd` | PASS, 72 assertions. |
| `tests/run_field_tactics_r2_playthrough_smoke.gd` | PASS. Route A: 39,400 ms, 12 food, 4 army casualties. Route B: 79,400 ms, 36 food, 3 army casualties, 0 specialist losses, 1 natural ambush. |
| `tests/run_field_tactics_r2_persistence_smoke.gd` | PASS: completed camps, roads, multisegment orders, blocked transfer and repair recovery across processes. |
| `tests/run_macro_march_low_poly_graphical_smoke.gd` | PASS, 19 assertions in a Metal graphical process at 1152×648, 1280×720 and 1920×1080, including fresh Blackstone tap inspection, specialist/enemy/location view priority, post-dispatch task focus and an engineered-camp location action under paused snapshot comparison. |
| `tests/run_macro_march_direct_dispatch_graphical_smoke.gd` | PASS, 18 assertions in a Metal graphical process. |
| `git diff --check` | PASS. |

The graphical runners require both an isolated `--user-data-dir` and an empty
`--txwzs-v5-save-dir`; running either headless is an expected test refusal, not
a product result. The successful graphical commands used temporary directories
and exited themselves. They did not attach to, operate, close or overwrite the
existing user-visible candidates.

## Candidate boundary

No new long-running candidate window was opened in this checkpoint. Existing
candidate windows and their isolated saves were intentionally retained. The
normal launcher remains the only supported candidate-launch route; player
acceptance is **OPEN**.

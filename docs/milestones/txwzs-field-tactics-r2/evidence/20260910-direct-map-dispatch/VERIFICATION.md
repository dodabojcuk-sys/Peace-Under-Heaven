# Direct Map Dispatch Gesture Verification

## Scope

This checkpoint adds a one-subject Macro March gesture without replacing the
existing explicit side-panel/multi-formation draft path:

1. Press a friendly city or camp and hold for 0.5 seconds.
2. Slide within the compact object strip to highlight one formation, stationed
   army, idle local scout, or idle local engineer. The last highlighted row
   locks only when the pointer leaves the strip toward the map.
3. Drag to a legal target and release to use the existing authority command
   entry immediately.

An uncreated scout is not dispatched when its strip option is merely opened or
locked. Its creation plus first movement order is one `ConstructionController`
transaction after a valid target release. Engineering keeps the deliberately
different editable plan: release into legal open land creates a draft only;
the visible map-side `开工` action is the sole construction commitment.

## Command and result

Run from the repository root with an isolated V5 store:

```sh
TXWZS_GODOT_BIN="/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot"
"$TXWZS_GODOT_BIN" --path . --script res://tests/run_macro_march_direct_dispatch_graphical_smoke.gd -- --txwzs-v5-save-dir="/tmp/txwzs-direct-dispatch-<isolated>/saves"
```

Godot 4.5.1 graphical Metal run passed:

```text
DIRECT_DISPATCH_TRACE invalid=true scout=true march=true engineering=true start=true
MACRO_MARCH_DIRECT_DISPATCH_GRAPHICAL_SMOKE PASS assertions=10
```

The test sends the normal `MacroMarchR0` GUI input sequence: mouse press,
real scene-frame hold, continuous strip motion, target motion and mouse
release. It asserts:

- invalid new-scout release creates no specialist and spends no food;
- valid new-scout release creates one moving scout and spends the one dispatch
  cost;
- a zoomed troop release records the preview's actual route identity, creates
  one army, charges its preview food once, and leaves no confirm draft;
- an engineer release into open land leaves food unchanged and exposes the
  editable plan plus enabled map-side start control; clicking that control
  creates exactly one project and spends the preview cost once.
- focus loss clears a pending direct gesture, so its later release cannot
  publish an order;
- a continuous path crossing several rows locks the intended final highlight,
  not an earlier crossed option;
- a food-shortage failure survives the next UI refresh with no army or food
  side effect; and a map-inspected army can arrive, remain stationed, then use
  the same camp's direct strip to issue its next route.

## Evidence boundary

This is graphical Godot GUI-event evidence. It proves the scene's input and
authority chain, but it is not a desktop-system-mouse video or a player-feel
acceptance result. The reported simulation-stall investigation is unchanged:
**NOT REPRODUCED / NOT DIAGNOSED**. Player acceptance remains **OPEN**.

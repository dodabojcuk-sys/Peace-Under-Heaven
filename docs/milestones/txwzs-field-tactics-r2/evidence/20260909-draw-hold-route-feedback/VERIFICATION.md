# Draw-hold route feedback verification

## Scope

This evidence covers only the Macro March draw interaction introduced after
`19ac414`: 0.5-second hold activation, road-graph preview, engineering-plan
preview, pointer-following endpoints, elapsed-time edge scrolling, and one
shared cancellation path. It does not alter ArmyRegistry order ownership,
ConstructionController's world clock, food transactions, route authority, or
campaign persistence.

## Interaction contract

- A left tap remains selection-only. A map route starts only after the hold
  threshold (`0.50` seconds) is reached; up to eight screen pixels of jitter
  are accepted.
- The hold timer and edge scroll use UI-process elapsed time. They are not
  advanced by pause or world speed.
- Troop dragging previews the authoritative road graph and selected directed
  route, with arrows and a highlighted target. It never displays the raw cursor
  trace as a traversable free-form route.
- Engineering keeps click-to-choose-source. Once held, it previews the same
  authority segment plan used on release, including land/bridge distinctions.
- Right-click, focus loss, and return-to-city clear only transient hold/draw
  state. A released valid draft remains available for confirmation; an invalid
  release clears its temporary geometry and makes no authority transaction.

## Commands and results

Godot executable:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| graphical `tests/run_macro_march_low_poly_graphical_smoke.gd` with an isolated V5 store | PASS, 16 assertions. The added GUI-event contract covers tap, early hold, jitter, live graph preview, pointer endpoint, right-click, focus loss, off-road rejection, elapsed-time edge scroll, visible confirmation, and cross-water engineering preview. |
| headless `tests/run_macro_march_r0_smoke.gd` with an isolated V5 store | PASS, 30 assertions. Existing formal march and engineering input helpers now wait through the same 0.5-second activation. |
| headless `tests/run_field_tactics_r2_smoke.gd` with an isolated V5 store | PASS, 69 assertions. |
| headless `tests/run_field_tactics_r2_playthrough_smoke.gd` with an isolated V5 store | FAIL, pre-existing natural Route B condition: engineer loss `1`, natural ambush `0`. This input-only checkpoint does not relax or inject that gameplay condition. Route A still completed. |

## Continuous recording

`draw-hold-engine-gui-events.avi` is a 3.8-second, 1152x648, 30 FPS Motion
JPEG recording created by Godot Movie Maker. It shows the engine GUI-event
sequence: source press, half-filled hold ring, activation, road preview
following the route, release, and the enabled confirmation draft.

- SHA-256: `d8bc7d348ebfd3fee35ae5ce9b79a4d25641b4da5eef763746ceb2265d9f5495`
- Source: `tests/capture_macro_march_draw_hold_evidence.gd`
- Boundary: this is **engine GUI-event evidence**, not normal macOS
  desktop-system-mouse footage and not player-feel acceptance.

Player hand-feel acceptance remains **OPEN**.

# Blackstone Formal Art Integration — Verification

## Evidence boundary

The PNG files in this directory are actual Godot engine-viewport captures from
the Blackstone candidate's GUI-event capture runner.  They are not generated
concept art and not normal desktop-system-input recordings.  The custom map
canvas was not available as a safe accessibility target, so this batch does
not claim normal-input video or player acceptance.

| File family | Captured runtime state |
| --- | --- |
| `00-*overview*` | theatre overview and material/anchor presentation |
| `01-*route-draft*` | released authoritative march draft |
| `02-*auto-march*` | dispatched army advancing on its confirmed route |
| `03-*engineering-preview*` | released road/bridge construction preview |
| `04-*land-construction*` | active normal-road construction state |
| `05-*bridge-construction*` | active bridge segment construction state |

The `low-poly` copies are the presentation `SubViewport`; the `full-engine`
copies include the actual Macro March UI.  They were captured from the local
art checkpoint before its source commit; the code and assets captured are
unchanged in `38bfe1b`.  The later fixture-only regression checkpoint does not
change rendering.

The current GUI-event capture script did not re-confirm the final army order
after refocusing the engineering route, so it is not retained as proof that an
army crossed the completed bridge.  That behaviour is instead verified by the
formal engineering playthrough; a normal-input crossing recording remains an
open media item.

For a same-camera before/after comparison, use the preceding built-in-geometry
overview at
`../20260909-low-poly-readability-fix/00-low-poly-overview-engine-viewport.png`
and this batch's `00-low-poly-overview-engine-viewport.png`.  The latter has
the selected GLB tree, rock and riverbank geometry; this comparison is limited
to rendering, not gameplay or performance acceptance.

## Engine and graphical check

- Engine:
  `/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`
  (`4.5.1.stable.official.f62fdbde1`, Metal / Apple M4).
- Command used an empty isolated V5 store:
  `Godot --path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd -- --txwzs-v5-save-dir=<temporary-empty-directory>`.
- Result: `MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=12`.
- Resolutions: 1152x648, 1280x720, 1920x1080.
- The largest Camera3D/2D anchor difference was 0.220 logical pixels; road and
  bridge endpoint geometric error was 0.0000; horizontal-ground normal error
  was 0.00000.
- The check also found seven actual selected nature-asset instances on their
  authoritative anchors plus the authored gatehouse and Ridge Watch tower.

## Performance boundary

No committed, same-machine pre-art frame-time or memory baseline exists for
this exact camera and engine configuration, so this record does not invent a
before/after performance claim.  The graphical smoke completed on the target
Apple M4 without renderer errors at all three review sizes.  The renderer loads
and instances selected static GLBs only during static rebuild, not every frame;
a profiler capture is still needed before accepting a performance target.

## Regression repair verification

The Field R2 smoke contains many independent city scenarios in one Godot
process.  With an explicit V5 directory, normal event publication had allowed
a later scenario to restore an earlier scenario's dispatched formations and
resolved patrol.  That made `blocked_transfer.route_segments` empty only after
an earlier `FORMATION_CHANGED` failure, and it made Route B observe Route A's
already-resolved patrol (`ambushes=0`).

The runners now capture an empty-store canonical snapshot and restore it via
the production V5 contract before each independent scenario/route.  This keeps
the real persistence workers responsible for cross-process continuity while
making same-process tests deterministic.

- `FIELD_TACTICS_R2_SMOKE PASS assertions=69` with an empty isolated V5 store.
- `FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE PASS assertions=3` with an empty isolated
  V5 store.
- Route A: 39,400 ms, 12 food spent, four army casualties, both required cities.
- Route B: 79,400 ms, 36 food spent, three army casualties, no specialist loss,
  one naturally triggered forest ambush, both required cities.

These are automated formal-UI/Controller test results, not a claim of player
acceptance or a normal desktop-input playthrough.

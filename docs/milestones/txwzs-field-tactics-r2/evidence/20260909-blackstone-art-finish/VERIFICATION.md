# Blackstone Formal-art Finish — Verification

## Evidence boundary

The PNGs in this directory are actual Godot engine-viewport captures from the
current candidate. They were driven through the Macro March GUI-event path in a
fresh isolated V5 directory. They are neither generated art nor normal
desktop-system-input recordings: the game custom canvas is still not a safe
accessibility target for the available desktop tool. This is an explicit media
gap, not a player-acceptance claim.

| Files | Captured state and scope |
| --- | --- |
| `00-*overview*` | Current material/grounding overview with the selected GLB set. |
| `01-*route-draft*` | Released authoritative military-route draft. |
| `02-*auto-march*` | Selected seven-person army moving at 7%; its pennant/count overlay remains visible at the truthful location near the gate. |
| `03-*engineering-preview*` | Released cross-water road/bridge plan before resource confirmation. |
| `04-*land-construction*` | Active first normal-road segment. |
| `05-*bridge-construction*` | Active bridge segment. |
| `06-*engineering-complete*` | The same project after all physical planned segments completed. |

`low-poly` files contain the actual `SubViewport`; `full-engine` files include
the Macro March rail and overlays. `00-low-poly-overview-engine-viewport.png`
can be compared with the earlier built-in-geometry image at
`../20260909-low-poly-readability-fix/00-low-poly-overview-engine-viewport.png`.
That is a same-camera visual comparison only; it makes no gameplay or
performance-improvement assertion.

## Graphical validation

- Engine:
  `/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`
  (`4.5.1.stable.official.f62fdbde1`, Metal / Apple M4).
- Command:
  `Godot --path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd -- --txwzs-v5-save-dir=<empty-temp-dir>`.
- Result: `MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=13`.
- Resolutions: `1152×648`, `1280×720`, `1920×1080`.
- Camera3D / 2D anchor agreement: at most `0.220` logical pixels; actual road
  midpoint/facing error: `0.0000`; horizontal-ground normal error: `0.00000`.
- The runner checks 82 visible imported GLB mesh instances across all seven
  declared source paths. It verifies no whole-instance material override,
  per-surface variants, transformed actual ground contact, plausible bounds and
  Camera3D-to-click-map anchor agreement. It also checks army, scout and
  engineer selection markers, UI route confirmation, released engineering
  draft, and normal-road/bridge construction rendering.

## First fixed-scene render baseline

At 1280×720, after entering the same Blackstone overview and sampling 30
`process_frame` intervals, the graphical runner recorded:

- mean process-frame interval: `17.237 ms`;
- maximum sampled interval: `32.223 ms`;
- draw calls in the sampled frame: `682`;
- render objects in the sampled frame: `1162`;
- static-memory monitor: `222,394,478 bytes`.

There is no pre-art measurement with the same Mac, renderer, scene, camera and
capture method. These values are a future comparison baseline, not evidence of
a performance improvement or a shipping performance target.

## Isolated regression recheck

Each command used a distinct empty V5 directory and the same 4.5.1 binary.

| Runner | Result |
| --- | --- |
| `run_field_tactics_r2_smoke.gd` | `PASS assertions=69` |
| `run_field_tactics_r2_playthrough_smoke.gd` | `PASS assertions=3`; Route A `39,400 ms`, 12 food, 4 army losses; Route B `79,400 ms`, 36 food, 3 army losses, 0 specialist losses, 1 natural ambush. |
| `run_field_tactics_r2_persistence_smoke.gd` | `PASS`; covers construction, repair, multi-road orders and blocked-transfer disk chains. |
| `run_macro_march_r0_smoke.gd` | `PASS assertions=30`. A first recheck exposed independent same-process contracts inheriting a previous contract's production publication. The runner now restores one pristine production V5 snapshot before each new city scene; no game code or save rule was relaxed. |
| `run_macro_march_r0_persistence_smoke.gd` | `PASS`; three-process blocked/recovered/stationed chain. |

The Macro runner repair is test isolation, analogous to the earlier Field route
isolation: it prevents a previous dispatched formation, project or patrol from
changing the next independent UI contract. It is not a new campaign state
owner or a change to ordinary player persistence.

## Remaining boundary

The existing Field R2, playthrough and persistence suites remain required
regressions; their results are recorded with this candidate's final verification
run. The still images prove the listed engine states only. A continuous normal
desktop-input recording and player acceptance remain open.

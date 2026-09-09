# Blackstone Targeted Render Fixes — Verification

## Scope and evidence boundary

This record covers only two render fixes applied after `83c7cca`:

1. seven selected Kenney natural-material runtime variants are non-metallic;
2. an opaque 3D selection cylinder is replaced by a compact pennant together
   with the established hollow 2D selection ring and status/count layer.

All PNGs here are real Godot engine-viewport captures at 1152×648, driven by
the established Macro March GUI-event chain in a fresh isolated V5 directory.
They are not generated reference art or normal desktop-system-input evidence.
The custom canvas remains unavailable as a safe accessibility target, so
continuous normal-input video and player acceptance remain open.

## Fixed-camera before and after comparison

| View | Before (`83c7cca`) | After (this candidate) | Checked result |
| --- | --- | --- | --- |
| Overview | `../20260909-blackstone-art-finish/00-overview-full-engine-viewport.png` | `00-overview-full-engine-viewport.png` | Tree crowns are recognisably green with separate darker trunks; rocks retain separate facets instead of the imported metallic-black response. Camera, lighting, exposure and scene are the same capture route. |
| Seven-person army at 7% | `../20260909-blackstone-art-finish/02-auto-march-full-engine-viewport.png` | `02-auto-march-full-engine-viewport.png` | The selected army still occupies the same truthful gate-side location and has the 2D hollow ring/count plus a compact marker; no solid 3D ground disc covers the gate or unit model. |

Additional after-state captures:

| Files | State |
| --- | --- |
| `07-*scout-selected*` | Selected scout, using the shared specialist marker contract. |
| `08-*engineer-selected*` | Selected engineer, using the same contract without a second count label. |
| `01-*route-draft*`, `02-*auto-march*` | Drafted route and actual marching state. |
| `03-*engineering-preview*` through `06-*engineering-complete*` | Released cross-water plan, normal road work, bridge work and completed engineering. |

`low-poly` PNGs show the actual `SubViewport`; `full-engine` PNGs include the
Macro March rail and 2D selection/status overlays. The bridge states validate
that the render-only marker/material changes do not suppress the existing
road/bridge state rendering. They do not claim that a user performed these
steps through desktop-system input.

## Material inspection and graphical validation

- Engine: `/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`
  (`4.5.1.stable.official.f62fdbde1`, Metal / Apple M4).
- Source-material inspection: a temporary read-only Godot inspector loaded the
  seven selected GLBs. Every active source surface printed `metallic=1.00` and
  `roughness=1.00`; no source file was modified.
- Graphical command:
  `Godot --path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd -- --txwzs-v5-save-dir=<empty-temp-dir>`.
- Result: `MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=13`.
- Resolutions: `1152×648`, `1280×720`, `1920×1080`.
- Projection/geometry stayed unchanged: Camera3D/2D maximum anchor error
  `0.220 px`; road/bridge midpoint/facing error `0.0000`; horizontal-ground
  error `0.00000`.
- The runner found 82 visible meshes across seven declared source assets,
  verified every runtime surface variant is `BaseMaterial3D` with
  `metallic=0`, retained per-surface overrides and tested grounded visible
  bounds. It also checked army, scout and engineer markers have a pennant and
  no `SelectionRing` mesh child.
- The fixed 1280×720 sampling recorded `16.691 ms` mean process-frame interval,
  `17.563 ms` peak, `682` draw calls, `1162` render objects and
  `222,463,430` static-memory bytes. This is a fresh initial sample only, not
  a stable-FPS, performance-improvement or acceptance claim.

## Remaining validation

The following focused rechecks were run from separate empty V5 directories on
this candidate. No test changes resource, movement, fog, save or combat
authority.

| Runner | Result |
| --- | --- |
| `run_macro_march_r0_smoke.gd` | `PASS assertions=30`; includes formal route, engineering, scout, repair, UI layout and map-input contracts. |
| `run_macro_march_r0_persistence_smoke.gd` | `PASS`; three independent processes preserve blocked, recovered and stationed states. |
| `run_field_tactics_r2_smoke.gd` | `PASS assertions=69`; includes the actual middle-of-road transfer, repair return, time-equivalence, expert contact and shared-patrol contracts. |
| `run_field_tactics_r2_playthrough_smoke.gd` | `PASS assertions=3`; Route A: 39,400 ms, 12 food spent, 4 army casualties. Route B: 79,400 ms, 36 food spent, 3 army casualties, 0 specialist losses, 1 natural ambush. These are automation results, not balance conclusions or player acceptance. |
| `run_field_tactics_r2_persistence_smoke.gd` | `PASS`; construction, repair, multi-road orders and transfer/station/return/recovery chains complete across independent disk processes. |

The latest candidate still has no normal desktop-system-input recording because
the available accessibility surface cannot safely target the custom map canvas.
The image set and GUI-event evidence remain explicitly labelled; player
acceptance is OPEN.

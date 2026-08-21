# Graybox Building Presence R3A Acceptance

## Identity

| Field | Value |
|---|---|
| Repository | `/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0` |
| Branch | `codex/product-successor-inner-city-r0` |
| Start head | `c1f7d5a6a0c1aeb64749b60964e7b73e5943ea59` |
| Formal main scene | `res://scenes/blank_map.tscn` |
| Formal city node | `MapWorld/RegularCitySpatialFoundation` |
| Visual status | `GRAYBOX_SPATIAL_FOUNDATION` |
| Final building art | `NOT_STARTED_BY_SCOPE` |

## Delivered

- Added the shared `GrayboxBuildingVisual` presentation component.
- Routed fixed and runtime building nodes through the component while retaining
  `ConstructionController` as the sole state writer.
- Preserved footprint, entrance, road-state, orientation, lifecycle, and V5
  snapshot inputs.
- Added the focused `run_r3a_graybox_building_presence_smoke.gd` contract test.

## Verification

The focused test covers real definition/footprint reads, N/E/S/W entrance
changes, shared ghost/completed geometry, foundation/frame/completed stages,
pause stability, neutral fallback, distinct farm/logging-camp/warehouse
silhouettes, connected/disconnected entrance presentation, no state mutation
from presentation, and V5 orientation restoration. The complete smoke suite
passed `42/42`, including the R2A and R2B focused runners and the unified
building interaction contract. Godot 4.5.1 editor parse/import and the formal
`blank_map`, Blackstone, and C0 headless smokes exited 0; no error signatures
were found in the captured logs.

Native 1440×900 evidence covers directory → logging camp → placement → `R`
rotation → one mouse confirmation → resource deduction → foundation →
construction → completion → selected detail. The evidence bundle is external
to Git at
`/Users/m4-zhi/Downloads/txwzs2-r3a-graybox-building-presence-evidence-20260821-v1`.
The native recording also shows foundation, mid-construction, completed,
selected-detail, and four-gate states. The requested 1920×1080 run was
displayed by macOS as 1920×960; it is recorded as a non-strict 1080-height
viewport result.

## Non-goals and follow-up

Organic-garden layout, final art, traffic/pathfinding, full-map camera rotation,
new schema, battle/world-map work, G4, push, and deployment remain untouched.
The evidence directory is external to Git and contains no product source.

# Road, Lot, and Entrance Semantic Closure — R2A

## Identity

| Field | Value |
| --- | --- |
| Repository | `/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0` |
| Branch | `codex/product-successor-inner-city-r0` |
| Pre-head | `86e25a47d14a2c5041518d2e67a06268eef25503` |
| Formal main scene | `res://scenes/blank_map.tscn` |
| Formal city node | `MapWorld/RegularCitySpatialFoundation` |
| Visual status | Graybox spatial foundation; final building art not started by scope |

## Authority decision

The brown road surface is now a formal projection owned by
`RegularCitySpatialFoundation`. `ROAD_LAYOUT_RECTS` is converted to a copied
cell dictionary and used by rendering, connected-road derivation, and
placement validation. The same projection exposes reserved civic cells, the
wall ring, and gate slots. No second map model or persistent road state was
introduced.

Ordinary building validation proceeds through the existing
`ConstructionController` authority: map bounds, existing occupied cells,
actual UI occlusion, and formal spatial blockers are evaluated before the
existing resource check. Existing occupied cells retain `位置已占用`; UI
overlap retains `被界面遮挡`; road, wall, gate, and reserved cells report their
specific blocker.

## Entrance and operation contract

`CityGridRules.get_definition_entrance_adapter()` consumes the existing
`BuildingDefinition.road_anchor_offsets` and selects a stable perimeter
adapter in north/east/south/west order. `resolve_entrance()` rotates the
entrance cell, facing, and contact cell together with the footprint. The
controller unions formal roads with the existing runtime road records and
reuses the existing root-connected flood fill.

Required-road buildings therefore have three honest states:

1. Green: legal lot and the derived entrance contacts a connected road.
2. Amber: legal lot but the derived entrance is disconnected; the building may
   be placed but remains stopped after completion.
3. Red: invalid lot, with the concrete blocker shown in the preview.

Operational status is derived from lifecycle completion and entrance contact;
it is not written as a save field. Existing V5 snapshot schema and legacy
orientation fallback remain unchanged.

## Implementation files

- `scripts/regular_city_spatial_foundation.gd` — formal road/lot projection and
  shared graybox rendering.
- `scripts/city_sandbox/city_grid_rules.gd` — deterministic definition entrance
  adapter.
- `scripts/construction_controller.gd` — spatial validation, derived entrance
  state, preview/diagnostic marker, and connected operational status.
- `scripts/state/early_city_snapshot_v1.gd` — snapshot validation uses the same
  entrance adapter and formal road projection.
- `scripts/building_selection_controller.gd` — selected-building marker
  visibility only.
- `tests/run_r2a_road_lot_entrance_smoke.gd` — 16 focused assertions.

Existing placement/lifecycle/selection/unified tests were only updated where
their hard-coded fixtures occupied the newly formal road band; no assertion
was deleted or weakened.

## Verification

Commands executed from the repository root:

```text
Godot --headless --path . --editor --quit-after 2
Godot --headless --path . --scene res://scenes/blank_map.tscn --quit-after 2
Godot --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 2
Godot --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 2
Godot --headless --path . --script res://tests/run_r2a_road_lot_entrance_smoke.gd
Godot --headless --path . --script res://tests/run_*_smoke.gd (40 discovered runners)
git diff --check
```

Results: editor parse/import and all three scene smokes exited 0; focused
R2A smoke passed 16/16; all 40 discovered runners passed with 0 failures.
Native 1440x900 runtime evidence was captured from a fresh Godot 4.5.1 copy
bound to the active successor and includes the road-red rejection, amber
disconnected lot, west-facing green connection, confirm hover, construction
foundation, normal-time completion, and connected building detail. The
existing shell has no user-facing save button; orientation/save/load
re-derivation is therefore claimed only from the focused authority test, not
from a fabricated visual save flow.

## Scope and non-regression

R2A does not add player road construction, road removal, traffic/pathfinding,
organic garden-city layout, final building art, full-map camera rotation, new
resources, economic rebalance, save migration, G4, push, or deployment.
Canonical (`4292ade22bbd3b4b14e48d98475ac50c1da265f6`) and RG-O1 v1 were not
modified or operated. R2B remains not started.

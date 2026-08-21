# Graybox Building Presence R3A

## Scope

R3A adds a reusable, procedural 2.5D presentation layer for the regular-city
building instances. It is intentionally graybox: final building art is not part
of this slice. The same visual grammar can be reused by regular axial/ward and
future organic-garden layouts without copying construction state or UI.

## Authority boundary

`ConstructionController` remains the only owner of placement, footprint,
orientation, road connection, lifecycle, resource transactions, and V5
save/load. `GrayboxBuildingVisual` reads those values and renders them; it does
not write resources, roads, buildings, timers, or snapshots. No autoload,
schema, scene entry point, or second state tree was added.

## Visual grammar

Each instance is built from a shared foundation, shadow, body, darker side,
roof, entrance, orientation marker, selection outline, and construction marker.
The projection is screen-space consistent: a fixed upper-left light direction
produces a lower-right shadow. Farm, logging camp, warehouse, watchtower, and
unknown definitions use distinct detail mappings with a neutral fallback.

The entrance and marker are derived from the authoritative N/E/S/W orientation.
The footprint passed to the component is the controller's rotated footprint, so
the visual occupancy cannot diverge from validation or save data.

## Lifecycle presentation

The component exposes four presentation stages without adding a persisted
progress field:

`PLACEMENT_GHOST` → `FOUNDATION` → `FRAME_OR_PARTIAL_MASS` →
`COMPLETED_BUILDING`.

Construction progress is derived from the existing start day, completion day,
current day, and day ratio. Only constructing nodes receive a per-frame pulse;
completed nodes update on state changes. Pausing the city freezes the visual
stage because the authoritative clock remains unchanged.

## Interaction and future profiles

Placement ghost, construction, and completed instances share the same geometry
source. Right-rail controls, minimap, road tools, Esc priority, and selection
remain owned by the existing UI/controllers. Organic-garden city is not
implemented in R3A; it will supply a different spatial profile to this same
component rather than a second building model.

## Explicit non-goals

- final art, external textures, models, fonts, or shader packages;
- new building definitions, costs, durations, upgrade writers, or economy rules;
- full-map camera rotation, curved roads, traffic/pathfinding, or city
  generation;
- new save schema, autoload, battle, world-map, G4, push, or deployment.

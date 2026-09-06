# Inner City Golden Path UI-R0

## Scope

This document defines the active product-successor presentation slice only.
It does not reopen technical-host selection, migrate legacy work, start G4,
or introduce a second city, state tree, save schema, or writer.

## Runtime chain

`project.godot` declares `res://scenes/blank_map.tscn` as `run/main_scene`.
`BlankMapRoot` owns the one `MapWorld`, one `Camera2D`, one
`ConstructionController`, and one `BuildingSelectionController`.
`ConstructionController` remains the presentation coordinator for the existing
single city authority; `NationState` remains the resource authority.

## Golden path

1. The player opens the inner city and sees the active Blackstone overview,
   shared national resources, strategic time, the visible one-city operating
   rail, and the build entry.
2. The player can collapse the rail without altering placement or time, then
   pan/zoom the single world and select a building through the existing
   placement-id selection route.
3. The building record supplies level, investment, duration, effect,
   prerequisite, progress, and operational status to the detail panel.
4. Upgrade status is intentionally read-only. The current authority exposes no
   building-upgrade command, so the gate can be opened and cancelled but never
   mutates a building, resource balance, or save.
5. The player opens the build catalog, selects an existing definition, confirms
   a legal map placement through the existing construction authority, or uses
   Escape/right click to cancel. No UI code creates a parallel placement or
   resource write path.

## Presentation rules

- Native Godot `Control`, `Theme`, `Panel`, `Button`, and `Label` are used;
  there is no DOM or embedded web UI.
- The shell uses a dark slate command surface, restrained teal action accents,
  and explicit status copy instead of visual placeholders.
- Layout is calculated on viewport-size changes, not rebuilt in `_process`.
- City rail, status bar, catalog, detail panel, and minimap card are registered
  UI occlusion regions, so input does not leak to the map behind them.

## Non-goals

- No multi-city switching, national writer, building upgrade writer, V5 schema
  change, save migration, scene replacement, campaign redesign, asset import,
  or legacy cleanup.

## R2A road, lot, and entrance semantics

The regular-city graybox now exposes one spatial projection from
`RegularCitySpatialFoundation`: its formal road rectangles, civic reserved
cells, wall ring, and four gate slots drive both the road drawing and the
construction queries. `ConstructionController` consumes copies of that
projection; it does not maintain a second road or lot map.

Ordinary building placement rejects road, wall, gate-slot, reserved-court, and
existing-building overlap. UI occlusion remains an input blocker, while an
existing occupied cell retains its authoritative `位置已占用` reason even when
that cell is outside the current camera.

Road-serving definitions use the existing `road_anchor_offsets` adapter and
`CityGridRules` to derive one entrance cell and facing for each N/E/S/W
orientation. A legal lot may be disconnected and is shown amber; a lot whose
derived entrance touches the formal connected road set is green. Operational
status is derived from completion plus that entrance contact and is never
persisted as a separate save field. Legacy snapshots without orientation keep
the existing north-facing fallback.

The preview and selected-building diagnostic marker is intentionally graybox
only. Player road construction, road removal, traffic/pathfinding, organic
garden layouts, and final building art remain out of scope for R2A.

## R2B player road construction

R2B adds a player-road delta on top of the formal road projection. The formal
layout remains owned by `RegularCitySpatialFoundation`; player road cells are
authoritative runtime placement records owned by `ConstructionController`. The
rendering projection, flood-fill connectivity, building entrance checks, and
V5 snapshot export all consume that same union. The base layout is never
serialized a second time.

The right rail exposes one road tool. A native pointer drag creates a single
horizontal or vertical draft; diagonal input is rejected with an explicit
reason, and a second drag is required for a turn. Release only fixes the
preview. The confirm button invokes the existing resource transaction once;
cancel and the first Escape clear only the draft, while the second Escape
leaves road mode. Invalid cells reject the entire path, including occupied
buildings, construction footprints, civic reserves, walls, gates, bounds, and
UI-occluded cells. Existing roads are traversable without duplicate cost.

Green and amber previews are derived from the same N/E/S/W flood fill used by
production buildings. The graybox projection draws straight, corner, T, cross,
and endpoint topology with one road tile scale. A connected road can activate a
completed required-road building immediately; production begins on the next
authoritative time boundary and is never backfilled for a disconnected period.

Player roads reuse the existing V5 placement array and orientation field, so
the schema version does not change. A legacy snapshot with no road placements
restores an empty player-road delta. Connectivity and operational status remain
derived values, not persisted booleans.

R2B deliberately does not add road deletion or upgrade, traffic/pathfinding,
bridges, slopes, curved roads, full-map camera rotation, organic garden-city
generation, final art, a second world-state owner, or G4.

# Regular City Spatial Foundation And Right Build Rail R1

## Result

`VISUAL_STATUS=GRAYBOX_SPATIAL_FOUNDATION`

`FINAL_BUILDING_ART=NOT_STARTED_BY_SCOPE`

The formal `blank_map` path now starts on the inner-city view. The external
expedition scene remains reachable only through its existing entry; it is no
longer an overlapping default layer.

## Delivered

- A regular axial/ward graybox city larger than a single viewport, with walls,
  cross and axial roads, wards, a compact civic court, passive volumes, and no
  default logical grid.
- Camera drag/zoom remains on the existing map controller; UI safe regions do
  not start map actions.
- A responsive right rail with an actual minimap viewport frame, build catalog,
  placement controls, and reused building detail surface.
- Placement ghost, local footprint grid, legal/illegal presentation, four-way
  building orientation, authority-backed confirmation/cancellation, and
  graybox foundation/construction/completion states.
- One gate component, instantiated four times at the city perimeter with
  `NORTH/EAST/SOUTH/WEST` rotations.
- Orientation in V5 snapshots with schema-2 compatibility defaulting to north.

## Runtime evidence

Real isolated Godot windows were inspected at 1280x720, 1440x900, and
1920x1080. The 1440x900 interaction pass opened the right catalog, selected
the real logging camp, positioned its placement ghost on the city, and used
the `R` shortcut plus the rotate control. The rail displayed the synchronized
east/south orientation and footprint. Construction command, cancellation,
completion, and V5 save/load behavior are also covered by the focused smoke
because they use the existing authoritative command and persistence path.

Evidence files are external to the repository:

- `baseline-1440x900.png`
- `final-overview-1280x720.png`
- `final-overview-1440x900.png`
- `final-overview-1920x1080.png`
- `final-build-catalog-1440x900.png`
- `final-placement-rotated-1440x900.png`

## Verification

Focused R1, UI, selection, construction, and V5 persistence smoke runners
passed after the implementation. Dynamic discovery ran all 39 repository smoke
runners with 135 `PASS:` assertions and zero failures. Godot 4.5.1 editor
parse/import and `blank_map`, `blackstone_expedition_mvp`, and
`c0_battle_graybox` headless scene smokes also passed without a parser, missing
resource, invalid-call, freed-instance, or signal error.

## Deliberate limits

- No full camera 90-degree map rotation: it requires a dedicated transform
  contract across selection, snapping, minimap, and safe UI regions.
- No `ORGANIC_GARDEN_CITY`, final art, traffic simulation, or automatic road
  generation.
- No upgrade writer was invented; the existing read-only upgrade gate remains
  truthful.

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

## R1C native mouse construction closure

The follow-up native-mouse pass found a product input-routing defect rather
than a Retina/DPI coordinate error. While the placement ghost was valid, the
root `MapPanController._input` path continued to translate pointer motion over
the right construction rail into a map preview update. Hovering the visible
confirm button therefore changed the preview to `被界面遮挡` and disabled the
button. The button itself had a normal hit rectangle, `mouse_filter=STOP`, and
the expected parent chain, so this was classified as
`B_CONTROL_OVERLAY_OR_MOUSE_FILTER` (root input routing / overlay ownership).

`MapPanController._handle_construction_input` now returns early for pointer
events inside the construction UI bounds. This leaves the rail's native
`Button` dispatch in control while preserving map placement updates outside
the rail. No resource values, save schema, building definition, or authority
writer changed.

The isolated 1440x900 Godot 4.5.1 probe recorded the complete native sequence:

```text
R1C_STATE=2 PREVIEW_VALID=true
R1C_CONFIRM_MOUSE_ENTERED
R1C_HOVERED_CONTROL=/root/BlankMapRoot/UI/Shell/ConstructionEntryPanel/ConfirmPlacementButton
R1C_CONFIRM_MOUSE_BUTTON pressed=true
R1C_CONFIRM_MOUSE_BUTTON pressed=false
R1C_CONFIRM_PRESSED_COUNT=1
R1C_STATE=0 PREVIEW_VALID=false
```

The single click spent exactly the logging-camp cost (wood 100 → 60), removed
the placement panel, showed the construction foundation, and later produced a
completed selectable `伐木场`. The evidence bundle is external:

- `r1c-native-mouse-probe.log`
- `r1c-construction-start-1440x900.png`
- `r1c-construction-paused-1440x900.png`
- `r1c-completion-clean-1440x900.png`
- `r1c-building-detail-1440x900.png`
- `r1c-gate-north-1440x900.png`
- `r1c-gate-south-east-1440x900.png`
- `r1c-gate-west-south-1440x900.png`

The gate frames are separate real-runtime pans because the full city exceeds a
single 1440x900 view at the readable zoom. Together they show north, east,
south, and west instances; the focused smoke verifies that all four instances
share one `CityGateComponentR1` script and orientations `[0, 1, 2, 3]`.

The committed smoke adds a regression assertion that pointer motion over the
confirm control cannot invalidate a legal ghost. Existing construction,
building-selection, V5 persistence, and gate-component tests continue to cover
authority, cancellation, double-submit rejection, orientation persistence,
legacy north fallback, and the single gate component. Native pressed-count and
post-confirm state are proven by the isolated probe rather than synthetic
signal emission.

## Verification

Focused R1C and the existing UI, selection, construction, and V5 persistence
smoke runners passed after the fix. Dynamic discovery ran all 39 repository
smoke runners with 1,877 `PASS:` assertions and zero failures. Godot 4.5.1
editor parse/import and `blank_map`, `blackstone_expedition_mvp`, and
`c0_battle_graybox` headless scene smokes also passed without a parser, missing
resource, invalid-call, freed-instance, or signal error. The pre-R1C live
baseline had no known failures; the R1C run did not expand the failure set.

## Deliberate limits

- No full camera 90-degree map rotation: it requires a dedicated transform
  contract across selection, snapping, minimap, and safe UI regions.
- No `ORGANIC_GARDEN_CITY`, final art, traffic simulation, or automatic road
  generation.
- No upgrade writer was invented; the existing read-only upgrade gate remains
  truthful.

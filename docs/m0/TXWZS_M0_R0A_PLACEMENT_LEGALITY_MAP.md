# TXWZS M0 R0A Placement Legality Map

## Status

- Scope: conditional M0 R0A repair only
- Base: `1312754260313ee12542cb1052f0b5bbe06b5dfa`
- Product authority: supplied R0A instruction, then game-bible decisions D-071 through D-073
- Overall MVP and final balance: not frozen

## Problem and Root Cause

R0 contained both kinds of defect. First, the authored Blackstone lower row used
`y=430`, height `120`. Conservative grid rasterization therefore occupied rows
10 through 13, while the formal horizontal road begins at row 13. Academy,
CityGate, CommandPlatform, and Noticeboard were logically on the road even
though the older test derived height with `ceil(size / 40)` and missed the
non-grid-aligned start. R0A moves that complete authored row to `y=400`, keeping
the same building sizes and road design while ending the footprints at row 12.

Second, `GrayboxBuildingVisual` drew its shadow up to 12 world units outside the
logical footprint. Even a legal building adjacent to a road therefore looked as
if it covered the road. R0A constrains the decorative shadow to the authoritative
footprint; the selected entrance marker may still point outward because it
communicates adjacency rather than occupancy.

The spatial contract was also fragmented: building and road validators returned
different result shapes, snapshot hydration had no derived legacy-overlap
report, and placed buildings exposed no atomic move/rotate revalidation writer.
Those paths now share one spatial authority.

`ROOT_CAUSE=BOTH`

- `VISUAL_BOUNDS_OVERFLOW`: the visible shadow crosses the exact footprint.
- `LOGICAL_OCCUPANCY_OVERLAP`: four default Blackstone fixed buildings occupied
  formal-road row 13. The authored row was shifted upward by 30 world units;
  Blackstone and Riverbend scans now both return zero overlap. Legacy/hydration
  overlaps are preserved and reported as `LEGACY_OVERLAP`.

## Single Legality Contract

`CityGridRules.evaluate_placement_legality()` is the pure spatial authority.
`ConstructionController` supplies current map bounds, building occupancy,
formal/player roads, fixed reserves, walls, and gates. UI visibility and
resource affordability remain separate non-spatial gates.

The result shape is:

```text
is_legal
reason_code
reason_text
conflicting_cells
conflicting_placement_ids
road_connection_state
entrance_state
legacy_overlap
```

Stable reason codes include `OUT_OF_BOUNDS`, `BUILDING_OVERLAP`,
`ROAD_OVERLAP`, `IMMOVABLE_OBJECT_OVERLAP`, `INVALID_ENTRANCE`,
`UI_OCCLUDED`, `INSUFFICIENT_RESOURCES`, and road-draft errors.

## Entry-Point Map

| Entry point | Shared spatial query | Commit behavior |
| --- | --- | --- |
| Building preview | Building footprint against occupancy and all roads | Confirm disabled when illegal |
| Building placement API | Same query, without UI occlusion | No ID, resource, or placement write on failure |
| Player-road preview/API | Same query for each new road cell | Whole orthogonal draft fails atomically |
| Move placed building | Same building query with source placement ignored | Original cell and node remain unchanged on failure |
| Rotate placed building | Same building query with source placement ignored | Original orientation and entrance remain unchanged on failure |
| Fixed-map scan | Same query over authored footprint/road sets | Read-only report; no automatic layout change |
| Save hydration | Same query after non-destructive restore | Preserve accepted data; expose `LEGACY_OVERLAP`; new writes still fail |

## Orientation and Entrance

`CityGridRules.resolve_entrance()` remains the only N/E/S/W transform for the
rotated footprint, entrance cell, facing vector, and adjacent road-contact cell.
Road connection is derived from that contact cell; a road never occupies the
building entrance cell itself.

## Compatibility and Rollback

- Schema 4 fields and snapshot identity remain unchanged.
- Legacy overlap detection is derived runtime information and is not persisted.
- Existing placements are never deleted, moved, or rotated during load.
- R0A rollback is the local base commit `1312754`; canonical source and remote
  state remain untouched.

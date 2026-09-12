# Design QA — Blackstone Sample Theater R2

## Source and implementation

- Source direction: `/var/folders/4c/kv_f21j16ml7wpmhtgsnpbch0000gn/T/codex-clipboard-7a747b03-319f-4ce8-abc2-8d648e69bd04.png`
- Source dimensions: 1680x945
- Runtime implementation: `scripts/macro_march/macro_march_r0.gd`
- Playable definition: `resources/macro_march/blackstone_playable_r2.tres`
- Compared runtime frame: `docs/milestones/txwzs-field-tactics-r2/evidence/20260909-blackstone-sample-final/04-engineering-plan.png`
- Candidate viewport: 1280x720 game content in an identified macOS window
- Combined comparison: `/tmp/txwzs-r2-concept-runtime-comparison-final.png`

## Comparison

The concept is art direction rather than a pixel-accurate target. The candidate
preserves the visible interaction hierarchy: battlefield-first layout, oblique
map projection, west-side player city, east-side objectives, river barrier,
forest staging area, route-aware minimap, and a right-side construction plan.
The runtime also exposes the required action facts in the same state: selected
construction endpoints, road and bridge intent, cost, travel/build time,
confirmation, cancellation, and target-window identity.

The implementation deliberately reduces asset density. It uses reusable Godot
primitives for city walls, gates, flags, tents, trees, rocks, river banks, roads,
bridge decks, armies, and specialists instead of the concept's illustrated
buildings and vegetation. That reduction remains within the requested sample
scope: tactical geometry, visibility, hit testing, and controls are readable and
operable, while final production art remains a separate acceptance gap.

## Visible checks

- Battlefield objects stay inside the clipped map and do not overlap the rail.
- The two route families and the river barrier are readable at the default view.
- Cities, friendly garrisons, forests, rocks, roads, bridges, and units use
  distinct silhouettes or marks.
- The engineering preview names both endpoints and distinguishes road plus bridge.
- Route drawing, rendering, minimap selection, and pointer hit testing share one
  projection.
- The identified candidate has no cropped primary control at 1280x720; automated
  geometry checks also pass at 1152x648 and 1920x1080.

## Iteration history

1. Replaced the color-only playable Resource with an authored battlefield.
2. Separated playable and regression theater definitions.
3. Added a fixed-oblique projection and projected rectangular terrain as shared
   world-space polygons.
4. Reworked city, camp, terrain, road, bridge, and damage presentation.
5. Compared the concept and runtime engineering state side by side; retained the
   simpler density because the player task and map hierarchy remain clear.
6. Verified the final window with native route and engineering input evidence.

passed

# Blackstone Low-poly Sample R2

## Purpose

This is a render-only miniature presentation for the player-facing Blackstone
sample theatre. It proves a small, operational segment—city gate, road, river,
bridge work, and forest garrison—can be presented with volume without creating
a second campaign simulation.

## Authority boundary

`MacroMarchLowPolyPresentation` receives the existing Macro March read model
and `FieldTacticsState` read model. It never creates roads, moves armies,
advances time, spends food, resolves battles, or writes a save. Those facts
remain with `ConstructionController`, `ArmyRegistry`, and the existing V5
publication path.

The legacy `MacroMarchMapCanvas` remains available through the visible
`切换为二维战区` control. Hit testing, panning, zooming, minimap navigation,
route drafting, and every command continue to use the established invertible
2D map transform. The 3D layer uses the inverse-compatible ground mapping only
to display those same coordinates.

## Projection contract

The low-poly ground is horizontal in XZ. Its two horizontal basis vectors are
derived from the active camera and scaled so orthographic projection still
equals the authoritative 2D expression `(x + 0.20y, 0.72y)` for every ground
anchor, rather than relying on manual per-location offsets. Only the explicit
presentation elevation changes 3D Y; world north/south never changes ground
height. `Camera3D.unproject_position()` is the renderer-side reference, and
the host converts its SubViewport-local result back through the map rectangle
only when comparing it to the 2D map coordinate.

Road and bridge segments are attached to their scene parent before their global
midpoint and `look_at()` transform are applied. Runtime actors and projects
also synchronize every world refresh, independently of the less-frequent point
ownership rebuild; a moving army cannot remain visually frozen merely because
no garrison changed owner.

## Rendering approach

- A `SubViewport` holds an orthographic `Camera3D`, one directional light, and
  an isolated 3D world.
- The scene uses small authored Godot primitive assemblies for Chinese frontier
  gates, camps, the watchtower, roads, bridges, units, and active construction.
  The static forest, rocks, and riverbank grass instantiate seven selected GLB
  files from Kenney Nature Kit 2.1 (CC0) through a small path mapping. The
  upstream license, source archive checksum, selected-file checksums, and
  modification boundary are recorded in `assets/blackstone_art/ASSET_MANIFEST.md`.
  The generated gatehouse image in `docs/design/references/` is an internal
  style reference only, not a runtime texture, model, or gameplay screenshot.
- Cities, garrisons, trees, rocks, river surfaces, roads, bridges, armies,
  specialists, patrols, and active construction are rebuilt or updated from
  the authoritative read models. The presentation adds a horizontal overscan
  ground only to fill the clipped camera viewport; it never expands terrain or
  passability. A released engineering draft is drawn from Field's authoritative
  segment plan, while active work renders only its current segment: normal road
  uses a road surface and bridge uses deck/rails. Bridge state visibly
  distinguishes deck, scaffold, and damaged break geometry.

### Formal-art material and grounding policy

The seven selected GLBs retain their imported mesh surfaces. The presentation
does not assign one `material_override` to a whole tree or rock: it makes a
cached material variant per declared asset kind and source surface, preserving
the GLB's texture slots and render flags while harmonising trunk/crown and
rock-facet colours with the Blackstone palette. The selected Kenney imports
declare `metallicFactor=1`, so only those runtime natural-material copies set
`metallic=0`; they remain non-metallic trees, grass and rocks without mutating
their source files or unrelated game materials. Runtime instances are then
settled by the transformed lowest visible mesh bound, rather than the imported
scene root, so an authored GLB offset cannot leave a tree, rock or grass clump
floating or buried beneath the horizontal ground.

Forest floor patches, rock-ground variation, shallow bank strips, camp tents,
palisades and campfires are presentation-only layers over existing theatre
regions. They do not alter movement, water, fog, hidden patrol knowledge,
forest ambush eligibility, or road availability. Roads are made visually wider
only in the render layer; their authoritative polylines and input transform are
unchanged.

The selected army or specialist receives an elevated, depth-independent command
pennant plus the existing hollow 2D selection ring and count/status overlay.
For a selected living scout or engineer, the transparent map canvas reads the
authoritative specialist `world_position` and existing map projection to draw
two hollow rings and a short role/phase label above any occluding gate, camp,
tree, or bridge. A specialist selection suppresses the army's competing
selected count/pennant, so the current command subject remains unambiguous;
unselected armies keep a single compact member count. At a shared city anchor,
successive normal map clicks cycle scout, engineer, then army. This replaces the
former opaque 3D ground disc without adding a game position, hit target,
visibility knowledge, or simulation responsibility.
When the player has explicitly selected city formations to issue a new order,
that intentional command mode retains the city-gate route-drafting click; it
does not get replaced by a coincident specialist selection.

## Player information correction

The city formation roster is an availability list, not a casualty report. Once
a seven-member formation is dispatched, its city count is zero because its
members were transferred to the active army snapshot. The Macro March panel
now labels that row `已出征（当前 N 人）`, reads `N` from the active army snapshot,
and keeps the original order source and target visible while marching. Latest
patrol engagement losses are read from the field engagement record rather than
inferred from an emptied city row.

## Validation boundary

Headless Macro March smoke verifies the formal UI model after dispatch: a
seven-member city formation becomes a zero-member city row while the active
army remains seven members and the status reports `黑石城 → 北望驻扎点`.

`tests/run_macro_march_low_poly_graphical_smoke.gd` deliberately requires a
non-headless Godot process. At 1152x648, 1280x720, and 1920x1080 it compares
named points, bridge heads, and a road midpoint against `Camera3D` projection,
checks actual segment midpoint/facing plus horizontal ground mesh normals,
drives route drawing and engineering confirmation through the Macro March input
handlers, verifies a released draft remains visible as `NORMAL → BRIDGE →
NORMAL` construction, verifies a moving army updates its rendered node, and
confirms switching 2D/3D does not mutate the campaign snapshot. Headless suites
do not claim this rendering coverage.

The graphical runner also asserts that all seven declared CC0 nature assets
were instantiated as visible, non-empty meshes; that their transformed bounds
are grounded at the authoritative anchors with plausible size; that surface
material partitioning is retained and their runtime variants are non-metallic;
and that their camera projection agrees with the clickable 2D map. It also
uses GUI mouse events to select a moving army and both same-gate specialist
roles, comparing whole-viewport image changes for their final overlays and
right-click cancellation; an internal selected ID or an absent opaque disc does
not stand in for that evidence. The runner logs a fixed 1280×720 30-frame process-time, draw-call,
render-object and static-memory baseline for later comparison; because no
matching pre-art measurement exists, that baseline is not an improvement claim.

The sample 3D viewport was launched in a separate Godot process for visual
inspection. It is render evidence only. The current desktop automation surface
does not expose the game's custom canvas controls as accessible targets, so it
does not establish normal system-input media for this candidate. That media
remains an explicit follow-up validation item.

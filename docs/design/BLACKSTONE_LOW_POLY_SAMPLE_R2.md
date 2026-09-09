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
- The scene uses only Godot built-in primitives (`BoxMesh`, `CylinderMesh`,
  `SphereMesh`, and generated ground meshes) and `StandardMaterial3D`. No
  third-party asset, generated model, or external texture is included.
- Cities, garrisons, trees, rocks, river surfaces, roads, bridges, armies,
  specialists, patrols, and active construction are rebuilt or updated from
  the authoritative read models. The presentation adds a horizontal overscan
  ground only to fill the clipped camera viewport; it never expands terrain or
  passability. A released engineering draft is drawn from Field's authoritative
  segment plan, while active work renders only its current segment: normal road
  uses a road surface and bridge uses deck/rails. Bridge state visibly
  distinguishes deck, scaffold, and damaged break geometry.

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

The sample 3D viewport was launched in a separate Godot process for visual
inspection. It is render evidence only. The current desktop automation surface
does not expose the game's custom canvas controls as accessible targets, so it
does not establish normal system-input media for this candidate. That media
remains an explicit follow-up validation item.

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

## Rendering approach

- A `SubViewport` holds an orthographic `Camera3D`, one directional light, and
  an isolated 3D world.
- The scene uses only Godot built-in primitives (`BoxMesh`, `CylinderMesh`,
  `SphereMesh`, and generated ground meshes) and `StandardMaterial3D`. No
  third-party asset, generated model, or external texture is included.
- Cities, garrisons, trees, rocks, river surfaces, roads, bridges, armies,
  specialists, patrols, and active construction are rebuilt or updated from
  the authoritative read models. Bridge state visibly distinguishes deck,
  scaffold, and damaged break geometry.

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

The sample 3D viewport was launched in a separate Godot process for visual
inspection. It is render evidence only. The current desktop automation surface
does not expose the game's custom canvas controls as accessible targets, so it
does not establish normal system-input media for this candidate. That media
remains an explicit follow-up validation item.

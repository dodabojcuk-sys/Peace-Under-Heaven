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

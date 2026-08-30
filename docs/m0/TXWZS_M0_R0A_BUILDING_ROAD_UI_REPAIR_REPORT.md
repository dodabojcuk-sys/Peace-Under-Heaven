# TXWZS M0 R0A Building-Road and Construction UI Repair Report

## Verdict

`ENGINEERING_PASS_PENDING_FOUNDER_LIVE_SMOKE`

The exact R0 base `1312754260313ee12542cb1052f0b5bbe06b5dfa` was repaired only
inside its isolated worktree. The canonical product-successor checkout remained
clean and unchanged. This report does not grant Founder acceptance and does not
authorize new gameplay.

## Root Cause and Repair

`OVERLAP_ROOT_CAUSE=BOTH`

1. Logical occupancy: four Blackstone fixed buildings started at world `y=430`
   with height `120`, which conservative rasterization correctly mapped through
   grid row 13, the formal horizontal road. An older size-only assertion missed
   the partial leading cell. The row now starts at `y=400`; building sizes,
   entrances, and road geometry are unchanged.
2. Visual bounds: the graybox shadow extended 12 units past the footprint and
   visually covered an adjacent road. The shadow now remains inside the exact
   footprint.
3. Fragmented mutation rules: building, road, load, move, and rotation did not
   expose one structured legality result. `CityGridRules` is now the pure spatial
   authority and `ConstructionController` remains the single writer.

Building placement, player-road placement, building move, building rotation,
default-map scans, and post-load legacy diagnostics now use the same occupancy,
road, protected-cell, and bounds contract. Illegal previews are red, show a
non-color X and a concrete reason, and cannot commit. Failed move/rotation is
atomic and leaves the source placement unchanged.

## Player-Facing Result

The lumber-camp panel now exposes one primary state only: global pause, missing
resources, waiting to start, constructing, completed but disconnected, event
disabled, pressure affected, or producing. It shows core effect, exact 2x2
footprint/orientation, entrance and road state, progress bar, paid amount,
remaining cost/current shortage, and an honest ETA. A blocked task says
`等待材料`; construction priority appears only during construction with a
short explanation. Completed buildings no longer give priority a primary visual
position. Resource capacity formatting is stable and overdue pressure displays
the next consequence rather than only an internal stage.

## Save Compatibility

The campaign snapshot remains schema 4. R0A adds no persisted field and does not
delete, move, rotate, or auto-repair a legacy building. A restored overlap is
kept at its original origin and surfaced as derived `LEGACY_OVERLAP`; every new
placement mutation still follows the repaired legality gate. Existing V2/V3/V5
migration and roundtrip runners remain green.

## Verification

- Focused R0A placement and UI-state runner: PASS, including both directions of
  overlap rejection, N/E/S/W entrance transforms, atomic move/rotation failure,
  Blackstone/Riverbend scans, non-destructive legacy restore, status priority,
  exact missing amount, ETA, priority persistence, resource format, and pressure.
- Baseline regression: all 45 pre-existing dynamically discovered smoke runners
  pass after updating superseded UI-string assertions.
- Full regression: 46/46 runners pass, including the new focused R0A runner.
- Godot 4.5.1 editor import: PASS.
- Formal scene smoke: `blank_map`, Blackstone expedition, and C0 battle all exit
  successfully after five headless frames.
- `git diff --check`: PASS.
- R0 38-file scope audit: PASS; unexplained files: none.

## Evidence

Ten native-rendered PNG files under `docs/m0/evidence/r0a/` cover illegal and
legal placement, construction, missing material, completed disconnected and
producing states, road-through-building rejection, 1280x720 layout, occupancy
debug projection, and overdue pressure feedback. Each PNG was visually inspected.

`m0-r0a-continuous-player-journey.avi` is a single unspliced Godot Movie Writer
recording: Motion JPEG AVI, 1152x648, 30 FPS, 511 frames, 17.01 seconds. Its ten
ordered steps show catalog entry, illegal building-on-road preview, legal
adjacent confirmation, paused construction, progress/payment, missing-material
pause, supply resume, completion/production, and road-through-building rejection.

## Remaining Gate and Rollback

Founder must still play the real window journey and judge legibility, feel, and
whether the repaired buildings visibly clear roads at normal interaction speed.
No push, merge, deployment, or next-stage work is authorized. Rollback is the
single local R0A commit's parent `1312754`; canonical source is unaffected.

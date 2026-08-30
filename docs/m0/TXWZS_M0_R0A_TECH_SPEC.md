# TXWZS M0 R0A Building, Road, and Construction UI Tech Spec

## Requirements

1. Building and road cells are mutually exclusive for all new writes.
2. A building entrance connects only to an adjacent road-contact cell.
3. Building placement, road placement, placed-building move, and rotation use
   one deterministic spatial legality contract with stable reason codes.
4. Invalid previews use red fill, outline, and a non-color conflict mark; legal
   disconnected previews remain amber and buildable.
5. Selecting a lumber camp shows its exact footprint, entrance, and connection.
6. The detail panel presents one mutually exclusive primary state, real
   progress, paid/remaining/missing materials, honest ETA, road state, and
   production effect. Priority appears only during construction.
7. Resource formatting remains stable across all states. Pressure feedback uses
   player-readable consequence and next-stage text.
8. Legacy overlaps load non-destructively and are reported, not repaired.
9. The default Blackstone and Riverbend authored layouts have no logical
   building-road overlap.
10. A continuous recorded journey and the specified static evidence are created
    from the R0A candidate.

## Design

- Extend `CityGridRules`; do not create a second placement controller.
- Keep `ConstructionController` as the only placement, time, resource, and save
  writer. Add narrow move/rotate mutation methods that atomically update the
  existing record and node after shared validation.
- Keep V5 schema 4 unchanged. Store legacy-overlap diagnostics only in runtime
  derived state.
- Keep the existing right contextual panel. Add only the labels/progress bar
  needed for the player read model and preserve existing battle/fixed-building
  panels.
- Constrain building body/shadow to the logical footprint. Entrance arrows may
  extend outward only while selected because they communicate adjacency.
- Use a debug-only overlay node in the evidence fixture; it is not enabled in
  ordinary play.

## State Priority

For an incomplete lumber camp:

1. `GLOBAL_PAUSED`
2. `MISSING_RESOURCES`
3. `WAITING_CONSTRUCTION` when progress is zero
4. `CONSTRUCTING`

For a completed lumber camp:

1. `COMPLETED_DISCONNECTED`
2. `EVENT_DISABLED`
3. `PRESSURE_AFFECTED`
4. `PRODUCING`

Only the highest applicable state becomes the badge. Secondary text may explain
another condition without presenting a second status.

## Verification

- One focused R0A runner covers the 12 placement cases and UI state matrix.
- Full dynamic `tests/run_*_smoke.gd` regression must pass.
- V5 roundtrip and V2/V3 migration must remain green.
- Godot 4.5.1 editor import and three formal scenes must pass headless.
- Native-rendered evidence must cover both target resolutions and all required
  static states.
- A single Godot movie-writer recording must show the ordered player journey
  without splicing.
- `git diff --check`, source-repository status, candidate status, and complete
  file-scope review are final gates.

## Non-goals

No new gameplay, worker scheduling, population, combat, trade, equipment,
technology, navigation, final art, HUD rewrite, schema redesign, push, merge,
deployment, or product-bible edit is authorized.

# TXWZS M0 Implementation Map

## Authority map

| Concern | Authoritative owner | Supporting data / UI | Write path |
| --- | --- | --- | --- |
| Strategic clock, pause, 1x/2x/4x | `scripts/construction_controller.gd` | Existing top status bar in `scenes/blank_map.tscn` | `_process` → `advance_city_time` |
| Construction lifecycle and priority | `scripts/construction_controller.gd` placement records | `scripts/building_selection_controller.gd` | fixed 1000 ms construction tick |
| Shared wood, food, tech | `scripts/state/nation_state.gd` | legacy controller accessors are projections | `commit_resource_transaction` only |
| Mainline deadline and pressure | `scripts/state/current_mainline_level.gd` | `resources/definitions/mainline/m0_first_level_pressure.tres` | monotonic day advancement and committed event IDs |
| Pressure tuning | `scripts/content/mainline_pressure_profile.gd` | one prototype `.tres` profile | read-only profile methods |
| Attempt-local battle retry | `scripts/battle/battle_attempt_state.gd` | no persistent city fields | attempt snapshot only |
| M0 HUD | existing top status bar and building detail panel | one priority `OptionButton`; reused alert label | controller read models |
| Persistent save | `scripts/state/v5_campaign_snapshot.gd` | V5 store/codec remain unchanged | schema 4 validation and V2/V3 migration |

## Runtime flow

```text
real delta
  -> ConstructionController speed selection
  -> authoritative strategic milliseconds
  -> fixed 1000 ms construction ticks
  -> priority ordering (high, normal, low; stable placement ID tie-break)
  -> cumulative target payment
  -> NationState atomic spend
  -> progress commit or BLOCKED_RESOURCES

day boundary
  -> construction completion count
  -> maintenance / training / production / research
  -> CurrentMainlineLevel monotonic pressure update
  -> NationState permanent resource loss transaction
  -> committed event ID and permanent loss totals
```

## Save schema 4 additions

- City: `security`.
- Root: `mainline_level` with level ID, activation/deadline days, pressure stage,
  clear state, committed pressure event IDs, and permanent loss totals.
- Placement: construction state, exact progress/required milliseconds, total and
  paid costs, three-level priority, and missing resource IDs.
- V3 migration treats legacy construction costs as already paid and uses empty
  M0 cost totals, preventing duplicate charges.
- V2 first receives the existing north-orientation migration, then the V3 M0
  defaults.

## Explicitly unchanged

- No second resource, save, placement, clock, or settlement owner.
- Immediate player-road placement remains atomic because its build duration is
  zero; timed buildings use incremental payment.
- No battle expansion, population simulation, equipment, trade, technology
  redesign, city AI, deployment, push, merge, or final-art work.

# Normal city building growth and operating yield R1

Baseline: remote default merge
`0b6f47c1bc3f7ab9f7c6d0573f23a732e419847f`.

## Product objective

Make the existing farm, logging camp, warehouse, housing and clinic usable as
level-one to level-two investments through the formal map selection flow. The
upgrade must preserve the placement identity and location, consume real
resources, use the existing construction workforce and world clock, survive V5
restore, and feed the existing production, capacity, population and treatment
authorities.

This slice adds no parallel building registry, economy projection, population
source or save owner. Art, new campaigns and higher-level expansion remain out
of scope.

## Existing coverage

| Building | Level-one authority | Existing real consumer | Missing before R1 |
| --- | --- | --- | --- |
| Farm | `building.farm.t1` | Daily food settlement | Level-two definition and upgrade writer |
| Logging camp | `building.logging_camp.t1` | Daily wood settlement | Level-two definition and upgrade writer |
| Warehouse | `building.warehouse.t1` | Food/wood admission capacity | Level-two definition and upgrade writer |
| Housing | `building.housing.t1` | Housing, winter and settlement gates | Level-two definition and upgrade writer |
| Clinic | `building.clinic.t1` | Shared medical capacity and treatment | Level-two definition and upgrade writer |

All five already have formal construction, placement identity, road state,
construction workforce modifiers and centralized capability lookup. The old
upgrade confirmation deliberately had no command behind it.

## R1 rules

1. Upgrade retains the same `placement_id`, origin, orientation and occupied
   cells. Only its definition advances after completion.
2. Confirmation charges the complete upgrade cost once. A failed checkpoint
   restores both resources and the unchanged level.
3. While work is active, the old definition remains authoritative, including
   production and capacity. The new capability applies only after completion.
4. One placement can own at most one upgrade. Duplicate confirmation, invalid
   targets, insufficient resources and battle locks are rejected without
   mutation.
5. Progress uses the existing one-second construction tick, construction-worker
   modifier, pressure modifier, pause and world-time boundary.
6. Cancellation returns the paid upgrade cost through one national-resource
   transaction and leaves the original building intact. A failed refund leaves
   the active project intact.
7. Road loss or production pressure can suppress output but does not erase or
   rewind the upgrade. Construction workers, rather than production workers or
   roads, determine upgrade progress.
8. Existing durability fields, if present, are left untouched; upgrading is not
   a repair command.
9. V16 placements migrate as their recorded level-one definitions with no
   upgrade target. No old building is promoted and no resource is granted.

## Level-two values

These bounded R0 values are independently revertible and intentionally keep
the five roles distinct:

| Upgrade | Cost | Work | Capability before -> after |
| --- | --- | ---: | --- |
| Farm L1 -> L2 | 65 wood, 6 food | 2 city days | 22 -> 36 food/day |
| Logging camp L1 -> L2 | 60 wood, 4 food | 2 city days | 18 -> 30 wood/day |
| Warehouse L1 -> L2 | 80 wood, 4 food | 2 city days | +120 -> +200 capacity per resource |
| Housing L1 -> L2 | 55 wood, 4 food | 2 city days | +16 -> +28 housing |
| Clinic L1 -> L2 | 70 wood, 8 food | 2 city days | +6 -> +10 medical capacity |

Production remains bounded by road connection, assigned production workers,
health, unrest, campaign pressure and storage headroom. Housing adds no people.
Storage adds no stock. Medical capacity neither replaces medical workers nor
revives fallen soldiers.

## Persistence and transaction boundary

V5 campaign schema 17 adds one placement field:
`upgrade_target_definition_id`. A non-empty target means the existing
construction progress fields describe an upgrade while `definition_id` still
names the active old level. Completion replaces `definition_id` atomically and
clears the target.

Start and completion both publish through the existing V5 checkpoint owner.
Failure restores the pre-command resource/record snapshot. In-progress state is
recoverable at its exact integer-millisecond progress. Completed state restores
only the new definition; replay cannot charge or complete it again.

## Acceptance criteria

1. Each of the five level-one placements exposes an accurate preview and can be
   upgraded from its map detail.
2. Old capability remains active during work; level-two capability begins only
   after a persisted completion.
3. Duplicate, insufficient-resource, battle-lock and cancellation cases are
   atomic and player-readable.
4. V16 migration, active V17 restore and completed V17 restore preserve
   identity, resources and capabilities exactly.
5. A connected production chain spends its new yield through existing training
   or field construction, and a real wounded ledger uses upgraded clinic
   capacity through existing treatment.
6. Three supported resolutions remain usable without turning detail into a
   permanent side panel. Human operating feel remains a separate gate.

# Macro March R0 Technical Specification

## Scope and authority

Macro March R0 adds one playable, replaceable `Resource`-configured outer-city
theatre:
Blackstone City, Northwatch Garrison, and Reedbank Garrison.  It is a
greybox traversal slice, not a siege, occupation, energy, ability, road
construction, or multi-army feature.

`ArmyRegistry` owns durable army identity and the issued macro-march order.
`GarrisonState` remains the only owner of resident formations.  The
`ConstructionController` is the transaction boundary: it validates the
selection, applies the exact formation extraction, spends food through
`NationState`, changes the registry, and requests the existing runtime
persistence coordinator to publish.  The macro screen is a projection and
input adapter only.

## Durable fields

Each macro army keeps the existing stable `army_id`, plus these serializable
facts under its registry record:

| Field | Meaning |
| --- | --- |
| `macro_march.order_id` | Immutable identity of the currently issued leg. |
| `macro_march.source_point_id`, `target_point_id` | Theatre endpoint IDs. |
| `macro_march.route_id`, `route_world_points` | Player-selected road route and its snapped world-coordinate polyline. |
| `macro_march.formation_snapshots` | Exact selected formation IDs, names, capacities, and member counts. |
| `macro_march.food_cost` | Issued-leg food debit. Uses the current expedition formula `ceil(total / maintenance_units_per_food)` temporarily. |
| `macro_march.progress_millis`, `total_millis` | Logical movement progress, never wall-clock time. |
| `macro_march.blocked_segment_index`, `temporary_station_point` | A blocked branch-road stop before the unavailable segment. |
| `macro_march.phase` | `MARCHING`, `BLOCKED`, or `STATIONED`. |

`resources/macro_march/blackstone_outer_city_r0.tres` supplies the theatre
definition for R0: stable point IDs, road IDs, draw polylines, and the one
branch road that can be blocked in the demonstrable scenario. It is not a
city/occupation record and can be replaced without moving transaction
authority into the UI.

## State transitions

```text
DRAFT (UI only, no durable write)
  -> confirm succeeds -> MARCHING
  -> invalid/cancel -> DRAFT cleared

MARCHING
  -> branch becomes blocked -> BLOCKED at preceding reachable station
  -> progress reaches route end -> STATIONED at friendly garrison

BLOCKED
  -> branch restored -> MARCHING on the same order, route, fee, and progress

STATIONED
  -> select a legal outgoing road and confirm -> MARCHING (new order_id,
     same army_id and exact carried formations)
```

Issued orders cannot be ordinarily cancelled or re-targeted.  The route must
end on another configured friendly point.  A draw that misses a road or an
endpoint produces a readable reason before any write.

## Atomic confirmation and rollback

Confirmation first re-reads source, selected formation identities/counts,
endpoint, route segments, current food, and the no-active-travel rule.  It
then snapshots the full garrison and registry state, extracts the selected
formations exactly, creates or advances the one army record, commits the
food transaction, persists, and only then exposes `MARCHING`.

Any owner or persistence failure restores the full formation distribution,
registry snapshot, and food transaction.  The legacy total-count dispatch
adapter is never used for a formation selection because a matching aggregate
can otherwise remove a different formation.

## Persistence and compatibility

The existing V6 campaign payload remains the single campaign payload.  The
army registry accepts snapshots without `macro_march` as legacy ordinary army
records.  Macro fields are validated when present; malformed macro data fails
closed.  No new save file, storage envelope, permanent roster, ledger, or
top-level city owner is introduced.  Existing R1E attempts do not synthesize a
macro order on restore.

## Verification plan

Focused smoke covers no-side-effect drafts, endpoint/route validation, two
distinct roads, one-time confirmation/payment, exact formation conservation
and rollback, non-cancellation, pause/speed movement, block/resume without
refee or teleport, station-to-station second command, and isolated-disk cold
restore.  Existing army, persistence, R1E, C0, scene startup, and import
checks remain required before a local atomic commit.

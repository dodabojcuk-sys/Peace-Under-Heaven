# V5 Persistent ArmyState Collection Contract V0

## Status and scope

Task: `V5-P3-T001`

Status: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

This contract defines a persistent collection shape that V6 can extend to
multiple simultaneous armies. V5 may enforce at most one active army as a
policy. The data model must not encode that policy as a singleton.

No ArmyState runtime implementation, second active army, pathfinding, enemy AI,
encounter runtime, siege, or V5-G2 work is added here.

## Collection source state

```text
ArmyRegistryV1
  schema_version: 1
  next_army_sequence: positive int
  armies_by_id: Dictionary[army_id, ArmyStateV1]

ArmyStateV1
  army_id: stable StringName
  owner_faction_id: stable StringName
  home_city_id: stable StringName
  source_node_id: stable StringName
  target_node_id: stable StringName
  route_id: stable StringName
  units_by_definition_id: Dictionary[unit_definition_id, positive int]
  progress_milliseconds: non-negative int
  duration_milliseconds: positive int
  phase: RESERVED | MARCHING | ARRIVED | RETURNING | SETTLEMENT_PENDING | CLOSED
  transaction_id: stable StringName
  last_applied_result_id: stable StringName or empty
```

Stable Army IDs use a persisted monotonic sequence, for example
`army.player.000001`. Dictionary/array index, Node identity, RID, frame number,
and UI selection are forbidden as identity.

The active set is derived from phase. The registry must never store
`active_army` as a sole object. V5 validation may reject a candidate with more
than one non-closed record; V6 may lift that validator rule without changing
the collection shape or remigrating a singleton.

## Persistence exclusions

An ArmyState must not save:

- `Node`, `NodePath` to a live instance, `Resource`, `Callable`, or signal;
- local or global pixel coordinates;
- camera position, marker position, tween, animation, or selected UI card;
- `WorldMapPresentationModel` fixture dictionaries;
- duplicated city garrison totals or duplicated BattleResult truth.

Only stable logical `source_node_id`, `target_node_id`, `route_id`, and integer
progress are persistent.

## Ownership and transitions

| Fact | Sole writer | Forbidden writer |
| --- | --- | --- |
| Registry identity/sequence | strategic army registry | UI/scene |
| Army composition | dispatch/settlement transaction | BattleSession |
| Route/progress/phase | strategic-time authority through registry commands | map marker/tween |
| Battle facts | BattleSession terminal result | ArmyState |
| City garrison | city authority/GarrisonState | ArmyState direct edit |
| Result application link | authorized settlement coordinator | presentation |

Allowed V5 transition skeleton:

```text
absent
  -> RESERVED
  -> MARCHING
  -> ARRIVED
  -> SETTLEMENT_PENDING
  -> CLOSED

MARCHING -> RETURNING -> ARRIVED -> CLOSED
```

Exact gameplay transitions remain G2 scope. Every transition requires the
matching `army_id` and `transaction_id`, an expected current phase, and a
single atomic commit.

## Garrison and ArmyState conservation

At dispatch commit, units move from a city reservation to one ArmyState exactly
once. A count cannot simultaneously be unreserved garrison and active army
composition.

For each unit definition within the bounded V5 world:

```text
city_garrison_total
+ sum(active_army_units)
+ terminal_unapplied_survivor_or_casualty_facts
= last_committed_world_total adjusted only by authorized recruit/result events
```

Battle reservation before dispatch remains a lifecycle fact, not an early
deduction from garrison. Failed ArmyState creation leaves the city reservation
and garrison in their pre-call state or cancels the reservation through its
authorized path.

All unit counts and progress values are non-negative. Composition dictionaries
cannot contain unknown IDs, zero entries, or duplicate logical IDs.

## Progress contract

- progress is exact integer simulation time, not a float ratio;
- `0 <= progress_milliseconds <= duration_milliseconds`;
- a display ratio is derived;
- scene close/reopen reads the same record;
- repeated strategic-time input is guarded by transaction/event identity;
- arrival is a phase transition, never marker overlap.

## Read model

Readers receive a stable ordering and deep copies. UI may select an `army_id`
locally, but selected identity is not part of ArmyRegistry persistence.

## G2 acceptance cases reserved by this contract

1. stable ID persists across save/load and scene re-entry;
2. failed create/transition is zero-write;
3. V5 rejects a second active record by policy;
4. the registry can still contain multiple CLOSED records;
5. a validator configuration that lifts the V5 policy accepts two active
   records without changing schema;
6. no Node, pixel coordinate, or UI field appears in serialized output;
7. dispatch, cancel, arrival, result, and return preserve troop conservation.

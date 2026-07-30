# V5 TrainingQueue Source-State Contract V0

## Status and scope

Task: `V5-P2-T001`

Status: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

This contract replaces the conceptual use of
`training_queued_count`, `training_complete_day`, and
`last_training_order_day` as three independent facts with one minimal,
versionable training-order aggregate. It does not implement the aggregate,
add a generic job system, add a second troop type, or enter V5-G2.

## Existing truth and migration boundary

At the G1 candidate:

- `ConstructionController` is the only city runtime authority.
- A single queued batch is represented by the three compatibility fields.
- Food is deducted when `queue_training()` succeeds.
- Completion occurs only inside `_advance_day_boundary()`.
- Completion writes through `infantry_count`, which proxies the accepted
  private `GarrisonState`.

The three fields remain the current runtime truth until G2 performs an atomic
migration. G1 documentation must not create a second live queue.

## Minimal source state

The future V5 source state is a collection even though the V5 policy permits
at most one active order:

```text
TrainingQueueV1
  schema_version: 1
  city_id: stable StringName
  next_order_sequence: positive int
  orders_by_id: Dictionary[order_id, TrainingOrderV1]

TrainingOrderV1
  order_id: stable StringName
  city_id: stable StringName
  unit_definition_id: stable StringName
  quantity: positive int
  ordered_day: positive int
  complete_day: positive int
  food_cost_committed: non-negative int
  phase: QUEUED | COMPLETED
  completed_day: 0 or positive int
```

Stable V5 IDs use the city identity and a persisted monotonic sequence, for
example `training.blackstone_city.000001`. Array position, object instance ID,
frame number, and current UI selection are forbidden as identity.

`orders_by_id` may retain completed records needed for idempotency and
migration audit. The active set is derived from `phase == QUEUED`; it is not a
separate mutable list.

## Ownership and write entry points

| Operation | Sole authority | Atomic result |
| --- | --- | --- |
| Validate an order | city authority adapter | read-only decision |
| Allocate `order_id` | TrainingQueue owned by city authority | sequence and order created together |
| Commit training | city authority adapter | food cost and QUEUED order commit together |
| Advance eligibility | city strategic-day boundary | no mutation before boundary |
| Complete training | city strategic-day boundary + GarrisonState entry | garrison increase and order completion together |
| Read UI state | read model | deep copy only |
| Save/load | versioned persistence adapter | validated aggregate, never Node/UI state |

UI code may request an order but cannot allocate IDs, deduct food, change
quantity, set completion day, or mark completion.

## State transitions

```text
absent --enqueue--> QUEUED --strategic day boundary--> COMPLETED
```

V5 does not define cancellation, acceleration, parallel slots, reorder,
partial completion, or refunds. Adding any of those requires a named contract
revision and migration.

Enqueue must reject without mutation when:

- another order is already `QUEUED`;
- the unit definition is unknown;
- quantity differs from the current authoritative batch rule;
- food cannot cover the full committed cost;
- garrison plus all queued quantities would exceed recruitment capacity;
- garrison plus all queued quantities would exceed effective command limit;
- the city is battle-locked or the daily order rule rejects the request.

Completion must be idempotent. Replaying a day boundary after an order is
`COMPLETED` cannot add units again.

## Conservation and invariants

For the current single unit:

```text
queued_infantry =
  sum(quantity for order where phase == QUEUED)

garrison_total + queued_infantry <= recruitment_cap
garrison_total + queued_infantry <= effective_command_limit
```

All quantities, days, costs, and sequences are integers and non-negative;
positive-only fields must be greater than zero. `complete_day` is strictly
after `ordered_day`. A completed order has `completed_day >= complete_day`; a
queued order has `completed_day == 0`.

Food is committed exactly once at enqueue. Completion never charges food
again. A failed enqueue or completion produces zero partial mutation.

## Compatibility projection

Until G2 removes the old fields:

- `training_queued_count` projects the single QUEUED order quantity or 0;
- `training_complete_day` projects its completion day or 0;
- `last_training_order_day` projects the last accepted order day.

These are compatibility views only after migration. They must not be restored
independently from the queue.

## Persistence exclusions

Training persistence must not contain:

- `Node`, `Resource`, `Callable`, signal connection, or scene path instances;
- pixel/world coordinates;
- selected UI card, open panel, hover, animation, or progress-bar state;
- derived capacity, derived command limit, or translated display text.

## G2 acceptance cases reserved by this contract

1. valid order creates one stable ID and deducts food once;
2. repeated/invalid order is zero-write;
3. pause and ordinary scene frames do not complete training;
4. one authorized strategic day boundary completes exactly once;
5. save/load preserves the same order ID and phase;
6. migration from the three V1 fields produces zero or one valid order;
7. completed-order replay cannot add garrison twice.

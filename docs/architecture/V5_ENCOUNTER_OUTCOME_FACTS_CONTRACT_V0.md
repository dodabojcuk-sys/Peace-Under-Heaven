# V5 Encounter Outcome Facts and Authoritative Writeback Contract V0

## Status and scope

Task: `V5-P4-T001`

Status: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

V5 reuses the existing minimal deterministic combat result. This contract
freezes the boundary between facts produced by a battle and policy applied to
persistent city/army/save state. It does not add a new encounter, enemy AI,
siege, combat rule, reward type, or V5-G2 runtime.

## Battle-produced facts

The current `BattleResult` authority snapshot is the V5 fact baseline:

```text
result_id
transaction_id
session_id
level_id
outcome
started_day
finished_tick
committed_count
survivor_count
casualty_count
enemy_casualties
breached_route
orders_digest
player_snapshot_digest
enemy_snapshot_digest
first_clear_key
```

Required invariants:

- all identity fields required by the current contract are non-empty;
- outcome is victory, defeat, or retreat;
- `finished_tick >= 0`;
- `committed_count > 0`;
- survivors and casualties are non-negative;
- `survivor_count + casualty_count == committed_count`;
- enemy casualties are non-negative;
- the snapshot matches the terminal `BattleSession` authority record.

## Facts that battle must not produce

BattleSession must not decide or write:

- city garrison after value;
- ArmyState phase or composition after value;
- city resource rewards or costs;
- city day/time after value;
- building, population, save, or migration fields;
- first-clear grant status;
- UI copy, toast, panel state, or translated explanation.

Those are settlement policy or presentation, not battle facts.

## Authoritative writeback path

The only public confirmation path remains:

```text
BattleSession terminal result
  -> CombatTransactionCoordinator.mark_result_pending()
  -> CombatTransactionCoordinator.confirm_result()
  -> bound authoritative settlement adapter
  -> city/GarrisonState and future ArmyRegistry explicit entries
  -> committed result ledger
```

The current city adapter is
`ConstructionController.apply_battle_result_atomic(transaction_id, result_id)`.
G2 may extract a named settlement service, but it may not create a second
BattleResult source or let BattleSession write persistent objects directly.

## Settlement authorization

Writeback requires all of:

- the coordinator is bound to the same city authority;
- the active request, bound session, transaction, result, and level IDs match;
- request phase and city reservation phase are `RESULT_PENDING`;
- the payload matches the captured terminal authority snapshot exactly;
- committed force and enemy snapshot digests match;
- the result has not already been committed with conflicting facts;
- the result references the expected ArmyState transaction when ArmyState
  exists.

Failure is zero-write.

## Idempotency and conflict

- `result_id` is the idempotency key for settlement replay.
- Same result and same authority facts return the already committed summary.
- Same result ID with different session, transaction, tick, outcome, digests,
  or counts is rejected.
- A second different result for an already closed transaction is rejected.
- Rewards, time, casualties, ArmyState closure, and ledgers commit once.

## Settlement policy outputs

The settlement layer may derive and commit:

- garrison/ArmyState survivor and casualty effects;
- formal city defense damage;
- enemy campaign count;
- first-clear reward grant;
- food cost and capacity-clamped rewards;
- exact strategic time advanced from `finished_tick`;
- result, transaction, and first-clear ledgers.

Derived values are recorded in the committed settlement summary for audit but
do not become BattleResult facts.

## Persistence boundary

Persist:

- the immutable fact snapshot or its canonical digest;
- `result_id`, `transaction_id`, `session_id`, and apply status;
- the committed settlement summary needed for idempotency.

Do not persist a `BattleSession` Node/object, squad presentation nodes, live
orders UI, pixel positions, or a second mutable result object.

## G2 acceptance cases reserved by this contract

1. valid terminal facts apply once;
2. same replay returns the same committed summary without new writes;
3. forged payload, session, city, coordinator, ArmyState, or digest is rejected;
4. battle facts contain no city/save/UI after-state;
5. settlement atomically updates garrison, ArmyState, time, resources, and
   ledgers or restores all pre-call state;
6. save/load retains enough ledger data to reject duplicate application.

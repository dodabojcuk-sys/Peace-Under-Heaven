# V5 Single-Unit War Foundation Contract V0

## Scope

This is the V5 P0 baseline and the contract for the first substantive V5 slice:
one stable infantry definition, one authoritative Blackstone city garrison, and
one read model that distinguishes total, reserved, unreserved, and dispatchable
infantry.

It does not add a second troop type, a persistent army collection, a new
`CityState`, a save schema, enemy AI, siege, or multi-army control. The eight
untracked S1A.2 files remain protected and are not a V5 persistence baseline.

## Frozen starting point

- V4 checkpoint: `5357c28` (`feat: freeze verified V4 milestone`)
- V4 parent: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- V4 status: `VERIFIED / FROZEN`
- S1A.1: accepted in-memory early-city snapshot
- S1A.2: present as eight protected untracked files; unaccepted
- City runtime authority: `ConstructionController`
- Static infantry definition: `UnitRole` resource
  `unit_role.infantry_basic`
- Battle-instance authority: `BattleSession`
- Result/transaction authority:
  `CombatTransactionCoordinator` + the bound city controller

## Ownership table

| Fact | Sole writer | Lifecycle | Readers | Forbidden path |
| --- | --- | --- | --- | --- |
| Infantry definition fields | authored `UnitRole` resource | static | city, coordinator, battle snapshot, UI | runtime mutation or duplicate V5 combat values |
| Blackstone garrison unit counts | `ConstructionController` through its private `GarrisonState` | city runtime | city UI, battle reservation, read models, snapshots through compatibility field | a second `CityState`, UI-owned counts, V4 scene garrisons as city truth |
| Compatibility `infantry_count` | property view on the private `GarrisonState` | V5 migration bridge | existing C0/P1/S1A.1 callers | treating it as independent storage |
| Active battle reservation | bound `ConstructionController` coordinator entry points | `RESERVED → ACTIVE → RESULT_PENDING → APPLIED`, or pre-battle `CANCELLED` | city UI, coordinator, result applier | direct scene/UI edits or a second ledger |
| Battle squads and terminal result | `BattleSession` | one battle instance | coordinator/presentation | persistent city mutation |
| Persisted early-city snapshot | S1A.1 serializer/controller contract | explicit capture/restore | validator/controller | importing protected S1A.2 or inventing a V5 schema in this slice |

## Stable single-unit definition

- Stable ID: `unit_role.infantry_basic`
- `get_unit_definition_ids()` returns only this ID in V5 P1.
- `get_unit_definition(id)` returns the existing `UnitRole`; it does not copy
  HP, attack, upkeep, or recruitment cost.
- A future second unit definition may extend the returned collection without
  changing the garrison count contract.

## Garrison and dispatch conservation

For the current single city and single troop definition:

```text
total = garrison[unit_role.infantry_basic]
reserved = active_battle_reservation.committed_count or 0
unreserved = max(total - reserved, 0)
dispatch_cap = min(recruitment_cap, effective_command_limit)
dispatchable = min(unreserved, dispatch_cap)
```

Rules:

- Reservation never deducts `total`; it only reduces `unreserved`.
- Pre-battle cancel releases the reservation without changing `total`.
- Result application changes `total` once through the existing atomic city
  writeback and then clears the reservation.
- Training completion, emergency mobilization, checkpoint restore, and S1A.1
  restore all pass through the compatibility property and therefore update the
  same private garrison source.
- Negative counts, over-removal, duplicate reservation, and unknown unit IDs
  are rejected without partial mutation.
- The read model is a deep copy. Callers cannot mutate city truth.

## Temporary V5 manpower rule

The current project has recruitment capacity and food cost, but no accepted
population/manpower source. This slice therefore preserves the existing,
explicit rule:

- training consumes `UnitRole.recruit_food_per_unit`;
- total plus queued infantry may not exceed recruitment capacity or the
  effective command limit;
- no population is fabricated or silently consumed.

A real population/manpower system requires a later named contract and
migration; it is not inferred from residents, UI labels, or capacity.

## Rollback and stop conditions

- Rollback point: V4 checkpoint `5357c28`.
- V5 P0/P1 files must stay separate from the protected S1A.2 files.
- Stop if implementation needs a second city authority, save migration,
  direct `BattleSession` persistent writes, unknown dirty changes, or a product
  decision about population or multi-army behavior.

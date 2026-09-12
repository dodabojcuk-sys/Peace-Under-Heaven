# Blackstone City Governance R0

## Purpose

This slice connects the existing aggregate population, national food ledger,
city calendar and construction authority into one recoverable city-pressure
loop. It deliberately avoids individual resident simulation and does not copy
war, resource or save ownership into the UI.

## Authority and transactions

- `PopulationRecoveryState` owns mutually exclusive resident allocations:
  available, production, construction, medical, governance, training and
  wounded. Garrison, field armies and specialists retain their existing domain
  owners and are included only in the conservation check.
- Silverford's finite local reserve remains a `FieldTacticsState` inventory.
  When a recruit actually enlists, the same transaction removes it from that
  inventory, adds it to the selected ArmyRegistry formation and admits it to
  the campaign population total. Save failure restores all three owners.
- `CityGovernanceState` owns aggregate health, disease pressure and stable city
  event identities. Disease is a health status over non-wounded civilians, not
  a second population pool.
- `ConstructionController` is the only calendar driver. One day boundary pays
  city rations through `NationState`, advances governance once, and publishes
  the resulting read model.
- Treatment still returns recovered people to the legal Blackstone garrison;
  it never inserts people into an external or active field formation. Capacity
  is rechecked at completion, so a full garrison keeps the treatment pending.
- Governance action cost and event resolution commit together. Failure restores
  the event and security state and cannot consume food partially.

## R0 rules

- Four three-day seasons use the existing city day. Autumn warns about winter;
  winter reduces effective housing capacity by eight.
- The authored base housing covers the initial population. A completed `民居`
  adds 16 capacity; loading a house never creates residents.
- Daily food is the existing Blackstone garrison maintenance plus one ration per
  20 city civilians. External armies are excluded because their departure food
  is already committed by the field-order transaction.
- A first shortage day is a warning and health loss. Two consecutive food or
  housing-pressure days can create two aggregate disease cases per day. Medical
  recovery is bounded by both operational capacity and assigned medical staff.
- Shortage or housing pressure lowers the existing persisted city security.
  Low security creates one stable petty-theft event. At least two assigned
  governance workers and two food resolve it once; loading cannot reroll it.
- Health affects existing production and construction modifiers. It cannot
  reduce essential work below the established 25% safety floor.

All values live in `blackstone_city_governance_r0.tres` and are reversible
development parameters. R0 does not yet model age groups, population growth,
multiple diseases, deep unrest, civilian officials or trade.

## Persistence and compatibility

Campaign schema 14 adds one strict `city_governance` record and population
schema 2 adds medical/governance allocations. A schema-13 save transfers up to
four available residents into each new staffed channel and creates neutral
governance state. It adds no resident, food, building or favourable event.
Malformed disease totals, event shapes and allocation totals are rejected
before live state changes.

The schema-13 compatibility step also recognises the exact historical
Silverford four-person pool when part of it was already enlisted before the
population ledger existed. It reconciles only that consumed amount; it does
not refill the location or accept unrelated conservation mismatches.

## Verification boundary

`run_city_governance_r0_smoke.gd` covers warning-before-disease, recovery,
winter housing pressure, completed housing/clinic capacity, stable event
resolution, V13 migration and invalid restore. The independent A/B/C process
chain proves an active event and its one-time resolution survive process
restart. The graphical runner checks the existing city workspace at three
resolutions and uses visible button signals for staffing and governance; its
day pressure setup is explicitly accelerated. Existing population, V5,
inner-city, Route A/B and invasion regressions cover shared boundaries. These
are deterministic implementation checks, not normal-speed player acceptance.

# Blackstone Recovery and Defense Expansion R0

## Rule-source inventory

| Area | Confirmed rule | Existing authority | R0 implementation decision |
| --- | --- | --- | --- |
| Military identity | Garrison, dispatched formations and field armies retain stable identities; settlement writes survivors once | `GarrisonState`, `ArmyRegistry`, battle settlement | Population never owns formations; it accounts for people by allocation and consumes authoritative casualty deltas |
| Training | One paid `TrainingQueue` order completes on a city-day boundary and adds to the Blackstone garrison once | `TrainingQueue`, `NationState`, `ConstructionController` | A training order also reserves the same number of available residents; completion moves that reservation into military allocation |
| Population | Prior architecture explicitly had no accepted population source and forbade UI-derived counts | None | Add one persisted `PopulationRecoveryState`; do not infer mutable population from labels |
| Wounded | No previous durable wounded rule exists | None | R0 battle casualties are split by configured permille into wounded and fallen; fallen never return, wounded exist at settlement time |
| Treatment | Medical pressure channel exists, but no treatment queue exists | Unified city time and national food ledger | One recoverable treatment job consumes food once, advances on city time, and returns treated veterans to the existing garrison subject to capacity |
| Workforce | Production/construction already use city time but no people | `ConstructionController` | Persist exclusive production and construction allocations; changing one transfers real available residents rather than duplicating workers |
| Occupied-city permission | Captured foreign story cities are garrison points, not automatic inner cities | Theatre location capability | Centralize role/capability projection; control changes never grant `allows_inner_city_actions` |
| Field defense | Watchtower, arrow tower and barricade already share persistent Field lifecycle | `FieldTacticsState` | Extend the same explicit-kind envelope for forts, mines and upgrades; C0 facilities remain separate |

## Adjustable R0 parameters

The values below are development parameters and belong to one recovery rules
resource:

- initial living population: 72;
- initial production workers: 12;
- initial construction workers: 12;
- initial available residents: 28 after the 20-person garrison;
- wounded share of formal battle casualties: 50%;
- treatment batch: up to 6 wounded;
- treatment food: 1 per person;
- treatment work: 1,000 world milliseconds per person;
- staffed production baseline: 12 workers;
- staffed construction baseline: 12 workers.

Legacy V12 saves migrate deterministically. Their existing military and alive
specialist counts are preserved; the migration adds the authored workforce and
chooses a living-population total large enough to avoid negative availability.
It does not add soldiers, resources or a completed treatment.

## Player loop and transaction boundaries

1. The normal city screen exposes the one population ledger: available people,
   exclusive production/construction allocation, garrison/external military,
   training reservation, wounded and cumulative fallen.
2. Training reserves people and commits the existing food cost together. At the
   existing day boundary the reservation becomes the existing garrison roster;
   failure restores queue, population and roster.
3. Formal battle settlement reduces the authoritative formation or army once,
   then records the configured wounded/fallen split. Fallen reduce living
   population and can never enter treatment.
4. Treatment commits food once, keeps exact progress in V13 and completes on
   the same city-time path as construction/training. Treated veterans return to
   the Blackstone garrison only when capacity permits.
5. The surviving existing formations can be dispatched again. The continuous
   regression follows the sourced Blackstone defense through treatment, march,
   Redcliff siege and occupation without editing strength or control.

## Location capabilities

| Location kind | Inner city | Long-term construction | Garrison/orders | Supply/replenishment |
| --- | --- | --- | --- | --- |
| Blackstone main city | Yes | Yes | Yes | Yes |
| Silverford resource city | No | No | Yes | Yes |
| Redcliff occupied point | No | No | Yes | No |
| Other garrison/engineered point | No | No | Yes | No |

The theatre definition is the common source for point preview and command
policy. A change of military controller does not upgrade a point's capability.

## Field facility rules

- Fortress: a persistent engineer project with durability and range. It protects
  exactly one existing stationed `ArmyRegistry` army in range. The protected
  part of an encounter loss becomes fortress durability loss; destruction
  clears the assignment. The army must leave the fortress before receiving a
  march order.
- Minefield: a persistent, owned facility with finite charges. It triggers once
  when a hostile patrol's actual movement segment enters its range, damages that
  same patrol, consumes a charge and persists the consumed state. Hostile mines
  stay outside the player read model until an in-range scout or engineer finds
  them; only an in-range engineer can clear a discovered minefield.
- Upgrade: an engineer travels and works through the normal project lifecycle,
  paying the configured food cost once. The old ability stays active during the
  job. Completion preserves facility identity and durability ratio while
  changing its configured real parameter; it is not a free repair. R0 exposes
  level two only.
- Lifecycle separation: these are field facilities. C0 temporary works keep
  their independent battle-instance lifecycle and never duplicate damage or
  durability when a field encounter hands off to a battle.

## Verification boundary

The focused tests begin from `restart_first_map()` with the authored 100 wood / 80
food / 72 living population. They use formal training, specialist, construction,
time, defense, march and siege commands. No post-start strength, inventory,
control or outcome edit substitutes for gameplay. The small field fixture
pre-creates one connected engineering camp so facility lifecycles can be tested
without replaying already-stable road construction.

The two 1152x648 screenshots are engine-GUI layout/effect evidence. Their
fortress setup is accelerated and uses the same isolated fixture, so they are
not a normal-speed player recording or human acceptance. A full unaccelerated
human journey remains `OPEN`.

## Deferred complete-edition scope

Disease, seasons, public order, civil officials, equipment and trade remain in
the functional-edition queue. This R0 population record must be reusable by
those systems, but none of their effects are invented here.

# Functional Edition Coverage R0

## Scope and precedence

This document records the current product work after the user explicitly
expanded the R2 review branch beyond the historical V5 gate notes. Those notes
remain historical evidence, but they do not prohibit this authorised functional
edition work. The architecture contract still applies: each fact has one
writer, scenes remain separate, and UI/read models do not become persistence
owners.

## Layer boundaries

| Layer | Lifecycle | Existing owner(s) | Product role |
| --- | --- | --- | --- |
| Regular inner city | Persistent | `ConstructionController`, `NationState`, `GarrisonState`, `TrainingQueue` | Long-term construction, production, research, training and garrison |
| Field theatre | Persistent-changing | `WarLoopState`, `FieldTacticsState`, `ArmyRegistry`, `ConstructionController` | Marching, roads, camps, specialists, scouting, supply, encounters and sieges |
| Wartime inner city | One battle instance | `BattleSession`, `CombatTransactionCoordinator`, `BattleResultApplier` | Battle-only layout, deployment, facilities, defence and outcome facts |
| World map | Persistent overview | Existing campaign/city projections | City/faction/campaign organisation; no duplicate city authority |

Battle-only facilities may consume a confirmed shared resource transaction, but
their placement, hit points and lifetime stay inside the battle instance. A
battle result returns only the facts authorised by the normal settlement path;
it never writes a permanent city building just because a temporary tower was
built in the battle scene.

## Coverage matrix

| User requirement | Existing evidence | Formal entry | Gap at this checkpoint | Planned proof |
| --- | --- | --- | --- | --- |
| Persistent city construction, roads, production, storage, training and research | `ConstructionController`, `NationState`, city road/placement and V5 runners | `blank_map.tscn` city rail and default governance workspace | Production and construction now consume exclusive workforce allocations; broader production chains remain incomplete | Normal start -> allocate -> train/build -> next day -> save/restore |
| Population and post-war medical recovery | `PopulationRecoveryState`, battle settlement, `TrainingQueue`, V13 snapshot | Default city governance workspace | R0 has one aggregate population ledger, wounded/fallen split and recoverable treatment; it does not yet model individual people or specialist medical buildings | Defense casualties -> treatment -> surviving formation counterattack, including in-progress restore |
| Disease, seasons and broad social simulation | Pressure channels only; no authoritative disease/season system | None | Still absent and retained in complete-edition scope | Separate rule/design slice using the population authority rather than UI counters |
| R2 field operations | R2 Field/Macro March smoke, Route A/B, supply/reinforcement/tower persistence | Macro March from city | Preserve completed loop while adding cross-layer hooks | Route A/B plus interrupted/recovered operations |
| Field construction catalogue | Roads, bridges, camps, watchtowers, arrow towers, barricades, forts and minefields are persistent field facts | Engineer map planning and facility detail/repair/upgrade actions | R0 observation/fire/blocking/fortification/mine line is connected; later catalogue expansion and final balance remain | Facility project -> route effect/garrison protection -> damage/consumption -> repair/upgrade -> restore |
| Regular/occupied/resource-city capability separation | Central theatre capability table merged into every point read model | Map location details and command validation | Blackstone is the long-term city; Silverford retains supply/replenishment without city building; Redcliff remains an occupied garrison after capture | Occupy -> restore -> inspect permissions -> reissue orders without city-build leakage |
| Wartime inner city | C0 has distinct assault/defense identities, two routes, gates, deployment, deterministic battle and atomic settlement | Formal C0 scene; `enter_macro_siege_wartime()` for an existing macro siege; Blackstone gate action only after the configured invader arrives | The same sourced field invader now hands its surviving count to one defense transaction and resolves once. Formal macro victory, retreat, survivor defeat and full wipe remain covered. A single unaccelerated human run spanning preparation, defense, recovery and counterattack remains unaccepted. | Sourced warning -> march/interception -> handoff -> defense result; stable siege/counterattack regression; human player journey remains OPEN |
| Generals, civilian abilities, equipment, technologies and trade | General/tech snapshots affect current C0 force; building/tech definitions exist | City selection/research UI | Civilian/energy, equipment and trade require source-rule inventory before implementation | Each confirmed ability changes one real transaction or battle/field result |

## First implementation sequence

1. Keep the regular city and R2 field theatre separate; add integration tests
   that demonstrate their current resource/personnel hand-off rather than
   cloning either state.
2. C0 is now a recoverable wartime-inner-city instance with a compact,
   data-driven facility plan. Watch platforms, arrow towers, barricades and
   defense-only spike traps are battle-only records; they do not become
   permanent city placements.
3. Formal macro sieges now hand one frozen original force to that same battle
   instance, and only the authorised result path returns formation losses,
   control, siege closure and post-battle disposition. Continue proving
   defensive-campaign outcomes rather than treating the connected entry as a
   new city expedition.
4. The first external defense line now uses explicit field facility kinds:
   watchtowers reveal through existing fog, arrow towers damage one real in-range
   patrol, and barricades delay one real patrol traversal while taking durable
   damage. They reuse the field project/save envelope but never inherit C0
   facility effects. Fortress protection requires one real stationed army;
   minefields trigger on actual route crossings and preserve discovery and
   consumed charges; level-two upgrades retain the same facility identity and
   do not repair it for free. Population is now one V13 authority, while disease,
   seasons and trade remain recorded gaps rather than UI counters.

## Verification boundary

Every slice needs a rule/transaction test, a formal entry integration test and
a graphical state trace. Active battle restoration must use a V5 field whose
contents are strict data, not a saved `Node`, animation or UI selection.

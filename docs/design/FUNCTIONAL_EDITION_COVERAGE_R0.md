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
| Persistent city construction, roads, production, storage, training and research | `ConstructionController`, `NationState`, city road/placement and V5 runners | `blank_map.tscn` city rail | Clarify city-type permissions and connect post-war consequences to later city days | City production/train -> expedition -> return -> next day |
| Population, medical, disease, seasons and broad social simulation | No authoritative implementation found | None | Not an existing source system; must not invent individual-NPC accounting | Separate focused design/implementation after an accepted rule source is identified |
| R2 field operations | R2 Field/Macro March smoke, Route A/B, supply/reinforcement/tower persistence | Macro March from city | Preserve completed loop while adding cross-layer hooks | Route A/B plus interrupted/recovered operations |
| Field construction catalogue | Roads, bridges, camps and watchtowers are authoritative | Engineer map planning | Arrow towers, forts, traps and obstacle rules are not yet an external facility framework | Facility type definition -> project -> real effect -> restore |
| Regular/occupied/resource-city capability separation | Theatre point capability/read model and location detail | Map location details | Persistent city type policy needs to be centralised for later city/world work | Occupy -> garrison/reinforce/supply/continue without city-build leakage |
| Wartime inner city | C0 has a distinct battle scene, two routes, gates, deployment, deterministic battle and atomic settlement | Formal C0 scene; `enter_macro_siege_wartime()` for an existing macro siege; `enter_wartime_defense_battle()` for Blackstone gate defense | A frozen macro request now keeps the original army/order/formation HP through takeover, active play, result-pending recovery and one result writeback. Watch platforms, arrow towers, barricades and defense-only spike traps have source-aware planning, construction, damage, interruption and repair. A complete defensive campaign with broader facility families and a macro-origin full-wipe route remains unverified. | Formal siege handoff -> build -> battle -> independent restore -> victory/retreat/defeat writeback; separate defense construction/interruption/repair chains |
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
   control, siege closure and post-battle disposition. Continue proving the
   remaining full-wipe route and defensive-campaign outcomes rather than
   treating the connected entry as a new city expedition.
4. Add further facility types and wider progression only after their confirmed
   source rules are inventoried. The absence of a prior population, disease or
   trade writer is recorded as a real gap, not silently filled by UI counters.

## Verification boundary

Every slice needs a rule/transaction test, a formal entry integration test and
a graphical state trace. Active battle restoration must use a V5 field whose
contents are strict data, not a saved `Node`, animation or UI selection.

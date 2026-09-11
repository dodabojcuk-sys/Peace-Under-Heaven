# Wartime Inner City R0

## Purpose

R0 turns the existing C0 battle scene into a recoverable battle-instance
surface without merging it into either the regular city or the R2 field
theatre. It is a narrow assault preparation slice: the player may confirm
temporary siege works after the normal expedition has reserved food and before
the battle begins.

## Ownership

| Fact | Owner |
| --- | --- |
| Permanent wood and food | `NationState` through `ConstructionController` |
| Immutable departure / facility plan / active battle snapshot | `ConstructionController.expedition_attempt` in V5 schema 9 |
| Battle ticks, units, routes, orders and temporary effects | `BattleSession` |
| Activation, result hand-off and settlement | `CombatTransactionCoordinator` / existing result applier |
| Buttons, selected squad, markers and feedback | C0 presentation only |

No R0 facility creates a city placement, a FieldTactics project, or a second
resource ledger. The attempt can pay for its plan exactly once while it is
`RESERVED`; once active, the plan is immutable.

## Facilities

| Facility | Cost | Battle effect | Lifetime |
| --- | ---: | --- | --- |
| Watch platform | 6 wood | Marks detailed enemy observation as available to the battle presentation | This battle instance only |
| Siege ram | 8 wood | Applies 160 real damage to its selected gate at session initialization | This battle instance only |

The current C0 scene is an assault, not a city-defence simulation. These
facilities therefore are siege preparation, not an assertion that the game now
has defensive wall repair, defenders, traps or a permanent wartime build mode.
Those remain follow-up work and must use this same battle-instance ownership.

## Persistence

Schema 9 adds `wartime_facility_plan` and `battle_session_snapshot` to an
expedition attempt. Schema 7 migrates to an empty plan; schema 8 migrates to an
empty session snapshot. Empty legacy active snapshots retain the old compatible
restart-at-tick-zero behavior; snapshots created by R0 restore the exact
authoritative battle tick, routes, squad health, accepted/pending orders and
objective facts. UI, nodes and animation state are forbidden.

Each nonterminal C0 tick requests the existing runtime V5 checkpoint. A failed
checkpoint restores the in-memory session to the preceding committed snapshot;
a terminal result clears the active session snapshot before normal result
settlement applies its already-established atomic transaction.

## Verification

`tests/run_wartime_inner_city_r0_smoke.gd` covers the formal city departure,
visible C0 plan controls, pre-confirm zero write, one-time resource debit,
legacy migration, actual session effects, active-instance restore through the
formal city entry, and rejection of a tampered snapshot. Existing C0,
expedition-causality and V5 persistence runners remain regression gates.

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
| Immutable departure plan / active battle snapshot | `ConstructionController.expedition_attempt` in V5 schema 9 |
| Macro-siege request / macro facility plan / active session relation | `WarLoopState.wartime_handoff` through `ConstructionController` |
| Battle ticks, units, routes, orders and temporary effects | `BattleSession` |
| Activation, result hand-off and settlement | `CombatTransactionCoordinator` / existing result applier |
| Buttons, selected squad, markers and feedback | C0 presentation only |

No R0 facility creates a city placement, a FieldTactics project, or a second
resource ledger. A normal city attempt can pay for its plan exactly once while
it is `RESERVED`. A macro siege uses the same visible C0 plan controls but
commits into its one frozen `wartime_handoff` request through a separate
construction resource transaction; it never creates another city departure or
deducts the macro army's food a second time. Once active, either plan is
immutable.

## Facilities

| Facility | Cost | Battle effect | Lifetime |
| --- | ---: | --- | --- |
| Watch platform | 6 wood | After 2 battle ticks of construction, marks detailed enemy observation as available to the battle presentation | This battle instance only |
| Siege ram | 8 wood | After 4 battle ticks of construction, applies 160 real damage to its selected gate | This battle instance only |
| Arrow tower | 10 wood | After 4 battle ticks of construction, targets the selected defended gate approach every 4 battle ticks (1 second) and contributes 24 damage to the existing enemy-HP intent | This battle instance only |

Confirmed works enter `CONSTRUCTING` first. The saved battle session owns their
tick progress; only `ACTIVE` works supply their stated ability. This prevents a
confirmed plan from granting observation, gate damage or tower fire before the
same world ticks have actually completed construction. The arrow tower does not own a second combat loop. Its selected route is the
existing battle model's gate approach and every volley is added to
`BattleSession`'s regular enemy-damage intent before the shared damage writer
applies route HP. It consequently survives/replays through the same active
battle snapshot as all other route damage, and cannot double-apply casualties
after a restore. The C0 presentation reads the resulting committed-tick event
only after its checkpoint succeeds, adds a short route/damage notice, and
never restores that transient notification as a new volley after reload.

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

Battle-session snapshot schema 2 also retains per-facility phase and progress.
Schema-1 session snapshots remain compatible: because their old behavior had
already applied the paid plan at tick zero, they restore those records as
active and never reapply ram damage. Each nonterminal C0 tick requests the existing runtime V5 checkpoint. A failed
checkpoint restores the in-memory session to the preceding committed snapshot;
a terminal result clears the active session snapshot before normal result
settlement applies its already-established atomic transaction.

## Verification

`tests/run_wartime_inner_city_r0_smoke.gd` covers the formal city departure,
visible C0 plan controls, pre-confirm zero write, one-time resource debit,
legacy migration, actual watch/ram/tower session effects, active-instance
restore through the formal city entry, and rejection of tampered duplicate
identities, malformed numeric fields and conflicting pending orders. Its scene
rebuild exercise is **same-process** evidence only. The macro-siege A/B
independent-process runner additionally saves a watch platform at construction
tick 1/2 and cold-restores it to its single active completion tick, proving that
this construction state does not become an immediately-active substitute or
charge a second plan. It does not yet prove facility damage/repair or a complete
defensive scenario across processes. Existing C0, expedition-causality and V5
persistence runners remain regression gates.

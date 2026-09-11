# Wartime Inner City R0

## Purpose

R0 turns the existing C0 battle scene into a recoverable battle-instance
surface without merging it into either the regular city or the R2 field
theatre. It is a narrow assault preparation slice: the player may confirm
temporary siege works after the normal expedition has reserved food and before
the battle begins.

## Blackstone gate defense source

`WARTIME_DEFENSE` is a separate durable source for the Blackstone gate-defense
scenario. It uses the existing V5 `expedition_attempt` ledger only as the
single frozen battle transaction: the same formation snapshots, reservation,
active-session checkpoint and result writer remain authoritative. It has a
distinct `source_id` and fixed mission id, costs no departure food, and does
not advance or settle the ordinary first-war pressure track. It must therefore
not be substituted with the noticeboard's transient protection missions.

The first R0 defense objective is a real `PROTECT_AND_ELIMINATE` task: two
enemy approaches attack the saved Blackstone gate objective whenever they are
not stopped by a frontline squad. The C0 facility plan is available from this
source, but its source-aware authority permits only observation, arrow-tower
and barricade works; a siege ram is neither displayed nor accepted by the
controller transaction. Construction and repair stay attached to the same
frozen battle session.

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
| Barricade | 5 wood | After 3 battle ticks of construction, reduces the selected route's ordinary incoming enemy damage to 65%; in `WARTIME_DEFENSE` it instead absorbs the remainder of that route's real gate damage into its durability | This battle instance only |

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

The barricade uses the same single route-damage intent: after it is actually
complete, the selected route's enemy hit is multiplied by 6500 basis points
before the existing squad-HP writer applies it. In the protection objective,
that same split is applied to the saved gate target: the barricade absorbs the
remainder into its own durability and the gate receives only the passed
damage. It does not hide or rewrite casualties, introduce a second combat
loop, or affect another route.

When a facility is damaged or destroyed, the active C0 panel exposes the next
eligible facility and its repair cost. Pressing that formal action spends only
the published repair cost through `ConstructionController`, changes the same
saved `BattleSession` record to `REPAIRING`, and checkpoints it immediately.
If that checkpoint fails, the session and resource spend are both rolled back.
Repairs take two battle ticks and restore the record's recorded maximum
durability; a repeated action while repair is underway has no second cost.
The repair source check accepts either the active city expedition or any active
macro-siege handoff transaction, so parallel siege display order cannot deny a
legitimate battle its repair. This is still assault-side facility lifecycle
coverage, not the complete independent city-defence gameplay promised later.

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
Schema-3 adds per-facility maximum/current durability plus `DAMAGED`,
`DESTROYED` and `REPAIRING` phases. Schema-2 snapshots receive their matching
full durability once on restore, preserving their historic construction/active
behavior. Schema-1 session snapshots remain compatible: because their old behavior had
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
rebuild exercise is **same-process** evidence only. The macro-siege A/B/C/D/E
independent-process runner saves watch-platform and barricade construction,
restores them before activation, damages the completed barricade through a real
battle tick, begins repair through the visible button, cold-restores
`REPAIRING`, completes its remaining two ticks, then separately restores and
writes back the terminal result. This proves neither construction nor repair
becomes an immediately-active substitute or charges a second plan. The focused
C0 smoke additionally asserts one authority resource debit, duplicate-click
idempotence, completion and active-session restoration. These are still
assault-side lifecycle checks, not a complete defensive scenario. Existing C0,
expedition-causality and V5 persistence runners remain regression gates.

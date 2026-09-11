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
enemy approaches advance through their saved routes and only attack the saved
Blackstone gate objective after reaching it without a frontline squad. Their
route progress is part of the active battle snapshot. Historical schema-1/2/3
sessions have no such fact, so migration conservatively restores them at the
route origin rather than inventing an arrival. While its one frozen request is
still `RESERVED`, the formal C0 squad route button can adjust a defense
squad's selected approach. The controller writes the matching route into both
the selected formation and immutable committed-force snapshot before it
publishes; it neither replaces the roster nor charges departure food. Once
activated, that deployment is locked like every other prepared request. The
C0 facility plan is available from this
source, but its source-aware authority permits only observation, arrow-tower
and barricade works; a siege ram is neither displayed nor accepted by the
controller transaction. Construction and repair stay attached to the same
frozen battle session.

When a defense result is confirmed, the summary retains this source and mission
identity. Returning from its C0 scene does not invoke the ordinary first-war
result panel or change the first-war state to `IN_BATTLE`. A route-driven gate
loss applies the recorded defense loss once and restores it from the settled V5
result; it does not reset the gate because the first-war runtime projection was
rebuilt. The focused formal smoke also sends three real Blackstone formations
through the visible select-and-advance controls until both approaches are
cleared, then confirms one defense victory with the gate still intact and
returns to the normal city. This is a durable defense conclusion, not a
substitute for the later full
defence/city-fall campaign flow.

## Ownership

| Fact | Owner |
| --- | --- |
| Permanent wood and food | `NationState` through `ConstructionController` |
| Immutable departure plan / active battle checkpoint / pending result | `ConstructionController.expedition_attempt` in V5 schema 11 |
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

The macro army's existing formation routes are also frozen with that handoff.
C0 keeps their route controls disabled for this source rather than presenting
an edit that would exist only in a transient scene. The player may still
select one of those existing formations to choose the route for a new
route-bound facility.

## Facilities

| Facility | Cost | Battle effect | Lifetime |
| --- | ---: | --- | --- |
| Watch platform | 6 wood | After 2 battle ticks of construction, reveals the exact incoming enemy count for its deployed defense route; before completion C0 shows that route as a visible but uncounted threat | This battle instance only |
| Siege ram | 8 wood | After 4 battle ticks of construction, applies 160 real damage to its selected gate | This battle instance only |
| Arrow tower | 10 wood | After 4 battle ticks of construction, targets the selected defended gate approach every 4 battle ticks (1 second) and contributes 24 damage to the existing enemy-HP intent; after a route barricade is gone, invaders dismantle the tower before resuming gate damage, and its volley scales with remaining durability | This battle instance only |
| Barricade | 5 wood | After 3 battle ticks of construction, reduces the selected route's ordinary incoming enemy damage to 65%; in `WARTIME_DEFENSE` it instead absorbs the remainder of that route's real gate damage into its durability | This battle instance only |
| Spike trap | 4 wood | Defense-only. After 2 battle ticks of construction, the first invader to reach its route takes 80 real damage; the trap consumes itself and has no second trigger | This battle instance only |

Facility identity is `kind + route`: one kind may be deployed once on each
actual approach, but never twice on the same route. This lets a player cover
both approaches without duplicating a resource, route, or combat owner. The
plan UI always reflects the selected squad's route; once active, each watch
platform reveals only its own route and each arrow tower contributes an
independent, route-local intent to the shared battle tick.

The spike trap is intentionally not an assault tool and is rejected by the
authority for ordinary or macro-siege sources. Its trigger is checked from the
same saved enemy route position used for gate damage, then writes both the
enemy HP intent and the consumed facility phase in that battle tick. A saved
destroyed trap does not replay its historic hit after restore. The standard
facility repair transaction can re-lay the exhausted work when that is still a
legal active-battle action.

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

An unfinished route work is not invulnerable. Once invaders reach that route's
objective, they target a `CONSTRUCTING` barricade, then tower, then watch
platform before applying ordinary gate damage. The hit changes the same saved
facility record to `DAMAGED` or `DESTROYED` and emits a construction-interrupted
event; it grants none of the unfinished work's normal effects. The established
repair transaction is the only way to return that record to `ACTIVE`, so an
interrupted work cannot silently resume construction or become effective during
the attack that stopped it.

In `WARTIME_DEFENSE`, a reached invader route first spends its ordinary damage
against a barricade. Once that route has no active barricade, it damages its
active or damaged arrow tower; after the tower is gone, it damages the route's
watch platform before it can resume gate damage. A damaged tower still fires a
durability-proportional volley; a destroyed tower fires nothing. A damaged or
destroyed watch platform immediately stops revealing that route's exact enemy
count, and resumes only after repair completes. The damage intent and facility
lifecycle are applied in the same battle tick, so the tower may make its final
eligible volley on the tick it is destroyed, but never on a later tick. The
existing repair transaction can restore a destroyed tower to its full saved
volley after its repair ticks complete.

Repair controls are scoped to the selected squad's route. If that route has
more than one damaged or destroyed facility, C0 exposes a local `switch repair
target` action before any repair transaction is submitted. The selected target
does not alter facility state or spend resources; the existing transaction
still revalidates and repairs exactly that saved facility ID.

The independent defense recovery chain saves a side-route watch platform and
barricade while both are constructing. On a separate-process restore, already
consumed normal battle time may complete only the watch platform according to
its saved two-tick requirement; the longer barricade retains its non-zero,
unfinished progress and route identity. This distinguishes normal time
continuation from rebuilding either facility from scratch or granting its
effect early.

Before confirming a plan, new works bind to the currently selected squad's
formal deployment route. C0 displays that route in the plan title, and the
controller still validates the route in the persisted plan at confirmation.
Changing a squad from front to side therefore changes the actual target of a
new watch platform, tower, or barricade; it is not a cosmetic route label.
The independent recovery chain covers this fact while a side-route barricade
is still constructing. If invaders destroy it in the same tick that a repair
finishes, the saved outcome is `DESTROYED`; a repair animation or stale
positive durability is not retained as a second result.

The barricade uses the same single route-damage intent: after it is actually
complete, the selected route's enemy hit is multiplied by 6500 basis points
before the existing squad-HP writer applies it. A damaged barricade retains a
durability-proportional share of that reduction: at full recorded durability it
passes 6500 basis points, and as durability reaches zero it passes 10000.
In the protection objective, that same split is applied to the saved gate
target: the barricade absorbs the remainder into its own durability and the
gate receives only the passed damage. It does not hide or rewrite casualties,
introduce a second combat loop, or affect another route.

For the defence objective, that same record also slows only the route on which
it stands: a complete barricade passes 7500 basis points of enemy movement per
battle tick, and damaged durability interpolates deterministically back to
10000. A destroyed work therefore neither delays invaders nor absorbs their
damage. Route position remains the existing battle-session fact; the facility
adds no second movement owner.

When a facility is damaged or destroyed, the active C0 panel exposes the next
eligible facility on the currently selected squad's route and its repair cost.
Pressing that formal action spends only the published repair cost through
`ConstructionController`, changes the same saved `BattleSession` record to
`REPAIRING`, and checkpoints it immediately. This prevents a generic repair
button from silently selecting a damaged facility on another approach.
If that checkpoint fails, the session and resource spend are both rolled back.
Repairs take two battle ticks and restore the record's recorded maximum
durability; a repeated action while repair is underway has no second cost.
The repair source check accepts either the active city expedition or any active
macro-siege handoff transaction, so parallel siege display order cannot deny a
legitimate battle its repair. This is still assault-side facility lifecycle
coverage, not the complete independent city-defence gameplay promised later.

The actual `PROTECT_AND_ELIMINATE` target has a separate, equally temporary
repair action: while the Blackstone gate is damaged but not destroyed, C0 can
spend 4 wood through the existing city transaction to begin a two-tick repair.
The active `BattleSession` owns that phase, its remaining ticks and the
one-time restoration of up to 120 target HP; a save failure restores both the
resource transaction and the prior session. Completion is processed before
the ordinary incoming damage intent of that same tick, so the target receives
its restored HP before any valid contemporaneous enemy hit. This does not
alter permanent city defense until the ordinary battle result is settled.

Once battle begins, the editable plan is hidden as intended. The same C0
surface instead shows a persistent route-focused read-only summary of each
saved facility's construction, active, damaged durability, repair, or
destroyed phase. This is a projection of the active `BattleSession`; it does
not create a UI-owned construction or durability state. A damaged barricade
also reports its currently passed damage and enemy-movement percentages from
that same durable projection, so its repair priority is not inferred from a
misleading intact-state label.

The C0 scene now has bounded assault and Blackstone gate-defence sources, but
it is not yet a complete city-defence campaign mode. Facilities stay local to
one battle instance; construction, repair and the actual facility lifecycle
must keep using the same battle-instance ownership rather than becoming
permanent city buildings.

## Persistence

Plan schema 2 adds `construction_squad_id` to each newly confirmed facility:
the visible selected C0 squad becomes the immutable construction detachment.
The Controller rechecks that identity against the frozen committed roster
before spending construction resources, so a forged or stale squad ID cannot
create a plan. Plan schema 1 remains readable for historical requests; its
missing identity is bound once when the active session is constructed rather
than retroactively spending or replacing a participant.

Schema 9 adds `wartime_facility_plan` and `battle_session_snapshot` to an
expedition attempt. Schema 7 migrates to an empty plan; schema 8 migrates to an
empty session snapshot. Schema 11 adds `terminal_result_snapshot` for the
strict `RESULT_PENDING` boundary. The last nonterminal checkpoint remains a
normal restorable battle session; the terminal authority is restored beside it
without replaying a combat tick. Empty legacy active snapshots retain the old
compatible restart-at-tick-zero behavior; a schema-10 pending record without a
terminal authority record instead conservatively resumes its last ACTIVE
checkpoint and never fabricates unrecoverable post-battle HP or rewards. UI,
nodes and animation state are forbidden.

Battle-session snapshot schema 2 also retains per-facility phase and progress.
Schema-3 adds per-facility maximum/current durability plus `DAMAGED`,
`DESTROYED` and `REPAIRING` phases. Schema-2 snapshots receive their matching
full durability once on restore, preserving their historic construction/active
behavior. Schema-1 session snapshots remain compatible: because their old behavior had
already applied the paid plan at tick zero, they restore those records as
active and never reapply ram damage. Each nonterminal C0 tick requests the existing runtime V5 checkpoint. A failed
checkpoint restores the in-memory session to the preceding committed snapshot.
A terminal result retains that last active checkpoint beside its terminal
authority until normal result settlement applies its already-established atomic
transaction, then clears both records.

Schema 5 adds strict protection-target repair state (`IDLE` or `REPAIRING`,
progress, required ticks and capped restore amount). Older schemas retain
their recorded target HP and are normalized to `IDLE`; no historical repair is
invented. New malformed target/repair records are rejected before they can
alter a live session.

Schema 6 adds `INTERRUPTED` for a route work damaged before construction
finished. It retains its actual build progress and remaining durability without
projecting a facility effect. Schema 1-5 records retain their recorded
lifecycle phase and are never guessed to have been interrupted.

Schema 7 adds `construction_squad_id` to every facility record. It references
one existing committed battle squad that is doing the facility work; it does
not create a second specialist or troop owner. If that squad exits or is lost,
unfinished construction/repair enters `INTERRUPTED` without granting its
effect. A formal repair binds a currently living committed squad before it can
resume. Schema 1-6 records migrate once using their recorded living squad with
the lowest stable ID; a new schema-7 record with an unknown identity is
rejected rather than silently inventing a worker.

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
`REPAIRING`, completes its remaining two ticks, then separately persists a
pending terminal result, reopens its formal confirmation, writes it back once,
and verifies the settled reload. This proves neither construction nor repair
becomes an immediately-active substitute, a result does not replay after
restart, and a second plan is not charged. The focused
C0 smoke additionally asserts one authority resource debit, duplicate-click
idempotence, completion, damaged-barricade attenuation, and active-session
restoration. These are still
assault-side lifecycle checks, not a complete defensive scenario. Existing C0,
expedition-causality and V5 persistence runners remain regression gates.

The dedicated defense process runner uses two isolated chains. A/B/C/D/E
covers construction, damage, facility and gate repair, retreat pending-result
recovery and one writeback. In particular B saves both repairs while pending;
C cold-restores them and consumes only the remaining ticks. F/G separately starts with three real formations, issues formal
advance commands to reach a defense victory, saves its `RESULT_PENDING` fact,
and lets a fresh process confirm exactly that result. Defense victory is not a
first-war victory: V5 validation preserves the unrelated mainline cleared
state instead of requiring it to match this mission outcome. H/I separately
saves a real route-arrival interruption while a barricade is still under
construction, then cold-restores its non-protective `INTERRUPTED` state and
uses the visible repair action to restore the same facility.

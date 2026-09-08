# FIELD_TACTICS_R2 Engineering Checkpoint

## Scope and authority

This checkpoint starts from R1 source `3fbc5b9`. It adds a persistent outer-city
field record without replacing city resource authority, army ownership, or V5
publication. `FieldTacticsState` is nested in `WarLoopState`; it holds runtime
road identities, camps, specialist positions, construction projects, patrol
facts, and player knowledge. `ConstructionController` is still the sole food
transaction and persistence-checkpoint caller.

## Delivered engineering evidence

### Formal bridge-planning and expert-route checkpoint

The formal map draft no longer converts a cross-water line into a global
`BRIDGE` material choice. It keeps the requested land material through the
Macro March adapter and `ConstructionController`; `FieldTacticsState` alone
produces the persisted per-segment `NORMAL → BRIDGE → NORMAL` plan. The
Controller still publishes one reversible project transaction, with the
existing bridge cost for a route containing a bridge. Unit-coordinate water
sampling is shared by construction classification and specialist movement, so
narrow water is not skipped by the former coarse construction interval.

An open bridge now enters the specialist path graph through its ordered,
turn-preserving polyline. An expert crossing a bent bridge stores those bridge
turns and does not travel directly between bridgeheads. Repair endpoint choice
uses that same specialist path and its geometric distance, permitting a
roadless-land approach while continuing to reject incomplete or damaged bridge
crossings. Focused Godot 4.5.1 results: Field 47 assertions, Macro March 27,
three isolated field persistence chains PASS, and R1 war 16 assertions. This
does not prove normal system-input play, interrupted-project reassignment,
safe-camp transfer, patrol guard/ambush casualties, or either full R2 route.

### On-site construction checkpoint

Road construction now reuses the persistent engineer specialist as its only
on-map worker. A confirmed project starts with that engineer travelling from
its current world coordinate to the chosen construction start; the existing
world clock then advances the same specialist across land work. For an
unfinished bridge the worker remains at the reachable bank rather than
crossing water in presentation or authority state. On completion, the worker
uses the physical final road endpoint until the new camp is created, avoiding
a transient floating-point coordinate that V5 correctly rejects.

The focused R2 suite adds an arrival-to-work position assertion and passes 42
assertions. The cross-process runner now isolates construction, repair and
multi-road march chains, and each chain passes through three independent
Godot processes. The repair chain deliberately returns the engineer over the
actual specialist movement entry before persisting travel and arrival work.
This proves engineering state continuity, not interruption/reassignment,
nearest reachable stationing, patrol guard/ambush combat, a full play route,
or normal system-input media.

Blocked macro orders also now carry their intended resume phase. The damaged
route handler can block either a normal march or a retreat; after repair it
restores the original phase rather than changing a retreat into an unrelated
march. ArmyRegistry schema 5 supplies `MARCHING` only when migrating old
blocked records that never retained this fact. The R1 war regression covers a
retreat block and resume. It does not yet prove a blocked retreat through the
full reachable-camp transfer or cold-recovery sequence.

Repair confirmation selects an endpoint only after resolving it from the
engineer's current point through open runtime roads. An unreachable far bridge
bank is therefore not selected merely because it is the authored road target;
when neither endpoint is reachable, no repair project or identifier is
created. This is bridge-work reachability, not the still-open army transfer to
a reachable friendly camp after a blocked order.

Specialist movement now stores a land-route polyline and uses it for duration,
world interpolation and recovery. The greybox visibility graph detours around
water but permits experts to cross ordinary roadless land, retaining the
separate road-only restriction for armies. Generated construction junctions
resolve from the adjoining physical road endpoint; unknown positions are
explicitly rejected instead of silently becoming `(0, 0)`. Field smoke adds
water-detour and junction-coordinate assertions and passes 44 assertions.

The theatre bounds now reach field authority through the controller and war
loop, and water checks use unit-coordinate sampling rather than the former
16px interval. Bridge endpoints are represented in the specialist graph, but
the automatically split bridge endpoint normalization is still open; this
checkpoint must not be read as proof that all specialists can already traverse
every completed bridge.

### Map camera and command UI follow-up

The return action and engineer action now occupy separate managed slots even
at 648px height. Formation buttons are retained while the roster projection is
unchanged, so a press/release spanning frames cannot switch to a rebuilt node.
The Macro runner additionally checks all visible control rectangles are
pairwise disjoint and verifies node continuity; it now passes 27 assertions.

The outer-city map uses a single screen/world camera transform for rendering,
hit testing and drafting. Cursor-anchored wheel zoom, middle-drag panning,
minimap recentering and edge-drawing pan all retain the same command world
coordinates. The camera has no resource, order or persistence authority.

Formation controls now live in a scroll container and action controls are
bottom-anchored outside that list. The focused macro test checks all visible
controls at 1152×648, 1280×648 and 1920×648, injects zoom/pan/drag events into
the formal map screen, and proves the controller's selected-force/food preview
does not mutate the V5 snapshot. It currently passes 26 assertions under
Godot 4.5.1. This is automated UI evidence only, not system-input screenshots
or a video.

The map also adds greybox forest, shore, bridge, road, camp, flag-army and
specialist-role representation for readability. It does not implement a
multi-segment graph, patrol-versus-army casualties, normal-input playthrough
or Founder acceptance.

### Formal-input and repair follow-up

- Confirming a camp-building project reserves its `camp_id` and its generated
  runtime camp point immediately.  A second engineer confirmed before the
  first completion receives a distinct persisted identity.
- Repeated automatic mouse input at an overlapping army marker cycles the
  selected `army_id`; dead specialist history does not hide a replacement
  dispatch control.
- A damaged field road now remains closed while its selected engineer travels
  to the endpoint and completes a timed repair project.  The same road ID is
  restored only at completion.  A completed road can be validated in either
  direction when the submitted polyline is directionally exact.

Verification after this follow-up: `run_field_tactics_r2_smoke.gd` passes 27
assertions, `run_macro_march_r0_smoke.gd` passes 18, and
`run_field_tactics_r2_persistence_smoke.gd` passes its independent three-process
construction/restore chain. The Macro runner injects a damaged-road map click
and repair-button callback; this is explicitly automated UI wiring rather than
system-input media. A dedicated repair disk chain is still open.

### Repair-time and bridge follow-up

Repair arrival no longer discards the remaining time in a shared world step:
the post-arrival remainder is applied to repair work. A focused snapshot
equivalence assertion covers a single long advance versus split advances.
Three further isolated processes now restore repair travel, the arrival
remainder after 500ms of work, and final opening of the original road.

The theatre Resource supplies a small greybox water region. Engineering lines
crossing it are classified by the field authority as bridge projects; the map
uses the same classification for preview and paints the water region. Current
focused results are 29 field assertions, 19 Macro March assertions, and the
construction-plus-repair persistence chain. This does not yet establish a
multi-segment road/bridge graph, blocked-army automatic resume, or encounters.

### Damaged-road macro recovery follow-up

The shared macro scheduler now detects a damaged runtime road before it
advances an affected order. It commits the existing order to `BLOCKED` at its
current route segment and, when the repair project reopens that exact road,
resumes the same `order_id` without charging march food again. The field
controller smoke exercises road construction, issue, damage, durable block,
on-site repair, automatic resume, and a subsequent advance. This is not yet
nearest-reachable-camp routing, arbitrary multi-segment routing, or a patrol
encounter system.

### Patrol movement and historical-intel follow-up

The finite patrol now has a persisted route, wait state, move interpolation and
world position. The field smoke observes it at Northwatch, confirms the scout's
last report, then verifies the patrol departs while the player only retains the
previously observed coordinate. No army collision, guard behavior, ambush,
casualty transaction, or patrol-derived road damage is claimed by this change.

- Two macro armies can be issued from distinct garrison formations. The
  registry rejects a persisted formation identity in two non-closed macro
  armies, and closed history no longer blocks a new departure.
- Existing roads are represented in a runtime graph. A field road is not open
  until its project completes; normal, reinforced, and bridge defaults are
  separate configurable record kinds. Damage affects field-road passage, while
  main roads cannot be damaged; repair preserves the road identifier.
- Scouts and engineers are dispatched via food transactions. Patrol facts are
  private to the authoritative record; the public field projection returns no
  unobserved location or strength, and observed intel becomes last-known after
  visibility is lost.
- V5 validation normalizes a real R1 nested war snapshot to the R2 field-state
  shape before exact restore verification. This preserves old city, gate,
  army, and order facts without granting map knowledge.

## Verification

Godot `4.5.1.stable.official.f62fdbde1` imported and parsed the project.

- `tests/run_field_tactics_r2_smoke.gd`: 20 assertions passed, including timed
  scout arrival and patrol contact, plus two
  independent city-keyed siege records advancing and restoring together.
- `tests/run_field_tactics_r2_persistence_smoke.gd`: three independent Godot
  processes persisted construction-in-progress, completed it after restore,
  and then cold-restored the completed road/camp.
- `tests/run_macro_march_r0_smoke.gd`: 14 assertions passed.
- `tests/run_war_loop_r1_smoke.gd`: 15 assertions passed.
- `tests/run_v5_campaign_persistence_smoke.gd`: passed, including its isolated
  three-process disk chain.

## Remaining work and evidence boundary

Follow-up engineering made the city-keyed siege records the controller's
settlement boundary and moved macro progression to the shared controller
clock. It also removed the normal-map static route-break demonstration controls
and prevents the macro read model from disclosing the authoritative field
snapshot. These changes close timing and cross-siege ownership defects, not
the remaining player-operated tactics work.

The current R2 continuation also connects a completed field road to the
controller's actual macro-order validator and duration calculation. An
engineer-selected drawn route can terminate at a newly created runtime camp;
its persisted endpoint coordinate is returned to the safe map projection. The
focused field runner now has 22 assertions. This confirms the state/command
connection, not a completed normal-input journey or road encounter loop.

The map now resolves a selected army from its visible marker. Subsequent
drafting and retreat use its identity, instead of silently targeting the first
army returned by the compatibility read model. This still needs normal-input
evidence alongside the remaining specialist and encounter work.

Field project completion and specialist encounter records now trigger the
controller's V5 checkpoint even when no siege ticks during that frame. The
controller snapshots field state before advancing and restores it if the
checkpoint fails. The existing three-process engineering chain remains green;
an immediate encounter-specific disk chain is still part of the unfinished
encounter delivery.

Specialists now carry persisted current/start/target coordinates and advance
between positions under the same shared clock. Scout visibility is a finite
coordinate radius, and an unobserved patrol remains unobserved through repeated
projection refreshes. The focused R2 runner has 23 assertions. Patrol movement,
army encounters and normal-input verification remain open.

The formal map now normalizes runtime-road records before using them as UI
drafts, eliminating the old `road_id/route_world_points` versus
`route_id/points` mismatch. Engineering drag release creates a cancellable
draft; only confirmation writes its resource transaction. The macro runner has
16 assertions including automated map-to-controller checks. This is not a
replacement for system-input evidence.

This is not a complete R2 play-flow delivery. The formal map does not yet offer
a full player-operated specialist drag-line workflow, nor does the formal
controller yet settle patrol/ambush damage against armies or apply
parallel-siege losses back to separate armies. No
safe candidate game window was locked for normal system input during this
checkpoint, so no real screenshots or recording are claimed. These gaps must
be completed before describing the R2 tactical loop as playable or accepted.

Suggested next engineering entry: make the existing city-keyed siege records
the controller's settlement loop, then bind `MacroMarchR0` selection/drawing
to the already-persisted field-road and specialist APIs. Keep
`ConstructionController` as resource/save authority.

The map now selects a concurrent siege record by the selected army ID; the
20-assertion Macro smoke verifies the lookup against two synthetic records.
This fixes detail cross-talk only and does not imply an encounter resolver.

Patrol advancement now consumes the residual milliseconds after wait and route
arrival instead of dropping them. The 32-assertion field runner compares a
single advance with split wait/move/contact advances. This remains patrol
motion evidence, not army casualty or ambush evidence.

### Ordered runtime-path checkpoint

Runtime path planning now accepts the player's world-space draft and chooses
among all simple connected candidates by that expressed route intent. The
authority rejects directed road sequences with an endpoint discontinuity before
any city resource transaction. The map displays the authority-returned duration
rather than reproducing a local travel-time formula.

New macro orders persist the validated road-ID/direction sequence; snapshot
validation migrates old single-road records and earlier composite path handles
into that explicit representation. The scheduler derives the current physical segment from
the shared order progress and only checks that segment and later segments for
damage; a road already passed by the army does not stop it. Focused field smoke
passes 38 assertions and Macro March smoke passes 27 under Godot 4.5.1.
This is automated engineering evidence, not normal system-input media, a full
cross-process tactical route, or R2 player acceptance.

The isolated persistence runner now provides the missing disk-level route
check: three separate Godot processes issue a two-road order, reload it while
in flight, complete the remaining route, and cold-reload the stationed result.
It verifies the stored directional sequence and one-time food transaction.
It does not yet include a multi-segment damaged bridge, safe-camp transfer,
or normal-input playthrough.

### Sequential bridge construction checkpoint

When a construction line crosses the theatre water region, field authority now
samples it into a persisted road-bridge-road plan rather than marking the
whole drawn polyline as one bridge. The project opens each completed physical
segment into the runtime graph in order; later segments remain non-existent and
cannot be traversed until their own work completes. The focused field runner
proves the three planned kinds and the staged opening order (39 assertions).
The existing single project resource transaction is retained for now; detailed
per-segment materials, bridge damage recovery, and normal-input evidence are
still open work.

### Retreat and segment-publication follow-up

Retreat now creates a new order by reversing the original validated physical
segments and their directions. Its route identity remains the same real road
path, so return scheduling and damage checks cannot resolve a fabricated
`.return` road. The R1 runner exercises a formal city attack, retreat, and
physical return to Northwatch.

Each construction segment opening now appears in the field advance result and
therefore triggers the controller's ordinary checkpoint/rollback flow even
before the whole project completes. Focused automated checks currently pass:
Field R2 40 assertions, War Loop R1 16, and Macro March 27. No normal-input
media or two-route tactical acceptance is claimed.

### Scalable route-planning follow-up

The runtime planner now uses a weighted graph search rather than enumerating
every simple path. Open physical-road length is the base cost and distance from
the player-drawn line is a route-choice penalty. This retains the alternative
route interaction while removing the former 12-segment ceiling; the focused
runner proves a 13-segment legal route. Larger-map interaction profiling,
safe-camp transfer, and encounter settlement are still open.

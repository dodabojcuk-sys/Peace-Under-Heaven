# FIELD_TACTICS_R2 Engineering Checkpoint

## Playable-theatre implementation contract (2026-09-09)

The current candidate is judged by a player-operable Blackstone theatre, not by
isolated Controller calls. Specialist, patrol, and guarding-army contact must
use positions from the same world-time interval. A spatial crossing at a
different time is not an encounter, and a guard only participates when it is
near the specialist at the actual contact time.

Engineering commands must preserve one authoritative plan from map preview to
commit. The plan identifies the selected engineer, reachable construction
start, existing-point connection or new-camp intent, ordered road/bridge
segments, duration, and food cost. The map may explain this result, but must
not duplicate cost, bridge, or duration rules. The playable checkpoint also
requires two normal-resource routes with distinct trade-offs and a clipped,
readable battlefield presentation. Automated Controller fixtures remain logic
evidence and are not substitutes for a player-operable input chain.

## Scope and authority

This checkpoint starts from R1 source `3fbc5b9`. It adds a persistent outer-city
field record without replacing city resource authority, army ownership, or V5
publication. `FieldTacticsState` is nested in `WarLoopState`; it holds runtime
road identities, camps, specialist positions, construction projects, patrol
facts, and player knowledge. `ConstructionController` is still the sole food
transaction and persistence-checkpoint caller.

## Delivered engineering evidence

### Low-poly presentation checkpoint (current worktree)

#### Formal-art finish evidence (current worktree)

#### Targeted material and selection-marker repair (current worktree)

The seven selected Kenney source GLBs were independently inspected: every
active imported `BaseMaterial3D` surface reports `metallic=1.00`. That is not a
credible response for Blackstone trees, riverbank grass and rocks. The
presentation now changes only its cached per-kind/per-surface runtime copies to
`metallic=0`, retaining source GLBs, texture slots, render flags and material
partitions. It does not alter another presentation asset or global material
policy.

The renderer no longer creates the opaque, depth-disabled `SelectionRing`
cylinder. Selection uses the existing hollow 2D ring and status/count overlay,
supplemented by one compact elevated command pennant. Army, scout and engineer
checks confirm the shared marker contract without adding a duplicate troop
count or changing a truthful actor location. Same-camera engine-viewport
captures and the non-headless regression record are under
`evidence/20260909-blackstone-render-targeted-fixes/`; those captures are
GUI-event/render evidence, not desktop-system-input footage or acceptance.

The current finish keeps the selected Kenney GLB material surfaces intact. The
presentation no longer applies a uniform whole-instance material override:
cached surface variants preserve each import's texture slots and render flags
while making trunk/crown and rock-facet colours coherent in the Blackstone
palette. The visible transformed mesh, not the GLB root node, is settled onto
the same horizontal ground anchor used by the authoritative map.

Forest/rock ground variation, shallow riverbank strips and expanded camp
silhouettes improve reading of the existing gate-road-river-bridge-forest-camp
segment only. Roads are wider in the renderer and selected actors receive an
elevated depth-independent pennant plus their normal 2D count/status overlay;
neither change alters passability, army position, fog, selection authority,
combat, clock or saves. The latest graphical runner validates visible imported
mesh bounds, actual ground contact, material partitions, camera/click alignment
and army/scout/engineer selection markers. It also records the first matched
1280×720 render baseline for later comparison, not a performance claim. Exact
engine-viewport evidence and the retained normal-system-input media gap are
under `evidence/20260909-blackstone-art-finish/`.

The final recheck also repaired one Macro March test-fixture boundary: each
independent UI contract now restores the same pristine production V5 snapshot
before it opens a new city scene. Earlier contracts can therefore no longer
leak dispatched formations, projects or patrol state into a later UI assertion.
This is runner isolation only; no player persistence, world-time or campaign
authority changes were made.

The Blackstone outer map now offers a render-only low-poly mode backed by an
orthographic `Camera3D` and `SubViewport`. It projects the existing 2D world
coordinates into a small 3D scene and consumes the established Macro March and
Field read models. `ConstructionController`, `ArmyRegistry`, `FieldTacticsState`
and V5 persistence retain their existing ownership; this presentation does not
advance a second clock, resolve a second battle, or write a separate save.

The first formal art batch uses seven selected CC0 Kenney Nature Kit GLBs for
trees, rocks and riverbank grass. The authored city gate/wall, camp and Ridge
Watch tower remain lightweight Godot assemblies so their foundations stay on
the same authoritative anchors. The generated gatehouse image is a non-runtime
design reference, never a texture or gameplay screenshot. Asset source,
license, checksums and modification boundary are recorded in
`assets/blackstone_art/ASSET_MANIFEST.md`. The existing clipped 2D renderer
remains selectable, and all input continues through the same 2D coordinate
transform. This is a sample for the Blackstone gate-road-river-forest-garrison
segment, not final art coverage for every theatre.

The map's roster copy was corrected at the same boundary. A zero count in the
city roster after dispatch means that the formation was transferred into an
active army, not that it was eliminated. The panel now says `已出征（当前 N 人）`,
reports the selected army's current snapshot strength and latest stored patrol
loss, and shows the original order direction while marching. Macro March smoke
adds a 30th assertion for a formal seven-member dispatch: city availability
becomes zero while the active army remains seven, with `黑石城 → 北望驻扎点`
visible in the status. Encounter-specific survivor counts remain facts of the
saved encounter/army state; they are never inferred from city availability.

An isolated Godot process rendered the low-poly map on the target Mac. Desktop
automation did not receive accessible child controls for its custom drawing
canvas, so this work has visual runtime inspection but not new normal-system-
input footage. That media gap is reported separately and does not change the
logic verification boundary.

Follow-up graphical validation corrects the original camera mapping and
road-segment transform. The presentation ground now remains on a horizontal XZ
plane while bridge elevation is explicit; `unproject_position()` is an
independent renderer-side check against the authoritative 2D map. At
1152x648, 1280x720, and 1920x1080, named
points, bridge heads, and a road midpoint stay within 0.22 pixels; segment
midpoint/facing error is 0. The graphical runner also uses the Macro March UI
event path to draft and confirm a military route, create a cross-river
engineering project, advance a visible army, and toggle presentation modes
without mutating campaign state. It is graphical UI-event evidence, not an OS
mouse recording.

### Blackstone sample-theatre candidate

The player-facing sample is now independent of the regression fixture. Its
Resource owns a 1500x980 battlefield with seven named points, two enemy cities,
distinct northern and lowland roads, three separated river reaches, three
forests, rocky banks, and one finite patrol. The northern road reaches combat
quickly; the central crossing must be built and reaches the authored Forest
garrison for concealed staging. Regression runners explicitly select the
legacy definition, so their historical geometry remains deterministic.

Two isolated routes start from the same normal city resource and formation
state and use the formal dispatch, construction, world-clock, encounter, siege,
resource, and V5 owners.

| Route | Formal result |
| --- | --- |
| Northern road | 39.40 world seconds, 12 food spent, 68 remaining, four real formation casualties, Redcliff and Silverford captured. |
| Scout/engineering | 79.40 world seconds, 36 food spent, 44 remaining, three army casualties, no specialist loss, one natural forest ambush, generated road-bridge-road, both cities captured. |

The natural engineering route does not inject road damage, force an engineer
death, or require meaningless bridge crossings. Road damage, replacement,
repair, camp transfer, original-order recovery, and their audited cold-start
boundaries remain in the separate fault-regression suite. The current metrics
are balance observations, not final tuning or player acceptance.

The map uses one invertible fixed-oblique projection for rendering, hit testing,
minimap navigation, zoom/pan, and route drafting. World objects are clipped away
from the side rail. Water banks, tree groups, rocks, roads, bridge decks, damage,
walled cities, faction flags, tent camps, armies, and specialist markers provide
one consistent readable greybox presentation without changing traversal facts.
Player copy identifies locations, actions, costs, travel time, build time, and
blocked-transfer phases instead of exposing internal IDs or enums.

The construction contact gap is closed on the shared time axis. An engineer
working through a road segment now emits timed movement records. If an unguarded
contact occurs inside a large step, later work is rolled back, later-opened roads
or camp state are removed, and the project is interrupted at the contact time.
Equivalent split steps produce the same specialist survival, project progress,
and road state.

Historical system-input evidence, captured before the current formal-art batch,
is under
`evidence/20260909-blackstone-sample-final/`:

- `00-overview.png`: identified 1280x720 sample-theatre overview;
- `01-route-draft.png`: selected formation and snapped northern route;
- `02-auto-march.png`: continuous army movement and explicit progress;
- `03-arrived-northwatch.png`: arrival at the northern garrison;
- `04-engineering-plan.png`: authoritative road-bridge-road preview and cost;
- `05-construction-progress.png`: engineer position and active work geometry;
- `blackstone-route-command.mov`: 23.99-second H.264 window-only recording of
formation selection, route drawing, confirmation, and continuous movement.
The current art batch instead records actual engine-viewport/GUI-event stills
under `evidence/20260909-blackstone-art-integration/`; it does not claim a new
normal-system-input recording or player acceptance.

The evidence window was locked to PID 64981 and window 12727 with the visible
title `CITY · codex/txwzs-field-tactics-r2@8c35afa · DEBUG · DIRTY`, and used an
isolated V5 save directory. It proves that native system input reached the
intended candidate. It does not claim that both complete campaigns were recorded
with normal input, and it is not Founder/player acceptance.

Focused verification uses
`/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`
(`4.5.1.stable.official.f62fdbde1`). Field R2 passes 69 assertions, Macro March
passes 29 assertions, and both formal playthrough routes pass. The audited Field
and Macro disk chains, War Loop R1/formal/arrival/disk recovery, V5 army/campaign/
encounter recovery, R1E 50 assertions, C0 presentation, editor import, four scene
starts, and `git diff --check` also pass. Raw logs are retained under
`/tmp/txwzs-r2-sample-final-logs/`.

`run_blackstone_playable_mvp_smoke.gd` remains obsolete historical test debt and
is not counted as a passing full-repository sweep. Full-route normal-input media,
final art, balance acceptance, and player acceptance remain open.

The remaining subsections preserve chronological checkpoint evidence. Their
then-open lists are historical and do not supersede this current summary.

### Patrol encounter, guard, ambush, and casualty checkpoint

The shared field clock now moves the authored patrol on its resolved
runtime-road polyline and reports its swept movement. The Controller compares
that trace with the actual road trace traversed by each army during the same
formal `_process` step. An army and patrol therefore still meet when a large
step places them on opposite ends of the road, rather than relying only on
their final coordinates. Several armies touching the same patrol join one
settlement against one finite enemy strength.

The tactical resolver calculates deterministic minimal greybox losses, while
`ArmyRegistry` remains the only owner that applies them to stable formation
IDs or closes a fully lost army. An unrelated army can continue a separate
siege in the same world step. A local army within the guard radius prevents a
moving specialist from being removed immediately; a deployed, unexposed army
in configured forest terrain can receive a single ambush opening against a
previously observed patrol. That opening is consumed and the army exposed.
The contact may damage the nearest built field road, but never a main road.

Formal V5 restore preserves the patrol's remaining strength, resolved army
IDs, consumed ambush IDs, exposure, road damage, and exact per-formation army
snapshots. Focused results are Field R2 65 assertions, audited field
persistence PASS, Macro March 27, War Loop R1 16, formal scene 10, and arrival
persistence 3. This remains an engineering checkpoint: both complete
normal-resource routes, normal-input media, balance review, and player
acceptance are still open.

### Temporary-route rebreak, time remainder, and audited recovery

Temporary camp and return movement now revalidates the actual remaining
physical segments before every advance. A new break either replans a camp path
from the army's exact temporary position or enters a persisted reblocked phase
without moving through the failed road. Repair returns that same temporary task
to motion. The immutable original order, frozen progress, formations, resume
phase, and already-paid march cost are unchanged.

Clipped physical segments carry their own ordered geometry and endpoint facts.
The same data therefore drives availability, movement, reverse return, map
projection, snapshot validation, and cold recovery. Arrival returns unused
milliseconds to the next legal phase, and a formal Controller `_process`
scenario reaches an identical army snapshot at 30 FPS, 60 FPS, and irregular
partitions while crossing the return boundary.

The disk harness now requires a child-written success marker as well as exit
code zero. That change found five worker parse errors that the previous
exit-code-only harness had falsely accepted. After repair, the existing chains
and a new three-process rebreak/repair/continue chain all pass. Focused results
are Field R2 58 assertions, audited field persistence PASS, Macro March 27,
War Loop R1 16, editor import, and `git diff --check`. This checkpoint does not
claim patrol/guard/ambush casualties, either complete R2 route, normal-input
media, or player acceptance.

### Formal bridge-return and recovery canonicalization repair

The map now attaches its interrupted-project selector to the actual control
tree and preserves the selector's options while its projection is unchanged.
It exposes new construction, selected-road repair, and selected-project resume
as distinct actions, so an interrupted project cannot silently capture the
normal road tool. The expanded seven-action rail remains inside the automated
648px layout contract.

V5 validation now initializes the temporary restored war loop with the same
Resource-owned theatre facts used by `ConstructionController` before
canonicalizing legacy specialist routes. The strict export-after-restore check
therefore compares two migrated snapshots, retaining rollback on any real
difference. Formal Controller regression covers a player-generated bridge
forward and backward, confirms a damaged bridge is no longer an open bridge
edge, and restores a V5 snapshot whose in-flight expert lacks a route. Focused
Godot 4.5.1 results are Field R2 52 assertions and Macro March 27 assertions.
This remains engineering evidence only: safe-camp transfer, encounters,
complete routes, normal system-input media, and player acceptance are open.

### Formal bridge-use and deferred-recovery checkpoint

The bridge verification now enters through the formal city and Controller
path. It confirms a player-shaped construction project, advances
the authoritative world clock to completion, dispatches a later engineer, and
checks the resulting specialist route against the physical bridge points
created by that project before the engineer reaches Reedbank. Specialist path
search permits water only through an open bridge's navigation geometry and its
shore connection; normal water remains blocked. Bridge preference affects
route selection only, while saved geometry and duration retain actual distance.

Missing-path specialist migration is deferred from raw `FieldTacticsState`
restore until `initialize_from_theater` receives the Resource-owned water,
boundary and bridge facts. The formal V5 restore therefore uses the same
terrain authority as normal advance. The map additionally exposes interrupted
projects through a selector and attempts every eligible engineer for the
chosen project. Focused results: Field 50 assertions, Macro March 27,
three-process field persistence PASS, and R1 war 16 assertions. This does not
prove safe-camp transfer, encounters, full player routes, or normal-input
media.

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
crossings. An interrupted project retains its ID, opened work, and camp
reservation while a new engineer resumes it through the Controller's normal
checkpoint/rollback path. Older moving-specialist saves which lack a route now
replan from their saved position or enter an explicit blocked state, rather
than silently using a direct line across water. Focused Godot 4.5.1 results:
Field 49 assertions, Macro March 27, three isolated field persistence chains
PASS, and R1 war 16 assertions. This does not prove normal system-input play,
combined interruption recovery, safe-camp transfer, patrol guard/ambush
casualties, or either full R2 route.

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

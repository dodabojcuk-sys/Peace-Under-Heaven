# 当前状态

## FIELD_TACTICS_R2 engineering checkpoint (2026-09-07)

### R2 formal-input and on-site-repair checkpoint

The map now preserves a camp identity at engineering confirmation, so two
engineers cannot reserve the same runtime camp while both projects are still
in progress.  The visible-army hit target cycles on repeated mouse clicks at
the same location, and historical dead specialists no longer suppress the
replacement-dispatch controls.

Damaged field roads now create a persisted repair project.  The assigned
engineer travels to the road endpoint, the road remains blocked during the
separate repair duration, and only completion restores the original road ID.
Runtime roads validate in both directions, including their reversed polyline.
Focused field smoke passes 27 assertions, Macro March passes 17, and the
three-process field construction restore runner passes.  This is still not a
complete R2 play flow: bridge classification, map-operable repair selection,
patrol/ambush settlement, road-damage auto-resume, full normal-input playthrough
and real media remain open.

### R2 concurrency and safe-projection follow-up

The controller now owns one shared world clock for all macro armies, field
projects and sieges. The map is presentation-only and no longer advances each
visible army, so observing a second army cannot change time accumulation.
Each order retains its own fractional-millisecond remainder. Parallel sieges
are settled by explicit city identity; finishing, losing or retreating one
siege no longer consumes the other city's record. The macro read model is now
a safe projection (cities and player-visible siege facts only), rather than a
path to hidden patrol data. Field restore also rejects dangling road, camp,
project and specialist references before replacing live state.

Focused parsing, R2 field smoke (20), R1 war smoke (15), and the independent
field persistence chain pass after this change. This is still an engineering
checkpoint: the normal map has not yet gained the required player-drawn
engineering workflow, active patrol/ambush settlement, real system-input
playthrough, screenshots or video. It is not a complete R2 delivery or player
acceptance.

The formal outer-city map now presents every active army, runtime roads,
completed camps, and living specialist roles in the same projection. Main,
field and damaged roads are visibly distinct; hidden patrol authority remains
excluded. This is clarity work only: it does not turn the unfinished fixed
engineering shortcut into the required player-drawn construction interaction.

### R2 runtime-road command checkpoint

Completed field roads now validate through the same controller path used by
macro commands, including their persisted polyline and computed march time.
Unfinished or damaged field roads are rejected before a food transaction. The
map's engineering action selects a living idle engineer and accepts a player
drawn route; its endpoint can be an existing point or a newly named runtime
camp. Completed camps retain their actual endpoint coordinate and appear in
the map's selectable point projection. R2 field smoke now has 22 assertions,
including dynamic-road validation and a non-authored camp endpoint.

This is a source-level checkpoint, not proof of the complete normal-input
journey: selected-army command targeting, specialist continuous movement,
bridge classification, repair arrival, patrol encounters and media remain
open.

### R2 selected-army command checkpoint

The outer-city map now selects an army by its rendered marker and retains that
`army_id` for route drafting, stationed follow-up and siege retreat. Selected
markers are visibly highlighted. This removes the normal-map first-army
default while retaining the compatibility projection used by older callers.
The macro adapter now forwards an explicit siege city for retreat.

### R2 key-event persistence checkpoint

The world-advance transaction now snapshots before field mutation and publishes
an immediate V5 checkpoint when an engineering project completes or a field
engagement changes specialist state, even with no siege tick. A failed publish
restores both army and war snapshots. Existing R2 smoke and the independent
three-process engineering restore runner pass after this change.

### R2 specialist position and fog checkpoint

Specialists now persist start, target and current world coordinates, with
distance-based movement duration and interpolation under the shared clock.
Scout vision uses the persisted coordinate plus a finite range. Fog no longer
converts a never-seen patrol into historical knowledge merely because the
projection refreshed. The map renders specialists at their actual current
position. R2 smoke now has 23 assertions, including continuous movement and
the never-observed fog boundary.

### R2 formal draft-contract checkpoint

The map now normalizes every authoritative runtime road into a stable UI draft
with `route_id`, `target_point_id` and `points`; confirmation no longer reads
missing legacy route fields. Engineering drag release creates a cancellable
draft and only its explicit confirmation spends resources or creates a project.
The macro runner has 16 assertions, including automated formal map-draft and
engineering-draft-to-controller coverage. This is automated UI wiring, not
system-input media.

### R2 continuation checkpoint

Specialists now move over shared logical milliseconds rather than jumping to a
target in one simulation call. A scout only gains enemy knowledge at arrival;
contact with the finite patrol records a last report and marks the specialist
lost. An engineer killed while building leaves its project interrupted, not
silently completed. The formal outer-city UI exposes food-backed scout and
engineer dispatch plus a visible side-road/camp construction action through
the existing narrow dispatch adapter.

`run_field_tactics_r2_smoke.gd` now passes 20 assertions. New
`run_field_tactics_r2_persistence_smoke.gd` runs three independent processes:
construction is saved mid-progress, restored and completed, then cold-restored
with its road and camp intact. The remaining R2 gap is army-versus-patrol
encounter/ambush settlement and its player-operable route/repair presentation;
this is not reported as a completed playable battle loop.

R2 introduces a persistent `FieldTacticsState` nested under the existing
`WarLoopState`: static roads enter a runtime graph, while field roads, camps,
specialists, construction projects, patrol facts, and player-facing last-known
intel live in the same V5-published authority. `ConstructionController` still
owns food/resource commits and the persistence checkpoint. An R1 war snapshot
is normalized to the R2 nested representation before restore postconditions
are checked, so migration does not change an otherwise valid old save into a
false failure.

`ArmyRegistry` no longer blocks macro orders globally: two distinct formation
sets can issue independently, and snapshot validation rejects any formation
identity shared by two non-closed macro armies. The macro map advances every
active army, while existing R1 single-army read access remains as a compatibility
projection. `get_field_tactics_read_model()` never exposes an unobserved
patrol's location or strength.

Focused `run_field_tactics_r2_smoke.gd` passes 19 assertions for independent
orders, duplicate formation rejection, fog knowledge boundaries, specialist
resource dispatch, construction/road/camp state, damage/repair, R1 migration,
and formal V5 cold restore. `run_macro_march_r0_smoke.gd` (14),
`run_war_loop_r1_smoke.gd` (15), and the three-process
`run_v5_campaign_persistence_smoke.gd` also pass. This is a greybox engineering
checkpoint: multi-city simultaneous siege/road encounters, enemy patrol combat
resolution, system-input playthrough, screenshots, and recording remain open.
It is not Founder acceptance or a completed tactical-release claim.

## WAR_LOOP_BATCH_R1 formal-scene wiring checkpoint (2026-09-07)

The `a5e7cc1` candidate had four confirmed formal-wiring defects despite the
existing domain smokes: opening the outer-city view disabled the controller
clock; a CLOSED macro army was mistaken for the current army; per-frame
millisecond rounding varied siege outcomes; and enemy-city arrival lost its
arrival flag after being replaced by a siege/surrender result, skipping the
mandatory synchronous checkpoint.

The outer-city view now hides/cancels city interaction without disabling the
authoritative controller. Controller and macro-view frame deltas retain a
sub-millisecond carry until whole logical milliseconds are available; pause
does not bank time and speed is applied once. CLOSED armies remain historical
records but are excluded from the commandable read model. Stationed follow-up
orders also archive their completed predecessor. Enemy arrival preserves a
separate commit fact so siege creation or immediate occupation is published
before the method returns; a final-read failure reuses V5 latest-generation
validation before deciding it was not durable.

New focused evidence: `run_war_loop_formal_scene_smoke.gd` passes 10 assertions
for the real formal entry, outer-city ticking, return/pause behavior, seven
losses to CLOSED then reissue, and 30/60/irregular frame equivalence. The new
three-process `run_war_loop_arrival_persistence_smoke.gd` passes 3 assertions
for immediate Redcliff siege, first-city completion/Silverford surrender, and
new-process double-city restore. This remains engineering and headless formal
scene evidence, not real system-input media or Founder acceptance.

The local source branch was then ordinarily pushed and read back as
`origin/codex/txwzs-war-loop-r1` at `1fd2014afee19dd7465d308b74eb39ff24d39e92`.
The remote review snapshot `df754e2c` remains a content-equivalent prior
snapshot with different history; it was not merged. A fresh remote clone was
started but its object transfer stalled after the ref query, so clone-based
verification is `BLOCKED_NETWORK_AFTER_REF_VERIFY`; the remote SHA itself was
verified and the local bundle remains available for independent review.

## WAR_LOOP_BATCH_R1 deterministic/double-city/disk checkpoint (2026-09-07)

Local candidate `f3249dc` now has a follow-up working checkpoint (not yet a
remote-reviewed revision). `ArmyRegistry` schema 4 keeps immutable original
macro orders in history when a retreat creates a separate reverse-route order;
complete losses close the army rather than storing a zero-member active army.
The war state rejects malformed nested city/siege fields, retains damaged gate
and defender facts on failed siege, and gives simultaneous attacker/defender
elimination to the attacker-failed branch.

Redcliff and Silverford are now both required enemy cities: Redcliff retains
its River Lords story ownership but begins under Border Rebels military control;
Silverford remains configured for automatic surrender. The level clears only
after both military controllers become player. The focused war-loop runner now
has 15 assertions, including the reported timing, 7+7 formation, single-loss,
mutual-destruction, gate persistence, immutable-return-order, malformed nested
snapshot, and double-city conditions. A separate 3-assertion runner launched
three isolated Godot processes against one V5 directory and recovered active
siege tick 1 → tick 2 exactly once.

This is an engineering/cold-recovery checkpoint only. A candidate `e0eec91`
window was launched with a per-run isolated save and exact title identity, but
the available desktop automation could only enumerate a pre-existing R1E Godot
window, not the candidate window. No input was sent to either process and the
identified candidate process was terminated normally. Real normal-input media,
Founder acceptance, deployment, Meshy work, and any fog/engineer/siege-expansion
work remain open. Remote source sync remains unverified until a later ordinary
push and remote SHA check succeeds. The final authorized ordinary push on
2026-09-07 used non-interactive HTTPS with a 10-second connect and 15-second
low-speed bound; it failed with `Operation too slow` before any bytes arrived.
No credential was read, no remote ref was created, and no force/merge/deploy
operation was attempted. `SOURCE_SYNC=BLOCKED_NETWORK`.

## WAR_LOOP_BATCH_R1 corrective checkpoint (2026-09-06)

`a800a84` corrects the first verified WAR_LOOP defects: siege advancement is
owned by `ConstructionController` rather than the macro presentation control,
uses persisted sub-tick remainder instead of a forced tick per render update,
does not double-drive from the modal, preserves formation identity during
rear-first attrition, allows zero survivors, resolves simultaneous annihilation
as failure, and persists damaged gate/guard facts after a failed siege.

The existing Macro March and V5 persistence runners pass after this checkpoint.
The required dedicated timing-equivalence, multi-required-city, and siege
cross-process-disk cases remain open; normal-input evidence is also open.
The review remote was configured as `origin` for the authorized repository,
but two normal non-interactive push attempts timed out while connecting and
produced no remote SHA. No force push, credential read, merge, or deployment
was attempted.

## WAR_LOOP_BATCH_R1 siege, occupation, and recovery candidate (2026-09-06)

WAR_LOOP_BATCH_R1 is a local engineering candidate on
`codex/txwzs-war-loop-r1`, based on `a5fda3dd`. It extends the outer-city
theatre with Redcliff (required) and Silverford (optional) enemy cities. A
macro army that reaches an enemy city first evaluates the persisted surrender
configuration; a refusal enters deterministic gate-then-guard combat using
the committed unit HP, attack, armor, city gate, and guard facts. This is a
new durable war-loop authority, not a shortcut through the legacy C0 result
writer.

`ArmyRegistry` schema 3 adds SIEGING and RETREATING phases while retaining the
same macro army and order. `V5CampaignSnapshot` schema 7 persists enemy
military control, gate/guard facts, active siege tick, losses, and idempotent
resolution IDs; V6 saves migrate to an empty WarLoop state and do not invent a
campaign order. Occupation changes military control only; story ownership is
retained. A required-city set makes Redcliff the single-city clear condition;
the data model supports a future multi-city required set without treating
optional Silverford as a victory requirement.

Focused WAR_LOOP_R1 smoke passes 9 assertions (surrender, attack, cold
restore, breach/guards/occupation, victory rule, casualties, and retreat).
Existing Macro March R0 movement and three-process persistence smokes also
pass. These are engineering checks, not a Founder acceptance. No verified
normal-input screenshots or continuous player recording are provided in this
candidate; no merge, push, deployment, 3D modelling, fog, or expanded strategy
systems were performed.

`WAR_LOOP_BATCH_R1=ENGINEERING_CANDIDATE_REAL_INPUT_MEDIA_NOT_PROVIDED`

## Macro March R0 outer-city greybox (2026-09-06)

Macro March R0 is a local engineering candidate on
`codex/txwzs-macro-march-r0`. It introduces one replaceable theatre Resource
with Blackstone City, Northwatch Garrison, Reedbank Garrison, two selectable
Blackstone-to-Northwatch road paths, and one demonstrable blockable branch
road. The normal city now enters the macro screen through `外城军令`; the
legacy Blackstone MVP scene remains source-only and no longer receives the
formal city entry or writes strategic army state.

`ArmyRegistry` schema 2 holds the stable army, issued order, snapped road
polyline, exact selected formation snapshots, fee, logical progress, and
blocked/stationed phase. `GarrisonState` extracts exact selected formations
instead of using the legacy aggregate tail-removal path. `ConstructionController`
keeps the food transaction, rollback snapshot, registry mutation, and runtime
save checkpoint as one boundary. The current expedition food formula is reused
only as temporary macro-march balancing, not as a final supply design.

Focused Macro March smoke passes 14 assertions. A three-process isolated-disk
smoke passes: process A persists a blocked order, B restores it, resumes and
arrives, and C cold-restores the stationed army. Existing V5 army and R1E
focused suites also pass. This is not siege victory, enemy-city attack,
occupation, energy/ability, 3D-art, Founder acceptance, merge, push, or
deployment.

The current desktop environment contains a separate user Godot window that
could not be displaced safely by the available UI controller. The real
candidate window was started and visually inspected during preflight, but real
mouse-drawn draft/marching/blocked screenshots and a 45–90 second system-input
video are **not provided**. No script/test state was relabelled as real-input
media.

`MACRO_MARCH_R0=ENGINEERING_PARTIAL_REAL_INPUT_MEDIA_NOT_PROVIDED`

## R1E expedition reconciliation (2026-09-06)

This section records the current expedition branch without re-labelling it as a
full-game acceptance.

- **Identity:** `codex/txwzs-expedition-visual-r1e` at
  `147430ed1d4fe584abcb423755da4455e5d5f95c` (Godot 4.5.1).
- **Engineering baseline:** the R1E causality smoke, C0 presentation smoke, and
  headless scene startup checks have passed. The focused R1E suite protects the
  city preparation, payment, persistence, retreat, victory, defeat, and reload
  boundaries; it is not a player acceptance decision.
- **Player-facing repair:** expedition roster cards no longer expose internal
  identifiers such as `formation.blackstone.1`; the focused smoke asserts that
  only player-readable formation names and force counts are shown.
- **Native run result:** an isolated Day 1 save was used for a real path of
  city → select the first two formations (14 people) → battle → issue advance
  orders on the front route → defeat → return to city. The battle failed at
  tick 532 with 0 survivors; food was charged once and the result returned to
  the city. This proves the current defeat/return path, **not** a normal-input
  siege victory, breach, occupation, or Founder acceptance.
- **Product reconciliation:** the latest product rules and explicit deferred
  items are recorded in
  [`R1E_RECONCILIATION_20260906.md`](docs/milestones/txwzs-r1e/R1E_RECONCILIATION_20260906.md).
  No shared-energy migration, active-ability system, replenishment economy,
  permanent-general-death semantics, fog/disguise/mine system, weather, or
  full UI system was introduced here.

The next meaningful gate is to establish a normal-input route that can produce
a real siege victory under the intended rules, then verify breach and
occupation semantics without substituting a static result or a test-only win.

## TXWZS City Governance Interaction 001

This isolated branch started from exact M1B documentation base
`2e39ac78f3c9d93585edee6e43a1b736e0ba05bf` and stopped before any product
change. The requested governance road recommendation contract assumes an
existing `RoadConnectivitySystem`, immutable road preview/confirm intent,
reservation, and `ScheduledJob`. This base has none of those: its existing
`ConstructionController` derives road connectivity through `CityGridRules` and
`RegularCitySpatialFoundation`, then immediately commits wood and road
placements on confirmation. Adding the missing job/intent system would create
the prohibited second transaction/queue and alter road behavior, so no partial
UI was made. See
`docs/reports/TXWZS_CITY_GOVERNANCE_INTERACTION_001_BLOCKER_REPORT.md`.

The only completed branch change is a portable tracked macOS debug export
preset (`eac441c`); `export_credentials.cfg` stays ignored. The exact Godot
4.5.1 export-template archive is resuming in the background and is not a
governance pass/fail condition.

`CITY_GOVERNANCE_INTERACTION_001=BLOCKED_BASELINE_CONTRACT_MISMATCH`

## M1B standalone playable shell R0

M1B adds a container-driven `title_shell.tscn` as the formal main scene. It
shows `天下无战事` / `黑石城`, provides only `进入黑石城` and `退出游戏`, gives
keyboard focus to the entry action, consumes title Esc safely, and changes once
to the existing `blank_map.tscn`. The title owns neither city state nor V5
persistence; entering the city still constructs the existing single
`ConstructionController` and `RuntimeCampaignPersistenceCoordinator`.

The M1B focused runner passes 44 assertions across 1152×648, 1280×720, and
1440×900. The full dynamic smoke set is 53/53 pass; editor import plus title
main-scene, blank-map, and C0 headless smokes pass. Schema 5, storage version,
city/battle/build/road/resource behavior, and V5 lifecycle semantics are
unchanged.

The requested standalone macOS artifact is blocked, not passed: the exact
Godot `4.5.1.stable.official.f62fdbde1` editor reports its matching
`export_templates/4.5.1.stable/macos.zip` missing. No `.app`, standalone
screenshot, short clip, or candidate acceptance is claimed. See
`docs/m1b/TXWZS_M1B_PLAYABLE_SHELL_R0_REPORT.md`.

`M1B_PLAYABLE_SHELL=ENGINEERING_IMPLEMENTATION_BLOCKED_BY_MISSING_EXPORT_TEMPLATE`

## M1A current-mainline battle settlement return loop

M1A is a local-only closure on `cafe26c`. A single current-mainline action now
lives within the existing deadline/pressure top-bar region and enters the
existing C0 formal-city battle scene. It reuses the coordinator-bound unique
attempt, terminal preview, result-ID ledger, one-time resource transaction, and
guarded same-city return; no new battle, national-resource, city-time, or Save
authority was introduced.

Victory now clears `CurrentMainlineLevel` in the authorized battle settlement
immediately after a successful resource commit, so future pressure modifiers
and pressure events stop on confirm while already committed permanent losses
remain. Retreat and defeat do not clear it. A retreat may create a fresh
current-mainline attempt without resetting time/deadline; defeat keeps the
existing city-loss state. V5 persists returned city/mainline/ledger/build-slot
and training state unchanged in schema 5. In-progress battle sessions remain
attempt-local and are deliberately not saveable.

Focused M1A, R0C.1, formal first-war, native PNG, H.264/yuv420p scene-journey,
and final regression evidence are recorded in `docs/m1a/`. The visual journey
is script-driven; the required physical native-mouse playthrough remains a
Founder/manual verification item. R0C and R0C.1 remain a usable engineering
baseline, so Founder does not need to separately block later development for
each closed local HUD repair; obvious overlap, clipping, click-through, and
world interpenetration remain milestone gates.

`M1A_CURRENT_MAINLINE_RETURN=PASS_LOCAL_ONLY_PENDING_FOUNDER_PLAYTEST`

## M1A.1-R2 V5 runtime persistence lifecycle

The normal GUI city runtime now composes the existing V5 codec/store with the
existing `ConstructionController` canonical authority. Valid latest generations
load through the existing rollback-safe restore boundary; an empty store alone
publishes the default city; corrupt-all and future stores are write-blocked
without overwriting disk. Dirty canonical commits are debounced and normal
window close performs a final flush. `CampaignSnapshotV2` schema 5, envelope
storage version, V1 migration, construction, battle, resources, and UI rules
are unchanged. Headless runners require an explicit isolated save root, so they
do not touch a player `user://` campaign.

The new three-process normal-scene lifecycle runner verifies empty creation,
real current-mainline victory and return, automatic cold startup restoration,
and whole-generation fallback. It passes alongside the 52-runner full dynamic
regression, editor import, and headless smoke. A final native player video is
not claimed: the current macOS UI channel could not focus the separately
launched game window over the project manager, so no background automation was
mislabelled as real player evidence.

`M1A1_R2_RUNTIME_PERSISTENCE=ENGINEERING_PASS_L3_EVIDENCE_BLOCKED`

## M0 R0C.1 top-bar responsive closure

R0C.1 is a local-only presentation repair on `bab6b78f`. The top bar now
allocates disjoint resource, city, date/settlement, deadline/pressure, and
speed/pause regions from the active viewport rather than combining left and
right fixed anchors. Settlement detail uses two rows and yields only secondary
detail; mainline deadline, pressure, security, speed, and pause retain readable
space without reducing font sizes.

The R0C.1 focused runner verifies the longest live settlement and pressure copy
at 1152x648, 1280x720, and 1440x900, including pairwise region-rectangle
disjointness. One native Godot PNG per target resolution is in
`docs/m0/evidence/r0c1/`. R0C focused input/persistence smoke and all 49
dynamically discovered smoke runners pass. Construction queues, resource
transactions, placement, roads, and save behavior were not changed.

`R0C1_TOPBAR_RESPONSIVE=PASS_LOCAL_ONLY`

## M1A.1 normal entry authority and cold-restore UI repair

At local base `21b5ccad8ec70bed14aacd1e3f99db6bbe12b89f`, the normal new-city
20-person `GarrisonState` force can enter the existing C0 current-mainline
battle during preparation, warning, pending, or retry-after-retreat. The 50
value is now explicitly displayed as a command cap rather than an implied
minimum. Entry uses the same real force snapshot and retains the existing
atomic reservation/idempotent settlement path; no resource, construction,
road, placement, battle, or save rule was expanded.

Cold V5 restore now reflows the right construction panel after the build-slot
presentation is restored. Its build-slot controls live in an anchored
`VBoxContainer` with content minimums and size flags. Focused M1A.1 automation
passes 31 assertions, including normal 20-person entry, one-time reservation,
an explicit empty-force failure, one actual C0 winning route, and geometry plus
input-capture checks at 1152×648, 1280×720, and 1440×900. The 51-runner local
dynamic regression, editor parse/import, and main-scene headless smoke pass.

No post-repair human mouse/keyboard recording or current visual evidence has
been made. The player-flow, cold-restart-in-video, attachment, and release
gates remain `FAIL / HOLD`; this is not Founder review, merge authorization,
push authorization, or deployment authorization.

M1A.1 live closure subsequently repaired the real UI-only concentrated-front
deployment cadence at `01d84df`: when every real squad is deployed on the
front route, pressing the existing Start button queues their existing advance
orders together. The real OS-level final flow now reaches a normal 20-person
victory, one settlement, and same-city return. It then exposes the remaining
blocker: normal runtime startup does not load a disk V5 campaign snapshot, so
the cold-restarted process resets day, resources, and the cleared mainline.
`M1A1_LIVE_CLOSURE=FAIL_COLD_RUNTIME_PERSISTENCE_UNWIRED`; evidence and the
recording digest are in `docs/m1a/TXWZS_M1A1_LIVE_CLOSURE_REPORT.md`.

## M0 R0C single build slot and ready placement

R0C replaces the R0B map-foundation order with one current-city build slot.
Buildings register off-map, pay through the existing `NationState` ledger as
pressure-adjusted progress advances, wait at the last paid progress when
materials are missing, and become one fully paid ready token at 100%. A legal
ready-placement click creates one completed building without a second payment
and exits placement; roads retain their independent drag flow.

Campaign persistence is schema 5 with one `build_slot`. Schema 4 foundations
remain non-destructive legacy records and lock only the new slot until they
finish. New-flow priority is removed; legacy priority remains readable.

The focused 33-assertion input runner, 48/48 dynamic regression with 2,321
explicit assertions, three cold-process ready-token roundtrips, physical mouse
zero-material smoke, ten native screenshots, and an uncut 16.466-second
H.264/yuv420p MP4 pass. Founder live smoke remains pending. No push, merge,
deploy, or new gameplay is authorized.

`R0C_ENGINEERING_CANDIDATE=PASS_PENDING_FOUNDER_LIVE_SMOKE`

`R0C_FULL_REGRESSION=48_OF_48_PASS`

`R0C_SAVE_SCHEMA=5`

`R0C_VIDEO=MP4_H264_YUV420P_PASS`

## M0 R0B direct click and explicit failure feedback

R0B is an isolated engineering candidate based on exact R0A commit
`80908263fbf09cbec963ba4c582ff9b22adea894`. Building placement now commits from
one legal map left click, exits after one order, rotates with `R`, and cancels
with right click or `Esc`. The building confirmation button is removed.

Invalid placement shows a stable exact reason in the rail and a replacing
2.5-second map message. Timed construction shortages remain orderable under the
existing incremental-payment contract and state the exact missing amount plus
`下单后将等待材料`. Save schema 4 and all R0/R0A legality, pause, construction,
pressure, and persistence behavior remain unchanged.

The focused 26-assertion real-input runner and full 47/47 dynamic regression
pass. Native real-mouse 1152x648 smoke, six inspected screenshots, and an
inspected 12.267-second H.264 MP4 pass. Founder live smoke remains pending; no
push, merge, deploy, or new gameplay is authorized.

`R0B_ENGINEERING_CANDIDATE=PASS_PENDING_FOUNDER_LIVE_SMOKE`

`R0B_FULL_REGRESSION=47_OF_47_PASS`

`R0B_VIDEO=MP4_H264_420V_PASS`

## M0 time, construction, and level pressure slice

The conditionally authorized M0 slice is implemented on the isolated
`codex/txwzs-m0-time-build-pressure-r0` branch. `ConstructionController`
remains the only strategic time and placement writer, and `NationState` remains
the only shared-resource writer. Timed buildings now advance on fixed 1000 ms
ticks, pay cumulative costs incrementally, pause on missing resources, resume
without losing progress, and expose high/normal/low priority.

`CurrentMainlineLevel` owns the persistent day-7 deadline, five monotonic
pressure stages, committed permanent losses, clear state, and event IDs.
Security mitigates consequences without clearing or reversing pressure; five
essential channels retain a 25% anti-softlock floor. V5 campaign persistence is
schema 4 with explicit V2/V3 migration and exact M0 roundtrip coverage.

The final 45-runner regression, editor import, formal headless scene smokes,
V5 cold-process persistence, and native 1440x900/1280x720 evidence pass. Video
was not recorded. This is local-only engineering evidence pending Founder
review, not an overall MVP freeze, merge, push, deployment, or authorization to
start subsequent game systems.

`M0_TIME_BUILD_PRESSURE=PASS_LOCAL_ONLY_PENDING_FOUNDER_REVIEW`

`M0_FULL_REGRESSION=45_OF_45_PASS`

`M0_VIDEO=NOT_RECORDED`

## Product successor UI-R0

`codex/product-successor-inner-city-r0` is the only mutable product branch.
R1 extends its one-city inner-city presentation slice with a regular
axial/ward graybox spatial foundation, a responsive right construction rail,
minimap, four-way authoritative building orientation, and V5-compatible
orientation persistence. `NationState` and the existing construction authority
remain the only resource and placement owners. This does not start G4–G6,
R2C-03, V6, legacy cleanup, or a broader save/schema migration.

`VISUAL_STATUS=GRAYBOX_SPATIAL_FOUNDATION`

`FINAL_BUILDING_ART=NOT_STARTED_BY_SCOPE`

## R3A graybox building presence

R3A adds `GrayboxBuildingVisual` as the shared procedural presentation layer
for fixed buildings, placement ghosts, construction stages, and completed
runtime buildings. It consumes the existing `ConstructionController` records;
it does not own resources, roads, lifecycle, orientation persistence, or save
data. The visual stages are foundation, frame/partial mass, and completed,
derived from the existing construction start/completion days. N/E/S/W entrance
markers and rotated footprints are taken from the authoritative controller.

The R3A focused contract covers real building definitions, distinct
farm/logging-camp/warehouse graybox silhouettes, connected/disconnected
entrance states, pause stability, V5 orientation restoration, and no state
mutation. The complete current smoke suite is `42/42 PASS`; editor parse/import
and the formal `blank_map`, Blackstone, and C0 headless smokes also pass.

`R3A_NATIVE_WINDOW=VERIFIED`

`R3A_EVIDENCE=EXTERNAL_ONLY`

Evidence directory:
`/Users/m4-zhi/Downloads/txwzs2-r3a-graybox-building-presence-evidence-20260821-v1`

`ORGANIC_GARDEN_CITY=R3B_ACCEPTED_NATIVE_AND_HEADLESS`

`FINAL_BUILDING_ART=NOT_STARTED_BY_SCOPE`

## R3B dual-city layout profiles

R3B adds the stable `blackstone_city` -> `REGULAR_IMPERIAL` and
`riverbend_city` -> `ORGANIC_GARDEN` profile mapping through
`CityLayoutProfileResolver`. Blackstone keeps the accepted regular axial/ward
layout. Riverbend is a formal world-map entry using an authored orthogonal
garden layout with offset/T roads, unequal wards, one large reserve, two small
reserves, an off-centre civic court, and four rotations of the existing single
`CityGateComponentR1`.

The existing `ConstructionController` remains the sole writer. City switching
captures and restores only in-memory runtime building and player-road records;
the national resource ledger remains shared. V5 and early single-city save
export/restore fail closed while Riverbend is active because no multi-city save
schema was authorized. The right rail, placement, road tool, minimap,
selection, Escape behavior, and input routing are reused.

Focused R3B resolver/geometry and dual-city navigation runners pass. The full
44-runner regression, editor parse/import, formal-scene smokes, native
Blackstone → Riverbend → native build/rotate/confirm/construction/completion →
Blackstone flow, and 1280/1440/actual-1920x960 window evidence are captured in
the external evidence package. No final art, curved roads, traffic, full-map
rotation, G4, push, or deployment is claimed.

R1C 已关闭正式内城的原生鼠标建造阻断：右侧确认按钮的鼠标悬停不会再被
`MapPanController` 根输入路由误转成地图预览，合法 placement 可由真实鼠标
单击一次进入施工并在正常时间推进后落成。权威建造、资源扣除、取消、V5
方向存读档和旧 schema 北向兼容均保持原路径；当前视觉仍为灰盒基础。

## R2B player road construction

R2B 在正式 55×35 规则城池中加入玩家铺路工具。正式基础道路仍由
`RegularCitySpatialFoundation` 提供；玩家新增道路作为
`ConstructionController` 的普通 V5 placement 增量写入，视觉、N/E/S/W
连通性、建筑入口状态和存读档均读取同一合并集合，不保存重复的连通或运行
布尔值，也不升级 V5 schema。

右侧道路入口支持原生鼠标水平/垂直拖拽、局部预览、连接/孤立/阻断文字、一次
性确认和取消。确认通过现有 `NationState` 木材事务逐格原子写入；取消和
Escape 不写入、不扣费。道路连接已落成且需要道路的建筑后，状态立即从停用
派生为运行，生产从下一次权威日结开始生效。道路拓扑以灰盒绘制直线、转角、
T 型、十字和端点；旧 V5 存档缺少道路 placement 时仍恢复为空增量。

当前本地实现已通过 R2B focused headless smoke、41/41 runner 全量回归、编辑器
解析和三个正式场景 smoke；实现提交为 `3b6099f`。真实 Godot 窗口的原生鼠标
hover/drag/click 证据尚未取得：隔离运行进程已绑定本 Successor，但桌面前景仍
是既有 Godot 项目管理器，Computer Use 无法安全定位临时运行窗口。因此本轮
保持 `PARTIAL_WITH_EXACT_ROAD_TOOL_BLOCKERS`，不得把自动化测试当作原生鼠标
通过。道路删除/升级、交通寻路、桥梁坡度、曲线道路、有机城池、正式美术、
全图旋转、G4、push 和 deploy 仍未启动。

## 结论

`TXWZS2_V5_G3_REFRESHED_FULL_REGRESSION_AND_TRACEABILITY_ACCEPTED`

V4 已冻结，V5-G0、G1、G2、G3 已 `VERIFIED`，V5 整体仍为 `IN_PROGRESS`。
G4–G6、P6、V6 尚未启动；P7 仅其 G3 的 T001–T003 已 `VERIFIED`。

`712dcbd8e092ff844c4274a2f3a3c260d29998e7` 是本次 refreshed G3 的
validated source head。G3 在仓库外隔离 tree、隔离 `user://` 与 Godot 4.5.1 下
重跑了全部动态发现 runner、focused 回归、editor parse/import 与三个正式场景
smoke；它不构成 G4 实际窗口、G5 独立复查、G6 用户试玩或 V5 冻结。

R2C-01 已将国家共享资源的运行时所有权收敛到单一 `NationState`。生产场景
仍由现有 `ConstructionController` 编排，但建造、日结、训练、科研和兼容属性
全部委托同一个国家资源事务入口。`blackstone_city` 与 `riverbend_city` 已进入
正式运行时城市注册边界；P0-01 继续提供一城只读兼容投影。

V5 schema 和磁盘 topology 未升级。旧 `blackstone_city` 资源字段仅作为兼容
序列化载体，在 load 时通过临时 DTO 水合 `NationState`，save 时从
`NationState` 投影。`riverbend_city` 的完整城市局部状态尚未进入 V5 持久化，
不在本轮声称完成。

R2C-02 在既有 `ArmyRegistry`、`ConstructionController` 和绑定的
`CombatTransactionCoordinator` 上完成一条固定的无头 First War 运行时闭环：
`blackstone_city` 派遣至 `riverbend_city`，由 `BattleSession` 产出 terminal
facts，所有幸存者经既有返乡 phase 回到黑石堡。它没有新增 operation aggregate、
ledger、ID sequence 或持久战区；Riverbend 没有 owner、faction、驻军或局部状态
变化。本轮没有既定资源后果。

## Git 基线

| 字段 | 值 |
| --- | --- |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| G2 acceptance checkpoint | `af244167f7b0a31f3de2cc34673faa953113b96b` |
| Post-G2 documentation convergence | `b1ad4a09e202904aced9262104545867a97573cb` |
| P0-01 national read-model seam | `81fe8a8f479b05952a910b53e66dd4608582dc27` |
| R2C-01 national resource convergence | `a0406ede852da687ed5033a24471b43f7ebdf2ab` |
| R2C-02 First War lifecycle / validated G3 source | `712dcbd8e092ff844c4274a2f3a3c260d29998e7` |
| Upstream | 本地 branch 无 upstream |
| Remote action | M4 仅使用显式 branch/tag refs；结果以 `git ls-remote` 与 fresh clone 现场证据为准 |
| Index | 只按精确路径暂存；不得 stage S1A.2 |
| Porcelain / tracked worktree | clean |
| Nonignored untracked | `0` |
| Named protected S1A.2 present | `0` |
| Ignored generated `.godot/**` | `82`（实施前现场计数） |

V5-G2 链：

```text
cd7be2b
→ e2c1096
→ 5d659243
→ fab962c
→ 4d0fbfc
→ af24416
→ b1ad4a0
→ cb7c87ba
→ 81fe8a8f
→ a0406ede
→ 712dcbd8
```

`fab962c` 的精确 repair 范围：

```text
scripts/army/training_queue.gd
scripts/army/army_registry.gd
scripts/construction_controller.gd
tests/run_v5_campaign_persistence_smoke.gd
```

## Gate 状态

| Gate / phase | 状态 |
| --- | --- |
| V4 | `VERIFIED / FROZEN` |
| V5-G0 | `VERIFIED` |
| V5-G1 | `VERIFIED` |
| V5-G2 | `VERIFIED` |
| V5 | `IN_PROGRESS` |
| V5-G3 | `VERIFIED` |
| V5-G4 | `NOT_STARTED` |
| V5-G5 | `NOT_STARTED` |
| V5-G6 | `NOT_STARTED` |
| V5-P4-T005 | `VERIFIED` |
| V5-P6 | `NOT_STARTED` |
| V5-P7 | `T001–T003 VERIFIED; T004–T007 NOT_STARTED` |
| V6 | `NOT_STARTED` |

精确 16 项 G2 runtime task：

```text
V5-P2-T002  V5-P2-T003  V5-P2-T005  V5-P2-T006  V5-P2-T007
V5-P3-T002  V5-P3-T003  V5-P3-T004  V5-P3-T005  V5-P3-T006
V5-P4-T002  V5-P4-T003  V5-P4-T004
V5-P5-T003  V5-P5-T004  V5-P5-T005
```

它们和 V5-G2 均已 `VERIFIED`。G1 的六项合同任务已在独立 Gate 接受，不
重复计入。

## 当前架构事实

- `NationState` 是国家共享木材、粮食和科技点的唯一运行时 authority；所有
  正式资源变化经过 `commit_resource_transaction()`。
- `ConstructionController` 是日期、建设、训练、驻军和恢复的业务编排入口；
  `wood`、`food`、`tech_points` 仅是委托到 `NationState` 的兼容属性，不持有
  第二份余额。
- 一次正式城市场景运行只构造一个 `NationState`，同时注册
  `blackstone_city` 与 `riverbend_city`；两城局部运行时状态实例彼此隔离。
- 私有 `GarrisonState` 是本城兵种数量唯一源状态；`infantry_count` 是兼容
  属性，不是第二份存储。
- `TrainingQueue` 是训练订单唯一源状态；旧三字段仅为只读兼容投影。
- `ArmyRegistry` 是集合型持久模型；V5 最多一支 active 是校验策略，不是
  singleton 数据结构。
- `BattleSession` 只产出 terminal facts；城市写回由绑定的
  `CombatTransactionCoordinator` 授权。
- R2C-02 固定 First War army path 不建立目标驻扎：所有幸存者进入既有
  `RETURNING` phase，随后只回补 `blackstone_city` 的 `GarrisonState`。
- `CampaignSnapshotV2`、V5 codec/store、V1 只读迁移、不可变代次、坏档
  fallback 和 live apply rollback 已实现。
- 天下地图 V0 仍是只读表现 fixture，不是持久世界状态。

完整合同见
[TXWZS_ARCHITECTURE_CONTRACT.md](docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md)。

## Stable ID 与原子性

Training/Army sequence：

- 必须是 `TYPE_INT`；
- 必须在 `1..9007199254740991`；
- 必须大于快照内既有最大 ID；
- 上限值是合法 exhausted sentinel；
- `MAX-1` 可分配一次，之后创建失败且零写入。

Army sequence exhausted 时，控制器必须在 reservation、transaction、
registry 或 garrison 写入前失败。

以下失败边界已独立确认零部分写入：

- malformed 或 stale sequence restore；
- Training 资源、容量、供养或 exhausted create；
- Army 容量、active limit 或 exhausted reservation；
- 重复/冲突结果写回；
- 非法 V1 migration；
- invalid store preflight；
- write、publish、final reread 和 live apply 注入失败。

合法 V1 空训练队列允许保留已经验证的历史下单日，并能迁移到 V2。

## V5-G2 验收证据

fresh reviewer：

```text
/root/v5_g2_boundary_fresh_independent_reviewer_003
```

独立结果：

| 项 | 结果 |
| --- | --- |
| boundary probe | 29/29，exit 0 |
| P5 persistence | 51/51，exit 0 |
| G2 focused | 6/6，185 assertions |
| tracked | 33/33，1739 assertions |
| all-present | 35/35，1871 assertions / 1905 PASS |
| V5 cold workers | A/B/C 0/0/0 |
| S1A.2 cold workers | A/B/C 0/0/0 |
| city / Blackstone / C0 | exit 0，error signatures 0 |
| editor | exit 0，error signatures 0 |
| diff checks | exit 0 |

上述统计与要求基线无差异。最终验收报告见
[TXWZS_V5_G2_FINAL_ACCEPTANCE.md](docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md)。

## S1A.2 保护

裁决保持 `CONDITIONAL_REUSE_ACCEPTED`：复用存储机制与 V1 只读输入，不
采用 V1 writer/schema。

| 文件 | SHA-256 |
| --- | --- |
| `scripts/state/early_city_save_store_v1.gd` | `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` |
| `scripts/state/early_city_save_store_v1.gd.uid` | `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd` | `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` | `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` | `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` |
| `tests/s1a2_early_city_disk_worker.gd` | `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` |
| `tests/s1a2_early_city_disk_worker.gd.uid` | `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` |

上述八文件保留为历史 G2 保护证据；当前 Candidate 现场不存在这些 named
untracked 路径，未被 stage、恢复或迁移。

## 主控计划

- Plan version：`1.0.3-v5-g3-refreshed-full-regression-accepted-001`
- Workbook：13 sheets
- Formula errors：0
- Workbook ↔ 5 CSV：`totalMismatches=0`
- V5 进度：84% VERIFIED（37/44）
- R2C-02 是 G2 后的已授权纠偏提交，并已成为 `712dcbd8` refreshed G3 基线；G3
  通过不提前启动 G4、G5、G6、R2C-03 或 V6

权威计划文件：

- [TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx](docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx)
- [TXWZS_MASTER_DEVELOPMENT_CONTROL.md](docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md)
- `docs/planning/csv/` 下五份镜像。

## 当前运行与验证

Godot：`4.5.1.stable.official.f62fdbde1`；project feature set `4.5`。

正式 CITY 入口：

```text
RUN_CURRENT_TXWZS.command
```

Headless：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 5
"$GODOT" --headless --path . --editor --quit
```

单个测试：

```sh
"$GODOT" --headless --path . --script res://tests/run_v5_vertical_loop_smoke.gd
```

窗口中的 `branch@commit`、`DEBUG`、`DIRTY`、`UNIDENTIFIED`、`CITY` 和
`BATTLE-C0` 必须按 README 的身份规则解释。自动输入和截图不能替代真实
鼠标体验。

## 文档与恢复

活跃文档只有：

- `README.md`
- `CURRENT_STATE.md`
- `docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md`
- `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md`
- `docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md`
- `docs/reports/TXWZS_V5_G3_REFRESHED_FULL_REGRESSION.md`
- `docs/reports/TXWZS_POST_G2_DOCUMENTATION_CONVERGENCE.md`
- `CHANGELOG.md`
- `docs/MIGRATION_HANDOFF.md`
- `AGENTS.md`

被删除的历史 Markdown 仍可从 `af24416` 或更早 Git 历史恢复。没有创建
`docs/archive`，也没有重写 Git 历史。

## 下一步与禁止项

R3B is the current accepted successor slice. The profile implementation,
headless regression, native dual-city flow, and responsive window evidence are
captured; its local commits are the only remaining repository state transition
for this turn. After R3B closes, G4 still requires a separate authorization.

已完成的最近两个已授权范围：

```text
TXWZS2_R2C-02_FIRST_WAR_RUNTIME_OPERATION_LIFECYCLE
TXWZS2_V5_G3_REFRESHED_FULL_REGRESSION_AND_TRACEABILITY_ACCEPTANCE
```

```text
P0_02_DISPOSITION=ABSORBED_AND_CLOSED_BY_R2C_01_V4
R2C02_SEQUENCE=PRE_G3_CORRECTIVE_SLICE
```

下一步只能是单独授权的 V5-G4 real-window gate。R2C-03 不自动成为下一步；永久
occupation 留在 V9。persistent external theater 与 mid-operation restart 留在
V6，本轮不声称已完成它们。

当前禁止：

- 进入 G4、G5 或 G6，除非分别获得授权；
- 开始 R2C-03 永久占领或重开 P0-02；
- 将 `riverbend_city` 完整局部状态写入 V5，或未经裁决升级 V6；
- 扩展驻军、战役、占领、道路交通、补给、UI、场景或资产；
- stage S1A.2；
- force push、批量推送其他 refs、部署；
- 清理或迁移存档；
- 把测试通过扩写为用户体验或发布结论。

## R2A road-lot-entrance semantic closure

R2A is implemented on the active product-successor branch from
`86e25a47d14a2c5041518d2e67a06268eef25503`. The regular-city foundation now
owns the formal road/reserved/wall/gate cell projection used by both graybox
rendering and construction validation. `CityGridRules` is the shared entrance
adapter for the existing `road_anchor_offsets` definitions and all four
orientations.

The authority remains `ConstructionController` plus the existing V5 snapshot
and save-store path. No operational flag, writer, autoload, schema version,
scene, resource cost, or road-construction tool was added. Legal disconnected
lots remain buildable but amber/disabled after completion until their derived
entrance contacts a connected formal road; protected cells and existing
buildings fail with concrete reasons.

Verification for this slice: the focused R2A road/lot/entrance runner passes
16/16; all 40 discovered smoke runners (the existing 39 plus the focused
runner) pass with 0 failures; Godot 4.5.1 editor parse/import and the formal
blank_map, Blackstone, and C0 headless smokes exit 0. Native 1440x900 evidence
also covers road rejection, amber disconnected placement, west-facing green
placement, native confirmation, construction, completion, and connected detail.
Versioned save/load re-derivation remains covered by the focused headless test;
the current shell exposes no user-facing save button, so no claim is made that
the visual shell itself provides a save action.

R2B player road construction, road removal, traffic/pathfinding, organic garden
city, final art, G4, push, and deployment remain not started.

## M0 R0A building-road and construction UI repair

R0A is an isolated engineering pass pending Founder live smoke. Root cause was
`BOTH`: four Blackstone lower-row fixed buildings logically occupied formal-road
row 13, and graybox shadows also extended beyond their footprints. The authored
row now ends before the road; visual shadows remain inside occupancy.

All new building/road placement, move, rotation, default-map scan, and legacy
diagnostics share one structured legality contract. Schema 4 is unchanged;
legacy overlaps are preserved and reported, never auto-moved or deleted. The
lumber-camp panel exposes one primary state with road, progress, material, ETA,
priority, and output feedback. Full regression is 46/46; ten static images and
one 17.01-second continuous Godot recording are in `docs/m0/evidence/r0a/`.

Founder live smoke remains pending. Do not push, merge, deploy, or start new
gameplay from this result.

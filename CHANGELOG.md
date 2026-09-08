# Changelog

## M1A.1 normal entry authority and cold-restore UI repair

- Allowed the current mainline to reserve any real non-empty dispatchable
  garrison force during preparation, warning, pending, or post-retreat retry.
- Added explicit force-breakdown diagnostics and a transient empty-force
  failure message; clarified the displayed command cap is not an entry minimum.
- Replaced the variable build-slot stack with anchored VBox content and added
  restore-driven layout refresh plus three-resolution geometry/input tests.

本文件只保留迁移时需要的高层里程碑。细节以 Git 历史、主控工作簿和当前
验收报告为准。

## Unreleased

### FIELD_TACTICS_R2 playable-loop candidate

- Added a formal two-route playthrough regression from the default 80-food
  city state. The main-road route resolves finite patrol losses and both city
  captures; the engineering route covers scouting, a real engineer loss and
  replacement, bridge traversal, guarded construction, one-use ambush, road
  damage, camp transfer, repair, original-order recovery, and both captures.
- Made a patrol kill interrupt a linked project during engineer travel as well
  as active construction, preserving the same project for formal reassignment.
- Projected construction progress, visible/historical patrol markers, exposure,
  and last engagement on the outer-city map without exposing unobserved patrols.
- Strengthened the engineering route with strict combined V5 restoration before
  repair, then continued through victory. Updated the legacy Macro March disk
  worker to use the unified scheduler and emit child diagnostics on failure.
- Updated the V5 Army regression for current schema 6 and retained its explicit
  legacy non-macro single-active policy check.
- Added window-specific PNG and MOV evidence under the R2 milestone. This is
  automated engineering evidence, not normal human input or player acceptance.

### FIELD_TACTICS_R2 patrol, guard, ambush, and casualty checkpoint

- Advanced patrols on resolved runtime-road geometry and compared swept patrol
  and army movement traces, preventing large-step pass-through misses.
- Settled one finite patrol record across all contacting armies and wrote exact
  losses to their stable formation identities through `ArmyRegistry`, while
  unrelated siege state continued independently.
- Added local specialist guard, one-use forest ambush and exposure state, plus
  nearby engineered-road damage without making main roads destructible.
- Persisted patrol strength, resolved participants, ambush consumption,
  exposure, road damage, and exact army casualties through formal V5 restore.
- Verified Field R2 65 assertions, audited field persistence, Macro March 27,
  War Loop R1 16, formal scene 10, and arrival persistence 3. Complete routes,
  normal-input media, balance review, and player acceptance remain open.

### FIELD_TACTICS_R2 temporary-route rebreak and clock checkpoint

- Rechecked blocked-transfer physical segments before movement, persisted
  explicit reblocked camp/return phases, and resumed the same temporary task
  after repair without replacing the original order or food transaction.
- Persisted clipped segment geometry so temporary replanning, reverse travel,
  rendering, validation, and cold recovery share one physical route.
- Carried unused milliseconds across camp arrival and return-to-order
  boundaries; formal `_process` checks now match at 30 FPS, 60 FPS, and
  irregular frame partitions.
- Hardened the disk runner to require per-worker success markers in addition to
  exit code zero. This exposed and fixed previously masked worker parse errors,
  and an N/O/P chain now cold-restores temporary-route rebreak and recovery.
- Verified Field R2 58 assertions, audited field persistence, Macro March 27,
  War Loop R1 16, editor import, and `git diff --check`. Encounters and the two
  complete routes remain follow-up work, so this is not player acceptance.

### FIELD_TACTICS_R2 safe-camp transfer checkpoint

- Corrected the follow-up state contract: moving blocked transfers no longer
  violate the temporary-station validation, schema-5 migration retains macro
  order history, and repaired original roads do not interrupt an in-progress
  camp transfer.
- Reused accumulated millisecond remainders for temporary transfer movement
  and extended isolated disk recovery through a fourth process that restores
  `TO_RESUME`, completes the return, and advances the original order.
- Made the transfer start and return-completion writes atomic with their
  validation contract: no premature station field during `TO_CAMP`, and no
  invalid `BLOCKED + NONE` snapshot before original-task resumption.

- Added schema-6 temporary execution records beside immutable macro orders.
  A future damaged road now sends an army from its exact ordered-road position
  along a clipped physical connector to a deterministic reachable garrison or
  completed camp, without reissuing the order or charging departure food.
- Added actual temporary movement, camp waiting, repair-triggered reverse
  return to the frozen original position, and original-task resumption. The
  Macro March marker, hit testing and status text use that temporary path.
- Added a formal Controller regression for a curved first segment and damaged
  constructed second segment, plus an isolated three-process disk chain for
  transfer-in-progress, waiting, and repair-return-in-progress recovery.
- Verified with Godot 4.5.1: Field R2 55 assertions, field persistence PASS,
  Macro March R0 27 assertions, War Loop R1 16 assertions, editor import,
  `blank_map` and Blackstone startup, and `git diff --check`. This is an
  engineering checkpoint, not normal-input media, player acceptance, or a
  completed R2 tactical loop.

### FIELD_TACTICS_R2 formal bridge-return and restore canonicalization repair

- Added the interrupted-project selector to the Macro March scene tree and
  retained its option nodes when the projection is unchanged. New construction,
  repair, and resume of the selected interrupted project are now separate
  actions; the seven-action rail remains within the 648px layout contract.
- Canonicalized legacy specialist-route migration during V5 structural
  validation with the same `MacroMarchTheater` Resource facts used by formal
  restore, preserving strict postcondition comparison and rollback instead of
  weakening either check.
- Made bridge-shore validation symmetric by sampling land-to-bridge regardless
  of travel direction. The formal Controller regression now covers an
  automatically generated bridge forward, reverse, damaged unavailability,
  and legacy missing-path V5 recovery.
- Focused Godot 4.5.1 results: Field R2 52 assertions and Macro March 27
  assertions. This is not a full R2 playthrough, normal-input evidence, or
  player acceptance.

### FIELD_TACTICS_R2 formal bridge-use and deferred-recovery checkpoint

- Added a formal city/Controller regression that completes a player-shaped
  bridge project and sends a second expert over the actual generated bridge.
- Restricted specialist water access to open bridge geometry and shore
  connections, while retaining physical-distance movement time.
- Deferred old specialist-route migration until theatre Resource facts are
  installed after V5/WarLoop restore; missing paths no longer replan before
  water and bridge state is available.
- Added a selectable interrupted-project list and retry across eligible
  engineers, so an unreachable first candidate does not block another project.
- Focused results: Field 50 assertions, Macro March 27, field persistence
  PASS, and R1 war 16 assertions. This is not a full R2 playthrough.

### FIELD_TACTICS_R2 formal bridge-planning checkpoint

- Kept the selected land-road material through the formal Macro March,
  Controller, and Field construction chain. Cross-water normal construction
  now yields `NORMAL → BRIDGE → NORMAL` physical segments instead of
  converting the whole project to bridge material.
- Unified construction water detection with unit-coordinate sampling and kept
  the existing one-time bridge-project food transaction.
- Made specialist bridge traversal follow the open bridge polyline (including
  bends) and choose repair endpoints using the same specialist path and actual
  distance rather than the army road graph or minimum-duration tie.
- Added formal Controller, bent-bridge, roadless-land repair, interrupted
  project reassignment, and old specialist-route migration regressions.
  Godot 4.5.1 focused results: Field 49 assertions, Macro March 27,
  three-process field persistence PASS, and R1 war 16 assertions. This is not
  normal-input evidence or a completed R2 player route.
- Preserved interrupted project identity, completed segments, and reserved
  camp IDs when a replacement engineer resumes work through the existing
  Controller persistence transaction. Old in-flight specialist saves without
  a route now replan from their saved position or enter an explicit blocked
  state rather than moving through water.

### FIELD_TACTICS_R2 on-site construction checkpoint

- Made the existing engineer specialist travel to a construction start before
  work begins, persist its real work position over land segments, and remain
  on the reachable bank while a bridge is unfinished.
- Kept newly completed camp construction at the actual road endpoint until
  the runtime camp exists, preventing a transient non-persistent coordinate.
- Separated construction, repair, and macro-march disk suites into isolated
  save roots; the repair chain now explicitly persists a real return journey
  and repair-arrival remainder.
- Focused Field R2 smoke passes 42 assertions and all three cross-process
  field chains pass. This is not a complete R2 tactical loop or normal-input
  player evidence.
- Persisted the pre-block task phase for macro orders. A damaged retreat now
  resumes as `RETREATING`; pre-schema-5 blocked records migrate to the prior
  conservative `MARCHING` behavior because that fact was not stored.
- Repair confirmation now chooses an actually reachable road endpoint through
  the open graph and refuses to create a project when neither endpoint can be
  reached, instead of targeting the far end of a damaged bridge by default.
- Unified specialist movement around persisted land-path points, duration and
  position interpolation. Generated construction junctions now resolve their
  physical coordinates; invalid point IDs are rejected rather than becoming
  world-origin movement targets. Field R2 smoke passes 44 assertions.
- Passed theatre bounds into field authority and tightened water intersection
  checks to unit-coordinate resolution for specialist path planning.

### FIELD_TACTICS_R2 map and command UI checkpoint

- Put the return action in the same fixed command stack as the engineer action
  and made formation controls incremental, eliminating the 648px overlap and
  cross-frame button replacement risks. Added overlap and stable-node tests;
  Macro March smoke now has 27 automated assertions.
- Moved tactical world bounds and forest regions from map presentation into the
  theatre Resource, preserving existing road coordinates and save semantics.
- Added deterministic runtime-path planning over connected open roads. The
  path validator and duration calculation reuse its ordered physical segments;
  a multi-road path receives the minimum duration only once.
- Made planning honor the player's drawn path across alternative connected
  routes, validate every directed segment join, and remove the map's duplicate
  duration calculation.
- Persisted the authority-validated physical road sequence on new macro orders
  and migrate existing single-road and composite-handle records into that
  field at snapshot validation. The shared scheduler now ignores damage behind a
  marching army and blocks only its current or forward road segment. Focused
  field smoke passes 38 assertions; Macro March smoke passes 27.
- Added a three-process disk regression for a multi-road macro order: issue
  and advance in process G, restore and cross the remaining route in H, then
  cold-restore the stationed result in I without a duplicate food transaction.
- Split cross-water engineering lines into persisted road-bridge-road segment
  plans. Segments open in construction order, so an unfinished bridge or final
  road remains unavailable to runtime route planning.
- Fixed retreat orders to reverse and retain the original physical road
  sequence instead of inventing a non-existent `.return` route ID. Added a
  formal siege-retreat return regression and made each newly opened construction
  segment an immediate persistence-checkpoint event.
- Replaced bounded simple-path enumeration with weighted graph search over
  open physical roads. Draw proximity biases the selected legal route without
  limiting commands to twelve road segments; focused R2 smoke now has 41
  automated assertions.

- Replaced fixed 1000×650 screen compression with a shared tactical-map camera:
  cursor-anchored wheel zoom, middle-drag pan, minimap recentering and
  cross-edge draft continuity all preserve world-coordinate command semantics.
- Rebuilt the right command column as a scrollable formation list plus a
  bottom-anchored action zone. At 1152, 1280 and 1920 widths, visible controls
  remain inside the game window and do not overlap the map.
- Added greybox terrain/shore, road-kind, bridge, camp, flag-army and specialist
  readability markers, alongside controller-owned selected-force and food
  preview copy. Macro March smoke now has 26 automated assertions.
- This is not normal-input media, a complete R2 playable loop, Founder
  acceptance, deployment or a balance sign-off.

### FIELD_TACTICS_R2 engineering checkpoint

- Reserved dynamic camp IDs at engineering confirmation, added repeat-click
  cycling for overlapping army markers, and made specialist replacement UI
  consult living specialists instead of historical records.
- Replaced instantaneous remote road repair with persisted engineer travel and
  timed repair work.  Field-road validation now accepts a correctly reversed
  polyline for return travel.  Added automated damaged-road map hit and repair
  action coverage. Focused field smoke is 27 assertions, Macro March smoke is
 18, and the three-process field persistence runner passes.
- This remains an engineering checkpoint; it does not claim bridge terrain,
  patrol/ambush play, route-block auto-resume, normal-input media, or Founder
  acceptance.

- Fixed repair travel to retain the remainder of an arrival frame for repair
  work; one-shot and split world advances now produce the same saved state.
- Added Resource-owned water-region bridge classification, bridge preview and
  a focused map-draft regression. Field smoke is 29 assertions, Macro March
  smoke is 19, and the persistence runner now includes three repair recovery
  processes.
- Connected actual damaged field roads to durable macro `BLOCKED` orders and
  automatic repair-driven resume. The focused controller regression verifies
  identity retention and no duplicate march-food charge.
- Replaced the static patrol position with a persisted wait-and-route movement
  record and retained a non-tracking last-observed coordinate after visibility
  ends. This is not yet an army encounter or casualty implementation.
- Resolved map siege details by selected `army_id` instead of the compatibility
  first-siege projection; Macro March smoke now has 20 assertions.
- Fixed patrol arrival to preserve the remainder of a world step across its
  next wait state. Field R2 smoke now has 32 assertions including patrol
  wait/move/contact partition coverage.

- Added a V5-persistent field-state record for runtime roads, camps,
  scouts/engineers, engineering projects, finite patrol intelligence, fog
  knowledge, road damage, and repair. R1 WarLoop snapshots normalize through
  the nested migration before controller postcondition checks.
- Allowed two independently formed macro armies, surfaced their read model to
  the outer-city screen, advanced each marching army, and rejected duplicate
  formation ownership in non-closed macro snapshots.
- Added `run_field_tactics_r2_smoke.gd` (19 assertions), including a
  city-keyed parallel-siege domain record/restore probe, and retained Macro
  March, War Loop, and V5 three-process persistence regression coverage.
- This checkpoint does not claim simultaneous siege/encounter resolution,
  patrol combat, full specialist drag UI, normal-input media, Founder
  acceptance, deployment, or release.

- Continued the specialist path from the formal outer-city adapter: scout and
  engineer dispatch buttons, a side-road/camp action, timed specialist arrival,
  patrol contact loss, and interrupted engineering state are now represented.
- Added a dedicated three-process field-tactics disk runner covering
  construction-in-progress → restored completion → cold-restored road/camp.
- Connected completed runtime roads and camps to normal macro-route validation
  and march-duration calculation; the map engineering action now starts from
  a selected idle engineer's drawn route rather than the old fixed side-road.
- Added R2 smoke coverage for completed dynamic-road command validation and a
  newly placed runtime camp endpoint.
- Bound map army selection, follow-up drafting and retreat to the selected
  army rather than the legacy first-army projection.
- Publish critical field completion and engagement events through the existing
  V5 checkpoint without requiring a concurrent siege tick.
- Added persisted interpolated specialist coordinates and distance-limited
  visibility; fixed refreshes incorrectly turning never-seen patrols into
  historical intel, with R2 regression coverage.
- Normalized runtime-road facts into explicit map drafts and made engineering
  drag release cancellable; only confirmation commits construction resources.
- Added automated formal map draft/confirmation regression coverage.

### WAR_LOOP_BATCH_R1 siege, occupation, and recovery candidate

- Kept the authoritative controller clock running while the outer-city view is
  open, excluded CLOSED historical armies from commandable-march lookup, and
  retained completed stationed orders in macro history.
- Replaced per-frame integer rounding with carried sub-millisecond input at
  both controller and macro-view time boundaries; pause discards elapsed input
  and speed applies exactly once.
- Made enemy arrival retain its synchronous checkpoint obligation after siege
  or surrender replaces the movement result, with V5 final-reread recovery.
- Added formal-entry/frame-rate/closed-army focused coverage (10 assertions)
  and A/B/C immediate-arrival persistence coverage (3 assertions).

- Corrected the reported timing, formation writeback, one-soldier retreat,
  simultaneous annihilation, failed-siege gate persistence, and malformed
  nested war-snapshot boundaries. Retreat now creates a new return order while
  preserving the original order record; zero survivors close the army.
- Promoted Silverford to a second required enemy city and added the direct
  Redcliff-to-Silverford road, so the clear rule is exercised as a real
  two-city occupation chain rather than a hypothetical data capability.
- Added 15 focused deterministic War Loop assertions and a separate three
  process active-siege V5 disk recovery runner (3 assertions). These remain
  engineering/cold-recovery evidence, not real-input media or acceptance.

- Added Redcliff and Silverford enemy-city data to the replaceable outer-city
  theatre. Arrival uses a configurable surrender check, then deterministic
  gate-first and guard-resolution combat when surrender is refused.
- Extended `ArmyRegistry` to schema 3 and `V5CampaignSnapshot` to schema 7.
  Siege, retreat, occupation control, exact combat tick facts, casualties, and
  resolution idempotence use the existing controller/save boundary; V6 saves
  migrate without creating a new macro army or order.
- Added a focused WAR_LOOP_R1 smoke for surrender, attack, cold restore,
  occupation, the required-city clear rule, casualty persistence, and retreat.
  This is a local engineering candidate only: no verified real-input media,
  Founder acceptance, merge, push, or deployment is claimed.

### Macro March R0 outer-city greybox

- Added a formal `外城军令` city entry and one small Blackstone/Northwatch/
  Reedbank theatre with player-drawn road selection, draft cancellation,
  confirmation, continuous movement, station-to-station follow-up orders, and
  a blockable branch-road recovery scenario.
- Extended `ArmyRegistry` to schema 2 with validated macro order facts and
  schema-1 normalization. Macro departures preserve exact formation identities
  and use a full roster/registry rollback snapshot around the existing food and
  V5 runtime persistence boundary.
- Added focused macro movement and isolated three-process disk persistence
  smokes. The legacy Blackstone MVP scene is no longer wired to the formal
  entry. Real system-input screenshots and video remain unprovided and are not
  substituted with scripted test footage.

### R1E reconciliation and player-facing roster labels

- Removed raw internal formation identifiers from expedition preparation cards.
- Added a focused regression assertion for player-readable roster labels.
- Recorded the current R1E product-rule reconciliation, implementation limits,
  and native single-city siege evidence.
- Recorded that the ordinary 14-person Day 1 assault reached the real defeat
  path; this is not a siege-victory or product-acceptance claim.

### M1B standalone playable shell R0

- Added a minimal title entry for 天下无战事 / 黑石城 and made it the formal
  main scene; it changes once to the existing city scene without taking over
  V5 persistence or city ownership.
- Added keyboard focus/Esc behavior and three-resolution title geometry tests,
  plus a minimal unsigned Universal macOS debug preset.
- The source and full regression pass, but standalone export remains blocked by
  a missing exact Godot 4.5.1 macOS export template. No `.app`, release claim,
  push, merge, or deployment is recorded.

### M1A.1-R2 V5 runtime persistence lifecycle

- Wired normal GUI city startup, dirty state commits, whole-generation fallback,
  and normal window-close flush to the existing V5 canonical snapshot store.
- Added a three-process normal-scene lifecycle runner covering initial publish,
  real current-mainline victory/return restoration, and corrupt-latest fallback.
- Kept schema 5, V1 migration, `ConstructionController` ownership, battle
  transactions, resources, construction, roads, and UI behavior unchanged.
- Kept headless scene runners off the default player store unless they pass an
  explicit isolated save directory. Native L3 video evidence remains blocked by
  game-window focus, not replaced by synthetic evidence.

### M1A current-mainline battle settlement return loop

- Added the bounded current-mainline action to the existing deadline/pressure
  top-bar region, reusing the formal C0 city scene rather than a fixture or a
  second battle route.
- Moved successful formal-mainline victory clearing into the existing
  authorized result settlement, so pressure stops at one confirm; retreat and
  defeat retain unresolved pressure, and retreat can retry without a time or
  deadline reset.
- Added focused entry/preview/idempotency/return/cold-save coverage plus native
  1152x648, 1280x720, and 1440x900 evidence and a 1152x648 H.264/yuv420p
  journey MP4. No schema, construction, road, placement, resource-owner, push,
  merge, or deployment change was made.

### M0 R0C.1 top-bar responsive closure

- Replaced mixed fixed-anchor top-bar positioning with five ordered responsive
  regions: resources, city, date/settlement, deadline/pressure, and speed/pause.
- Kept time and settlement within a two-row budget, preserving the next-stage
  line while clipping only trailing settlement detail at the smallest target.
- Added a 57-assertion three-resolution region-boundary runner and three native
  Godot screenshots of the longest settlement/deadline/pressure state.
- Re-ran R0C focused input/persistence smoke and all 49 dynamic smoke runners;
  no construction, resource, placement, road, save, push, merge, or deployment
  behavior changed.

### M0 R0C single build slot and ready placement

- Replaced new-building map foundations with one current-city off-map build
  slot; zero resources register a 0% waiting plan and partial resources advance
  only alongside exact incremental payment.
- Added one fully paid ready token at 100%; actual input can rotate and place it
  once as a completed building with no second charge, while invalid placement
  retains the token and successful placement exits.
- Preserved direct player-road drag construction as an independent flow and
  removed construction priority from the new building-slot UI.
- Upgraded campaign persistence to schema 5 with one `build_slot`; schema 4
  foundations migrate non-destructively and lock only the new slot.
- Added exact refunds, pressure-aware ETA/progress, responsive slot UI, focused
  state/input/persistence tests, and updated conflicting R0B tests as
  `SUPERSEDED_BY_R0C`.
- Passed 48/48 dynamic runners and delivered ten native screenshots plus an
  uncut 1152x648 H.264/yuv420p MP4. Founder live smoke remains pending; no push,
  merge, deploy, or new gameplay was performed.

### M0 R0B direct click and explicit failure feedback

- Replaced the building-only right-rail confirmation step with one revalidated
  map left click; success creates one timed order and exits placement.
- Removed `ConfirmPlacementButton`, retained the existing road-only confirmation
  flow, and preserved `R`, right-click, and `Esc` behavior.
- Added structured exact player copy for road/building overlap, bounds, map
  targets, resource deltas, state changes, and unknown commit failures.
- Added amber exact-shortage guidance without changing incremental construction
  payment, missing-material resume, pause behavior, balance, or schema 4.
- Added a 26-assertion actual-input runner, updated superseded tests, and passed
  all 47 dynamic smoke runners plus editor and formal scene gates.
- Added six inspected PNGs and an inspected uncut 1152x648 MP4 verified as
  MPEG-4/H.264/4:2:0. Founder live smoke remains pending; no push, merge, deploy,
  or new gameplay was performed.

### M0 R0A building-road and construction UI repair

- Fixed both logical and visual road overlap: shifted four Blackstone lower-row
  fixed anchors off formal-road row 13 and constrained graybox shadows to the
  authoritative footprint.
- Unified building placement, player-road placement, move, rotation, map scan,
  and legacy-overlap diagnostics behind one structured spatial legality query.
- Added atomic move/rotation revalidation and non-destructive `LEGACY_OVERLAP`
  reporting without changing campaign snapshot schema 4.
- Reworked lumber-camp feedback into one primary state with progress, paid and
  missing materials, honest ETA, road status, construction-only priority, and
  actual versus base pressure output.
- Added focused R0A tests, updated superseded UI assertions, and passed all
  46 dynamically discovered smoke runners plus editor import and three formal
  scene smokes.
- Added ten inspected native PNGs and one unspliced 17.01-second Godot recording.
  Founder live smoke remains pending; no push, merge, deploy, or new gameplay.

### M0 time, construction, and level pressure

- Reused the authoritative strategic clock for pause and 1x/2x/4x, adding
  deterministic 1000 ms construction ticks, incremental `NationState` payment,
  missing-resource pause/resume, and three-level task priority.
- Added a persistent current-mainline deadline with five pressure stages,
  security mitigation, committed permanent losses, and essential anti-softlock
  floors without adding another settlement or save owner.
- Upgraded campaign snapshots to schema 4 with exact M0 state, V2/V3 migration,
  and duplicate-payment prevention for legacy construction.
- Reused the compact top HUD and building detail panel for deadline, pressure,
  security, progress/payment, missing material, and priority feedback.
- Added eight-scenario M0 coverage and updated superseded freeze/prepayment
  contracts; the complete 45-runner regression and native target-resolution
  evidence pass. No video, push, merge, deploy, final art, or broader MVP freeze
  is claimed.

### R3B dual-city layout profiles

- Added deterministic `REGULAR_IMPERIAL` and `ORGANIC_GARDEN` profiles keyed by
  the stable `blackstone_city` and `riverbend_city` IDs.
- Wired the formal world-map Riverbend entry to the existing
  `ConstructionController`, preserving one building/road/resource authority
  while isolating runtime placement and player-road state per city in memory.
- Added an authored orthogonal garden graybox with offset/T roads, unequal
  wards, three reserves, an off-centre civic court, and the same four rotated
  `CityGateComponentR1` instances. The minimap reads the active profile's
  projected roads and reserves.
- Kept V5 and early single-city save exports fail-closed for Riverbend; no save
  schema, autoload, resource, asset, or final-art change was introduced.
- Added focused resolver, geometry, dual-city state, formal navigation, and
  non-regression coverage. Native runtime evidence is external to Git and was
  captured at 1280x720, 1440x900, and an actual 1920x960 macOS window for the
  requested 1920x1080 launch. Final art, curved roads, traffic, full-map
  rotation, G4, push, and deployment remain out of scope.

### R3A graybox building presence

- Added the shared `GrayboxBuildingVisual` component for footprint-aligned
  foundations, height/roof/side/shadow volume, entrance direction, selection,
  connection state, and construction-stage presentation.
- Routed fixed and runtime buildings through the component without adding a
  writer, autoload, save field, schema version, asset, or second state tree.
- Added focused R3A coverage for N/E/S/W geometry, lifecycle stages, pause
  stability, fallback rendering, distinct real building silhouettes,
  connected/disconnected entrance states, no state mutation, and V5
  orientation restore. The complete 42-runner smoke suite passes 42/42.
- Native evidence is external to Git. The 1920×1080 request rendered as
  1920×960 on macOS; strict 1080-height pass is not claimed. Organic-garden
  city, final art, G4, push, and deployment remain out of scope.

### R2B player road construction

- Added a right-rail road tool with native horizontal/vertical drag previews,
  explicit connected/isolated/invalid states, atomic confirmation, and
  Escape/right-click cancellation.
- Player roads are written through the existing `ConstructionController` and
  `NationState` transaction, projected with the formal road layout, and
  persisted as ordinary V5 placement records without a schema bump.
- Shared road topology now renders straight, corner, T, cross, and endpoint
  graybox paths; connecting a completed required-road building immediately
  derives its operational state and starts production on the next day boundary.
- Added the focused R2B smoke for drag validation, atomic writes, topology,
  activation, production, persistence, and legacy snapshot compatibility.
- Road deletion/upgrades, traffic/pathfinding, bridges/slopes, curved roads,
  organic city layouts, final art, G4, push, and deployment remain out of scope.

### R2A road-lot-entrance semantic closure

- Unified the regular-city graybox road rectangles, reserved court, wall ring,
  and gate slots with the construction controller's spatial queries.
- Added deterministic `road_anchor_offsets` entrance adaptation through
  `CityGridRules`, so footprint rotation, entrance facing, and road contact
  remain one derived model for preview, placement, and operational status.
- Kept disconnected legal lots buildable with an amber warning, rejected
  ordinary buildings on roads/protected cells, and added a lightweight
  placement/selected entrance marker without changing save schema or adding a
  second writer.
- Added the focused R2A smoke and retained the existing 39-runner regression
  contract; player road construction, traffic, organic city layouts, final art,
  G4, push, and deployment remain out of scope.

### R1C native mouse construction closure

- Fixed right-rail pointer routing so hovering or clicking the native confirm
  button no longer invalidates the map placement ghost as `被界面遮挡`.
- Kept construction confirmation on the existing authoritative writer; native
  1440×900 evidence records one pressed event, exact wood cost, placement exit,
  construction, completion, and selectable building details.
- Added a focused regression assertion for pointer motion over the rail. No
  save schema, economy values, formal art, Canonical, RG-O1 quarantine, G4,
  push, or deployment changed.

### Regular City Spatial Foundation R1

- Replaced the flat default inner-city backdrop with a regular axial/ward
  graybox spatial layer, a compact civic court, passive ward volumes, and
  four rotations of one city-gate component.
- Moved the formal construction flow into a responsive right rail with a
  minimap, real catalog, placement controls, and reused building detail.
- Added authority-backed building orientation and legacy V5 snapshot fallback
  to north; no second building/resource owner or upgrade writer was added.
- Final building art, organic garden city, camera view rotation, road traffic,
  G4–G6, R2C-03, V6, push, and deployment remain out of scope.

### Product successor UI-R0

- Established the isolated `codex/product-successor-inner-city-r0` branch and
  rebuilt the `blank_map` inner-city shell with a native Godot theme,
  responsive operating rail, shared-resource summary, build catalog, and
  building context panel.
- The upgrade affordance is an explicit no-writer gate: confirm/cancel returns
  to the existing record and does not mutate buildings, resources, or saves.
- Added a focused UI-R0 smoke and updated existing viewport/selection tests to
  assert the new visible-by-default city rail and safe-area interaction.
- No Canonical, legacy, RG-O1 v1, project settings, schema, or remote state was
  modified; G4–G6, R2C-03, and V6 remain not started.

### V5-G3 — refreshed full regression and traceability

- `712dcbd8e092ff844c4274a2f3a3c260d29998e7` 在仓库外隔离副本和隔离
  `user://` 下通过 refreshed G3：37/37 动态发现 runner、1819 条 `PASS:`、
  P0-01 10/10、R2C-02 focused 20/20、V5 persistence 51/51，以及 editor 与
  blank_map/Blackstone/C0 headless smoke。
- G3 接受 V5-P4-T005 与 V5-P7-T001–T003 的回归/追溯工作；不新增游戏功能，
  不修改 V5 schema、storage version、snapshot topology、场景、UI、资源或资产。
- G4 实际窗口、G5 独立复查、G6 用户试玩/冻结、R2C-03 和 V6 均未启动。

### R2C-02 — First War runtime lifecycle

- 复用既有 `ArmyRegistry`、`ConstructionController` 与绑定的
  `CombatTransactionCoordinator` 完成固定无头 First War 纵向闭环。
- First War army terminal settlement 的幸存者统一进入既有返乡 phase，只回补
  `blackstone_city`；不在 `riverbend_city` 建立驻扎、归属、派系或局部状态写入。
- 新增 focused lifecycle smoke，并更新 V5 army encounter/vertical-loop 回归以
  验证返乡守恒；未修改 V5 schema、codec、store、场景、UI、资源或项目设置。
- `P0_02` 已由 R2C-01 v4 吸收并关闭；下一步仍需单独授权 refreshed V5-G3。

### Documentation

- 将 76 份、14,940 行、706,926 字节的 Markdown 基线收敛为 9 份活跃文档。
- 新增统一 README、架构合同、迁移交接和本 Changelog。
- 将 372 行且含陈旧 pending 叙述的 `CURRENT_STATE.md` 改为当前 Gate 快照。
- 将多个 V5-G2 candidate、repair 和 review 稿合并为单一最终验收报告。
- 删除 Git 可恢复的旧研究稿、handoff、重复报告、旧测试统计和本机绝对路径。
- 主控 XLSX 与三份受影响 CSV 只把 deleted Markdown 和 `/tmp` 证据改为
  稳定活文档或明确的历史证据标记；Gate、任务状态、公式和结构不变。
- 未修改代码、测试语义、场景或资源。

## 2026-07-31 — V5-G2 accepted

- 原 candidate `cd7be2b` 因 checksum-valid snapshot 可回退 sequence 并复用
  stable ID，被独立复查拒绝。
- 第一轮 repair `e2c1096` 阻断 sequence 小于等于既有最大 ID 的恢复，但仍
  留有 type coercion、精确上限/successor、Army pre-write exhaustion 和
  合法 V1 空队列历史迁移缺口。
- 第二轮四文件 repair `fab962c` 关闭上述边界并增加永久对抗测试；修复者未
  自签接受。
- Fresh independent verdict：`V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED`。
- Acceptance checkpoint：`af244167f7b0a31f3de2cc34673faa953113b96b`。
- 绑定链：
  `cd7be2b → e2c1096 → 5d659243 → fab962c → 4d0fbfc → af24416`。
- 精确 16 项 G2 runtime task 和 V5-G2 标为 `VERIFIED`。
- focused `6/6 · 185`、tracked `33/33 · 1739`、
  all-present `35/35 · 1871 / 1905 PASS`。
- G3–G6、P6、P7、V6 保持 `NOT_STARTED`。

## 2026-07-30 — V5-G0/G1 accepted

- V5-G0 独立接受单兵种定义、私有 `GarrisonState`、驻军/可派守恒和容量
  阻断。
- V5-G1 独立接受 TrainingQueue、时间矩阵、ArmyRegistry、遭遇事实、V5
  schema/迁移/回滚和 S1A.2 条件复用合同。
- S1A.2 八文件保持 untracked、unstaged，未成为 V5 writer/schema。

## 2026-07-30 — V4 frozen

- V4 派遣主链路完成独立复查、正式窗口证据和里程碑冻结。
- C0 城市时间、terminal authority、coordinator ownership、幂等重放和
  冲突拒绝进入冻结基线。
- V4 checkpoint：`5357c28`。

## 2026-07-25 至 2026-07-27 — P0/P1/C0 baseline

- 建立 Camera2D 导航、固定 UI、建造、选择、建筑生命周期和统一交互。
- 建立第一张地图的道路、生产、日期、威胁、训练、科技和军令台技术闭环。
- 建立 C0 确定性战斗灰盒和城市写回事务。
- S1A.1 内存快照 roundtrip 获得接受；S1A.2 留在保护边界外。
## 2026-09-07 — R2 shared-clock and parallel-siege repair

- Made ConstructionController the sole advancing world-clock owner; map views
  no longer tick armies and each order keeps its own fractional remainder.
- Added explicit city-keyed siege advance, retreat, occupation and failure
  settlement so concurrent battles do not consume one another.
- Removed normal-map static route-break controls, hid authoritative field
  state from macro UI projections, and reject dangling field persistence
  references before restore.
- This is an engineering repair, not a completed R2 playthrough or acceptance.

## 2026-09-07 — R2 map-state presentation

- Render all active armies, runtime roads, camps and living specialist roles
  from the safe field projection, with main/field/damaged road distinction.
- Removed player-facing timing formulas from the normal map panel.

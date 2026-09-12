# Product Successor Decisions

## Blackstone first-invasion ownership

- The first Blackstone invasion is authored in the playable theatre resource
  and persisted as one `FieldTacticsState` patrol record. R0 deliberately does
  not add a generic event bus or a UI-owned countdown.
- Warning knowledge and tactical intel remain distinct. The campaign can reveal
  a known source, target and broad approach before departure, while exact force
  strength still requires the existing visibility projection.
- Arrival transfers the same patrol identity and surviving count into the
  existing wartime-defense transaction. While handed off, field movement and
  field-facility effects skip that force; settlement resolves it once.
- External watchtowers, arrow towers and barricades share the existing durable
  field project/facility envelope for save compatibility, but carry an explicit
  `facility_kind`. C0 works stay separate `BattleSession` objects even when
  Chinese labels overlap.
- R0 barricades use a persisted one-time traversal delay rather than dynamic
  rerouting. This matches the current ordered-road patrol model and can be
  tuned or replaced later without changing facility identity or save ownership.

## Field Tactics R2 outer-city state

- `FieldTacticsState` is a serializable subrecord of `WarLoopState`, not a
  second scene timer, resource ledger, or save owner. `ConstructionController`
  remains the only route for food commits and runtime checkpoint publication.
- The R1 `active_siege` compatibility record remains intact while R2 work
  moves dynamic roads, camps, specialists, patrol knowledge, and project
  progress into the persistent field record. R1 war snapshots normalize before
  the controller's exact restore postcondition.
- Macro command concurrency is limited by available distinct formations, not
  a global “first active army” lookup. Closed history never occupies a formation;
  a current macro formation may belong to only one non-closed army snapshot.
- The player projection contains field construction and own specialists but
  only observed or last-known patrol intel. It must not render the authoritative
  patrol table directly.
- R2 initial food costs, construction durations, and durability are reversible
  greybox defaults, not user-approved final balance. Patrol combat, parallel
  siege completion, full drag-line specialist UI, and player media remain
  deliberately unaccepted follow-up work.
- Specialists consume shared world time before changing location. Patrol contact
	may remove a specialist only at the same recorded node and preserves the last
	observed report; a building project with a lost engineer remains interrupted.
- Completed field roads are authoritative macro-command routes, not display
	overlays. Their endpoint coordinates become runtime camp points and the same
	persisted route identity is validated before an army order can be issued.
	Unfinished and damaged routes remain non-commandable.
- Macro map interaction resolves a selected `army_id` from player-visible army
	markers. Route continuation and retreat use that identity rather than the
	legacy first-army read-model projection.
- Field project completion and encounters are persistence boundaries. They use
	the controller's existing checkpoint and rollback transaction rather than
	depending on unrelated siege activity.
- A Field watchtower is a completed engineering-camp attachment, not a city
	construction platform. `FieldTacticsState` persists its project and completed
	observer; `ConstructionController` owns its resource transaction, world time
	and V5 publication. A tower contributes only to the existing fog observer
	set after completion, and older snapshots conservatively restore no tower.
- Specialist movement and fog use persisted world coordinates. A historical
	intel record exists only after actual visibility, never as a side effect of
	reading the player projection.
- Map drafts are a presentation contract distinct from persisted road records.
	They normalize road identity and polyline before confirmation; engineering
	drafts have no resource side effect until the explicit confirm action.
- Camp IDs are reserved at engineering confirmation, not completion, so an
	in-progress project already owns its future runtime point and camp record.
	The reservation is kept inside `FieldTacticsState` and therefore the V5
	snapshot; no UI counter owns a strategic identity.
- Field-road repair is an explicit persisted project: an engineer first travels
	to the damaged endpoint, then repairs over shared world time.  The original
	road remains closed until the completion transaction, and runtime road
	validation accepts either direction only when the submitted polyline matches
	the corresponding direction.
- The theatre Resource owns the greybox water regions used for bridge
	classification. A crossing construction line becomes a bridge in the field
	authority even if a presentation caller requested a normal road; the map only
	previews that authoritative choice.
- World-step partitioning is a simulation invariant. If specialist travel
	ends during a step, any remaining milliseconds are consumed by its repair
	work in that same step; this prevents frame rate from changing completion.
- A damaged runtime road blocks an affected macro order through `ArmyRegistry`
	and preserves its original order identity. Repair completion is the only
	path that automatically resumes it; no new food transaction, route rewrite,
	or UI-owned recovery record is created.
- Patrols are finite persistent field participants with a route, wait and
	interpolated position. Historical intel stores the last observed coordinate;
	it must not derive a new location from the current patrol record after
	visibility has been lost. Army encounter and ambush resolution remain a
	separate unfinished authority extension.
- Patrol wait, route movement and arrival are one time-partition invariant:
	any remainder of a shared world step continues into the next patrol state
	instead of being discarded at arrival.
- Macro map camera state is presentation-only. Every map render, hit test and
	draft point uses the same reversible screen/world transform; camera position
	and zoom are not part of a command, field record or save migration.
- Command-cost copy uses a controller-owned immutable preview. The map may
	display its selected force, food shortfall and duration, but it never copies
	the food formula or reserves resources before the user confirms a command.
- Tactical world bounds and terrain regions are theatre Resource data. The
	map renders them but does not define tactical geography independently.
- A runtime path is an ordered traversal of physical roads, not a newly merged
	road record. Its handle encodes road identity and direction for validation;
	damage and repairs still belong to the physical road records.
- A normal macro command requires an explicit selected city formation or
	stationed army. Clicking a legal destination uses the authority's shortest
	completed path. Dragging from that subject may cross a displayed physical-road
	choice point; the latest crossed `road_id` is then a hard authority
	constraint, not a pointer-proximity score. If that road becomes unfinished or
	damaged, confirmation rejects without substituting another route or charging
	food. Engineering remains the separate free-polyline planning interaction.
- Macro drawing has a single UI-time hold gate: pressing for 0.5 seconds starts
	planning, while a pre-activation displacement above eight screen pixels
	cancels. It is independent of world pause and speed. Road identity can change
	only at the same visible choice points that accept the hit; a formation/army
	subject switch or successful confirmation clears the draft-only road choice.
- Engineering stores committed strokes separately from the live pointer end.
	Undo removes one complete continuation rather than an arbitrary sample. New
	camps use FieldTacticsState's bounds and land checks at preview and commit,
	so the map does not reserve an impossible endpoint.
- A newly issued macro order persists the directed physical road segments that
	the field authority validated. This is immutable command intent, whereas
progress remains the existing single shared-clock value. Snapshot validation
migrates older single-road orders and composite route handles into this field.
Road-damage checks start at
	the segment containing current progress, so completed segments cannot freeze
	the remainder of the same order.
- A cross-water field project owns a sequential physical-segment plan instead
	of one misleading bridge polyline. Intermediate generated junction IDs are
	road-network connections only, never player-commandable camps; the final
	camp remains the sole deployed endpoint. A finished early segment may enter
	the graph while later construction remains closed.
- Retreat is a new order over the same immutable physical roads: it reverses
	the ordered segments and their directions but never invents a derivative
	route ID. A construction segment becoming traversable is a durable world
	event, so it uses the controller's existing checkpoint/rollback boundary.
- Runtime path planning is weighted graph search, not all-simple-path
	enumeration. Physical road length is the base cost and proximity to the
	player's drawn line biases legal alternatives, removing the artificial
	twelve-segment ceiling without substituting a UI-side route choice.

## Macro March R0 outer-city greybox

- `ArmyRegistry` owns one issued macro order and preserves the existing stable
  `army_id`; the macro screen owns only draft pointers, selected controls, and
  rendering. A stationed army receives a new `order_id` for its next leg but
  keeps its army identity and exact carried formations.
- `GarrisonState.try_extract_selected_formations()` is the only R0 city
  departure mutation. Aggregate `try_remove_units()` and `set_unit_count()`
  remain compatibility paths and must not be used for selected formation
  marching or rollback.
- A road draw resolves to one configured polyline before confirmation. The
  stored path is world-coordinate `Vector2i` data, and the controller validates
  it again before it charges food or creates an army.
- `BLOCKED` remains the same durable order at the preceding reachable segment;
  recovery resumes the same route and fee. `STATIONED` is not an active-army
  phase, permitting the same army to issue one later garrison-to-garrison leg.
- The legacy Blackstone MVP scene remains retained for historical reference but
  is no longer the formal city entry and may not mutate macro army state.

## M1B standalone playable shell

- `title_shell.tscn` is the formal player entry and owns only title copy,
  keyboard focus, a one-shot scene transition, and title-state exit. It never
  probes, parses, creates, restores, or writes V5 campaign data.
- `blank_map.tscn` remains the first and only scene that creates
  `ConstructionController` and composes `RuntimeCampaignPersistenceCoordinator`.
  This keeps automatic V5 recovery and normal WM-close flushing inside the
  existing city lifecycle.
- The title action is always named `进入黑石城`; no Continue/New Game branch is
  introduced, so the title cannot become a second save-read authority or imply
  destructive overwrite semantics.
- The M1B macOS preset is a minimal unsigned Universal debug preset with the
  unique identifier `org.txwzs.heishicheng`. It does not encode an output path,
  certificate, notarization setting, or a second product configuration.

## M1A current-mainline battle settlement return

- The deadline-and-pressure region is the single player-facing entry to the
  existing current mainline; it is not a sixth floating HUD region or a new
  combat mode.
- `CombatTransactionCoordinator` retains attempt uniqueness, immutable battle
  facts, authorized confirmation, and same-city return. `BattleSession` and
  `BattleAttemptState` remain attempt-local.
- `ConstructionController.apply_battle_result_atomic` remains the only formal
  city writeback. On formal current-mainline victory it clears
  `CurrentMainlineLevel` only after the existing national-resource transaction
  has succeeded; retreat and defeat never clear it.
- A settled retreat may re-enter the unresolved current mainline without
  resetting strategic time, deadline, or accumulated losses. Defeat retains
  the existing city-loss outcome and is not rebranded as a retry.
- V5 schema 5 is unchanged. It persists a returned city but intentionally does
  not serialize a live C0 battle session or active battle reservation.
- Engineering evidence does not grant Founder acceptance or authorize push,
  merge, deployment, or an expanded warfare feature.

## M0 R0C queue-first construction and ready placement

- The current city owns exactly one building slot with `IDLE`, `PRODUCING`,
  `WAITING_MATERIAL`, `READY_TO_PLACE`, and runtime-only
  `PLACEMENT_ACTIVE` states.
- New buildings do not occupy the map while being built. Progress and matching
  cumulative cost commit atomically through the existing construction tick and
  `NationState`; zero materials means zero progress and no foundation.
- At 100%, the slot owns exactly one fully paid ready token. Placement
  revalidates the existing spatial authority and creates one completed building
  without another charge. Invalid placement retains the token.
- Roads remain direct map-drag construction and do not use the building slot.
  New-flow construction priority is removed; schema 4 legacy priority remains
  non-destructively compatible.
- Campaign schema 5 adds only `build_slot`. Runtime placement-active saves as
  ready, while legacy foundations remain placed and lock the new slot until
  completion.
- Engineering evidence does not grant Founder acceptance or authorize merge,
  push, deploy, or another gameplay slice.

## M0 R0B direct placement and failure feedback

- A legal building position commits on the map left press; a separate building
  confirmation control is not part of the product contract.
- `R` rotates, right click or `Esc` cancels, and one successful placement exits
  placement mode. Continuous placement remains deferred.
- The click coordinate is previewed and revalidated immediately before the
  existing `ConstructionController` writer is invoked. No second placement,
  resource, or save authority is introduced.
- Spatial/rule failures are red and explicit. Timed-order material shortages are
  amber, list exact deltas, remain orderable, and explain that the order waits
  for materials; incremental deduction remains authoritative.
- Engineering evidence remains separate from Founder experience acceptance and
  does not authorize merge, push, deploy, or a new gameplay slice.

## M1A.1 normal force entry and restored build-slot layout

- `GarrisonState` remains the only resident-infantry owner. A current-mainline
  attempt may reserve any non-empty dispatchable real force; command capacity
  is an upper bound, never a hidden 50-person minimum.
- The existing C0/coordinator reservation and result ledger remain the only
  attempt and settlement path. Entry feedback is presentation-only and cannot
  create, augment, or duplicate a force reservation.
- The restored build-slot panel uses one anchored `VBoxContainer` for its
  variable content. Its child minimums determine the panel minimum; city-state
  restoration schedules a layout pass instead of preserving an idle-height
  panel around restored controls.

## M1A.1 live concentrated-front deployment

- A player who has explicitly assigned every existing squad to the front route
  may press the existing battle Start button to queue their existing advance
  orders in the same opening tick. This removes a UI-cadence difference between
  the available mouse controls and the normal-20 victory contract.
- The programmatic `start_battle()` API remains neutral unless the real Start
  button supplies the deployment-plan flag, so retreat, defeat, and simulation
  callers keep their original command authority and timing.
- The normal runtime still has no disk V5 load/save lifecycle. This report does
  not create one or reassign Save ownership; a real cold restart remains a
  blocker until that lifecycle is separately wired and verified.

## M1A.1-R2 runtime persistence composition

- `ConstructionController` remains the only live city authority. The runtime
  coordinator is an orchestration adapter around its existing
  export/validate/restore boundary and the accepted V5 generation store; it is
  not a SaveManager, a second canonical state, or another on-disk schema.
- A valid V5 generation restores atomically through the existing controller
  rollback contract. Missing storage alone may create an initial generation;
  future, invalid, or all-corrupt storage must remain on disk and block writes.
- Runtime state changes are dirty/debounced. Explicit flush is available for
  product boundaries and window-close finalization, but `_exit_tree` is never
  the only persistence mechanism.
- Headless normal-scene runners must opt into a temporary V5 root. This avoids
  accidental reads or writes to a player campaign while retaining GUI default
  persistence.

## M0 R0A placement legality and construction presentation

- `CityGridRules.evaluate_placement_legality` is the pure building/road spatial
  authority; `ConstructionController` remains the only placement/save-facing
  writer. Preview, commit, move, rotation, map scan, and legacy diagnostics must
  not invent separate occupancy semantics.
- Building footprints and road cells are mutually exclusive. Entrance
  connection means an adjacent contact cell, never a road inside the footprint.
- Failed move or rotation is atomic. Legacy overlaps load non-destructively and
  are reported as derived `LEGACY_OVERLAP`; schema 4 remains unchanged.
- A building visual, including its shadow, must remain inside the logical
  footprint. Only a selected entrance indicator may point outward.
- Construction detail has one primary state. Priority is a construction-only
  scheduling control, and blocked ETA is `等待材料`.
- R0A engineering evidence does not equal Founder acceptance or authorize a new
  gameplay slice.

## M0 time, construction, and level pressure

- Strategic time stays in `ConstructionController`; M0 extends its existing
  pause and 1x/2x/4x path with fixed 1000 ms construction ticks.
- Timed construction reserves a valid site without full prepayment. Each tick
  computes cumulative target payment and commits through `NationState`; a
  failed payment marks the same task `BLOCKED_RESOURCES` and later resources
  resume it. Zero-duration roads preserve atomic payment.
- Construction priority is exactly low, normal, or high. Different priorities
  sort high-first; equal priority uses stable placement ID.
- Persistent deadline/pressure state is owned by one `CurrentMainlineLevel`.
  Pressure is monotonic until the level is cleared. Attempt-local battle retry
  state cannot write or restore the current mainline object.
- Security only mitigates committed consequences. It cannot clear, decrease, or
  roll back pressure. Essential survival channels retain a 250-permille floor.
- Campaign snapshot schema 4 is the authoritative M0 save contract. V3 timed
  construction is treated as already paid during migration to prevent duplicate
  charges; V2 first receives its established orientation default.
- The existing top bar and building detail panel are reused. No permanent large
  sidebar, second clock/resource/save owner, combat expansion, or UI rewrite is
  introduced.

## R3B dual-city layout profiles

- `blackstone_city` remains the default `REGULAR_IMPERIAL` profile. The formal
  world-map `riverbend_city` entry resolves to `ORGANIC_GARDEN` by stable ID;
  no name-based matching or debug-only city is used.
- `RegularCitySpatialFoundation` projects both authored profiles into the
  existing 55x35 orthogonal grid. Garden roads, reserves, gates, and fixed
  anchors are static data; `ConstructionController` remains the sole runtime
  writer.
- Switching cities snapshots and restores only in-memory runtime placement
  records and player-road cells. Nation resources remain shared. V5 and early
  single-city saves fail closed on Riverbend instead of changing schema or
  writing Riverbend under the Blackstone ID.
- Both cities reuse one `CityGateComponentR1`, one building visual path, one
  placement path, one road path, and one right-rail UI. Final art, traffic,
  curved roads, full-map rotation, and persistent multi-city V5 storage remain
  separate scopes.

## R2B player road construction

- Formal roads remain the spatial authority of
  `RegularCitySpatialFoundation`; player roads are runtime placement records
  owned by `ConstructionController`.
- The player-road set is a delta over the formal 55×35 layout. Rendering,
  connectivity, entrance checks, production activation, and save/load all read
  the same union and do not persist derived connectivity flags.
- The right rail is the only road entry point. A drag creates one orthogonal
  segment; diagonal input is rejected and turns require another segment.
- Confirmation uses the existing national resource transaction and writes one
  record per new road cell. Existing roads are traversable without duplicate
  cost; invalid paths fail atomically.
- Player roads reuse the existing V5 placement array without a schema bump.
  Legacy snapshots with no road placements restore an empty delta.
- R2B excludes road deletion/upgrades, traffic/pathfinding, bridges/slopes,
  curved roads, full-map rotation, organic city generation, final art, and G4.

## Blackstone formal art integration and R2 scenario isolation

- The low-poly presentation is strictly a read-only adapter over theatre,
  army, project and fog facts. Imported models may replace static visual
  geometry, but never own passability, selection, timing, combat, resource, or
  V5 persistence state. The 2D map remains the rollback path.
- Only selected, traceable third-party files belong in the runtime tree. Asset
  source, license, archive/file checksums and modifications are recorded next
  to the selected files; generated imagery is a non-runtime design reference
  unless a separate asset approval explicitly changes that boundary.
- Field R2 same-process scenario tests restore one pristine production V5
  snapshot per independent scenario. This prevents normal persistence
  publication from leaking one test route's armies or patrol results into the
  next one; dedicated multi-process workers continue to prove disk recovery.

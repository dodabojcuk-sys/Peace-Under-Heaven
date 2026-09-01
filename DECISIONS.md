# Product Successor Decisions

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

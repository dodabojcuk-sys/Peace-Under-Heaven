# TXWZS S1A.1 City State Snapshot Roundtrip

## 1. Status

- Task: `TXWZS.S1A.1R2`
- Result: `ACCEPT_S1A1_CITY_STATE_SNAPSHOT_ROUNDTRIP`
- Godot: `4.5.1.stable.official.f62fdbde1`
- Review baseline: `main@5f01fc60b662b87482d4a90afaa4f4b6437dea5e`
- Scope: versioned, same-process, in-memory early-city snapshot roundtrip
- Next stage: `TXWZS.S1A.2`, not started in this task

S1A.1 does not provide disk persistence, process-crash recovery, save migration,
battle persistence, automatic loading, or save UI.

## 2. Authority Boundary

`ConstructionController` remains the only current city runtime authority.
`EarlyCitySnapshotV1` is a stateless `RefCounted` validator and carries no
mutable city state, scene node, or second `CityState`.

The root snapshot fields are:

- `schema_version`
- `snapshot_kind`
- `city_id`
- `city`
- `placements`
- `next_placement_id`

The stable city identity is the exact `String` value:

```text
blackstone_city
```

Missing, empty, non-`String`, or mismatched city identities are rejected before
the first city mutation.

The saved city source fields are:

- current day and elapsed time
- wood, food, and technology points
- infantry count and recruitment cap
- selected general
- training queue count, completion day, and last order day
- researched technology IDs
- supply-shortage and emergency-mobilization flags
- player pause state and 1×／2×／4× time speed

Each runtime placement saves:

- stable placement ID
- definition ID
- grid origin
- lifecycle state
- built day
- disabled-until day
- construction start and completion days

The snapshot does not contain `Node`, `Resource`, `RID`, `Callable`, `Signal`,
UI state, battle state, scene paths, or mutable runtime references.

## 3. Derived State Reconstruction

The following values are not stored as parallel writable state:

| Derived value | Reconstruction source |
| --- | --- |
| occupied cells | fixed occupancy plus placement origins and typed footprints |
| connected roads | restored road cells, fixed road roots, and four-neighbor BFS |
| building operational state | lifecycle, day, disabled-until day, typed road requirements, and connected roads |
| wood and food capacity | base capacity plus operational typed storage capabilities |
| enemy count and fortification | restored day and the existing threat schedule |
| first-war preparation or warning | restored day and the existing first-war rules |
| UI projection and day progress ratio | current authority state and existing view code |

Successful restore runs a formal postcondition that compares all saved source
fields and verifies placement uniqueness, runtime nodes, occupancy, connected
roads, capacities, and operational states.

## 4. Validation Boundary

Validation rejects:

- unknown schema or snapshot kind
- missing, unknown, or wrongly typed fields
- NaN, positive infinity, negative infinity, and elapsed time outside
  `[0, 180)`
- unsupported time speed
- negative resources or invalid recruitment capacity
- training batches, completion days, order days, or totals that the authority
  rules cannot produce
- unknown generals, technologies, definitions, and missing technology
  prerequisites
- invalid lifecycle and construction-date combinations
- out-of-bounds, overlapping, duplicate, unsorted, or fixed-conflicting
  placement IDs
- conflicting or non-monotonic `next_placement_id`
- resource values above deterministically reconstructed capacity
- city state outside the accepted early-city scope

Validation does not silently normalize malformed data.

The training validator reuses the controller's typed technology rule. It also
allows a base-size queue created before a recruitment technology was researched
while that queue was active; later queues use the upgraded typed batch.

## 5. Apply Failure And Rollback

Restore performs these steps:

1. verify the current early-city scope and placement integrity;
2. fully validate the candidate snapshot;
3. export and validate the old authority snapshot before mutation;
4. clear existing runtime placements with explicit failure propagation;
5. install candidate source state and runtime placements;
6. run the formal postcondition;
7. emit success-side signals only after the postcondition passes.

Any clear, install, or postcondition failure returns failure and enters
rollback. Rollback does not call the possibly failing normal release path
again. It:

1. resets runtime records, order, and occupancy to the fixed layer;
2. synchronously detaches remaining runtime children from `PlacedBuildings`;
3. schedules detached obsolete nodes for deletion;
4. reinstalls the validated old snapshot;
5. reruns the same formal postcondition;
6. emits one city-state refresh after the old state is valid.

`tree_exited` callbacks cannot remove newly restored records: records are
cleared before obsolete children leave the tree, and each callback also checks
that its node is still the authoritative node for that placement ID.
`queue_free()` therefore only completes destruction of already detached,
non-authoritative nodes.

Rollback failure is explicitly returned and logged; it is never converted into
ordinary success.

## 6. Fault Injection Evidence

The test uses an existing one-shot `tree_exited` signal and no production
failure switch:

1. create two old runtime road placements;
2. validate the incoming candidate snapshot;
3. successfully release the first old placement;
4. on its `tree_exited`, remove one occupancy entry owned by the second old
   placement;
5. make the second real `_release_runtime_record()` fail its complete-ownership
   check;
6. require restore to return failure and perform rollback.

After failure, the test verifies:

- the exported authority snapshot
- placement ID set
- runtime node IDs and count
- occupied cells
- connected roads
- building operational state
- wood and food capacities
- `next_placement_id`
- selected placement rebinding to a valid restored node
- unchanged report and daily-breakdown projection
- no extra cost, reward, date, recruitment, or battle transition
- the rollback branch and untouched reference branch remain equal after the
  next daily settlement

The S1A.1 runner was executed three independent times. Each run produced:

- 126 explicit assertions passed
- 1 runner summary passed
- exit code 0
- 0 `FAIL`
- 0 `ERROR`
- 0 `Parse Error`
- 0 `SCRIPT ERROR`

## 7. Reference Isolation And Idempotency

Runtime tests prove:

- mutating nested arrays and dictionaries in an exported snapshot does not
  mutate the controller;
- mutating the caller's input after restore does not mutate restored state;
- later controller mutations do not alter an earlier exported snapshot;
- restoring the same snapshot repeatedly does not append placements, duplicate
  nodes, repeat cost or reward, advance the day, or repeat recruitment;
- a placement created after repeated restore uses the expected next ID;
- paused 2× and running 4× snapshots overwrite different target pause/speed
  states correctly;
- unsupported 3× state is rejected without changing the target.

## 8. Commands And Results

Godot version:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
```

Result: exit `0`,
`4.5.1.stable.official.f62fdbde1`.

Editor scan:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" --editor --quit
```

Result: exit `0`; no script, parse, scene, or resource error.

S1A.1 runner, repeated three times:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" \
  --script res://tests/run_s1a1_early_city_snapshot_smoke.gd
```

Result for each run: exit `0`, 126 explicit assertions and one summary.

All smoke runners:

```bash
for runner in tests/run_*_smoke.gd; do
  /Applications/Godot.app/Contents/MacOS/Godot \
    --headless --path "$PWD" --script "res://$runner"
done
```

Actual result:

- runners: 26
- runner exits: 26 exit `0`, 0 nonzero
- explicit assertions: 1364
- runner summaries: 26
- all `PASS` lines: 1390
- `FAIL`: 0
- `ERROR`: 0
- `Parse Error`: 0
- `SCRIPT ERROR`: 0

Main scene:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" --quit-after 3
```

Result: exit `0`.

C0 scene:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" \
  res://scenes/c0_battle_graybox.tscn --quit-after 3
```

Result: exit `0`.

Static checks:

- tracked `git diff --check`: exit `0`
- each untracked file diff check: passed
- duplicate `.gd.uid` values: 0
- helper and test UIDs: unique
- helper preload path: resolved
- test-before and test-after `git status --short`: identical

## 9. Remaining Risks And Non-Guarantees

S1A.1 guarantees only synchronous same-process restore under the accepted
early-city scope. It does not guarantee recovery from process termination,
engine fatal errors, out-of-memory conditions, power loss, partial disk writes,
or save-schema migration.

Formal disk encoding must still decide how Godot in-memory types such as
`StringName` and `Vector2i` are serialized and validated. S1A.2 must not
silently broaden this contract to battle ledgers, noticeboard progress,
strategic-map state, or post-war city state.

The existing battle-result persistence boundary remains unresolved and is not
part of S1A.1.

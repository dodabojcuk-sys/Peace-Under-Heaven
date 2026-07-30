# TXWZS V5 G1 Contract Package 001

## Result

`V5_G1_CONTRACTS_IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

The six authorized G1 architecture tasks are complete as contracts, contract
validation, state synchronization, and planning-control synchronization. This
package contains no G2 runtime implementation and does not claim an
independent G1 verdict.

## Accepted entry gate

- reviewed repair candidate: `bd15fca`;
- reviewed parent: `242f793`;
- independent verdict:
  `V5_P0_P1_PACKAGE_REVIEW_ACCEPTED`;
- durable review report:
  `docs/reports/TXWZS_V5_P0_P1_PACKAGE_INDEPENDENT_REVIEW_002.md`;
- local review checkpoint: `2cc4ebf`;
- V5-G0 and the eleven P0/P1 tasks: `VERIFIED`.

## Six G1 artifacts

| Task | Artifact | Contract result |
| --- | --- | --- |
| `V5-P2-T001` | `docs/architecture/V5_TRAINING_QUEUE_SOURCE_STATE_CONTRACT_V0.md` | minimal collection, stable order IDs, atomic food/garrison boundary, strategic-day-only advancement |
| `V5-P2-T004` | `docs/architecture/V5_STRATEGIC_TIME_SCENE_MATRIX_CONTRACT_V0.md` | city time, pause, war block, battle duration, scene switch, and save/load matrix |
| `V5-P3-T001` | `docs/architecture/V5_ARMY_STATE_COLLECTION_CONTRACT_V0.md` | persistent collection shape; at-most-one-active is V5 validator policy, not singleton storage |
| `V5-P4-T001` | `docs/architecture/V5_ENCOUNTER_OUTCOME_FACTS_CONTRACT_V0.md` | BattleResult fact boundary and coordinator-bound authoritative writeback |
| `V5-P5-T001` | `docs/reports/TXWZS_V5_S1A2_REUSE_DECISION_001.md` | `CONDITIONAL_REUSE_ACCEPTED` for storage mechanics and V1 read-only import only |
| `V5-P5-T002` | `docs/architecture/V5_SAVE_SCHEMA_MIGRATION_ROLLBACK_CONTRACT_V0.md` | V2 schema, deterministic V1 migration, immutable generations, failure and rollback |

The package test matrix is
`docs/testing/V5_G1_CONTRACT_TEST_MATRIX.md`.

## Frozen architecture boundaries

- `TrainingQueue` advances only from the city strategic-day authority.
- `ArmyRegistry` persists stable logical IDs and integer progress, never a
  Node, pixel coordinate, or UI state.
- V5 may reject a second active army through validation; the stored model is
  still a collection that V6 can extend without remigrating a singleton.
- `BattleSession` produces immutable outcome facts and cannot write city,
  garrison, army, time, reward, or save truth.
- Settlement remains coordinator/city-authority bound, idempotent, and
  conflict rejecting.
- Schema V1 is read-only migration input; schema V2 is the only future V5
  write target.
- G1 does not add a second troop type, multi-army concurrency, enemy AI,
  siege, or a new battle.

## S1A.2 read-only decision

All eight protected files retained the hashes recorded in
`TXWZS_V5_S1A2_REUSE_DECISION_001.md`. They remained the exact protected
untracked set and were not staged.

The verdict permits reuse of immutable-generation publication, validation,
checksum, writer lock, recovery, and V1 read-only compatibility mechanics.
It explicitly forbids treating the early-city V1 payload/store as the V5
writer or schema.

## Planning-control synchronization

The canonical workbook, its Markdown mirror, and five CSV mirrors were updated
to plan version `0.8.0-v5-g0-review-g1-contracts-001`.

- P0/P1 eleven tasks and V5-G0: `VERIFIED`;
- six G1 tasks: `IMPLEMENTED_PENDING_REVIEW`;
- V5-G1: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`;
- V5 verified progress: 11/44, 25%;
- V5-G2: `NOT AUTHORIZED`, while its pre-existing partial/in-progress ledger
  state is retained rather than rewritten;
- V6: `NOT STARTED`.

The final persisted workbook passed 38 value, formula-error, and mirror
checks. All 13 sheets were rendered and visually reviewed; the stale e1c8
worktree path in the current-baseline sheet was corrected to this worktree.

## Validation and regression

Session-local evidence:
`/tmp/txwzs-v5-g1-contracts-001.0QQ8C8`.

| Check | Result |
| --- | --- |
| G1 static contract/current-code/protected-state validator | 51/51 PASS |
| V5 focused runner | exit 0; 27 explicit assertions |
| tracked runners | 29/29; 1601 explicit assertions; 0 signatures |
| all-present runners | 30/30; 1713 explicit assertions; 1742 PASS lines; 0 signatures |
| formal main scene | exit 0 |
| formal Blackstone scene | exit 0 |
| final Godot editor scan | exit 0 |
| final workbook validation | 38/38 PASS; 0 formula errors |
| `git diff --check` | exit 0 |
| final error-signature scan | 0 matches |

The runtime counts match the independently reviewed G0 baseline. The G1 diff
contains only architecture/testing/report/state/planning artifacts and does
not change V4, C0, `BattleSession`, Blackstone, GarrisonState, save runtime, or
any protected S1A.2 file.

## Final gate state

- V4: `VERIFIED / FROZEN`
- V5-G0: `VERIFIED`
- V5-G1: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`
- V5-G2: `NOT AUTHORIZED`; existing partial ledger state unchanged
- V6: `NOT STARTED`

The local commit containing this report is the G1 candidate checkpoint. The
next permitted action is an independent review of this exact G1 package. No
push, deploy, release, or V6 work is authorized.

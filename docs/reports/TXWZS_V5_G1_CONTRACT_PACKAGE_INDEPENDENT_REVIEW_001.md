# TXWZS V5 G1 Contract Package Independent Review 001

## Verdict

`V5_G1_CONTRACT_PACKAGE_REVIEW_ACCEPTED`

Reviewed candidate:
`b3a7f03055350f25caa14dee8a630cf3b004d028`.

Reviewed parent:
`2cc4ebf01622b424ff4a4cd145c421b8fd1bbec3`.

This independent review accepts the six-contract V5 G1 package and marks
V5-G1 `VERIFIED`. Under the user's conditional authorization, the complete
V5-G2 automated vertical loop may now proceed without another authorization
pause.

The verdict does not accept any G2 runtime implementation, does not mark
V5-G2 or later gates verified, and does not permit V6, push, deployment, or
release.

## Independent review identity

| Field | Value |
| --- | --- |
| Reviewer task | `/root`, current Codex task `019fb2b7-23b2-7b60-8c8d-2ca085e747d8` |
| Review worktree | `/Users/m1-meng/.codex/worktrees/3231/godot-天下无战事2` |
| Reviewed branch | `codex/v5-g0-review-g1-contracts-001` |
| Reviewed range | `2cc4ebf..b3a7f03` |
| Godot | `4.5.1.stable.official.f62fdbde1` |
| Session-local evidence | `/tmp/txwzs-v5-g1-independent-review-001.MJhd1Y` |
| External actions | no push, deploy, release, production mutation, or V6 work |

`README`, `DECISIONS.md`, and `CHANGELOG.md` do not exist in this checkout.
`AGENTS.md`, `CURRENT_STATE.md`, the planning workbook and mirrors, G0 Review
002, G1 package report, all six contracts, the test matrix, candidate diff,
runtime authorities, tests, and protected files were read directly.

## Candidate binding

`git rev-parse`, `git diff-tree`, `git show`, and SHA-256 checks confirmed the
exact parent above and the following 16-file candidate:

| Status | File | SHA-256 |
| --- | --- | --- |
| M | `CURRENT_STATE.md` | `72e3430070bc7ca2a6d2dfd1f107baab5cc811c90d7ff392a362b431b6412716` |
| A | `docs/architecture/V5_ARMY_STATE_COLLECTION_CONTRACT_V0.md` | `d0f67b59992a6dff2782a3f0b8072f57914991fe86df652c4a48eda517c418e0` |
| A | `docs/architecture/V5_ENCOUNTER_OUTCOME_FACTS_CONTRACT_V0.md` | `72b3d59915fbb9ad855495db061e724b267573b3651a0482ca60a6ed9e080ed0` |
| A | `docs/architecture/V5_SAVE_SCHEMA_MIGRATION_ROLLBACK_CONTRACT_V0.md` | `cee39fbe8e5c9228c8a69142aa060bd614875a2552432ea9766be3b48f670897` |
| A | `docs/architecture/V5_STRATEGIC_TIME_SCENE_MATRIX_CONTRACT_V0.md` | `7587e0ee6c5d828d7e2993cd1a8e7b7fa4c4d01b8c199d79007a7c5634cd8951` |
| A | `docs/architecture/V5_TRAINING_QUEUE_SOURCE_STATE_CONTRACT_V0.md` | `f80a531f724e2173db254ec696536e3fe717539b9410ae654a1df54df1ede579` |
| M | `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md` | `44372c7be2466ec9d27e057a237d959cf0e1cf706191d115b97e3577ee14b263` |
| M | `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx` | `803f2872701014f64a4908b0641dcff4ec71f8a4e10cacb3ae57ffa5df36ea00` |
| M | `docs/planning/csv/acceptance_matrix.csv` | `36b99fdf27b60e6d1f820eda8eafdd76131ce983af0007e22ff92d3309fd53e9` |
| M | `docs/planning/csv/risks_and_decisions.csv` | `603705df40736c5a5b20302f0c7fd637daa447b90f3a7cadc2a99afbf9e74882` |
| M | `docs/planning/csv/roadmap.csv` | `b31128fc82c01760ea4f6bb2faf149ca245feae663b15f664c8cbf628dbff865` |
| M | `docs/planning/csv/tasks.csv` | `38e23566063ab956e3151220160e95f31f2a4a0d94ea02f82dcdad066ddd5a57` |
| M | `docs/planning/csv/tests.csv` | `e09ba135654f8f593a0a2ba3889d23dec8b1eb36433177f71e23c9a70a935ec7` |
| A | `docs/reports/TXWZS_V5_G1_CONTRACT_PACKAGE_001.md` | `08e9accf708f76f7ceb55759c4b5beefec4073473a50b57847b130ea28210a0c` |
| A | `docs/reports/TXWZS_V5_S1A2_REUSE_DECISION_001.md` | `21289c2d9de3747461042bfac35c0366354639b4dfed64e8debd61d0527e063d` |
| A | `docs/testing/V5_G1_CONTRACT_TEST_MATRIX.md` | `dc29d5857e1f78d93333b8a6c8134fc4614342579d5dcd69285fb8374db7ebfa` |

No runtime source, scene, `project.godot`, or protected S1A.2 file occurs in
the candidate diff.

## Six-contract review

### TrainingQueue

- The future queue is a collection with persisted monotonic order IDs.
- Compatibility fields remain the current runtime truth until one atomic G2
  migration; G1 does not create a second live queue.
- Only the city strategic-day boundary may complete an order.
- Failed enqueue or completion is explicitly zero-write.

### Strategic time

- Manual pause, war block, battle time, result acknowledgement, scene switch,
  and save/load have distinct rules.
- Ordinary scene frames cannot advance unloaded or battle-blocked city time.
- Battle duration is applied exactly once from terminal simulation facts and
  is not multiplied by UI speed.

### ArmyRegistry

- The source is `armies_by_id`, not an `active_army` singleton.
- The V5 one-active limit is a validator rule that V6 can lift without schema
  replacement.
- Persistence is restricted to stable logical IDs, integer progress, phase,
  composition, and transaction/result links.

### Encounter facts and writeback

- The listed fact fields match the current `BattleResult` fields exactly.
- `BattleSession` has no direct city, garrison, save, or migration dependency.
- Confirmation remains coordinator-bound; replay is idempotent and conflicting
  facts are rejected.

### S1A.2 reuse

- The decision permits storage mechanics and V1 read-only import only.
- The exact V1 payload/store is not the V5 writer/schema.
- The eight original files remain outside the Git index.

### Save, migration, and rollback

- Storage version 1, nested aggregate versions, and campaign schema 2 are
  explicitly separate.
- V1 input must validate before deterministic isolated migration.
- Legacy bytes are immutable; publication uses new generations.
- Migration/live-apply failures retain source bytes and restore the complete
  pre-apply authority snapshot.

## Cross-contract consistency

The independent validator reproduced the requested 51/51 baseline checks and
added 30 checks covering:

- exact `BattleResult` field alignment;
- shared time, unit, queue, army, transaction, and result identities;
- version-layer separation;
- TrainingQueue and ArmyRegistry embedding in the V2 snapshot;
- replay-ledger persistence;
- coordinator-only confirmation;
- immutable V1 input and live rollback ordering.

All 81 checks passed. No field, phase, identity, writer, conservation, or
version-rule conflict was found.

## Workbook review

The canonical workbook imported successfully. Fourteen persisted-value and
gate checks passed, formula-error scan returned zero matches, and all 13
worksheets were rendered and visually reviewed. No clipping, broken formula,
blank required sheet, or status contradiction was found.

## Fresh runtime evidence

| Check | Result |
| --- | --- |
| G1 baseline validator | 51/51 PASS |
| extended cross-contract validator | 30/30 PASS |
| V5 focused runner | exit 0; 27 explicit assertions |
| tracked runners | 29/29; 1601 explicit assertions; 0 signatures |
| all-present runners | 30/30; 1713 explicit assertions; 1742 PASS lines; 0 signatures |
| formal main scene | exit 0 |
| formal Blackstone scene | exit 0 |
| final Godot editor scan | exit 0 |
| workbook persisted checks | 14/14 PASS; 0 formula errors |
| workbook render review | 13/13 sheets |
| `git diff --check` | exit 0 |
| final error-signature scan | 0 matches |

## Protected S1A.2 manifest

The following SHA-256 values were identical before and after review:

| File | SHA-256 |
| --- | --- |
| `scripts/state/early_city_save_store_v1.gd` | `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` |
| `scripts/state/early_city_save_store_v1.gd.uid` | `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd` | `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` | `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` | `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` |
| `tests/s1a2_early_city_disk_worker.gd` | `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` |
| `tests/s1a2_early_city_disk_worker.gd.uid` | `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` |

They remain the exact eight untracked files and remain unstaged.

## Findings and disposition

No blocking or non-blocking finding was opened. No candidate repair was
required.

## Gate decision

- V4: `VERIFIED / FROZEN`
- V5-G0: `VERIFIED`
- V5-G1: `VERIFIED`
- V5-G2: authorized to begin; not yet accepted or verified
- V5-G3 through G6: unchanged
- V6: `NOT STARTED`

The local commit containing this report and synchronized state is the G1
independent-review checkpoint. The next action is the authorized full G2
automated vertical-loop implementation.

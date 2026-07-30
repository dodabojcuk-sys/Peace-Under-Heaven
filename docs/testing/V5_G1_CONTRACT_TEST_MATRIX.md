# V5 G1 Contract Test Matrix

## Package status

`V5_G1_CONTRACTS_IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

This matrix validates the six G1 artifacts against the accepted G0 code and
reserves runtime cases for G2. Passing this matrix does not mark G1 or G2
`VERIFIED`.

## Contract coverage

| Task | Durable artifact | G1 validation |
| --- | --- | --- |
| V5-P2-T001 | `V5_TRAINING_QUEUE_SOURCE_STATE_CONTRACT_V0.md` | stable collection/ID, transitions, conservation, compatibility, forbidden fields |
| V5-P2-T004 | `V5_STRATEGIC_TIME_SCENE_MATRIX_CONTRACT_V0.md` | pause, speed, war block, battle settlement, scene switch matrix |
| V5-P3-T001 | `V5_ARMY_STATE_COLLECTION_CONTRACT_V0.md` | collection not singleton, stable logical route/node/progress, no Node/pixel/UI |
| V5-P4-T001 | `V5_ENCOUNTER_OUTCOME_FACTS_CONTRACT_V0.md` | BattleResult facts only, coordinator authority, idempotency/conflict |
| V5-P5-T001 | `TXWZS_V5_S1A2_REUSE_DECISION_001.md` | immutable hashes, fresh runner, conditional reuse boundary |
| V5-P5-T002 | `V5_SAVE_SCHEMA_MIGRATION_ROLLBACK_CONTRACT_V0.md` | V1→V2 mapping, unknown version, failure/rollback, immutable generations |

## Static G1 checks

| Check | Expected |
| --- | --- |
| all six task IDs occur exactly once as the artifact task owner | PASS |
| all architecture artifacts state `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW` | PASS |
| ArmyState contract contains a collection and explicitly forbids singleton persistence | PASS |
| TrainingQueue contract binds completion to city strategic day boundaries | PASS |
| time matrix blocks normal time in battle and applies terminal duration once | PASS |
| outcome contract forbids BattleSession city/garrison/save writes | PASS |
| S1A.2 decision records all eight exact hashes | PASS |
| V5 schema separates storage version from domain schema version | PASS |
| V5 schema includes migration failure and rollback rules | PASS |
| no contract authorizes G2 implementation, V6, second troop, multi-army concurrency, AI, siege, or new combat | PASS |

## Current-code evidence checks

| Evidence | Expected |
| --- | --- |
| one production `var infantry_count`, proxying GarrisonState | PASS |
| one production reservation creation assignment | PASS |
| reservation gate uses `get_dispatchable_infantry_count()` | PASS |
| training completion occurs under `_advance_day_boundary()` | PASS |
| normal `_process` delegates to `advance_city_time()` | PASS |
| war block stops normal time | PASS |
| settlement uses terminal battle duration once | PASS |
| BattleSession produces terminal facts without direct city/save calls | PASS |
| coordinator/city remains authoritative result entry | PASS |

## Runtime regression required for the G1 candidate

- V5 garrison runner;
- S1A.2 runner as read-only all-present evidence;
- all tracked runners;
- all-present runners;
- formal main scene;
- formal Blackstone scene;
- final Godot editor scan;
- `git diff --check`;
- final error-signature scan;
- protected hash and staged-file audit.

## Stage boundary

G1 contract tests validate architecture and planning consistency only.
TrainingQueue, ArmyRegistry, V2 writer/migrator, and new settlement runtime
remain G2 `NOT AUTHORIZED` in this candidate.

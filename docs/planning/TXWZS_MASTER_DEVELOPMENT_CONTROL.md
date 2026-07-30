# TXWZS Master Development Control

## Control Metadata

- Plan version: 1.0.1-v5-g2-repair-001
- Updated: 2026-07-30
- Workbook: docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx
- Canonical editing rule: edit the workbook first, then export Markdown/CSV in the same planning change.
- Fact authority: Git, code, configuration, tests, and identified runtime evidence override this plan.
- Current phase: V4 VERIFIED / FROZEN; V5-G0 VERIFIED; V5-G1 VERIFIED; V5-G2 REPAIRED_PENDING_INDEPENDENT_REVIEW
- Unique next gate: fresh independent review of the V5-G2 repair candidate; do not enter G3/G4/G5/G6/V6 first
- Gate instances: 63 (V4–V12 × G0–G6)
- Requirements / tasks / tests: 25 / 88 / 69
- P0 uncovered requirements: 0

## Current Git Baseline

| Field | Value |
| --- | --- |
| Branch / parent HEAD | codex/v5-g0-review-g1-contracts-001@e2c1096 repair checkpoint |
| Upstream | none for the local branch; no push |
| V4 checkpoint | 5357c28 (`feat: freeze verified V4 milestone`) |
| V5 repair candidate | bd15fca, parent 242f793, independently accepted |
| V5 G0 review checkpoint | 2cc4ebf (`docs: accept repaired V5 P0 P1 package`) |
| V5 G1 candidate | `b3a7f03`; independently accepted |
| V5 G1 independent verdict | `V5_G1_CONTRACT_PACKAGE_REVIEW_ACCEPTED`; 51/51 baseline + 30/30 cross-contract checks |
| V5 G1 evidence | /tmp/txwzs-v5-g1-independent-review-001.MJhd1Y |
| V5 P2 checkpoint | `023f11a` (`feat: implement V5 training and strategic time`) |
| V5 P3 checkpoint | `a95f510` (`feat: implement V5 persistent army state`) |
| V5 P4 checkpoint | `8a6e65a` (`feat: implement V5 encounter settlement`) |
| V5 P5 checkpoint | `ee32d84` (`feat: implement V5 campaign persistence`) |
| V5 G2 candidate | `cd7be2b`, parent `ee32d84`; independent review found stable-ID sequence rollback |
| V5 G2 repair checkpoint | `e2c1096f858d571d4621b93174d3848406b42ffa`, parent `cd7be2b`; exact three code/test files |
| V5 G2 review verdict | `V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`; repair reviewer cannot self-accept |
| Protected untracked | 8 S1A.2 files |
| G0 boundary probe | 10 explicit assertions: dispatchable 10; reserve 12 rejects without writes; reserve 10 succeeds |
| G0 V5 focused | 27 explicit assertions, all passed |
| G0 tracked regression | 29/29 runners, 1601 explicit assertions, 0 error signatures |
| G0 all-present regression | 30/30 runners, 1713 explicit assertions / 1742 PASS lines, 0 error signatures |
| G0 evidence | /tmp/txwzs-v5-g0-review-002.BlGA2l |
| G2 V5 focused | 6/6 runners, 168 explicit assertions |
| G2 tracked regression | 33/33 runners, 1722 explicit assertions |
| G2 all-present regression | 35/35 runners, 1854 explicit assertions / 1888 PASS lines |
| G2 evidence | durable: atomic repair commit + `docs/reports/TXWZS_V5_G2_RUNTIME_PACKAGE_INDEPENDENT_REVIEW_001.md`; command/exit statistics are session records without retained per-run log directory |

The `/tmp` evidence is session-local, not the durable rollback point. The durable V4 rollback point is the local V4 checkpoint commit containing this revision and its parent. The eight protected S1A.2 files remain outside that checkpoint.

## Baseline Differences

- The branch, checkpoint, V4/C0 candidate, state machine, single visible troop option, and protected S1A.2 scope match the repository.
- `BattleSession`, private `GarrisonState`, `TrainingQueue`, collection-based `ArmyRegistry`, and the V5 campaign snapshot/codec/store now exist. `UnitDefinition`, `SiegeSession`, `CityState`, `WorldState`, and `RouteState` do not exist as new runtime classes.
- UnitRole is the current static infantry definition; the plan must adapt or evolve it instead of automatically adding a duplicate UnitDefinition.
- V4 stores marching armies in the scene script. `_marching_armies` is an array, but the implementation only updates element 0 and blocks concurrent commands.
- WorldMapPresentationModel is a read-only fixture, not persistent strategic state.
- S1A.1 memory snapshots are accepted. S1A.2 remains `CONDITIONAL_REUSE_ACCEPTED`: V5 reused validation and immutable-generation mechanics through separate V2 files, while all eight protected V1 files stayed hash-identical, untracked, and unstaged.
- G0 independent review accepted `bd15fca`; G1 independent review accepted `b3a7f03`. G2 review of `cd7be2b` found checksum-valid sequence rollback could reuse stable training-order and army IDs. The reviewer applied the minimal validator repair and full regression, but cannot self-accept it; G2 remains pending a fresh independent review.

## V4–V12 Roadmap

| Phase | Name | Player result | Detail level | Status | Progress |
| --- | --- | --- | --- | --- | ---: |
| V4 | 派遣主链路冻结 | 玩家从己方驻军节点选路线、选比例、完成可见行军并得到一次性到达结算。 | Work-package | VERIFIED / FROZEN | 100% |
| V5 | 单兵种战争底座＋城内训练补兵 | 城市能真实训练步兵；驻军可派出；伤亡、幸存、驻扎/返回写回；保存重载后保持一致。 | Detailed | IN_PROGRESS | 39% VERIFIED |
| V6 | 持久外城战区＋多军队数据模型 | 多支军队可以在持久外城道路上行军、驻扎、支援、进攻、返回，重进场景后位置与进度一致。 | Medium | NOT_STARTED | 0% |
| V7 | 步兵遭遇战 | 两军在道路或据点相遇时进入可读、可决策的步兵遭遇战，结果写回军队与战区。 | Work-package | NOT_STARTED | 0% |
| V8 | 围城状态＋战事内城 | 军队抵达敌城后形成围城；进入临时战事内城，城墙/城门/核心代表战役，不摧毁常态内城布局。 | Work-package | NOT_STARTED | 0% |
| V9 | 第二持久城市＋占领闭环 | 玩家可占领/收复第二城市；其布局和归属持久，失败不销毁原布局。 | Work-package | NOT_STARTED | 0% |
| V10 | 敌方战略行动 | 敌军会在天下地图上增援、封锁、进攻；玩家能提前看见并响应。 | Work-package | NOT_STARTED | 0% |
| V11 | 第二兵种＋正式编组 | 玩家用两种真实兵种组成可保存编组，并在战前/战中体现差异。 | Work-package | NOT_STARTED | 0% |
| V12 | 工程、侦察、伏击和特殊行动 | 军队可执行少量明确的非正面战斗行动，改变路线、情报或战斗条件。 | Work-package | NOT_STARTED | 0% |

## V5 Detailed Plan

- Vertical loop: produce one infantry unit → local garrison → real dispatch → result → survivors return or garrison → state writeback → save and reload.
- G1 defines a future persistent `ArmyRegistry` collection with stable army/route/node IDs and logical progress; the V5 gameplay limit of at most one active army is a validator policy, not a singleton data model.
- Task count: **44**
- Work packages:
  - P0 基线与合同: 5
  - P1 单兵种与驻军: 6
  - P2 训练与时间: 7
  - P3 派遣与军队: 6
  - P4 战果写回: 5
  - P5 存档与迁移: 5
  - P6 最小军备 UI: 3
  - P7 验证与冻结: 7
- V5 P0 and P1 were implemented as one substantive first slice and independently accepted at V5-G0.
- P0 evidence freezes the V4 checkpoint, ownership table, stable single-unit contract, garrison conservation, temporary manpower rule, rollback, and stop conditions.
- P1 uses a private `GarrisonState` under the existing `ConstructionController`, preserves `infantry_count` as a compatibility property, reuses `UnitRole`, adds a dispatchable read model, exposes “驻军 / 可派” in the city sidebar, and has a 27-assertion focused runner.
- G1 adds six independently accepted contract artifacts: TrainingQueue source state; strategic-time/scene matrix; ArmyState collection; encounter facts/writeback; S1A.2 reuse decision; and V5 save schema/migration/rollback.
- G2 implements the contracted `TrainingQueue`, collection-based `ArmyRegistry`, Army encounter settlement adapter, `CampaignSnapshotV2`, `SaveEnvelopeV1`, V1 read-only migration, immutable generations, cold-process recovery, and rollback. Independent review repaired sequence validators so a restored snapshot cannot reuse an existing stable training-order or army ID.
- The 16 runtime tasks remain `IMPLEMENTED_PENDING_REVIEW`. Repair-agent tests are evidence, not independent acceptance. This candidate adds no second unit, multi-active policy, enemy AI, siege, new battle source, P6 UI package, or V6 work.

## V6 Medium Plan

- Persistent outworld state and logical routes.
- Enable multiple active ArmyState records on the V5 collection container; do not replace or remigrate the container.
- Extend full persistent theater and scene restoration for concurrent armies.
- UI may issue one command at a time, but the model cannot depend on a singleton active army.
- Garrison, support, attack, return, march save/reload, scene re-entry, encounter trigger, and siege trigger contracts.
- Encounter combat and siege presentation remain V7/V8 scope.

## Gate Model

G0 baseline → G1 ownership contract → G2 automated vertical loop → G3 full regression → G4 real window → G5 independent review → G6 user playtest/freeze

Only VERIFIED counts as complete. CANCELLED requires a decision record and is removed from the denominator.

The workbook contains 63 concrete gate instances: V4-G0 through V12-G6. V4-G0 through V4-G6 are VERIFIED. `V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_002_ACCEPTED` remains the final route repair review; its candidate hashes match the final V4 candidate. `TXWZS_V4_MILESTONE_CLOSURE_001_ACCEPTED` records the fresh eight-state 1152×648 path, 150 Blackstone assertions, 59 C0 authority assertions, tracked 27/27, all-present 29/29, formal scenes, editor scan, diff check, and zero final error signatures. `T-V4-003` is PASS and V4 is VERIFIED/FROZEN.

V5 P0/P1 now has independent acceptance evidence: `bd15fca`, its exact parent
and four-file manifest, the 10/12 capacity boundary probe, the 27-assertion
focused runner, tracked 29/29, all-present 30/30, formal scenes, editor scan,
diff check, and zero final error signatures. The 11 related tasks and V5-G0
are VERIFIED.

The six selected G1 tasks and V5-G1 are independently accepted and VERIFIED
by `TXWZS_V5_G1_CONTRACT_PACKAGE_INDEPENDENT_REVIEW_001.md`. The review bound
`b3a7f03`, parent `2cc4ebf`, the exact 16-file manifest, 51/51 baseline
checks, 30/30 cross-contract checks, full regression, workbook verification,
and the protected S1A.2 hashes.

The user's conditional authorization activated V5-G2. P2/P3/P4/P5 and the
automated vertical loop are implemented. Review of original candidate
`cd7be2b` reproduced a critical stable-ID sequence rollback defect. The same
review task applied a minimal repair and completed focused, tracked,
all-present, formal-scene, editor, and workbook regressions. The ledger is
`REPAIRED_PENDING_INDEPENDENT_REVIEW`: it must not be marked VERIFIED, and
G3/G4/G5/G6/V6 must not begin, before a fresh reviewer binds and reruns the
repair candidate.

Independent review must bind the reviewer task identity, reviewed commit/patch/hash, findings, implementer response, and re-review result. Main-agent evidence is labeled PASS_MAIN_AGENT until independently rerun.

## Independent Review

- Review record: RVW-PLAN-001
- Reviewer task: /root/master_plan_review_fast
- Initial verdict: REQUEST_CHANGES / V5_EXECUTION_BLOCKED
- Findings PLAN-001 through PLAN-006 were incorporated in plan version 0.1.0-review1; re-review result is recorded in docs/reviews/TXWZS_MASTER_PLAN_REVIEW_001.md.
- Repair review: RVW-PLAN-002, reviewer task /root/master_plan_review_final, report docs/reviews/TXWZS_MASTER_PLAN_REVIEW_002.md.
- The external REVIEW_002 report binds the final XLSX, Markdown, five CSV and ZIP hashes; the workbook does not self-reference its own hash.
- Gate-control repair review: RVW-PLAN-003, report docs/reviews/TXWZS_MASTER_PLAN_REVIEW_003.md.
- REVIEW_003 remains immutable historical evidence and binds the pre-sync PLAN-REPAIR-002 hashes.
- The user accepted REVIEW_003 on 2026-07-29. PLAN-STATE-SYNC-001 records the state transition and binds the regenerated artifact hashes.
- V4 technical review record: RVW-V4-P5-002, reviewer task `/root`, report `docs/reviews/TXWZS_V4_P5_T001_INDEPENDENT_REVIEW_002.md`.
- RVW-V4-P5-002 verdict: `ACCEPT_V4_P5_T001_READY_FOR_USER_STAGE_TEST`; V4-P5-T001 and V4-G1 through V4-G5 are VERIFIED.
- Visual slice review: `docs/reports/TXWZS_V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_002.md`; verdict `V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_002_ACCEPTED`.
- Milestone closure: `docs/reports/TXWZS_V4_MILESTONE_CLOSURE_001.md`; verdict `TXWZS_V4_MILESTONE_CLOSURE_001_ACCEPTED`.
- The user explicitly accepted Review 002 and authorized the consolidated V4 Gate. `T-V4-003` and V4-G6 are PASS/VERIFIED, V4 is frozen, and V5-P0-T001 was released from that checkpoint. No Review 003 was created.
- V5 first-slice implementation report: `docs/reports/TXWZS_V5_SINGLE_UNIT_GARRISON_SLICE_001.md`.
- V5 P0/P1 contract: `docs/architecture/V5_SINGLE_UNIT_WAR_FOUNDATION_CONTRACT_V0.md`.
- G0 repair review: `docs/reports/TXWZS_V5_P0_P1_PACKAGE_INDEPENDENT_REVIEW_002.md`; verdict `V5_P0_P1_PACKAGE_REVIEW_ACCEPTED`.
- G0 local review checkpoint: `2cc4ebf`.
- G1 artifacts: `docs/architecture/V5_TRAINING_QUEUE_SOURCE_STATE_CONTRACT_V0.md`, `V5_STRATEGIC_TIME_SCENE_MATRIX_CONTRACT_V0.md`, `V5_ARMY_STATE_COLLECTION_CONTRACT_V0.md`, `V5_ENCOUNTER_OUTCOME_FACTS_CONTRACT_V0.md`, `V5_SAVE_SCHEMA_MIGRATION_ROLLBACK_CONTRACT_V0.md`, and `docs/reports/TXWZS_V5_S1A2_REUSE_DECISION_001.md`.
- G1 validation matrix: `docs/testing/V5_G1_CONTRACT_TEST_MATRIX.md`.
- G1 independent review: `docs/reports/TXWZS_V5_G1_CONTRACT_PACKAGE_INDEPENDENT_REVIEW_001.md`; verdict `V5_G1_CONTRACT_PACKAGE_REVIEW_ACCEPTED`.
- G1 status is `VERIFIED`; original G2 candidate `cd7be2b` did not pass review. The repaired candidate is `REPAIRED_PENDING_INDEPENDENT_REVIEW` and has no acceptance verdict.
- G2 implementation reports: `TXWZS_V5_P2_TRAINING_TIME_IMPLEMENTATION_001.md`, `TXWZS_V5_P3_ARMY_STATE_IMPLEMENTATION_001.md`, `TXWZS_V5_P4_ENCOUNTER_WRITEBACK_IMPLEMENTATION_001.md`, `TXWZS_V5_P5_CAMPAIGN_PERSISTENCE_IMPLEMENTATION_001.md`, and `TXWZS_V5_G2_RUNTIME_PACKAGE_001.md`.
- G2 independent review and repair report: `docs/reports/TXWZS_V5_G2_RUNTIME_PACKAGE_INDEPENDENT_REVIEW_001.md`; verdict `V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`.
- G2 atomic repair checkpoint: `e2c1096f858d571d4621b93174d3848406b42ffa`, parent `cd7be2b4e65f453889c5f49a4922f788cca08a68`; exact scope is `army_registry.gd`, `training_queue.gd`, and `run_v5_campaign_persistence_smoke.gd`.

## Four-Layer Architecture

| Layer | Persistence | Boundary |
| --- | --- | --- |
| 常态内城 | Persistent | buildings, population/manpower, training, garrison, food |
| 外城战区 | Persistent-changing | routes, positions, armies, garrisons, encounters |
| 战事内城 | Battle instance | walls, gates, defenders, siege phases; never a second city truth |
| 天下地图 | Persistent overview | cities, factions, campaign and enemy strategic actions |

## Mirrors

- docs/planning/csv/roadmap.csv
- docs/planning/csv/tasks.csv
- docs/planning/csv/acceptance_matrix.csv
- docs/planning/csv/tests.csv
- docs/planning/csv/risks_and_decisions.csv

Do not edit mirrors independently. Regenerate them from the same workbook revision.

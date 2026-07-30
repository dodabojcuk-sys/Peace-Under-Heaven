# TXWZS Master Development Control

## Control Metadata

- Plan version: 0.7.0-v5-p0-p1-implementation-001
- Updated: 2026-07-30
- Workbook: docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx
- Canonical editing rule: edit the workbook first, then export Markdown/CSV in the same planning change.
- Fact authority: Git, code, configuration, tests, and identified runtime evidence override this plan.
- Current phase: V4 VERIFIED / FROZEN; V5 P0/P1 IMPLEMENTED_PENDING_REVIEW
- Unique next gate: V5 P0/P1 package review; only G0 can receive a full verdict, while G1/G2 remain partial
- Gate instances: 63 (V4–V12 × G0–G6)
- Requirements / tasks / tests: 25 / 88 / 69
- P0 uncovered requirements: 0

## Current Git Baseline

| Field | Value |
| --- | --- |
| Branch / parent HEAD | codex/v4-milestone-closure@64f37bda130397f08cdd012609dc2d3a5f5c6b99 |
| Upstream | none for the local closure branch |
| V4 checkpoint | 5357c28 (`feat: freeze verified V4 milestone`) |
| V5 candidate | P0 contract + P1 garrison source/adapter/UI/runner |
| Protected untracked | 8 S1A.2 files |
| Blackstone / C0 focused | 150 / 59 explicit assertions, all passed |
| Tracked regression | 27/27 runners, 1515 PASS lines, 0 error signatures |
| All-present regression | 29/29 runners, 1686 PASS lines, 0 error signatures |
| Final evidence | /tmp/txwzs-v4-milestone-closure.fD2A6P |
| V5 first-slice regression | 30/30 all-present runners, 1740 PASS lines, 0 error signatures |
| V5 evidence | /tmp/txwzs-v5-single-unit-garrison.20260730 |

The `/tmp` evidence is session-local, not the durable rollback point. The durable V4 rollback point is the local V4 checkpoint commit containing this revision and its parent. The eight protected S1A.2 files remain outside that checkpoint.

## Baseline Differences

- The branch, parent HEAD, V4/C0 candidate, state machine, single visible troop option, and protected S1A.2 scope match the repository.
- BattleSession exists; UnitDefinition, GarrisonState, ArmyState, SiegeSession, CityState, WorldState, RouteState, TrainingQueue, and SaveSchemaVersion do not exist as the named classes.
- UnitRole is the current static infantry definition; the plan must adapt or evolve it instead of automatically adding a duplicate UnitDefinition.
- V4 stores garrisons and marching armies in the scene script. _marching_armies is an array, but the implementation only updates element 0 and blocks concurrent commands.
- WorldMapPresentationModel is a read-only fixture, not persistent strategic state.
- S1A.1 memory snapshots are accepted. The eight S1A.2 disk files exist but remain protected and are not treated as an accepted disk-save baseline.
- The final tracked regression is 27/27. The all-present 29/29 observation includes the untracked S1A.2 runner but does not accept or freeze S1A.2.

## V4–V12 Roadmap

| Phase | Name | Player result | Detail level | Status | Progress |
| --- | --- | --- | --- | --- | ---: |
| V4 | 派遣主链路冻结 | 玩家从己方驻军节点选路线、选比例、完成可见行军并得到一次性到达结算。 | Work-package | VERIFIED / FROZEN | 100% |
| V5 | 单兵种战争底座＋城内训练补兵 | 城市能真实训练步兵；驻军可派出；伤亡、幸存、驻扎/返回写回；保存重载后保持一致。 | Detailed | IN_PROGRESS | 0% VERIFIED |
| V6 | 持久外城战区＋多军队数据模型 | 多支军队可以在持久外城道路上行军、驻扎、支援、进攻、返回，重进场景后位置与进度一致。 | Medium | NOT_STARTED | 0% |
| V7 | 步兵遭遇战 | 两军在道路或据点相遇时进入可读、可决策的步兵遭遇战，结果写回军队与战区。 | Work-package | NOT_STARTED | 0% |
| V8 | 围城状态＋战事内城 | 军队抵达敌城后形成围城；进入临时战事内城，城墙/城门/核心代表战役，不摧毁常态内城布局。 | Work-package | NOT_STARTED | 0% |
| V9 | 第二持久城市＋占领闭环 | 玩家可占领/收复第二城市；其布局和归属持久，失败不销毁原布局。 | Work-package | NOT_STARTED | 0% |
| V10 | 敌方战略行动 | 敌军会在天下地图上增援、封锁、进攻；玩家能提前看见并响应。 | Work-package | NOT_STARTED | 0% |
| V11 | 第二兵种＋正式编组 | 玩家用两种真实兵种组成可保存编组，并在战前/战中体现差异。 | Work-package | NOT_STARTED | 0% |
| V12 | 工程、侦察、伏击和特殊行动 | 军队可执行少量明确的非正面战斗行动，改变路线、情报或战斗条件。 | Work-package | NOT_STARTED | 0% |

## V5 Detailed Plan

- Vertical loop: produce one infantry unit → local garrison → real dispatch → result → survivors return or garrison → state writeback → save and reload.
- V5 already introduces a persistent ArmyState collection container with stable route/node IDs and progress; the V5 gameplay rule allows at most one active army.
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
- V5 P0 and P1 are implemented as one substantive first slice and await the V5-G0/G1/G2 package review.
- P0 evidence freezes the V4 checkpoint, ownership table, stable single-unit contract, garrison conservation, temporary manpower rule, rollback, and stop conditions.
- P1 uses a private `GarrisonState` under the existing `ConstructionController`, preserves `infantry_count` as a compatibility property, reuses `UnitRole`, adds a dispatchable read model, exposes “驻军 / 可派” in the city sidebar, and adds a 25-assertion focused runner.
- No persistent `ArmyState`, save schema, second unit, or S1A.2 reuse is part of this slice.

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

V5 P0/P1 now has main-agent implementation evidence: the architecture
contract, one authoritative city garrison source, compatibility/read APIs,
player-visible city-sidebar output, a 25-assertion focused runner, and 30/30
all-present regression. The 11 related tasks are
`IMPLEMENTED_PENDING_REVIEW`; V5-G0 is pending review, while V5-G1/G2 are only
partial because their required P2–P5 tasks have not started. They are not
self-upgraded to VERIFIED.

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
- V5 status is `IMPLEMENTED_PENDING_REVIEW`; this implementation record does not claim an independent package verdict.

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

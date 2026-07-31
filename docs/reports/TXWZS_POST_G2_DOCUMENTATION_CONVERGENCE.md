# TXWZS Post-G2 Documentation Convergence

## Verdict

`POST_G2_DOCUMENTATION_CONVERGENCE_COMPLETE`

Validation 已通过。范围包含 Markdown 收敛，以及主控 XLSX/CSV 对
deleted Markdown 的必要引用修正；没有运行时代码、测试语义、场景、资源、
Gate 或任务状态修改。

## Bound Baseline

| 字段 | 编辑前值 |
| --- | --- |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| HEAD | `af244167f7b0a31f3de2cc34673faa953113b96b` |
| Gate | `V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED` |
| Plan | `1.0.2-v5-g2-fresh-review-accepted-003` |
| Markdown files | 76 |
| Markdown lines | 14,940 |
| Markdown bytes | 706,926 |
| `CURRENT_STATE.md` | 372 lines / 54,512 bytes |
| Index | empty |
| Untracked/unstaged | exact 8 protected S1A.2 files |

## Inventory Findings

- byte-identical Markdown groups：0。
- 重复一级标题：0；但 V4/C0 与 V5-G2 同一 Gate 存在多份 candidate、
  repair、review 和 re-review 稿。
- 多份历史报告仍以 `PENDING`、`IMPLEMENTED_PENDING_REVIEW`、
  `REPAIRED_PENDING_INDEPENDENT_REVIEW` 或 `NOT AUTHORIZED` 描述已经被
  后续 acceptance 关闭的旧时点。
- 多份历史 handoff/report 保存本机 checkout、worktree 或 `/tmp` 绝对路径。
- 活跃规划 Markdown 引用大量将被合并或删除的历史稿。
- `CURRENT_STATE.md` 将历次状态按时间倒序累积，当前事实与历史冲突信息混排。

这些问题不改变代码或 Gate，但会污染迁移基线和 future reviewer 的入口。

## Truth Priority

本轮合并采用：

```text
Git / code / tests / identified runtime
→ af24416 acceptance checkpoint
→ canonical XLSX and five CSV mirrors
→ converged CURRENT_STATE
→ final G2 acceptance
→ historical Markdown
```

历史文本与更高层证据冲突时，只保留可追溯的历史结论，不保留过期 current
claim。

## Complete Classification

`UNKNOWN = 0`。`MERGE` 表示独特且仍有效的合同/命令/决定已进入新的活跃
文档，原文件删除或原地重写；`DELETE` 表示无剩余独特活跃内容，可由 Git
历史恢复。

| # | 原路径 | 分类 | 处置 |
| ---: | --- | --- | --- |
| 1 | `AGENTS.md` | KEEP | 阶段收尾协议继续生效 |
| 2 | `CURRENT_STATE.md` | MERGE | 原地重写为当前 Gate 快照 |
| 3 | `docs/DEV_RUN_CURRENT.md` | MERGE | 运行身份和启动命令并入 README/Current |
| 4 | `docs/architecture/CONTENT_DEFINITION_AND_LEVEL_PIPELINE_V0.md` | MERGE | 内容定义原则并入统一架构合同 |
| 5 | `docs/architecture/MINIMUM_REAL_COMBAT_CONTRACT_V0.md` | MERGE | BattleRequest/Session/Result 权威边界并入统一合同 |
| 6 | `docs/architecture/V5_ARMY_STATE_COLLECTION_CONTRACT_V0.md` | MERGE | ArmyRegistry 合同并入统一合同 |
| 7 | `docs/architecture/V5_ENCOUNTER_OUTCOME_FACTS_CONTRACT_V0.md` | MERGE | terminal facts/writeback 并入统一合同 |
| 8 | `docs/architecture/V5_SAVE_SCHEMA_MIGRATION_ROLLBACK_CONTRACT_V0.md` | MERGE | V2/migration/rollback 并入统一合同 |
| 9 | `docs/architecture/V5_SINGLE_UNIT_WAR_FOUNDATION_CONTRACT_V0.md` | MERGE | 单兵种/驻军守恒并入统一合同 |
| 10 | `docs/architecture/V5_STRATEGIC_TIME_SCENE_MATRIX_CONTRACT_V0.md` | MERGE | 时间矩阵并入统一合同 |
| 11 | `docs/architecture/V5_TRAINING_QUEUE_SOURCE_STATE_CONTRACT_V0.md` | MERGE | TrainingQueue 合同并入统一合同 |
| 12 | `docs/design/C0_BATTLEFIELD_READABILITY_V0.md` | MERGE | C0 可读性与体验边界并入统一合同 |
| 13 | `docs/design/CAMPAIGN_CITY_BATTLE_STATE_BOUNDARY_V0.md` | MERGE | 城市/战斗状态与失败后果并入统一合同 |
| 14 | `docs/design/CITY_SANDBOX_V0_TECHNICAL_CONTRACT.md` | MERGE | 格、投影、道路和表现非权威并入统一合同 |
| 15 | `docs/design/FIRST_BATTLE_GRAYBOX_RULES_V0.md` | MERGE | C0 tick/命令/结果/奖励基线并入统一合同 |
| 16 | `docs/design/NOTICEBOARD_MISSION_PACK_V0.md` | MERGE | 告示板作为非权威内容边界并入统一合同 |
| 17 | `docs/design/P0_03A_CONSTRUCTION_RESEARCH.md` | MERGE | 已接受建造决策并入统一合同 |
| 18 | `docs/design/P0_04A_BUILDING_SELECTION_DETAIL_PANEL_RESEARCH.md` | MERGE | 选择/详情/输入决策并入统一合同 |
| 19 | `docs/design/P0_05_NEXT_COHERENT_FEATURE_BUNDLE_RESEARCH.md` | MERGE | 生命周期/安全移除边界并入统一合同 |
| 20 | `docs/design/P0_06_CONDITIONAL_NEXT_COHERENT_BUNDLE_RESEARCH.md` | DELETE | 被后续统一交互方向取代的条件研究稿 |
| 21 | `docs/design/P0_06_UNIFIED_BUILDING_INTERACTION_AND_RIGHT_SIDE_CONSTRUCTION_ENTRY.md` | MERGE | 统一记录与右侧入口并入统一合同 |
| 22 | `docs/design/P1_00_FIRST_CITY_GAMEPLAY_LOOP_RESEARCH.md` | MERGE | 首图产品方向和 Gate 并入统一合同 |
| 23 | `docs/design/P1_FIRST_MAP_VERTICAL_SLICE_V0.md` | MERGE | 首图资源/时间/压力/闭环边界并入统一合同 |
| 24 | `docs/design/P1_F_CONSTRUCTION_DATAIZATION_V0.md` | MERGE | 建设数据化合同并入统一合同 |
| 25 | `docs/design/WORLD_MAP_V0.md` | MERGE | 天下地图只读 fixture 边界并入统一合同 |
| 26 | `docs/handoffs/C0_COMBAT_CONTRACT_DECISION_GATE.md` | DELETE | 历史决策 Gate，接受结论已合并 |
| 27 | `docs/handoffs/C0_REAL_COMBAT_GRAYBOX_CLOSEOUT.md` | DELETE | 历史 closeout，可由 Git 恢复 |
| 28 | `docs/handoffs/P0_GRAYBOX_FOUNDATION_STAGE_CLOSEOUT.md` | DELETE | 历史 closeout，命令已进入 README |
| 29 | `docs/handoffs/P1_CITY_TIME_AND_VIEWPORT_CORRECTION_CLOSEOUT.md` | DELETE | 历史 closeout，当前时间合同已合并 |
| 30 | `docs/handoffs/P1_FIRST_MAP_VERTICAL_SLICE_BLOCKED_AT_COMBAT_GATE.md` | DELETE | 已被后续 C0/V4/V5 状态取代 |
| 31 | `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md` | KEEP | 原地收敛为当前工作簿的人类摘要 |
| 32 | `docs/process/PROJECT_EXECUTION_GATES.md` | MERGE | Gate 和停止条件并入统一合同/README |
| 33 | `docs/reports/P0_04B_BUILDING_SELECTION_PHYSICAL_ACCEPTANCE.md` | DELETE | 历史实体接受已在 changelog 保留 |
| 34 | `docs/reports/P0_05_RUNTIME_BUILDING_LIFECYCLE_DEFERRED_PHYSICAL_TEST.md` | DELETE | 已完成的历史测试卡 |
| 35 | `docs/reports/P0_05_RUNTIME_BUILDING_LIFECYCLE_PHYSICAL_ACCEPTANCE.md` | DELETE | 历史实体接受已在 changelog 保留 |
| 36 | `docs/reports/P0_06_UNIFIED_BUILDING_INTERACTION_STAGE_ACCEPTANCE.md` | DELETE | 历史阶段接受已在架构/变更记录保留 |
| 37 | `docs/reports/TXWZS_S0_REAL_ENGINEERING_BASELINE_AUDIT.md` | DELETE | 旧工程审计，事实已被 V4/V5 基线取代 |
| 38 | `docs/reports/TXWZS_S1A1_CITY_STATE_SNAPSHOT_ROUNDTRIP.md` | MERGE | 校验、回滚和引用隔离并入持久化合同 |
| 39 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_INDEPENDENT_REVIEW_001.md` | DELETE | 被后续 repair/review 关闭 |
| 40 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_INDEPENDENT_REVIEW_002.md` | DELETE | 被后续 ownership repair/review 关闭 |
| 41 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_REPAIR_001.md` | DELETE | 中间 repair，可由 Git 恢复 |
| 42 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_REPAIR_002.md` | DELETE | 中间 repair，可由 Git 恢复 |
| 43 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_INDEPENDENT_REVIEW_003.md` | DELETE | 发现记录被 Review 004 关闭 |
| 44 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_INDEPENDENT_REVIEW_004.md` | MERGE | 最终 ownership 接受边界并入架构/变更记录 |
| 45 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_003.md` | DELETE | 中间 repair，可由 Git 恢复 |
| 46 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_004.md` | DELETE | 最终实现细节由代码/测试承担 |
| 47 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_IMPLEMENTATION_001.md` | DELETE | 实现过程稿，由代码/测试和架构替代 |
| 48 | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_INDEPENDENT_REVIEW_001.md` | DELETE | 被后续 authority reviews 取代 |
| 49 | `docs/reports/TXWZS_V4_C0_RESULT_TIME_DIAGNOSIS_001.md` | DELETE | 诊断过程已被最终合同关闭 |
| 50 | `docs/reports/TXWZS_V4_MILESTONE_CLOSURE_001.md` | MERGE | V4 freeze checkpoint 并入 current/changelog |
| 51 | `docs/reports/TXWZS_V4_P5_T001_REPAIR_001.md` | DELETE | 中间 repair，可由 Git 恢复 |
| 52 | `docs/reports/TXWZS_V4_UI_VISUAL_SLICE_IMPLEMENTATION_001.md` | DELETE | 历史实现报告，可由 Git 恢复 |
| 53 | `docs/reports/TXWZS_V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_002.md` | MERGE | 最终视觉接受边界并入 current/changelog |
| 54 | `docs/reports/TXWZS_V4_UI_VISUAL_SLICE_REPAIR_001.md` | DELETE | 中间 repair，可由 Git 恢复 |
| 55 | `docs/reports/TXWZS_V5_G1_CONTRACT_PACKAGE_001.md` | MERGE | G1 六合同索引并入统一架构 |
| 56 | `docs/reports/TXWZS_V5_G1_CONTRACT_PACKAGE_INDEPENDENT_REVIEW_001.md` | MERGE | G1 接受和测试统计并入 current/plan |
| 57 | `docs/reports/TXWZS_V5_G2_RUNTIME_PACKAGE_001.md` | MERGE | candidate 范围并入最终 G2 报告 |
| 58 | `docs/reports/TXWZS_V5_G2_RUNTIME_PACKAGE_INDEPENDENT_REVIEW_001.md` | MERGE | rollback 缺陷/repair 并入最终 G2 报告 |
| 59 | `docs/reports/TXWZS_V5_G2_STABLE_ID_BOUNDARY_REPAIR_FRESH_INDEPENDENT_REVIEW_003.md` | MERGE | 改名并收敛为最终 G2 报告 |
| 60 | `docs/reports/TXWZS_V5_G2_STABLE_ID_SEQUENCE_REPAIR_INDEPENDENT_REVIEW_002.md` | MERGE | type/range/exhaustion/V1 findings 并入最终 G2 报告 |
| 61 | `docs/reports/TXWZS_V5_P0_P1_PACKAGE_INDEPENDENT_REVIEW_001.md` | DELETE | 阻断发现已由 Review 002 关闭 |
| 62 | `docs/reports/TXWZS_V5_P0_P1_PACKAGE_INDEPENDENT_REVIEW_002.md` | MERGE | G0 acceptance 并入 current/plan/architecture |
| 63 | `docs/reports/TXWZS_V5_P2_TRAINING_TIME_IMPLEMENTATION_001.md` | DELETE | 过程报告，最终合同/测试已覆盖 |
| 64 | `docs/reports/TXWZS_V5_P3_ARMY_STATE_IMPLEMENTATION_001.md` | DELETE | 过程报告，最终合同/测试已覆盖 |
| 65 | `docs/reports/TXWZS_V5_P4_ENCOUNTER_WRITEBACK_IMPLEMENTATION_001.md` | DELETE | 过程报告，最终合同/测试已覆盖 |
| 66 | `docs/reports/TXWZS_V5_P5_CAMPAIGN_PERSISTENCE_IMPLEMENTATION_001.md` | DELETE | 过程报告，最终 G2 acceptance 已覆盖 |
| 67 | `docs/reports/TXWZS_V5_S1A2_REUSE_DECISION_001.md` | MERGE | verdict/hash/allowed path 并入 architecture/current/handoff |
| 68 | `docs/reports/TXWZS_V5_SINGLE_UNIT_GARRISON_SLICE_001.md` | MERGE | GarrisonState/compatibility 边界并入 architecture |
| 69 | `docs/reviews/TXWZS_MASTER_PLAN_REVIEW_001.md` | DELETE | 历史 plan review，可由 Git 恢复 |
| 70 | `docs/reviews/TXWZS_MASTER_PLAN_REVIEW_002.md` | DELETE | 历史 plan review，可由 Git 恢复 |
| 71 | `docs/reviews/TXWZS_MASTER_PLAN_REVIEW_003.md` | DELETE | 历史 plan review，可由 Git 恢复 |
| 72 | `docs/reviews/TXWZS_MASTER_PLAN_STATE_SYNC_001.md` | DELETE | 历史 state sync，当前 workbook 接管 |
| 73 | `docs/reviews/TXWZS_V4_P5_T001_INDEPENDENT_REVIEW.md` | DELETE | findings 已由 Review 002 关闭 |
| 74 | `docs/reviews/TXWZS_V4_P5_T001_INDEPENDENT_REVIEW_002.md` | MERGE | V4 acceptance 并入 current/changelog |
| 75 | `docs/testing/C0_COMBAT_CONTRACT_TEST_MATRIX.md` | MERGE | C0 contract coverage 并入 architecture/README |
| 76 | `docs/testing/V5_G1_CONTRACT_TEST_MATRIX.md` | MERGE | G1 coverage 与 Gate 区分并入 architecture/plan |

## Live Documentation Set

收敛后活跃 Markdown：

```text
AGENTS.md
README.md
CURRENT_STATE.md
CHANGELOG.md
docs/MIGRATION_HANDOFF.md
docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md
docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md
docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md
docs/reports/TXWZS_POST_G2_DOCUMENTATION_CONVERGENCE.md
```

没有创建 `docs/archive`。所有被删除文件仍由 Git 历史保存。

## Naming Review

技术文档的目标读者是下一位 M4 reviewer；核心收益是快速定位当前事实、
迁移边界和可恢复证据。候选命名按“状态精确、证据可对应、无整体完成误导”
排序：

1. `TXWZS V5-G2 Final Acceptance`
2. `TXWZS Architecture Contract`
3. `M4 Migration Handoff`
4. `TXWZS Post-G2 Documentation Convergence`

风险审查：

- `Final` 只修饰 V5-G2 acceptance，不表示 V5 或项目完成；
- `Migration Handoff` 不表示迁移已经执行；
- 不使用“ready to ship”“migration complete”等超出证据的标题。

## Recovery

收敛前完整文档树：

```sh
git show af24416:path/to/document.md
git log --all -- path/to/document.md
```

删除仅发生在新的本地后继提交中；没有重写 Git 历史。V5-G2 acceptance
rollback point 保持 `af24416`。

## Validation

### Markdown

| 指标 | Before | After |
| --- | ---: | ---: |
| 文件 | 76 | 9 |
| 行 | 14,940 | 1,592 |
| 字节 | 706,926 | 64,880 |
| `CURRENT_STATE.md` 行 | 372 | 239 |

- 16 个内部 Markdown/file links 已检查，missing target/anchor `0`。
- 活跃 Markdown 中用户主目录、本任务 worktree、file URI 和旧 workspace
  绝对路径命中 `0`。
- 活跃 Markdown 对 deleted historical reports 的链接依赖 `0`。
- `git diff --check` exit `0`。

### 主控工作簿

使用 bundled `artifact-tool` 导入、检查、更新和重新导出：

| 项 | 结果 |
| --- | --- |
| Sheets | 13/13 |
| Formula-error matches | 0 |
| 五 CSV `totalMismatches` | 0 |
| 视觉检查 | 13/13 sheets 完成 |
| 引用修正 | 107 个文本单元格 |
| Gate/status/formula 修改 | 0 |

工作簿及 CSV 中的 deleted Markdown 引用已映射为：

```text
CHANGELOG.md
docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md
docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md
docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md
```

保留的 `/tmp` 证据均加上
`[historical session evidence; non-required]`，不再作为运行依赖。
`roadmap.csv` 与 `acceptance_matrix.csv` byte-identical；`tasks.csv`、
`tests.csv`、`risks_and_decisions.csv` 只同步上述引用。

状态复核：

- 精确 16 项 G2 runtime task：全部 `VERIFIED`；
- V5-G0/G1/G2：`VERIFIED`；
- V5-G3/G4/G5/G6：`NOT_STARTED`；
- V5-P4-T005、P6、P7、V6：`NOT_STARTED`；
- V4：`VERIFIED`；V5：`IN_PROGRESS`。

### Godot regression

统一命令：

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path <repo> --script res://tests/<runner>.gd
```

结果：

| Basket | Exit | 结果 | 基线差异 |
| --- | ---: | --- | --- |
| G2 focused | 0 | 6/6；185 assertions | 0 |
| tracked | 0 | 33/33；1739 assertions | 0 |
| all-present | 0 | 35/35；1871 assertions；1905 PASS | 0 |
| P5 persistence | 0 | 51/51；cold A/B/C 0/0/0 | 0 |
| S1A.2 disk | 0 | 112 assertions；cold A/B/C 0/0/0 | 0 |

Focused runners：

```text
tests/run_v5_single_unit_garrison_smoke.gd
tests/run_v5_training_queue_smoke.gd
tests/run_v5_army_state_smoke.gd
tests/run_v5_encounter_writeback_smoke.gd
tests/run_v5_campaign_persistence_smoke.gd
tests/run_v5_vertical_loop_smoke.gd
```

Tracked 基线是 34 个 tracked `run_*.gd` 中排除已单独计入 focused 的
`run_v5_vertical_loop_smoke.gd`，因此为 33 runners；它保留 0 explicit
assertion 的 runtime identity runner。审计脚本初版错误地做了相反替换，
得到 33/33·1759；独立日志确认差值恰为 vertical-loop 的 20 assertions。
修正集合并使用全新日志目录重跑后得到要求的 33/33·1739。all-present
始终为 35/35·1871/1905，运行时没有统计漂移。

正式运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path <repo> --scene res://scenes/blank_map.tscn --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path <repo> \
  --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path <repo> --scene res://scenes/c0_battle_graybox.tscn \
  --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path <repo> --editor --quit
```

city、Blackstone、C0、editor 均 exit `0`，unexpected signatures `0`。

### Protected S1A.2

八文件的 before/after SHA-256 与
[最终 G2 验收清单](TXWZS_V5_G2_FINAL_ACCEPTANCE.md#s1a2-保护边界)
逐项一致。没有 stage、修改或采用这些文件。

### Git scope

- 基线：`af244167f7b0a31f3de2cc34673faa953113b96b`；
- branch：`codex/v5-g0-review-g1-contracts-001`；
- diff 中非文档规划资产只有当前 XLSX 与三份引用同步 CSV；
- `.gd`、`.tscn`、`.tres`、`.godot`、永久测试语义和 S1A.2 diff：0；
- 使用精确路径暂存，不使用 `git add -A`；
- 本报告所在 documentation commit 的 SHA 由
  `git log -1 --format=%H` 现场解析，避免自引用哈希。

## Final Boundary

完成文档 checkpoint 后停止：

```text
M4_MIGRATION_TAG_AND_GITHUB_FRESH_CLONE_READINESS
```

本轮不 push、不 tag、不 fresh clone、不部署、不进入 G3。

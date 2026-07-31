# TXWZS Master Development Control

## Control Metadata

- Plan version: `1.0.2-v5-g2-fresh-review-accepted-003`
- Updated: `2026-07-31`
- Canonical workbook:
  `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx`
- Five direct CSV mirrors: `docs/planning/csv/`
- Requirements / tasks / tests: `25 / 88 / 69`
- Gate instances: `63` (`V4–V12 × G0–G6`)
- Current phase: V4 `VERIFIED / FROZEN`; V5-G0/G1/G2 `VERIFIED`;
  V5 `IN_PROGRESS`
- Unique next action: finish the authorized post-G2 documentation checkpoint,
  then stop
- Not authorized: G3–G6, P6, P7, V6, push, tag, fresh clone, deployment

Git、代码、配置、测试和识别明确的运行时证据高于本计划。工作簿是结构化
主控；本 Markdown 是人类可读摘要；五份 CSV 是工作簿指定表的逐值镜像。

## Current Baseline

| Field | Value |
| --- | --- |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| V4 checkpoint | `5357c28` |
| V5-G0 review checkpoint | `2cc4ebf` |
| V5-G1 candidate | `b3a7f03` |
| V5-G2 original candidate | `cd7be2b` |
| V5-G2 repair chain | `cd7be2b → e2c1096 → 5d659243 → fab962c → 4d0fbfc` |
| V5-G2 acceptance checkpoint | `af244167f7b0a31f3de2cc34673faa953113b96b` |
| V5-G2 verdict | `V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED` |
| Protected untracked | exact 8 S1A.2 files |
| Upstream | none for local branch |

Durable evidence:

- [V5-G2 final acceptance](../reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md)
- [Current state](../../CURRENT_STATE.md)
- [Architecture contract](../architecture/TXWZS_ARCHITECTURE_CONTRACT.md)
- [Migration handoff](../MIGRATION_HANDOFF.md)

## V4–V12 Roadmap

| Phase | Player result | Detail | Status | Progress |
| --- | --- | --- | --- | ---: |
| V4 | 可见派遣、行军、失败/胜利与一次性到达结算 | Work-package | `VERIFIED / FROZEN` | 100% |
| V5 | 单兵种训练、驻军、派遣、战果写回、保存重载一致 | Detailed | `IN_PROGRESS` | 75% VERIFIED |
| V6 | 持久外城战区与多军队数据模型 | Medium | `NOT_STARTED` | 0% |
| V7 | 步兵遭遇战 | Work-package | `NOT_STARTED` | 0% |
| V8 | 围城状态与战事内城 | Work-package | `NOT_STARTED` | 0% |
| V9 | 第二持久城市与占领闭环 | Work-package | `NOT_STARTED` | 0% |
| V10 | 敌方战略行动 | Work-package | `NOT_STARTED` | 0% |
| V11 | 第二兵种与正式编组 | Work-package | `NOT_STARTED` | 0% |
| V12 | 工程、侦察、伏击与特殊行动 | Work-package | `NOT_STARTED` | 0% |

## V5 Scope

Vertical loop：

```text
produce infantry
→ local garrison
→ real dispatch
→ battle facts
→ survivors return or garrison
→ authoritative writeback
→ save and reload
```

任务总数 `44`：

| Work package | Count | Current boundary |
| --- | ---: | --- |
| P0 基线与合同 | 5 | `VERIFIED` |
| P1 单兵种与驻军 | 6 | `VERIFIED` |
| P2 训练与时间 | 7 | G1 contracts + G2 runtime `VERIFIED` |
| P3 派遣与军队 | 6 | G1 contract + G2 runtime `VERIFIED` |
| P4 战果写回 | 5 | T001 contract、T002–T004 runtime `VERIFIED`; T005 `NOT_STARTED` |
| P5 存档与迁移 | 5 | G1 decisions/contracts + G2 runtime `VERIFIED` |
| P6 最小军备 UI | 3 | `NOT_STARTED` |
| P7 验证与冻结 | 7 | `NOT_STARTED` |

### Exact G2 runtime tasks

```text
V5-P2-T002  V5-P2-T003  V5-P2-T005  V5-P2-T006  V5-P2-T007
V5-P3-T002  V5-P3-T003  V5-P3-T004  V5-P3-T005  V5-P3-T006
V5-P4-T002  V5-P4-T003  V5-P4-T004
V5-P5-T003  V5-P5-T004  V5-P5-T005
```

这 16 项和 V5-G2 已独立接受。没有因此接受 P4-T005、P6、P7 或 G3。

## Gate Model

```text
G0 baseline
→ G1 ownership/contracts
→ G2 automated vertical loop
→ G3 full regression
→ G4 real window
→ G5 independent review
→ G6 user playtest/freeze
```

只有 `VERIFIED` 计入完成。`CANCELLED` 仅在绑定已接受决策记录时从分母
移除。

| Gate | Status | Evidence boundary |
| --- | --- | --- |
| V5-G0 | `VERIFIED` | 单兵种、驻军源状态、容量阻断、独立复查 |
| V5-G1 | `VERIFIED` | 六项架构合同、51/51 baseline、30/30 cross-contract |
| V5-G2 | `VERIFIED` | fresh stable-ID review、focused/tracked/all-present |
| V5-G3 | `NOT_STARTED` | 不由本轮重复回归自动推进 |
| V5-G4 | `NOT_STARTED` | 真实窗口垂直闭环尚未执行 |
| V5-G5 | `NOT_STARTED` | 阶段级独立复查尚未执行 |
| V5-G6 | `NOT_STARTED` | 用户试玩和 V5 冻结尚未执行 |

## G2 Acceptance Summary

Fresh reviewer：
`/root/v5_g2_boundary_fresh_independent_reviewer_003`。

| Basket | Result |
| --- | --- |
| boundary probe | 29/29 |
| P5 permanent runner | 51/51 |
| G2 focused | 6/6 · 185 |
| tracked | 33/33 · 1739 |
| all-present | 35/35 · 1871 assertions / 1905 PASS |
| V5 cold workers | A/B/C 0/0/0 |
| S1A.2 cold workers | A/B/C 0/0/0 |
| formal city / Blackstone / C0 / editor | exit 0 |

`fab962c` 的精确四文件 repair 关闭：

- sequence type coercion；
- JSON-safe exact integer range；
- successor 与 exhausted sentinel；
- Army reservation 前失败；
- 合法 V1 空队列历史下单日迁移；
- 失败零部分写入。

## Architecture

| Layer | Persistence | Boundary |
| --- | --- | --- |
| 常态内城 | Persistent | buildings, resources, training, garrison, time |
| 外城战区 | Persistent-changing | routes, logical positions, armies, encounters |
| 战事内城 | Battle instance | battle-only walls/gates/defenders; no second city truth |
| 天下地图 | Persistent overview | cities, factions, campaign actions |

当前唯一城市写入者是 `ConstructionController`；本城兵力来自私有
`GarrisonState`；训练来自 `TrainingQueue`；军队来自集合型
`ArmyRegistry`；`BattleSession` 只产出事实；coordinator 授权写回。

## S1A.2

Verdict：`CONDITIONAL_REUSE_ACCEPTED`。

V5 复用严格校验、不可变代次、临时写/flush/复读/发布、SHA-256、
writer lock、上一有效代次恢复和 V1 read-only import 思路。八个 V1 文件
不成为 V5 writer/schema，并继续 untracked、unstaged。

精确清单和 SHA-256 见
[CURRENT_STATE.md](../../CURRENT_STATE.md#s1a2-保护)。

## Workbook and Mirrors

- Workbook sheets: `13`
- Formula-error matches: `0`
- Five CSV mirror mismatches: `0`
- Markdown title and current Gate data match plan version
  `1.0.2-v5-g2-fresh-review-accepted-003`

Mirrors:

```text
docs/planning/csv/roadmap.csv
docs/planning/csv/tasks.csv
docs/planning/csv/acceptance_matrix.csv
docs/planning/csv/tests.csv
docs/planning/csv/risks_and_decisions.csv
```

不得独立编辑镜像。任何状态变化必须先更新工作簿，再在同一 planning change
中重导 Markdown/CSV。

## Next Control Point

完成并提交本轮纯文档收敛后停止。下一任务只有在用户明确授权后才是：

```text
M4_MIGRATION_TAG_AND_GITHUB_FRESH_CLONE_READINESS
```

该任务之前不创建 tag、不 push、不 fresh clone、不进入 G3。

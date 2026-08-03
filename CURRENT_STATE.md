# 当前状态

## 结论

`TXWZS2_R2C_02_FIRST_WAR_RUNTIME_OPERATION_LIFECYCLE_COMPLETE`

V4 已冻结，V5-G0、G1、G2 已 `VERIFIED`，V5 整体仍为 `IN_PROGRESS`。
G3–G6、P6、P7、V6 尚未启动。

R2C-01 已将国家共享资源的运行时所有权收敛到单一 `NationState`。生产场景
仍由现有 `ConstructionController` 编排，但建造、日结、训练、科研和兼容属性
全部委托同一个国家资源事务入口。`blackstone_city` 与 `riverbend_city` 已进入
正式运行时城市注册边界；P0-01 继续提供一城只读兼容投影。

V5 schema 和磁盘 topology 未升级。旧 `blackstone_city` 资源字段仅作为兼容
序列化载体，在 load 时通过临时 DTO 水合 `NationState`，save 时从
`NationState` 投影。`riverbend_city` 的完整城市局部状态尚未进入 V5 持久化，
不在本轮声称完成。

R2C-02 在既有 `ArmyRegistry`、`ConstructionController` 和绑定的
`CombatTransactionCoordinator` 上完成一条固定的无头 First War 运行时闭环：
`blackstone_city` 派遣至 `riverbend_city`，由 `BattleSession` 产出 terminal
facts，所有幸存者经既有返乡 phase 回到黑石堡。它没有新增 operation aggregate、
ledger、ID sequence 或持久战区；Riverbend 没有 owner、faction、驻军或局部状态
变化。本轮没有既定资源后果。

## Git 基线

| 字段 | 值 |
| --- | --- |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| G2 acceptance checkpoint | `af244167f7b0a31f3de2cc34673faa953113b96b` |
| Post-G2 documentation convergence | `b1ad4a09e202904aced9262104545867a97573cb` |
| P0-01 national read-model seam | `81fe8a8f479b05952a910b53e66dd4608582dc27` |
| R2C-01 national resource convergence | `a0406ede852da687ed5033a24471b43f7ebdf2ab` |
| Upstream | 本地 branch 无 upstream |
| Remote action | M4 仅使用显式 branch/tag refs；结果以 `git ls-remote` 与 fresh clone 现场证据为准 |
| Index | 只按精确路径暂存；不得 stage S1A.2 |
| Porcelain / tracked worktree | clean |
| Nonignored untracked | `0` |
| Named protected S1A.2 present | `0` |
| Ignored generated `.godot/**` | `82`（实施前现场计数） |

V5-G2 链：

```text
cd7be2b
→ e2c1096
→ 5d659243
→ fab962c
→ 4d0fbfc
→ af24416
→ b1ad4a0
→ cb7c87ba
→ 81fe8a8f
→ a0406ede
```

`fab962c` 的精确 repair 范围：

```text
scripts/army/training_queue.gd
scripts/army/army_registry.gd
scripts/construction_controller.gd
tests/run_v5_campaign_persistence_smoke.gd
```

## Gate 状态

| Gate / phase | 状态 |
| --- | --- |
| V4 | `VERIFIED / FROZEN` |
| V5-G0 | `VERIFIED` |
| V5-G1 | `VERIFIED` |
| V5-G2 | `VERIFIED` |
| V5 | `IN_PROGRESS` |
| V5-G3 | `NOT_STARTED` |
| V5-G4 | `NOT_STARTED` |
| V5-G5 | `NOT_STARTED` |
| V5-G6 | `NOT_STARTED` |
| V5-P4-T005 | `NOT_STARTED` |
| V5-P6 | `NOT_STARTED` |
| V5-P7 | `NOT_STARTED` |
| V6 | `NOT_STARTED` |

精确 16 项 G2 runtime task：

```text
V5-P2-T002  V5-P2-T003  V5-P2-T005  V5-P2-T006  V5-P2-T007
V5-P3-T002  V5-P3-T003  V5-P3-T004  V5-P3-T005  V5-P3-T006
V5-P4-T002  V5-P4-T003  V5-P4-T004
V5-P5-T003  V5-P5-T004  V5-P5-T005
```

它们和 V5-G2 均已 `VERIFIED`。G1 的六项合同任务已在独立 Gate 接受，不
重复计入。

## 当前架构事实

- `NationState` 是国家共享木材、粮食和科技点的唯一运行时 authority；所有
  正式资源变化经过 `commit_resource_transaction()`。
- `ConstructionController` 是日期、建设、训练、驻军和恢复的业务编排入口；
  `wood`、`food`、`tech_points` 仅是委托到 `NationState` 的兼容属性，不持有
  第二份余额。
- 一次正式城市场景运行只构造一个 `NationState`，同时注册
  `blackstone_city` 与 `riverbend_city`；两城局部运行时状态实例彼此隔离。
- 私有 `GarrisonState` 是本城兵种数量唯一源状态；`infantry_count` 是兼容
  属性，不是第二份存储。
- `TrainingQueue` 是训练订单唯一源状态；旧三字段仅为只读兼容投影。
- `ArmyRegistry` 是集合型持久模型；V5 最多一支 active 是校验策略，不是
  singleton 数据结构。
- `BattleSession` 只产出 terminal facts；城市写回由绑定的
  `CombatTransactionCoordinator` 授权。
- R2C-02 固定 First War army path 不建立目标驻扎：所有幸存者进入既有
  `RETURNING` phase，随后只回补 `blackstone_city` 的 `GarrisonState`。
- `CampaignSnapshotV2`、V5 codec/store、V1 只读迁移、不可变代次、坏档
  fallback 和 live apply rollback 已实现。
- 天下地图 V0 仍是只读表现 fixture，不是持久世界状态。

完整合同见
[TXWZS_ARCHITECTURE_CONTRACT.md](docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md)。

## Stable ID 与原子性

Training/Army sequence：

- 必须是 `TYPE_INT`；
- 必须在 `1..9007199254740991`；
- 必须大于快照内既有最大 ID；
- 上限值是合法 exhausted sentinel；
- `MAX-1` 可分配一次，之后创建失败且零写入。

Army sequence exhausted 时，控制器必须在 reservation、transaction、
registry 或 garrison 写入前失败。

以下失败边界已独立确认零部分写入：

- malformed 或 stale sequence restore；
- Training 资源、容量、供养或 exhausted create；
- Army 容量、active limit 或 exhausted reservation；
- 重复/冲突结果写回；
- 非法 V1 migration；
- invalid store preflight；
- write、publish、final reread 和 live apply 注入失败。

合法 V1 空训练队列允许保留已经验证的历史下单日，并能迁移到 V2。

## V5-G2 验收证据

fresh reviewer：

```text
/root/v5_g2_boundary_fresh_independent_reviewer_003
```

独立结果：

| 项 | 结果 |
| --- | --- |
| boundary probe | 29/29，exit 0 |
| P5 persistence | 51/51，exit 0 |
| G2 focused | 6/6，185 assertions |
| tracked | 33/33，1739 assertions |
| all-present | 35/35，1871 assertions / 1905 PASS |
| V5 cold workers | A/B/C 0/0/0 |
| S1A.2 cold workers | A/B/C 0/0/0 |
| city / Blackstone / C0 | exit 0，error signatures 0 |
| editor | exit 0，error signatures 0 |
| diff checks | exit 0 |

上述统计与要求基线无差异。最终验收报告见
[TXWZS_V5_G2_FINAL_ACCEPTANCE.md](docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md)。

## S1A.2 保护

裁决保持 `CONDITIONAL_REUSE_ACCEPTED`：复用存储机制与 V1 只读输入，不
采用 V1 writer/schema。

| 文件 | SHA-256 |
| --- | --- |
| `scripts/state/early_city_save_store_v1.gd` | `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` |
| `scripts/state/early_city_save_store_v1.gd.uid` | `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd` | `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` | `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` | `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` |
| `tests/s1a2_early_city_disk_worker.gd` | `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` |
| `tests/s1a2_early_city_disk_worker.gd.uid` | `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` |

上述八文件保留为历史 G2 保护证据；当前 Candidate 现场不存在这些 named
untracked 路径，未被 stage、恢复或迁移。

## 主控计划

- Plan version：`1.0.2-v5-g2-fresh-review-accepted-003`
- Workbook：13 sheets
- Formula errors：0
- Workbook ↔ 5 CSV：`totalMismatches=0`
- V5 进度：75% VERIFIED
- R2C-02 是 G2 后、刷新 G3 前的已授权纠偏提交；G3 尚未启动

权威计划文件：

- [TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx](docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx)
- [TXWZS_MASTER_DEVELOPMENT_CONTROL.md](docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md)
- `docs/planning/csv/` 下五份镜像。

## 当前运行与验证

Godot：`4.5.1.stable.official.f62fdbde1`；project feature set `4.5`。

正式 CITY 入口：

```text
RUN_CURRENT_TXWZS.command
```

Headless：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 5
"$GODOT" --headless --path . --editor --quit
```

单个测试：

```sh
"$GODOT" --headless --path . --script res://tests/run_v5_vertical_loop_smoke.gd
```

窗口中的 `branch@commit`、`DEBUG`、`DIRTY`、`UNIDENTIFIED`、`CITY` 和
`BATTLE-C0` 必须按 README 的身份规则解释。自动输入和截图不能替代真实
鼠标体验。

## 文档与恢复

活跃文档只有：

- `README.md`
- `CURRENT_STATE.md`
- `docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md`
- `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md`
- `docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md`
- `docs/reports/TXWZS_POST_G2_DOCUMENTATION_CONVERGENCE.md`
- `CHANGELOG.md`
- `docs/MIGRATION_HANDOFF.md`
- `AGENTS.md`

被删除的历史 Markdown 仍可从 `af24416` 或更早 Git 历史恢复。没有创建
`docs/archive`，也没有重写 Git 历史。

## 下一步与禁止项

本轮完成的已授权范围：

```text
TXWZS2_R2C-02_FIRST_WAR_RUNTIME_OPERATION_LIFECYCLE
```

```text
P0_02_DISPOSITION=ABSORBED_AND_CLOSED_BY_R2C_01_V4
R2C02_SEQUENCE=PRE_G3_CORRECTIVE_SLICE
```

下一步只能是 refreshed V5-G3 的单独授权。R2C-03 不自动成为下一步；永久
occupation 留在 V9。persistent external theater 与 mid-operation restart 留在
V6，本轮不声称已完成它们。

当前禁止：

- 进入 G3，除非获得 refreshed V5-G3 的单独授权；
- 开始 R2C-03 永久占领或重开 P0-02；
- 将 `riverbend_city` 完整局部状态写入 V5，或未经裁决升级 V6；
- 扩展驻军、战役、占领、道路、补给、UI、场景或资产；
- stage S1A.2；
- force push、批量推送其他 refs、部署；
- 清理或迁移存档；
- 把测试通过扩写为用户体验或发布结论。

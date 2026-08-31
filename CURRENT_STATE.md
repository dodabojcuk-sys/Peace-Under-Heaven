# 当前状态

## M0 R0C single build slot and ready placement

R0C replaces the R0B map-foundation order with one current-city build slot.
Buildings register off-map, pay through the existing `NationState` ledger as
pressure-adjusted progress advances, wait at the last paid progress when
materials are missing, and become one fully paid ready token at 100%. A legal
ready-placement click creates one completed building without a second payment
and exits placement; roads retain their independent drag flow.

Campaign persistence is schema 5 with one `build_slot`. Schema 4 foundations
remain non-destructive legacy records and lock only the new slot until they
finish. New-flow priority is removed; legacy priority remains readable.

The focused 33-assertion input runner, 48/48 dynamic regression with 2,321
explicit assertions, three cold-process ready-token roundtrips, physical mouse
zero-material smoke, ten native screenshots, and an uncut 16.466-second
H.264/yuv420p MP4 pass. Founder live smoke remains pending. No push, merge,
deploy, or new gameplay is authorized.

`R0C_ENGINEERING_CANDIDATE=PASS_PENDING_FOUNDER_LIVE_SMOKE`

`R0C_FULL_REGRESSION=48_OF_48_PASS`

`R0C_SAVE_SCHEMA=5`

`R0C_VIDEO=MP4_H264_YUV420P_PASS`

## M0 R0B direct click and explicit failure feedback

R0B is an isolated engineering candidate based on exact R0A commit
`80908263fbf09cbec963ba4c582ff9b22adea894`. Building placement now commits from
one legal map left click, exits after one order, rotates with `R`, and cancels
with right click or `Esc`. The building confirmation button is removed.

Invalid placement shows a stable exact reason in the rail and a replacing
2.5-second map message. Timed construction shortages remain orderable under the
existing incremental-payment contract and state the exact missing amount plus
`下单后将等待材料`. Save schema 4 and all R0/R0A legality, pause, construction,
pressure, and persistence behavior remain unchanged.

The focused 26-assertion real-input runner and full 47/47 dynamic regression
pass. Native real-mouse 1152x648 smoke, six inspected screenshots, and an
inspected 12.267-second H.264 MP4 pass. Founder live smoke remains pending; no
push, merge, deploy, or new gameplay is authorized.

`R0B_ENGINEERING_CANDIDATE=PASS_PENDING_FOUNDER_LIVE_SMOKE`

`R0B_FULL_REGRESSION=47_OF_47_PASS`

`R0B_VIDEO=MP4_H264_420V_PASS`

## M0 time, construction, and level pressure slice

The conditionally authorized M0 slice is implemented on the isolated
`codex/txwzs-m0-time-build-pressure-r0` branch. `ConstructionController`
remains the only strategic time and placement writer, and `NationState` remains
the only shared-resource writer. Timed buildings now advance on fixed 1000 ms
ticks, pay cumulative costs incrementally, pause on missing resources, resume
without losing progress, and expose high/normal/low priority.

`CurrentMainlineLevel` owns the persistent day-7 deadline, five monotonic
pressure stages, committed permanent losses, clear state, and event IDs.
Security mitigates consequences without clearing or reversing pressure; five
essential channels retain a 25% anti-softlock floor. V5 campaign persistence is
schema 4 with explicit V2/V3 migration and exact M0 roundtrip coverage.

The final 45-runner regression, editor import, formal headless scene smokes,
V5 cold-process persistence, and native 1440x900/1280x720 evidence pass. Video
was not recorded. This is local-only engineering evidence pending Founder
review, not an overall MVP freeze, merge, push, deployment, or authorization to
start subsequent game systems.

`M0_TIME_BUILD_PRESSURE=PASS_LOCAL_ONLY_PENDING_FOUNDER_REVIEW`

`M0_FULL_REGRESSION=45_OF_45_PASS`

`M0_VIDEO=NOT_RECORDED`

## Product successor UI-R0

`codex/product-successor-inner-city-r0` is the only mutable product branch.
R1 extends its one-city inner-city presentation slice with a regular
axial/ward graybox spatial foundation, a responsive right construction rail,
minimap, four-way authoritative building orientation, and V5-compatible
orientation persistence. `NationState` and the existing construction authority
remain the only resource and placement owners. This does not start G4–G6,
R2C-03, V6, legacy cleanup, or a broader save/schema migration.

`VISUAL_STATUS=GRAYBOX_SPATIAL_FOUNDATION`

`FINAL_BUILDING_ART=NOT_STARTED_BY_SCOPE`

## R3A graybox building presence

R3A adds `GrayboxBuildingVisual` as the shared procedural presentation layer
for fixed buildings, placement ghosts, construction stages, and completed
runtime buildings. It consumes the existing `ConstructionController` records;
it does not own resources, roads, lifecycle, orientation persistence, or save
data. The visual stages are foundation, frame/partial mass, and completed,
derived from the existing construction start/completion days. N/E/S/W entrance
markers and rotated footprints are taken from the authoritative controller.

The R3A focused contract covers real building definitions, distinct
farm/logging-camp/warehouse graybox silhouettes, connected/disconnected
entrance states, pause stability, V5 orientation restoration, and no state
mutation. The complete current smoke suite is `42/42 PASS`; editor parse/import
and the formal `blank_map`, Blackstone, and C0 headless smokes also pass.

`R3A_NATIVE_WINDOW=VERIFIED`

`R3A_EVIDENCE=EXTERNAL_ONLY`

Evidence directory:
`/Users/m4-zhi/Downloads/txwzs2-r3a-graybox-building-presence-evidence-20260821-v1`

`ORGANIC_GARDEN_CITY=R3B_ACCEPTED_NATIVE_AND_HEADLESS`

`FINAL_BUILDING_ART=NOT_STARTED_BY_SCOPE`

## R3B dual-city layout profiles

R3B adds the stable `blackstone_city` -> `REGULAR_IMPERIAL` and
`riverbend_city` -> `ORGANIC_GARDEN` profile mapping through
`CityLayoutProfileResolver`. Blackstone keeps the accepted regular axial/ward
layout. Riverbend is a formal world-map entry using an authored orthogonal
garden layout with offset/T roads, unequal wards, one large reserve, two small
reserves, an off-centre civic court, and four rotations of the existing single
`CityGateComponentR1`.

The existing `ConstructionController` remains the sole writer. City switching
captures and restores only in-memory runtime building and player-road records;
the national resource ledger remains shared. V5 and early single-city save
export/restore fail closed while Riverbend is active because no multi-city save
schema was authorized. The right rail, placement, road tool, minimap,
selection, Escape behavior, and input routing are reused.

Focused R3B resolver/geometry and dual-city navigation runners pass. The full
44-runner regression, editor parse/import, formal-scene smokes, native
Blackstone → Riverbend → native build/rotate/confirm/construction/completion →
Blackstone flow, and 1280/1440/actual-1920x960 window evidence are captured in
the external evidence package. No final art, curved roads, traffic, full-map
rotation, G4, push, or deployment is claimed.

R1C 已关闭正式内城的原生鼠标建造阻断：右侧确认按钮的鼠标悬停不会再被
`MapPanController` 根输入路由误转成地图预览，合法 placement 可由真实鼠标
单击一次进入施工并在正常时间推进后落成。权威建造、资源扣除、取消、V5
方向存读档和旧 schema 北向兼容均保持原路径；当前视觉仍为灰盒基础。

## R2B player road construction

R2B 在正式 55×35 规则城池中加入玩家铺路工具。正式基础道路仍由
`RegularCitySpatialFoundation` 提供；玩家新增道路作为
`ConstructionController` 的普通 V5 placement 增量写入，视觉、N/E/S/W
连通性、建筑入口状态和存读档均读取同一合并集合，不保存重复的连通或运行
布尔值，也不升级 V5 schema。

右侧道路入口支持原生鼠标水平/垂直拖拽、局部预览、连接/孤立/阻断文字、一次
性确认和取消。确认通过现有 `NationState` 木材事务逐格原子写入；取消和
Escape 不写入、不扣费。道路连接已落成且需要道路的建筑后，状态立即从停用
派生为运行，生产从下一次权威日结开始生效。道路拓扑以灰盒绘制直线、转角、
T 型、十字和端点；旧 V5 存档缺少道路 placement 时仍恢复为空增量。

当前本地实现已通过 R2B focused headless smoke、41/41 runner 全量回归、编辑器
解析和三个正式场景 smoke；实现提交为 `3b6099f`。真实 Godot 窗口的原生鼠标
hover/drag/click 证据尚未取得：隔离运行进程已绑定本 Successor，但桌面前景仍
是既有 Godot 项目管理器，Computer Use 无法安全定位临时运行窗口。因此本轮
保持 `PARTIAL_WITH_EXACT_ROAD_TOOL_BLOCKERS`，不得把自动化测试当作原生鼠标
通过。道路删除/升级、交通寻路、桥梁坡度、曲线道路、有机城池、正式美术、
全图旋转、G4、push 和 deploy 仍未启动。

## 结论

`TXWZS2_V5_G3_REFRESHED_FULL_REGRESSION_AND_TRACEABILITY_ACCEPTED`

V4 已冻结，V5-G0、G1、G2、G3 已 `VERIFIED`，V5 整体仍为 `IN_PROGRESS`。
G4–G6、P6、V6 尚未启动；P7 仅其 G3 的 T001–T003 已 `VERIFIED`。

`712dcbd8e092ff844c4274a2f3a3c260d29998e7` 是本次 refreshed G3 的
validated source head。G3 在仓库外隔离 tree、隔离 `user://` 与 Godot 4.5.1 下
重跑了全部动态发现 runner、focused 回归、editor parse/import 与三个正式场景
smoke；它不构成 G4 实际窗口、G5 独立复查、G6 用户试玩或 V5 冻结。

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
| R2C-02 First War lifecycle / validated G3 source | `712dcbd8e092ff844c4274a2f3a3c260d29998e7` |
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
→ 712dcbd8
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
| V5-G3 | `VERIFIED` |
| V5-G4 | `NOT_STARTED` |
| V5-G5 | `NOT_STARTED` |
| V5-G6 | `NOT_STARTED` |
| V5-P4-T005 | `VERIFIED` |
| V5-P6 | `NOT_STARTED` |
| V5-P7 | `T001–T003 VERIFIED; T004–T007 NOT_STARTED` |
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

- Plan version：`1.0.3-v5-g3-refreshed-full-regression-accepted-001`
- Workbook：13 sheets
- Formula errors：0
- Workbook ↔ 5 CSV：`totalMismatches=0`
- V5 进度：84% VERIFIED（37/44）
- R2C-02 是 G2 后的已授权纠偏提交，并已成为 `712dcbd8` refreshed G3 基线；G3
  通过不提前启动 G4、G5、G6、R2C-03 或 V6

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
- `docs/reports/TXWZS_V5_G3_REFRESHED_FULL_REGRESSION.md`
- `docs/reports/TXWZS_POST_G2_DOCUMENTATION_CONVERGENCE.md`
- `CHANGELOG.md`
- `docs/MIGRATION_HANDOFF.md`
- `AGENTS.md`

被删除的历史 Markdown 仍可从 `af24416` 或更早 Git 历史恢复。没有创建
`docs/archive`，也没有重写 Git 历史。

## 下一步与禁止项

R3B is the current accepted successor slice. The profile implementation,
headless regression, native dual-city flow, and responsive window evidence are
captured; its local commits are the only remaining repository state transition
for this turn. After R3B closes, G4 still requires a separate authorization.

已完成的最近两个已授权范围：

```text
TXWZS2_R2C-02_FIRST_WAR_RUNTIME_OPERATION_LIFECYCLE
TXWZS2_V5_G3_REFRESHED_FULL_REGRESSION_AND_TRACEABILITY_ACCEPTANCE
```

```text
P0_02_DISPOSITION=ABSORBED_AND_CLOSED_BY_R2C_01_V4
R2C02_SEQUENCE=PRE_G3_CORRECTIVE_SLICE
```

下一步只能是单独授权的 V5-G4 real-window gate。R2C-03 不自动成为下一步；永久
occupation 留在 V9。persistent external theater 与 mid-operation restart 留在
V6，本轮不声称已完成它们。

当前禁止：

- 进入 G4、G5 或 G6，除非分别获得授权；
- 开始 R2C-03 永久占领或重开 P0-02；
- 将 `riverbend_city` 完整局部状态写入 V5，或未经裁决升级 V6；
- 扩展驻军、战役、占领、道路交通、补给、UI、场景或资产；
- stage S1A.2；
- force push、批量推送其他 refs、部署；
- 清理或迁移存档；
- 把测试通过扩写为用户体验或发布结论。

## R2A road-lot-entrance semantic closure

R2A is implemented on the active product-successor branch from
`86e25a47d14a2c5041518d2e67a06268eef25503`. The regular-city foundation now
owns the formal road/reserved/wall/gate cell projection used by both graybox
rendering and construction validation. `CityGridRules` is the shared entrance
adapter for the existing `road_anchor_offsets` definitions and all four
orientations.

The authority remains `ConstructionController` plus the existing V5 snapshot
and save-store path. No operational flag, writer, autoload, schema version,
scene, resource cost, or road-construction tool was added. Legal disconnected
lots remain buildable but amber/disabled after completion until their derived
entrance contacts a connected formal road; protected cells and existing
buildings fail with concrete reasons.

Verification for this slice: the focused R2A road/lot/entrance runner passes
16/16; all 40 discovered smoke runners (the existing 39 plus the focused
runner) pass with 0 failures; Godot 4.5.1 editor parse/import and the formal
blank_map, Blackstone, and C0 headless smokes exit 0. Native 1440x900 evidence
also covers road rejection, amber disconnected placement, west-facing green
placement, native confirmation, construction, completion, and connected detail.
Versioned save/load re-derivation remains covered by the focused headless test;
the current shell exposes no user-facing save button, so no claim is made that
the visual shell itself provides a save action.

R2B player road construction, road removal, traffic/pathfinding, organic garden
city, final art, G4, push, and deployment remain not started.

## M0 R0A building-road and construction UI repair

R0A is an isolated engineering pass pending Founder live smoke. Root cause was
`BOTH`: four Blackstone lower-row fixed buildings logically occupied formal-road
row 13, and graybox shadows also extended beyond their footprints. The authored
row now ends before the road; visual shadows remain inside occupancy.

All new building/road placement, move, rotation, default-map scan, and legacy
diagnostics share one structured legality contract. Schema 4 is unchanged;
legacy overlaps are preserved and reported, never auto-moved or deleted. The
lumber-camp panel exposes one primary state with road, progress, material, ETA,
priority, and output feedback. Full regression is 46/46; ten static images and
one 17.01-second continuous Godot recording are in `docs/m0/evidence/r0a/`.

Founder live smoke remains pending. Do not push, merge, deploy, or start new
gameplay from this result.

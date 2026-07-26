# TXWZS.S0 真实工程基线审计与首个稳定闭环规划

- 审计日期：2026-07-27
- 任务：`TXWZS.S0`
- 性质：只读工程审计
- 验收状态：`ACCEPTED / FROZEN AS S0 DOCUMENT BASELINE`
- 推荐路径：`A. 继续在现有工程中小步修复`
- 下一任务建议：`TXWZS.S1A — 早期城市日结算与版本化存读档闭环`
- 源码修改：否
- 场景、资源、配置、测试修改：否
- S0 审计阶段 Git 提交：否；本报告由后续 S0F docs-only 提交冻结
- S1 状态：未开始

## A. Repository Identity

| 项目 | 审计事实 |
| --- | --- |
| 工作目录 | `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2` |
| 仓库根目录 | `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2` |
| Godot 项目文件 | `project.godot` |
| 当前分支 | `main` |
| HEAD | `228ae52fa1954d38b0598491a67b0d5161bb7998` |
| Godot 版本 | `4.5.1.stable.official.f62fdbde1` |
| 项目主场景 | `res://scenes/blank_map.tscn` |
| Autoload | `RuntimeIdentity="*res://scripts/runtime_identity.gd"` |
| 标准启动入口 | `RUN_CURRENT_TXWZS.command` |
| 标准场景标签 | `CITY` |

`project.godot:13` 仍使用历史项目名
`TXWZS-P0-00-BASELINE`，但 `project.godot:14` 的实际主场景是
`blank_map.tscn`。项目名是旧基线标签，不代表当前实现仍停在 P0。

审计开始时已有一个登记中的 GUI 运行实例：

```text
PID 34215
scene=CITY
branch=main
commit=228ae52
dirty=0
```

该实例的启动日志没有脚本、场景或资源错误，并显示：

```text
TXWZS_RUNTIME_IDENTITY 天下无战事 · CITY · main@228ae52 · DEBUG
```

但是审计时实际工作树已经 dirty，因此这个窗口的 `dirty=0` 只代表它
启动时的状态，不能代表当前工作树身份。本轮没有关闭或重启该窗口。

## B. Git And Working Tree State

审计开始时：

```text
 M CURRENT_STATE.md
?? docs/design/CAMPAIGN_CITY_BATTLE_STATE_BOUNDARY_V0.md
```

分类：

- staged：0；
- unstaged：1 个，`CURRENT_STATE.md`；
- untracked：1 个，
  `docs/design/CAMPAIGN_CITY_BATTLE_STATE_BOUNDARY_V0.md`。

这两项均为审计开始前的用户工作。本轮没有修改、覆盖、暂存或清理它们。

本地跟踪引用显示：

```text
origin/main = b3114c24b3809fe1157a73905279a6543ee74e2e
origin/main...HEAD = behind 0 / ahead 26
```

本轮没有执行 `fetch`，因此这里只是本地 `origin/main` 跟踪引用，不是
远端实时确认。

测试和 headless 加载后，除本报告外，工作树与审计开始时相同。Godot
使用已有的忽略目录 `.godot/`，没有产生新的可见源码修改。

## C. Documents Reviewed

已按项目优先级检查：

1. `AGENTS.md`
2. `CURRENT_STATE.md` 及其未提交 diff
3. `project.godot`
4. `docs/DEV_RUN_CURRENT.md`
5. `RUN_CURRENT_TXWZS.command`
6. `docs/process/PROJECT_EXECUTION_GATES.md`
7. `docs/handoffs/P0_GRAYBOX_FOUNDATION_STAGE_CLOSEOUT.md`
8. `docs/handoffs/P1_CITY_TIME_AND_VIEWPORT_CORRECTION_CLOSEOUT.md`
9. `docs/handoffs/P1_FIRST_MAP_VERTICAL_SLICE_BLOCKED_AT_COMBAT_GATE.md`
10. `docs/handoffs/C0_COMBAT_CONTRACT_DECISION_GATE.md`
11. `docs/handoffs/C0_REAL_COMBAT_GRAYBOX_CLOSEOUT.md`
12. `docs/reports/P0_04B_BUILDING_SELECTION_PHYSICAL_ACCEPTANCE.md`
13. `docs/reports/P0_05_RUNTIME_BUILDING_LIFECYCLE_DEFERRED_PHYSICAL_TEST.md`
14. `docs/reports/P0_05_RUNTIME_BUILDING_LIFECYCLE_PHYSICAL_ACCEPTANCE.md`
15. `docs/reports/P0_06_UNIFIED_BUILDING_INTERACTION_STAGE_ACCEPTANCE.md`
16. `docs/design/P1_00_FIRST_CITY_GAMEPLAY_LOOP_RESEARCH.md`
17. `docs/design/P1_FIRST_MAP_VERTICAL_SLICE_V0.md`
18. `docs/design/P1_F_CONSTRUCTION_DATAIZATION_V0.md`
19. `docs/design/CITY_SANDBOX_V0_TECHNICAL_CONTRACT.md`
20. `docs/design/WORLD_MAP_V0.md`
21. `docs/design/CAMPAIGN_CITY_BATTLE_STATE_BOUNDARY_V0.md`
22. `docs/architecture/MINIMUM_REAL_COMBAT_CONTRACT_V0.md`
23. `docs/architecture/CONTENT_DEFINITION_AND_LEVEL_PIPELINE_V0.md`
24. `docs/testing/C0_COMBAT_CONTRACT_TEST_MATRIX.md`

仓库根目录没有 `README`、`DECISIONS` 或 `CHANGELOG` 文件，无法审阅这
三类资料。历史阶段事实主要散布在 `CURRENT_STATE.md`、`docs/handoffs`
和设计文档中。

文档结论没有被直接采信；以下判断同时核对了场景、脚本、资源和本轮
实际运行结果。

## D. Runtime And Test Evidence

### 实际执行

1. Godot 版本：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
```

结果：`4.5.1.stable.official.f62fdbde1`。

2. Headless editor scan：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" --editor --quit
```

结果：exit 0；完成文件系统、全局类、GDExtension、autoload 和场景扫描，
没有脚本、场景或资源错误。

3. 当前主场景 headless 加载：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" --quit-after 3
```

结果：exit 0；实际进入 `blank_map.tscn`，输出
`TXWZS_RUNTIME_IDENTITY 天下无战事 · CITY · DEBUG · UNIDENTIFIED`。
`UNIDENTIFIED` 是因为没有通过 GUI 标准启动器传入身份参数，不是项目
加载失败。

4. 现有全部 smoke runner：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" --script res://tests/<runner>.gd
```

实际逐个运行 `tests/run_*_smoke.gd`：

- runner：25；
- exit 0：25（`25/25`）；
- 非零退出：0；
- 明确断言 `PASS`：1238 条；
- runner 总结 `PASS`：25 条；
- 全部 `PASS` 行：1263 条；
- `FAIL`、`SCRIPT ERROR` 或 Godot `ERROR:` 行：0。

覆盖范围包括：

- 建造 placement、选择、生命周期和统一建筑交互；
- 城市空间 helper、时间和视口；
- P1-A 道路与伐木、P1-B 日经济、P1-C 威胁、P1-D 征募与科技；
- P1-E 首战门禁与城市—战场—城市技术闭环；
- C0 事务、确定性战斗、场景、结果写回、退出返回和表现投影；
- 告示板三类任务；
- 瞭望塔目录边界；
- 只读世界地图；
- 运行身份。

5. 工作树检查：

```bash
git diff --check
git status --short
```

结果：`git diff --check` exit 0；测试没有新增可见源码修改。

### 证据解释

- “editor scan 和主场景加载成功”只证明工程可以加载。
- “25 个 runner 通过”只证明已编码合同和回归条件通过。
- 这些结果不能证明战斗好玩、信息易懂或完整 10～15 分钟闭环已经通过
  真人验收。
- 现有 GUI 窗口证明 `main@228ae52` 的 CITY 可以运行，但本轮没有进行
  新的实体鼠标玩法验收。

## E. Implemented Systems Matrix

| 能力 | 状态 | 代码与运行证据 | 边界 |
| --- | --- | --- | --- |
| 城市／黑石城状态 | 已有且可运行 | `blank_map.tscn`；`ConstructionController`；25 个 runner | 没有独立 `CityState`，全部为进程内存态 |
| 资源库存与变化 | 已有且可运行 | `wood`、`food`、容量、生产、维护、奖励；P1-A/B/D/E 测试 | 没有持久账本或跨进程恢复 |
| 建造与道路连接 | 已有且可运行 | 类型化 `BuildingDefinition`、placement、occupancy、四向道路连通、施工期 | UI、状态和节点创建集中在 3348 行控制器中 |
| 招募与兵力 | 已有且可运行 | `queue_training()`、次日完成、维护、上限；P1-D 测试 | 只有一种步兵与一个总兵力数，不是正式驻军分配 |
| 驻军 | 已有但不完整 | 黑石城显示可用步兵；战斗通过兵力预留 | 没有城市间、地点间或部队编制驻军状态 |
| 北坡入口 | 已有且可运行 | 第 6 日 WARNING、第 7 日 PENDING、军令台进入 C0 | 真人可读性和操作体验未通过 |
| 出征命令 | 已有且可运行 | 兵力预留、路线分配、前进／坚守／撤退 | 仅北坡和告示板 C0；世界地图路线不是正式出征 |
| 战斗／结算 | 已有且可运行 | `BattleSession` 0.25 秒固定 tick；胜败撤退；25 个 runner | 是技术灰盒，用户已判定产品体验不通过 |
| 战后奖励与伤亡 | 已有且可运行 | `apply_battle_result_atomic()`；结果 ID、首通键、粮草、伤亡、城防 | 幂等性只在同一进程有效 |
| 全局日期／回合 | 已有且可运行 | 自动 180 秒／日、1×/2×/4×、暂停、唯一日界线 | 没有离线时间；战斗阻断时冻结 |
| 敌方行动／敌袭 | 已有但不完整 | 固定第 5/8/10/12 日威胁与第 7 日首战 | 只有一份固定首图时间表，没有通用敌方战略 AI |
| 随机事件与随机种子 | 完全缺失 | 全仓库没有 RNG、`randi`、`randf` 或 seed 运行代码 | 当前威胁和战斗均为确定性 |
| 存档 | 完全缺失 | 运行代码没有 `FileAccess`、`ConfigFile`、`ResourceSaver` 或 `user://` 写入 | 第 9 日 checkpoint 只是内存 Dictionary |
| 读档 | 完全缺失 | 没有加载器、版本校验、迁移或坏档处理 | 退出进程即丢失城市、任务和 ledger |
| 存档版本 | 完全缺失 | 没有 schema/version 字段 | S1 原方案的最后两步当前不成立 |
| 操作／结算日志 | 已有但不完整 | `last_daily_report`、`last_daily_breakdown`、战果摘要、C0 最近动作 | 只保留少量当前内存显示，不是持久审计日志 |
| 世界地图 | 只有界面或占位数据 | 固定五节点、五道路、编队固定位置、只读路线预览 | 不行军、不扣粮、不触发战斗、不保存 |
| 自动化测试 | 已有且可运行 | `25/25` 个 smoke runner；1238 条明确断言和 25 条 runner 总结通过，共 1263 行 PASS | 缺少正式存读档 round-trip 和坏档测试 |
| 集成／冒烟 | 已有且可运行 | editor scan、主场景加载、城市—战场—城市 runner | 没有覆盖完整退出进程再加载 |

## F. Document–Code Conflicts

### 1. 当前测试规模记录过期

`CURRENT_STATE.md` 在 S0F 冻结前仍写“18 个 runner、933 条显式断言”。
本轮实际发现并运行 `25/25` 个 runner，得到 1238 条明确断言 `PASS` 和
25 条 runner 总结 `PASS`，全部 `PASS` 行合计 1263。旧数字没有包含后续
告示板、C0 表现、退出返回、瞭望塔和世界地图等测试；S0F 已在当前状态
文档中更正这一当前统计，不批量改写历史 closeout。

### 2. 旧时间 closeout 与当前代码冲突

`docs/handoffs/P1_CITY_TIME_AND_VIEWPORT_CORRECTION_CLOSEOUT.md:33`
写 `SECONDS_PER_DAY = 60.0`；当前
`scripts/construction_controller.gd:77` 和
`CURRENT_STATE.md:49` 均为 `180.0`。运行事实以 180 秒为准。

### 3. 历史“六个固定建筑”已经过期

早期 P0 文档多处写六个固定建筑；当前场景和控制器实际注册七个：
城主府、兵营、粮仓、学院、城门、军令台、告示板。

### 4. 正式首战失败语义与新设计边界冲突

当前 `apply_battle_result_atomic()` 在正式首战失败时：

- 把当前城防全部计为伤害；
- 设置 `city_fallen = true`；
- UI 显示“城市失守”。

未跟踪的
`docs/design/CAMPAIGN_CITY_BATTLE_STATE_BOUNDARY_V0.md`
则要求战时核心被攻破不能直接等同于摧毁持久内城。该冲突已经在
`CURRENT_STATE.md` 的未提交修改中登记，但运行时代码尚未调整。

它不阻断 S1A 的早期城市存读档闭环，但阻断把原始完整 S1 的北坡战斗
结果直接写入正式持久存档。

### 5. 项目显示名仍是 P0 基线

`project.godot` 的项目名仍为 `TXWZS-P0-00-BASELINE`。这不影响运行，但
会让窗口、日志或导出识别与当前 P1 状态不一致。本轮不修改。

### 6. 历史 handoff 不能当作当前能力表

P0 和早期 P1 handoff 中的“没有道路、生产、军事或军令台功能”是当时
正确的历史边界，已经被后续提交替代。它们应作为阶段记录保留，而不能
覆盖当前代码事实。

## G. Reusable And Unsafe Components

### 建议继续复用

1. `BuildingDefinition`、`BuildingCapability` 和现有 `.tres`：
   静态定义与运行态边界明确，适合继续作为保存时的稳定
   `definition_id` 来源。
2. `ConstructionController` 的 placement、occupancy、道路连通和唯一日
   界线：
   已有真人建造交互证据和大量回归测试。S1A 不应另建第二套城市状态。
3. `CityGridRules`、`CityProjection`、`CityRoadDraft`：
   是无 Node 副作用的空间 helper，可继续保留。
4. P1-A 至 P1-D 的资源、施工、日结算、征募与科技规则：
   测试覆盖完整，足以组成不含战斗的第一轮稳定闭环。
5. `BattleRequest`、不可变双方快照、`BattleSession`、`BattleResult` 和
   `BattleResultApplier`：
   确定性和同进程幂等性强，适合在存档合同成立后继续复用。
6. 当前 25 个 smoke runner 和单实例启动器：
   它们是后续改动的回归基线。

### 不应直接当作可靠持久模块

1. `get_city_state()`：
   它是 UI/投影快照，不含完整 placement、occupancy、next placement ID、
   所有任务 ledger 和恢复所需字段，不能直接序列化为正式存档。
2. `_readiness_checkpoint`：
   只在内存存在；恢复 placement 时重新分配 ID；没有版本、校验、坏档
   处理和事务 ledger，不能改名冒充存档。
3. `WorldMapPresentationModel`：
   节点、道路、编队位置和计划路线含明确 fixture，不得迁移成战略权威。
4. 活动 `BattleSession`：
   当前没有跨进程恢复合同。S1A 必须禁止在活动战斗或待确认战果时保存。
5. 正式首战失败写回：
   与最新城市保全设计冲突，在冲突解决前不能进入正式存档验收。
6. `ConstructionController` 的 UI 绑定：
   脚本 3348 行，并直接绑定大量 `../UI/...` NodePath。核心状态可靠，
   但不能据此认为可以低风险新建一套主场景。
7. 当前日志与首通 ledger：
   只在内存中；进程重启后会丢失，可能造成重复首通奖励。

### 重复、原型与废弃入口

- 旧 `PanContent.position` 导航已被替换，当前代码只有根 `_input` 和 C0
  `_unhandled_input` 两个有明确范围的输入所有者。
- 独立 C0 fixture 与正式城市入口复用同一战斗场景；fixture 仍用于测试，
  不是第三套正式战斗。
- 告示板和世界地图已经超过原始首城闭环所需，当前应冻结，不再扩展。
- 世界地图的编队位置与路线属于演示数据，不是可迁移系统。
- `RestartMapButton` 和第 9 日 checkpoint 是调试／恢复入口，不是存读档。

## H. Continue / Clean Scene / New Project Decision

| 路径 | 可复用比例 | 状态统一 | UI耦合 | 测试覆盖 | 回归风险 | 首闭环适配 |
| --- | --- | --- | --- | --- | --- | --- |
| A. 现有工程小步修复 | 高 | 当前只有一个城市权威 | 高但已稳定 | 高：25/25 | 最低 | 最合适 |
| B. 同仓库新建干净主场景 | 中 | 容易因迁移产生双状态 | `ConstructionController` 大量硬 NodePath 会放大迁移量 | 新场景需重建测试 | 中高 | 当前没有必要 |
| C. 新建最小工程迁移模块 | 低至中 | 可以重建，但会丢失现有串联 | 可降低 | 需重新搭建 | 最高 | 没有证据支持 |

### 推荐

选择 **A：继续在现有工程中小步修复**。

证据：

- 25 个现有 runner 全部通过，城市、建造、日结算、征募和战斗事务并非
  只有文档；
- `ConstructionController` 虽然过大，但当前确实是唯一城市状态来源；
- `BattleSession` 与城市写回已经有清晰接口和确定性测试；
- 真正阻断 10～15 分钟稳定闭环的首要缺口是“没有版本化存读档”，不是
  主场景无法加载，也不是底层模块不可用；
- B 会立即触碰大量硬编码 NodePath，C 会丢掉已验证的集成与测试，两者
  都无法更快证明第一个稳定闭环。

本推荐不是长期认可 3348 行控制器。S1A 只允许增加一个受控的存档边界，
不得趁机重做 UI 或全面拆分控制器。

## I. Proposed S1 Or S1A

### 判断

原 S1：

```text
进入黑石堡
→资源与驻军
→建造
→招募
→北坡战斗
→结算
→推进一天
→保存退出
→重新进入
```

在玩法代码层面大部分已经存在，但“战后 ledger 持久化”和“正式首战失败
语义”都没有定论。把战斗与第一版存档同时加入一轮，会让范围跨越城市、
活动战斗、幂等 ledger 和失败语义，超过首个稳定闭环应承担的风险。

因此先执行 **S1A：早期城市日结算与版本化存读档闭环**。

### 玩家入口

使用现有标准 `CITY` 主场景和黑石城，不创建新项目或新主场景。

### 玩家流程

```text
进入黑石城
→暂停并查看木材、粮食和步兵
→铺设一格道路并建造一座伐木场
→征募一批 5 人步兵
→恢复时间并完成一次日界线结算
→看到施工完成、木材变化、粮食维护和步兵增加
→保存并退出
→通过标准入口重新进入
→加载后关键状态与退出前一致
```

### 结束条件

重新进入后，以下状态与保存时一致并能继续运行下一日：

- 日期和日内进度；
- 木材、粮食、科技点；
- 步兵、训练队列和维护状态；
- 道路与伐木场的 placement ID、位置、施工状态和道路连通结果；
- 下一个 placement ID 不与已加载记录冲突；
- 暂停／速度状态；
- UI 从加载后的权威状态刷新，没有第二份可写缓存。

### 允许修改的模块

- 新增一个版本化城市存档数据／序列化适配器；
- 在 `ConstructionController` 增加最小、显式的
  `export_save_state()` / `restore_save_state()` 权威入口；
- 当前主场景增加最小“保存并退出”和“继续游戏”入口；
- 增加 S1A 存读档测试；
- 更新当前状态与 S1A 报告。

具体文件名在 S1A 实施前确定，但不得把 UI 快照直接作为存档。

### 禁止修改

- C0 战斗规则、数值、路线和命令；
- 正式首战失败语义；
- 告示板任务、世界地图、将领、装备、时代、礼包码、联网；
- 新主场景、新项目、UI 重做；
- 新依赖；
- 活动战斗存档；
- 多存档槽、云存档、自动存档、迁移框架和复杂设置页面；
- 无关重构或拆分整个 `ConstructionController`。

### 必须复用

- `blank_map.tscn`；
- `ConstructionController` 的唯一权威状态；
- placement ID、occupancy 和道路派生规则；
- 类型化建筑定义；
- `_advance_day_boundary()`；
- P1-A/P1-B/P1-D 现有规则；
- 当前 smoke 回归和标准启动器。

### 需要补齐的最小能力

1. `schema_version = 1` 的显式存档根对象；
2. 完整但最小的早期城市权威字段；
3. placement 稳定 ID、`_next_placement_id` 和 occupancy 重建；
4. 写入临时文件后再原子替换正式文件；
5. 加载前完整校验，校验失败不得部分修改运行态；
6. 无存档、坏档和未知版本的安全错误提示；
7. 活动战斗、待确认战果或活动事务时拒绝保存；
8. 保存完成后退出，启动后显式继续或自动识别存档；
9. 加载期间冻结时间，成功恢复后再按保存状态运行。

### 本轮不要求持久化

- 活动 `BattleSession`；
- 世界地图选择、计划路线与编队 fixture；
- UI 面板开关、当前选中建筑、相机位置；
- 告示板活动任务与首通 ledger；
- 北坡战果 ledger。

若这些状态存在，S1A 保存入口必须拒绝执行并说明原因，不能静默丢弃。

## J. Acceptance And Test Plan

### 自动化测试

新增 runner 至少覆盖：

1. 新游戏无存档时使用默认状态；
2. schema v1 必填字段和类型校验；
3. 道路、伐木场、资源、日进度、兵力和训练队列 round-trip；
4. placement ID 与 `_next_placement_id` round-trip；
5. load 后 occupancy、道路连通和生产派生结果一致；
6. load 后再放置建筑不会 ID 冲突；
7. load 前后权威状态 digest 一致；
8. 加载期间不多推进一天；
9. 不存在文件、空文件、截断文件、错误类型和未知版本安全失败；
10. 失败加载不部分覆盖当前城市；
11. 活动战斗、预留兵力和待确认结果拒绝保存；
12. 连续保存两次只保留最后一次完整状态；
13. 全部现有 25 个 runner 继续通过；
14. editor scan、主场景 headless、`git diff --check` 通过。

### 人工冒烟步骤

1. 使用 `RUN_CURRENT_TXWZS.command` 进入唯一 CITY。
2. 暂停，记录日期、木材、粮食和步兵。
3. 从城主府道路根格铺设一格道路。
4. 在可接路位置建造一座伐木场。
5. 征募一批 5 人步兵。
6. 恢复时间，等待进入第 2 日。
7. 确认伐木场完工、木材结算、粮食维护、步兵增加和科技点增加。
8. 执行“保存并退出”，确认窗口关闭前出现保存成功反馈。
9. 再次使用标准启动器进入。
10. 继续游戏，逐项核对第 7 步状态和建筑位置。
11. 再推进一个日界线，确认加载后的状态仍可继续结算。
12. 放置第二个对象，确认 placement ID 和 occupancy 没有冲突。

全部人工操作预计 10～15 分钟。自动接口或注入输入不能替代第 1～12 步。

### 回滚方式

- S1A 必须形成单一原子提交；
- 回滚使用 `git revert <S1A commit>`，不改写历史；
- v1 是首个正式 schema，不做旧版迁移；
- 回滚前保留 `user://` 存档作为诊断样本，是否删除由用户决定；
- 回滚后当前无存档基线仍应正常启动。

## K. Risks And Stop Conditions

### 最容易出现的 5 个 Bug

1. **placement ID 重分配**：照搬 checkpoint 恢复方式导致 ID 改变，后续
   occupancy、选择或 ledger 引用错位。
2. **next placement ID 冲突**：加载后新建筑复用了旧 ID，覆盖已有记录。
3. **加载中时间前进**：场景 `_process()` 在恢复中跨过日界线，资源和训练
   多结算一次。
4. **部分恢复**：坏档在校验完成前已经清空现有 placement 或写入部分资源。
5. **不安全状态被保存**：活动战斗、待确认战果或预留兵力被静默丢弃，
   重进后造成兵力或奖励重复。

### 必须停止

出现以下任一情况，S1A 不得扩大范围：

- 需要第二个可写城市状态才能完成存读档；
- 无法在应用前完整校验存档；
- 必须保存活动 `BattleSession` 才能通过验收；
- 必须解决正式首战失败语义才能完成早期城市 round-trip；
- 需要新依赖、网络服务、云存档或存档迁移；
- placement ID 和 occupancy 无法无损恢复；
- 任何现有 runner 回归且根因无法在 S1A 范围内收敛；
- 工作树出现无法归属的新修改；
- 实体体验结论需要修改核心玩法或 UI 信息架构。

## L. Exact Next Task Recommendation

下一条任务只应是：

```text
TXWZS.S1A — 早期城市日结算与版本化存读档闭环
```

目标：

```text
道路 + 伐木场 + 一批步兵
→一次日结算
→保存并退出
→重新进入
→状态一致并可继续推进
```

S1A 不进入北坡战斗，不扩展告示板和世界地图，不实现将领、装备、时代、
礼包码或联网，不重做主界面。

只有 S1A 的版本化存读档、25 个现有 runner 回归、新增 round-trip 测试和
10～15 分钟人工冒烟全部通过后，才评估 S1B：

```text
北坡出征
→真实战斗
→战果与 ledger 持久化
→退出重进后不重复奖励
```

本审计没有开始 S1 或 S1A。

S0 审计已由用户验收，推荐路径 `A` 成立。本报告与
`CAMPAIGN_CITY_BATTLE_STATE_BOUNDARY_V0.md`、`CURRENT_STATE.md` 一起
作为 S1A 开工前的 docs-only 冻结基线；下一任务是 `TXWZS.S1A`，尚未开始。

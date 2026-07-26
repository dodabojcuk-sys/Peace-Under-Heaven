# CAMPAIGN CITY BATTLE STATE BOUNDARY V0

状态：`FROZEN AS S0 DOCUMENT BASELINE`

任务：`TXWZS-P1-CAMPAIGN-CITY-BATTLE-STATE-BOUNDARY-V0`

性质：纯设计契约与当前仓库只读核验。本文件不表示相关接口已经实现，
也不授权修改源码、场景、测试、数值或存档结构。

## 1. 结论

当前项目后续必须严格区分三层状态和一个写回协调边界：

```text
持久城市状态
CityState（当前等价实现：ConstructionController）
        │ 只读快照／受控权威命令
        ▼
战略战役状态
Campaign / Strategic Map State（当前尚未实现）
        │ BattleRequest
        ▼
单次战役状态
BattleSession（当前已实现；TheaterState 不是第二份同义权威）
        │ 冻结 BattleResult
        ▼
CampaignOutcomeResolver（当前尚未实现）
        │ 调用各层幂等权威入口
        ├──────────────► CityState
        └──────────────► Strategic Map State
```

不可违反：

```text
战时核心被攻破 != 常规内城被摧毁
BattleSession 失败 != CityState 删除或布局重置
战役结算写回 != 战场临时状态直接修改城市
战略地点 != 战役实例 != 战时核心
```

当前 `WORLD_MAP V0A` 可以继续作为战略地图视觉和交互只读基线，但它不是
战略地图权威状态。正式行军、编队移动、战斗扩展和 P1-F1B 仍继续暂停，
除非后续任务另行明确授权。

## 2. 核验范围与证据

本轮读取并核验：

- `AGENTS.md`
- `CURRENT_STATE.md`
- `docs/architecture/MINIMUM_REAL_COMBAT_CONTRACT_V0.md`
- `docs/design/FIRST_BATTLE_GRAYBOX_RULES_V0.md`
- `docs/design/NOTICEBOARD_MISSION_PACK_V0.md`
- `docs/design/WORLD_MAP_V0.md`
- C0 closeout、decision gate 和现有交接文档
- `scenes/blank_map.tscn`
- `scenes/c0_battle_graybox.tscn`
- `scenes/world_map_v0.tscn`
- `scripts/construction_controller.gd`
- `scripts/map_pan_controller.gd`
- `scripts/world_map/world_map_presentation_model.gd`
- `scripts/world_map/world_map_controller.gd`
- `scripts/combat/` 下的请求、快照、会话、结果、写回和返回实现
- 现有 P0／P1／C0／WORLD_MAP smoke runner
- 全仓库持久化、ledger、事务 ID 和 save schema 搜索

仓库没有 `README`、`DECISIONS.md` 或 `CHANGELOG.md`。本轮不为缺失文件
虚构职责，也不创建 `DECISIONS.md`。

## 3. 已确认的当前仓库事实

### 3.1 城市权威实际是 ConstructionController

当前没有名为 `CityState` 的类或资源。`CityState` 在本文中是领域名称；
实际唯一城市运行时权威是：

```text
scripts/construction_controller.gd
class: scene child ConstructionController
```

它直接持有：

- placement 记录、顺序和占用格；
- 木材、粮食、容量、生产和每日结算；
- 日期、时间速度、暂停和威胁；
- 步兵、训练、将领和科技；
- 首战状态、城市城防和 `city_fallen`；
- 告示板任务的当前进程状态；
- 当前战斗预留、关闭事务、已提交结果和首通键。

`get_city_state()` 返回的是只读 `Dictionary` 快照，不是独立可写
`CityState`。地图、UI 和测试读取该快照；城市修改仍由
`ConstructionController` 的方法完成。

### 3.2 当前没有正式持久化

运行时代码没有使用 `FileAccess`、`ConfigFile`、`ResourceSaver` 或
`user://` 保存城市、战略地图或战斗事务。

第 9 日 readiness checkpoint 只是 `ConstructionController` 内存中的
恢复快照。告示板任务、首通键、结果 ledger、城市布局和战略地图均没有正式
跨进程保存能力。

因此：

- 本轮没有 save schema 可以修改；
- “保留存档兼容性”当前只意味着不得暗中新增或迁移 schema；
- 未来若要求跨进程原子恢复，必须单独设计存档版本和迁移门禁。

### 3.3 战略地图当前只是只读表现模型

`WorldMapPresentationModel` 的五个节点、五条道路、坐标、基础归属和道路状态
全部来自脚本常量：

```text
NODE_CONFIGS
ROAD_CONFIGS
```

它从 `ConstructionController.get_city_state()` 读取：

- 当前日期；
- 可用步兵；
- 首战状态；
- `city_fallen`；
- 当前告示板任务摘要。

玩家编队坐标和计划路线明确标记为：

```text
NON_PERSISTENT_PRESENTATION_FIXTURE
persistent = false
```

当前仓库尚无可写的战略地图状态来保存：

- 城池归属变化；
- 道路危险、封锁和侦察变化；
- 战略驻军位置；
- 敌军行动；
- 战役实例与占领进度；
- 正式行军中的兵力和军需。

`WorldMapController` 只保存 UI 选择和非持久路线预览。它不是战略状态写入者。

### 3.4 当前存在 BattleSession，不存在 TheaterState

当前真实临时战斗权威为：

```text
scripts/combat/battle_session.gd
class_name BattleSession
```

它拥有固定 tick、小队、路线、门、临时生命、定点位置、命令队列、任务目标
临时状态和最终 `BattleResult`。

仓库没有 `TheaterState` 类、节点或资源。V0 冻结决定是：

- `BattleSession` 继续作为唯一可变的单局战斗权威；
- `TheaterState` 只作为“战役实例临时状态”的领域称呼；
- 不新增与 `BattleSession` 字段重复的第二个可写对象；
- 如果未来确需 `TheaterState` 包装战区元数据，它只能拥有不可变战役身份、
  战场定义引用和恰好一个 `BattleSession`，不得复制 tick、小队、生命、核心、
  波次或胜负状态。

### 3.5 当前写回路径

当前真实路径是：

```text
ConstructionController
→ CombatTransactionCoordinator.create_request()
→ BattleRequest + 双方 Snapshot
→ BattleSession
→ BattleResult
→ BattleResultApplier
→ ConstructionController.apply_battle_result_atomic()
→ ReturnToCityContract
```

`BattleResultApplier` 当前只是一个窄代理，最终直接调用
`ConstructionController.apply_battle_result_atomic()`。

仓库没有 `CampaignOutcomeResolver`。当前也没有第二个战略状态需要协调，
所以一次同步函数可以在同一个 `ConstructionController` 内完成：

- 扣除实际伤亡；
- 扣除正式首战粮草；
- 应用首胜奖励；
- 修改城防和敌军数量；
- 更新首战或告示板状态；
- 写入结果摘要和当前进程 ledger；
- 清理活动预留。

该函数没有 `await`，会先计算新值再集中赋值，因此当前同一进程内具备明确的
“全部前置验证失败则零写入”边界。它不提供跨进程事务恢复。

### 3.6 当前幂等字段

`ConstructionController` 当前持有：

| 字段 | 当前用途 | 持久化 |
| --- | --- | --- |
| `_active_battle_reservation` | 当前唯一兵力预留和 phase | 否 |
| `_closed_battle_transactions` | 已取消／已应用事务 phase | 否 |
| `_committed_battle_result_ids` | `result_id → summary`，吸收重复结果 | 否 |
| `_first_clear_keys` | 首通奖励一次性门禁 | 否 |
| `_completed_noticeboard_mission_ids` | 告示板任务当前进程完成状态 | 否 |
| `_next_battle_transaction_sequence` | 生成 `battle-%06d` | 否 |

当前 `BattleRequest` 没有独立 `request_id`，实际使用 `transaction_id` 作为请求
身份。`session_id` 派生为 `<transaction_id>-session`，`result_id` 派生为
`<transaction_id>-result-001`。

### 3.7 与本契约冲突的现有行为

现有正式首战失败路径会：

- 把当前全部城防计为损伤；
- 设置 `city_fallen = true`；
- 把首战状态设为 `RESOLVED_DEFEAT`；
- 让战略地图把黑石城显示为“城市失守”。

这与本轮新冻结的“战时核心被攻破不等于持久内城被摧毁”不一致。

本轮不修改该运行时行为。它必须登记为下一次实现前的阻断差异：

```text
当前 P1-E 失败语义 = 技术灰盒旧语义
冻结后的产品语义 = 单次北坡防御失败，不删除、不重置常规内城
```

`restart_first_map()` 可以主动清理运行时 placement 并恢复初始首图，但它是
显式调试／恢复操作，绝不能由普通战败、战时核心被攻破或返回战役地图自动调用。

## 4. 权威边界表

| 状态／对象 | 权威字段 | 生命周期 | 持久化 | 创建者 | 唯一写入者 | 合法读取者 | 销毁时机 | 禁止承载 | 当前文件／符号 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `CityState` 领域状态 | 城市 ID；建筑、道路和布局；生产、资源、科技、人口、驻军；可维修损伤；城市版本 | 城市创建至存档删除 | 设计要求持久；当前否 | 未来存档／城市加载器；当前由主场景创建 `ConstructionController` | 城市权威命令 API；当前为 `ConstructionController` | UI、战略投影、请求快照器、Resolver | 只在明确删档时；战败不得销毁 | 单局单位位置、投射物、战斗 tick、临时核心和波次 | `scripts/construction_controller.gd` | 部分实现；无独立类、无正式持久化和人口／维修损伤模型 |
| 战略地图状态 | 地点归属；道路状态；战略驻军；敌军行动；战役与占领进度；状态版本 | 战役／周目 | 设计要求持久；当前否 | 未来 Campaign 初始化器 | 战略层权威命令 API | WorldMap 投影、请求构建器、Resolver | 战役结束或明确新周目 | 单局单位、投射物、临时防线、战斗计时、UI 选择 | 当前无对应状态；`WorldMapPresentationModel` 不是它 | 尚未实现 |
| `BattleRequest` | `transaction_id`、关卡、创建日、双方快照、来源、承诺粮草、首通和奖励引用 | 派兵确认至取消／结算 | 当前否；未来必须随活动事务恢复 | `CombatTransactionCoordinator.create_request()` | Coordinator 只修改 phase；快照创建后冻结 | BattleSession、Applier、Resolver、UI 摘要 | 事务完成且 ledger 可恢复后 | 城市布局、战略归属任意修改、战场 tick | `scripts/combat/battle_request.gd` | 已实现 C0 版本；缺 source city、target theater 和状态版本 |
| `BattleSession` | session ID、tick、小队、路线、临时门／核心、局内目标、命令和结果 | 战斗开始至结果应用／战前取消 | 否；当前仅进程内 | `CombatTransactionCoordinator.create_session()` | `BattleSession` 固定 tick API | 战场表现、Coordinator、测试 | 结果已应用并安全返回；或战前取消 | 城市资源、建筑、道路、战略归属、首通 ledger | `scripts/combat/battle_session.gd` | 已实现；当前没有通用双方“核心”字段，主要为路线门和任务目标 |
| `TheaterState` 领域名 | 战役实例身份、战区定义引用、唯一 session 引用 | 单次战役 | 否 | 若未来需要，由战役入口创建 | 不得复制 BattleSession；V0 不设第二写入者 | UI／加载过场／Resolver 可读元数据 | BattleSession 与返回契约结束后 | tick、小队生命、命令、波次和胜负的第二份副本 | 当前不存在 | 概念契约；不新增同义权威 |
| `BattleResult` | result、transaction、session、level、胜负、伤亡、敌军伤亡、tick、摘要 digest | 战斗终局至永久历史记录 | 当前否；未来应由 ledger 保存 | `BattleSession._complete()` | 创建后不可变 | Resolver、结果 UI、历史记录 | 不销毁事实记录；可释放内存对象 | 可执行命令、任意字段赋值、城市／战略状态引用 | `scripts/combat/battle_result.gd` | 已实现 C0 事实集；缺正式战役类型和更完整目标事实 |
| `CampaignOutcomeResolver` | 不拥有玩法状态；只拥有一次 resolution 上下文和效果计划 | 收到结果至 ledger 完成 | journal 设计要求持久；当前不存在 | 未来战役返回协调层 | 自身只推进 resolution status；实际数据通过各层权威 API 写入 | 结果页、返回流程、恢复器 | ledger 为 `COMPLETED` 后释放运行对象 | 第二份 CityState／CampaignState、直接改内部 Dictionary | 当前以 `BattleResultApplier → ConstructionController.apply_battle_result_atomic()` 代替 | 尚未实现跨层版本 |
| `WorldMapPresentationModel` | 固定地理配置；由权威快照派生的只读节点、道路、编队摘要 | 每次刷新重建 | 否 | `WorldMapController` | 纯函数构建；无运行时权威写入 | `WorldMapCanvas`、地图 UI | 刷新或退出地图 | 城池归属真相、行军真相、奖励、BattleSession、正式存档 | `scripts/world_map/world_map_presentation_model.gd` | 已实现；明确为表现层 fixture |
| `CombatTransactionCoordinator` | 当前 request、session、applier、return contract | 单次活动事务 | 否 | C0 场景或战前撤退流程 | 自身 phase 协调；城市写入经城市 API | 战场 UI、测试 | 返回完成或取消 | 城市和战略权威字段 | `scripts/combat/combat_transaction_coordinator.gd` | 已实现；不是 CampaignOutcomeResolver |

## 5. CityState 保全规则

所有战役类型和所有战果必须保留以下城市身份与布局事实：

- 稳定 `city_id`；
- placement ID 与建筑定义 ID；
- 建筑逻辑锚点、占地、朝向和入口；
- 道路格、道路连接和玩家布局；
- 建筑等级、施工和升级记录；
- 已解锁科技和城市发展记录；
- 城市历史与已结算战役 ledger。

允许战果通过城市权威 API 修改：

- 真实参战部队的伤亡；
- 已承诺且实际消耗的军需；
- 战略时间；
- 可维修损伤；
- 临时生产／征募／研究停摆；
- 城市危急、敌占或锁定状态。

不得：

- 删除 CityState；
- 清空 placement 或 occupied cells；
- 调用 `restart_first_map()` 伪装战败；
- 随机拆除建筑；
- 重新生成城市布局；
- 把战场核心生命映射为全城建筑生命；
- 因战败清档或迁移存档。

### 5.1 可维修损伤契约

未来建筑损伤必须是可追踪、可维修和可幂等应用的状态，至少需要：

```text
damage_id
source_result_id
city_id
placement_id
damage_kind
operational_effect
repair_status
```

同一 `source_result_id + placement_id + damage_kind` 不得施加两次。

损伤只改变建筑的运行能力或维修需求，不改变其 placement、占地、等级和布局。
本轮不冻结损伤数值、维修资源或停摆时长。

## 6. 四类失败后果矩阵

下表冻结后果类别，不冻结伤亡率、资源罚款、时间天数和维修时长。

| 项目 | 普通远征失败 | 普通防御失败 | 副城决战失败 | 主城决战失败 |
| --- | --- | --- | --- | --- |
| 战略归属 | 不改变 | 不改变 | 目标副城可改为敌占／锁定 | 不删除主城；进入危急／重创保护 |
| 部队 | 写回实际伤亡；幸存者返回来源城市 | 写回实际伤亡；幸存者回到城市驻军 | 写回实际伤亡；幸存者按战役规则撤回 | 写回实际伤亡；保留剩余驻军事实 |
| 军需 | 已消耗部分不返还；未消耗部分规则待定 | 已消耗部分不返还 | 已消耗部分不返还 | 已消耗部分不返还 |
| 战略时间 | 推进，具体天数待定 | 推进，具体天数待定 | 推进，具体天数待定 | 推进或进入恢复阶段，具体规则待定 |
| 路线／敌方压力 | 可增加压力、筑防或使路线危险 | 防线后撤、压力上升、部分路线可变危险 | 敌占区路线和通行状态按战略规则改变 | 敌方压力维持；进入危急恢复门禁 |
| 城市状态 | 来源城市仍正常存在 | 城市不失去归属；可有短期维修／停摆 | 副城原布局冻结保存，城市进入敌占／锁定 | 主城仍存在；进入危急／重创保护，不删档 |
| 建筑影响 | 原则上不直接损伤来源城市建筑 | 允许确定性、可维修的防御设施停摆 | 原布局全部保留；收复后恢复并维修 | 允许可维修停摆，不随机拆除 |
| 恢复／收复 | 补兵、补给后可再远征 | 修复防线、降低压力后继续 | 收复后加载原布局和损伤记录，不重建新城 | 完成恢复条件后解除危急状态 |
| 明确禁止 | 无损重试、固定胜利、删来源城 | 普通失败直接丢城 | 删除副城布局、随机重排、清空建筑 | 删除主城、清档、重置布局、直接 Game Over 毁档 |

### 6.1 当前北坡首战的分类

当前 `first_war.north_slope.v0` 应按“普通防御失败”理解，而不是主城毁灭。

因此下一次实现必须把现有：

```text
DEFEAT → city_fallen = true → 黑石城显示城市失守
```

改为：

```text
DEFEAT → 北坡防线失利／城市进入明确压力后果
       → 黑石城 CityState 和布局完整保留
```

具体压力、维修和时间数值仍需后续数值门禁，本文件不制定。

## 7. 派兵与战果事务契约

### 7.1 身份与版本

正式事务至少需要区分：

```text
request_id
transaction_id / reservation_id
session_id
result_id
idempotency_key
source_city_id
target_theater_id
battle_definition_id
battle_type
source_city_version
campaign_state_version
```

当前 C0 把 `transaction_id` 同时作为 request 身份使用。允许在旧 C0 适配层暂时
保持别名，但正式战略流程的契约语义必须区分：

- `request_id`：玩家确认的一次派兵请求；
- `transaction_id`：该请求对兵力和军需的预留事务；
- `session_id`：实际创建的一次战场运行实例；
- `result_id`：该 session 唯一接受的结果事实；
- `idempotency_key`：Resolver 和各权威层共同吸收重试的稳定键。

### 7.2 请求冻结内容

`BattleRequest` 必须冻结或引用：

- 来源城市与目标战略地点；
- 战役实例和战役类型；
- 出发城市版本与战略状态版本；
- 派出兵力和军需承诺；
- 玩家选择的路线；
- 创建日期；
- 双方快照；
- 允许的结果种类；
- 可由 Resolver 选择的后果模板 ID。

请求不得携带“把某城市删除”“任意修改资源”等自由格式命令。

### 7.3 BattleResult 是事实，不是命令包

`BattleResult` 只能陈述：

- 哪个请求、会话和战役产生结果；
- 胜利、失败或撤退；
- 参战、幸存和伤亡；
- 敌方损失；
- 实际消耗和战场目标状态；
- 终局 tick 和确定性摘要；
- 哪个战时核心／目标被攻破。

它不得直接携带：

- `delete_city = true`；
- 任意资源增减脚本；
- 任意建筑删除列表；
- 战略归属的无校验赋值；
- 任意 scene tree 或 `ConstructionController` 引用。

Resolver 根据 `battle_type + BattleResult + 当前 ledger` 选择冻结的后果规则，
再调用城市和战略层各自的权威命令。

### 7.4 CampaignOutcomeResolver 职责

Resolver 只负责：

1. 验证 request、session、result 和快照摘要；
2. 确认该 session 尚未接受其他结果；
3. 检查来源城市和战略版本；
4. 生成不可变 outcome effect plan；
5. 把 plan 记录到 outcome journal；
6. 以同一 `result_id` 调用城市层幂等命令；
7. 以同一 `result_id` 调用战略层幂等命令；
8. 完成任务、奖励和首通 ledger；
9. 标记 resolution completed；
10. 返回只读战后摘要。

Resolver 不得绕过城市和战略层 API 直接改内部 Dictionary。

### 7.5 当前无跨层原子存储时的最小 journal

未来 CityState 和战略状态成为两个持久权威对象后，单个同步函数无法保证跨对象
原子写回。最小方案是持久 outcome journal：

```text
PREPARED
→ CITY_APPLIED
→ STRATEGY_APPLIED
→ REWARDS_APPLIED
→ COMPLETED

任何校验失败 → REJECTED / CONFLICT
```

每一步都使用相同 `result_id / idempotency_key`，目标权威 API 必须做到：

```text
第一次调用：应用并记录 result_id
重复调用：返回原摘要，不产生第二次效果
冲突调用：拒绝，不做部分写入
```

Resolver 必须先持久化 `PREPARED` 和完整 effect plan，才能写任一权威层。崩溃后
按 journal 状态重放未完成步骤，而不是重新计算后果。

本轮不实现 journal，也不增加 save schema。

## 8. 失败路径

| 失败路径 | 冻结处理 |
| --- | --- |
| 同一 `BattleResult` 提交两次 | 第一次完成；第二次根据 `result_id` 返回同一摘要，零副作用 |
| 战略层写入后、城市层写入前崩溃 | journal 保留已完成步骤；恢复后只重试城市层及后续步骤 |
| 城市层写入后、战略层写入前崩溃 | 同上；战略层使用同一 key 幂等补写 |
| 已结算战役再次加载 | session ledger 指向已接受 `result_id`；只显示历史摘要，不重开事务 |
| 两个不同结果引用同一 session | `session_id → accepted_result_id` 只能绑定一次；后到结果标记冲突并拒绝 |
| 旧结果写入已变化战略状态 | 比较 `campaign_state_version`；若变化不在允许重放范围，进入 `CONFLICT`，不猜测合并 |
| 来源城市已变化 | 比较 `source_city_version`；只允许由同一事务造成的已记录变更，其他变化进入冲突 |
| 结果过期 | 只有活动／待恢复 ledger 和未关闭预留可继续；无 ledger 或预留已被其他事务消费则拒绝 |
| 重复场景返回或重复信号 | `ReturnToCityContract` 只负责输入和场景恢复；不能重新调用 outcome apply |
| 重复奖励 | reward／first-clear ledger 使用同一 `result_id` 和稳定 reward key |
| 应用中任一步校验失败 | 不执行后续步骤；保留 journal 供恢复或人工诊断，不回滚为第二份状态 |

当前仓库只能自动吸收同一进程内的重复结果和重复返回；跨进程恢复、版本冲突和
跨城市／战略状态写回尚未实现。

## 9. 玩家可见语义

### 9.1 名称层级

| 领域 | 示例 | 含义 |
| --- | --- | --- |
| 战略地点 | 河湾城 | 世界地图上长期存在的地点 |
| 地图操作 | 派兵前往河湾城 | 从来源城市建立派兵请求 |
| 战役实例 | 河湾城解放战 | 一次可结算、可重试或已完成的战役 |
| 我方战时核心 | 前线军营／援军大营／北门城防中枢 | 单局目标，不是常规城市实体布局 |
| 敌方战时核心 | 河湾守军中枢／城防司令部 | 单局胜负目标，不是可直接管理的内城 |

黑石城防御示例：

```text
持久城市：黑石城
战役实例：黑石城北门保卫战
我方战时核心：北门城防中枢
```

北门城防中枢被攻破只说明本次防御失败，不表示黑石城的粮仓、学院、兵营、
道路和布局被删除。

### 9.2 地图按钮

| 对象状态 | 玩家可见操作 |
| --- | --- |
| 玩家持久城市 | `返回黑石城`／`管理城市` |
| 可远征目标 | `派兵前往河湾城` |
| 已创建但未进入的玩家战役 | `进入战场` |
| 不允许玩家直接控制的战役 | `查看战况` |
| 敌占城市 | 不显示 `进入内城`；显示战略操作或占领状态 |
| 只读路线 | `路线预览 · 尚未出征` |

当前 WORLD_MAP V0A 已做到：

- 黑石城可以返回内城；
- 河湾城不能进入内城；
- 路线预览明确“尚未出征”；
- 计划路线不扣资源、不推进时间。

当前按钮 `设为计划行军目标` 仍只是只读预览。正式行军恢复后，必须经过明确的
`确认派兵`，不能把路线预览误当成已经出征。

### 9.3 出征加载过场

仅冻结语义，不在本轮实现：

```text
正在派兵前往河湾城
黑石城出发 → 所选路线 → 河湾战区
```

过场应显示本次派出的兵力、路线和军需，并绑定已创建的 `BattleRequest`。
它不得创建第二个派兵事务，也不得在动画结束时再次扣资源。

## 10. 旧文档与新契约的差异

| 旧文档／实现 | 本轮处理 |
| --- | --- |
| `MINIMUM_REAL_COMBAT_CONTRACT_V0` 将旧 Project Dawn 的 `TheaterState / resolver` 直接架构判为淘汰 | 继续禁止恢复旧运行时代码；重新采用“临时战役状态与跨层结果协调”的领域边界，但以当前 `BattleSession` 为唯一单局权威 |
| C0 只有 `BattleResultApplier → ConstructionController` | 继续作为单城市、单进程 C0 适配；不能冒充未来跨城市／战略层 Resolver |
| P1-E 失败设置 `city_fallen` 且城防归零 | 与新产品契约冲突；登记为下一实现阻断，不在本轮改代码 |
| WORLD_MAP 的节点、道路和编队是常量／fixture | 保留为 V0A 视觉基线；不得称为战略状态已实现 |
| 当前 result／first-clear ledger 只在内存 | 保留 C0 同进程幂等；正式持久 journal 尚未实现 |
| 当前没有 save schema | 本轮不新增；跨进程恢复必须另过迁移门禁 |

## 11. 尚未实现的接口

本契约人工通过后，后续仍需单独授权和实现：

- 持久战略地图状态及其版本；
- 城市稳定 ID 和城市版本；
- 战役类型／后果模板定义；
- `CampaignOutcomeResolver`；
- 城市层幂等 outcome 命令；
- 战略层幂等 outcome 命令；
- 持久 outcome journal；
- 可维修建筑损伤记录；
- 副城敌占／收复和主城危急恢复状态；
- 正式派兵、军需承诺和行军加载过场；
- 当前北坡失败语义纠正。

这些接口不得通过复制 `ConstructionController`、建立第二套 CityState 或让
`BattleSession` 直接写城市来实现。

## 12. 仍需后续决定的数值问题

本轮故意不决定：

- 四类失败的伤亡率；
- 未消耗军需是否返还及返还比例；
- 各战败路径推进多少战略时间；
- 压力、筑防和路线危险的数值；
- 建筑损伤数量、选择规则和停摆时长；
- 维修成本和维修速度；
- 主城危急状态的恢复条件；
- 副城收复后的维修基线；
- 何时允许重试同一战役。

这些是平衡和体验门禁，不得被默认值偷渡成架构事实。

## 13. 后续实施门禁

本契约已作为 S0 文档基线冻结。以下事项仍继续暂停，除非后续任务另行明确
授权：

- 正式行军和编队实时移动；
- 战斗扩展和正式战场开发；
- 加载过场实现；
- P1-F1B；
- 建筑移动；
- 新存档字段或迁移；
- 把 P1-E 技术灰盒失败语义继续扩散到战略地图。

后续涉及该边界的实施仍须确认：

1. `ConstructionController` 是否继续作为当前 CityState 适配权威；
2. `BattleSession` 是否作为唯一可变单局权威；
3. 四类失败后果等级是否正确；
4. outcome journal 是否作为未来跨层原子恢复的最小方向；
5. 当前北坡失败是否按普通防御失败纠正。

确认具体实施范围后再制定最小代码迁移顺序，不能直接开始正式行军。

## 14. S0 工程基线冻结

本契约随 `TXWZS.S0` 审计一起冻结为后续实施的文档基线。冻结不代表文中
尚未实现的接口已经存在，也不改变第 3.7 节登记的运行时冲突。

| 项目 | 冻结事实 |
| --- | --- |
| Godot | `4.5.1.stable.official.f62fdbde1` |
| 当前主场景 | `res://scenes/blank_map.tscn` |
| 城市日长 | `180` 秒／日 |
| 固定建筑 | 七个，包含告示板 |
| 自动回归 | `25/25` 个 runner 通过 |
| 明确断言 | `1238` 条通过 |
| runner 总结 | `25` 条通过 |
| 全部 PASS 行 | `1263` 条 |
| 正式存档 | 不存在正式存档、读档或存档版本 |
| 已知阻断差异 | 首战失败旧语义与持久城市保全契约冲突；本轮未修复 |
| 工程路径 | `A：继续在现有工程中小步修复` |
| 下一任务 | `TXWZS.S1A` |
| 实施状态 | S1 和 S1A 均尚未开始 |

历史 closeout 中的旧日长、固定建筑数和回归统计继续作为当时的阶段记录，
不覆盖本节的当前工程事实。`TXWZS.S1A` 必须从本 docs-only 冻结基线之后的
干净工作树开始；本文件没有实现或授权战斗存档。

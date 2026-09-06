# TXWZS Architecture Contract

## 文档状态

本文件是 post-G2 的单一活跃架构合同，合并此前分散在 architecture、
design、process、testing 和 acceptance 文档中的已接受边界。

它记录当前已成立的合同，不授权 G3、G4、G5、G6、P6、P7、V6 或新产品
方向。代码、测试和现场运行证据高于本文。

## 核心原则

1. 每类可写业务状态只有一个权威所有者。
2. UI、场景表现、兼容属性和 read model 不能成为第二份真相。
3. 身份、数量、时间、写回和持久化操作必须确定、可验证、可回滚。
4. 失败在发布任何权威写入前完成校验；失败结果必须零部分写入。
5. 自动测试、真实窗口、独立复查和用户体验是不同 Gate。
6. 阶段授权不自动扩展到相邻阶段、远端操作或不可逆迁移。

## 四层世界模型

| 层 | 生命周期 | 当前边界 |
| --- | --- | --- |
| 常态内城 | 持久 | 建筑、资源、训练、驻军、时间和本城权威 |
| 外城战区 | 持久变化 | 路线、逻辑位置、军队、驻扎、遭遇；V5 最多一支 active 是校验策略 |
| 战事内城 | 单次战斗实例 | 城墙、城门、防守方和战役阶段；不能成为第二份城市真相 |
| 天下地图 | 持久总览 | 城市、阵营、战役和战略行动；当前 V0 表现模型不是持久权威 |

V5 建立集合型 `ArmyRegistry`，不能把“当前最多一支 active”固化为单例
数据模型。多 active 行为和持久外城战区属于 V6。

## 当前所有权

| 事实 | 唯一写入者 | 允许读取者 | 禁止路径 |
| --- | --- | --- | --- |
| 国家共享资源 | `NationState`（经 `commit_resource_transaction()`） | `ConstructionController`、城市 UI、快照、协调器 | UI 或表现节点直接改写，或第二资源账本 |
| 本城步兵驻军 | `ConstructionController` 持有的私有 `GarrisonState` | UI、训练、派遣、快照 | 第二套 `CityState` 或独立 `infantry_count` 存储 |
| `infantry_count` | `GarrisonState` 的兼容属性 | 旧 C0/P1/S1A.1 调用方 | 作为独立源状态 |
| 训练订单 | `TrainingQueue` | 城市 read model、快照 | 旧三字段或 UI 自建队列 |
| 军队集合和行军进度 | `ArmyRegistry` | 派遣适配、遭遇、快照 | 场景字典或 UI 成为持久权威 |
| 战斗实例和 terminal facts | `BattleSession` | coordinator、表现层 | 直接修改城市、驻军或存档 |
| 战斗预留、写回和幂等 ledger | 绑定城市的 `CombatTransactionCoordinator` | 城市、结果应用器 | 未绑定 coordinator 或另一城市复用信任根 |
| V5 存档发布与恢复 | `V5CampaignSaveStore` 与城市权威入口 | codec、迁移器、恢复流程 | V1 writer 直写 V5 或边读边改 live state |

`ConstructionController` 当前承担较多职责，但在没有单写入者迁移合同前，
不能通过新增第二个可写 `CityState` 来“整理”它。

## 城市、建设与内容

### 已接受城市基线

- 唯一导航结构是 `Node2D + Camera2D`；固定 UI 不随地图移动。
- 放置、选择、详情、运行时建筑生命周期和统一右侧建造入口已经形成 P0
  基线。
- 建筑权威记录统一固定建筑与运行时放置建筑；表现节点不参与权威事务。
- UI 遮挡是输入规则，不是空间合法性本身。
- 入口由格与朝向共同定义；放置、占用和道路查询使用逻辑格。
- 建造、选择、拖动和缩放必须服从单一输入所有权。

### 内容定义原则

- 静态内容优先使用类型化 Godot `Resource`。
- 静态定义描述能力；运行时实例、资源账本和结果 ledger 是独立权威状态。
- 稳定 ID 不依赖节点路径、数组位置、像素坐标或显示文本。
- 当前步兵沿用 `UnitRole` 的 `unit_role.infantry_basic`，不复制 HP、攻击、
  维护费或征募成本。
- 新兵种、人口/兵源系统、完整地图编辑器和大规模内容生成均需独立合同。

### 已接受首图方向

- 第一条生产链是“伐木场 → 道路接通 → 木材”。
- 农田、粮食、仓储、日期结算、威胁、步兵、将领、科技和军令台已经进入
  P1 技术闭环。
- 建设数据化包含等级、工期、投入、效果、前置、进度和不可建原因。
- “技术闭环通过”不等于“产品体验通过”；首战灰盒仍需真实体验 Gate。
- 数值基线允许在真人测试后局部校准；改变玩家目标、胜负条件或时间压力
  必须重新进入产品方向 Gate。

## 单兵种与驻军守恒

当前唯一兵种：

```text
unit_role.infantry_basic
```

对本城当前单兵种：

```text
total = garrison[unit_role.infantry_basic]
reserved = active reservation committed count or 0
unreserved = max(total - reserved, 0)
dispatch_cap = min(recruitment_cap, effective_command_limit)
dispatchable = min(unreserved, dispatch_cap)
```

合同：

- 预留不扣 `total`，只减少 `unreserved`。
- 战前取消释放预留，不改 `total`。
- 结果应用通过既有原子城市写回仅修改一次 `total`，随后清理预留。
- 训练、紧急动员和恢复都写回同一私有 `GarrisonState`。
- 负数、超量、未知兵种、重复预留和冲突结果必须拒绝且零写入。
- read model 必须深复制，调用方不能借引用修改城市真相。

当前没有接受的人口/兵源源状态。训练消耗
`UnitRole.recruit_food_per_unit`，并受征募容量和有效指挥上限约束；不得从
居民数字或 UI 标签中推导并消耗虚构人口。

## TrainingQueue 合同

`TrainingQueue` 是训练订单唯一源状态。每个订单至少包含：

- `order_id`；
- `city_id` 和稳定 `unit_role_id`；
- 数量、已支付成本和下单日；
- 完成日与明确 phase。

行为：

- 订单创建先验证资源、容量、供养、日期和 stable-ID 可分配性。
- 扣费、订单发布、ledger 和序列推进属于同一原子边界。
- 完成只发生在城市战略日边界，并只向本城驻军写入一次。
- 旧训练字段只能是只读兼容投影，不能独立推进或恢复。
- 空队列快照可以保留经验证的历史 `last_order_day`；非空队列必须与最大
  下单日一致。

## 战略时间合同

唯一城市时间权威仍在 `ConstructionController`。

| 场景/状态 | 正常城市时间 | 终局时间 |
| --- | --- | --- |
| 城市、未暂停、无战争阻断 | 按 1×/2×/4× 推进 | 不适用 |
| 城市暂停 | 不推进 | 不适用 |
| 战争阻断等待战斗 | 不推进 | 不适用 |
| C0/遭遇战实例 | 不由城市 `_process` 推进 | terminal duration 通过权威写回应用一次 |
| 场景切换或恢复中 | 不隐式补时 | 验证完成后恢复明确状态 |

边界顺序：

1. 读取并验证权威时间状态；
2. 计算跨越的日边界；
3. 依次执行确定的日结算；
4. 完成训练和威胁推进；
5. 发布 read model。

暂停、速度、战争阻断和场景切换不能建立第二个计时器。

## ArmyRegistry 合同

`ArmyRegistry` 是持久军队集合，不是 singleton。每个 `ArmyState` 使用
稳定逻辑 ID，至少包含：

- `army_id`、home/target city ID；
- route/node 等逻辑标识；
- phase、兵力和整数毫秒进度；
- reservation/transaction/result 身份；
- 必要的 settlement/disposition 信息。

持久模型禁止包含：

- `Node`、场景路径或对象引用；
- 像素坐标、插值后的表现坐标；
- UI 选择、弹窗或动画状态；
- 只能由场景 fixture 解释的数据。

V5 最多一支 active 是 validator policy。抵达、结算和返回必须幂等；重载后
只推进剩余逻辑时长。

## 遭遇、战斗与写回

### BattleRequest 与快照

派遣入口冻结本次事务所需的城市、兵种、数量、路线、敌军、事务 ID 和版本
信息。战场不回读可变城市状态来改变已提交战斗。

### BattleSession

- 使用确定的固定 tick；
- 持有单个战斗实例的单位、命令和 terminal result；
- 只产出事实：终局类型、伤亡、幸存、duration、奖励资格等；
- 不直接改城市、驻军、世界地图或存档。

### 权威写回

只有与城市双向绑定的 `CombatTransactionCoordinator` 可以提交结果。
写回必须同时核对 coordinator、城市、reservation、transaction 和 result
身份。

结果事实经城市策略解析为：

- 胜利后驻扎目标；
- 主动撤退或其他允许结果后返城；
- 失败后关闭军队；
- 首次胜利奖励等城市策略输出。

R2C-02 的固定无头 First War army vertical slice 是该通用策略的受限例外：不建立
目标城市驻扎、owner、faction 或局部状态。无论 terminal outcome，只要有幸存者，
`ArmyRegistry` 就以现有 `RETURNING` phase 回到 `blackstone_city`；零幸存者关闭
原军队记录。它不新增 operation aggregate、ledger、ID sequence 或持久外城战区。

重复同一结果是幂等；相同事务的冲突结果必须拒绝；任何未通过校验的结果
不得部分扣兵、加资源、推进时间或清理 ledger。

### C0 当前产品边界

C0 已实现最多三支步兵小队、两条路线、前进/坚守/撤退、0.25 秒固定 tick
和实际演算结果。首通奖励木材 30、粮食 20 是已接受的可调基线，不代表最终
平衡。C0 通过自动契约不替代玩家对胜败、撤退、路线意义和节奏的体验判断。

## Stable ID 合同

训练和军队 sequence 的精确持久化上限：

```text
MAX_EXACT_PERSISTED_SEQUENCE = 9007199254740991
```

规则：

- 恢复值必须是 Godot `TYPE_INT`；字符串、浮点、null、容器、负数和零拒绝。
- sequence 必须大于快照中已有最大稳定 ID 的序号。
- `MAX_EXACT_PERSISTED_SEQUENCE` 是合法 exhausted sentinel。
- 在 `MAX-1` 可分配一次并推进到 sentinel；其后创建失败且零写入。
- Army exhaustion 必须在 reservation ID、transaction、registry 或 garrison
  写入前失败。
- stable ID 不得因恢复、fallback 或迁移回退而重用。

## V5 持久化与迁移

### 版本层

- envelope 的 `storage_version` 管磁盘编码。
- payload 的 `schema_version` 管领域结构。
- 两者分别校验；未来版本不得静默降级。

V5 snapshot 包含：

- 城市资源、日期、建设、科技和时间状态；
- `GarrisonState`；
- `TrainingQueue`；
- 集合型 `ArmyRegistry`；
- battle/result/settlement 幂等 ledger；
- 必要的稳定 ID 和逻辑进度。

禁止存储 Node、像素、UI、动画、可重建缓存或第二份兼容真相。

### V1 → V2

S1A.2 的裁决保持 `CONDITIONAL_REUSE_ACCEPTED`：

- 允许复用严格校验、不可变代次、临时写入、flush、复读、发布、最终复读、
  SHA-256、writer lock、上一有效代次恢复和只读 V1 import 思路；
- 不采用 V1 exact payload、early-city storage kind、V1 writer/schema 或
  `load_and_restore()` 作为 V5 恢复入口；
- 八个受保护文件不进入当前提交。

迁移流程：

1. 只读 V1 字节，不覆盖或删除源代次；
2. 用 V1 原校验器验证；
3. 在临时内存中构造完整 V2 candidate；
4. 校验 garrison、queue、army、ledger、版本和稳定 ID；
5. 通过 V5 store 发布新的不可变代次；
6. durable publication 完成后再原子应用 live authority。

合法的 V1 空训练队列可以保留历史下单日。非法 V1、未来版本、损坏 envelope
和领域无效 payload 必须拒绝且不污染输入、旧代次或 live state。

### 原子存储与恢复

保存：

```text
preflight → temporary write → flush → reread → publish generation
→ final reread → success
```

恢复：

```text
enumerate newest to oldest → decode → checksum → domain validate
→ build complete candidate → apply transaction → success
```

合同：

- 代次不可覆盖；
- 最新坏档可回退到完整的较早有效代次；
- 未来版本阻止不安全 fallback；
- write、flush、publish、final reread、migration 和 live apply 失败均不得
  部分替换旧权威状态；
- live apply 中途失败必须完整恢复 pre-apply snapshot。

## 执行 Gate

```text
G0 baseline
→ G1 ownership/contracts
→ G2 automated vertical loop
→ G3 full regression
→ G4 real window
→ G5 independent review
→ G6 user playtest/freeze
```

只有 `VERIFIED` 计为完成。实现者测试通过不等于独立复查通过，G2 通过也
不自动启动 G3。

AI 在已授权阶段内可自行做低风险拆分、实现、测试、修复、文档和本地原子
提交。出现以下情况必须停止：

- 未知 dirty 修改或无法调和的事实冲突；
- 需要第二个权威状态或替换核心数据模型；
- 需要存档迁移、新依赖、重大产品方向或跨阶段扩张；
- 无法在当前范围收敛的持续测试失败；
- 需要 push、tag、发布、部署、改写历史或不可逆数据操作；
- 结论必须依赖用户主观体验。

## 当前明确不授权

- 第二兵种；
- 多支 active 军队；
- 敌方战略 AI；
- 正式遭遇战、攻城和战事内城；R2C-02 的固定 headless First War lifecycle
  已完成，但不授权扩展为通用战区；
- 新的持久世界状态；
- P6 军备 UI、P7 冻结、G3–G6；
- V6 及以后；
- S1A.2 八文件进入 Git 或成为 V5 writer/schema；
- push、tag、部署或 fresh-clone 验收。

# 内容定义与关卡生产管线 V0

## 1. 目的

本文件定义建筑、兵种、时代变体、将领、装备、科技、关卡、威胁和奖励的通用内容语法，以及 Codex 批量编写后续内容时必须遵守的预算、校验和用户门禁。

目标是：

- 复用通用能力，不为每个时代重写系统；
- 让静态内容可校验、可预览、可生成；
- 保持现有 placement、占用格、选择和运行时记录的单一权威；
- 在没有真实编辑需求前不维护完整地图编辑器；
- 阻止生成内容静默引入新资源、新胜负规则、新权威状态或新存档结构。

状态：`V0_PROPOSED_AWAITING_VERTICAL_SLICE_ACCEPTANCE`。

## 2. 基本原则

### 2.1 类型化 Godot Resource 优先

运行时使用类型化 Godot `Resource` 表达静态定义，获得：

- 编辑器内字段类型和资源引用检查；
- 稳定 ID 与显式依赖；
- 可由校验器扫描的统一结构；
- 运行时无需解释任意字典；
- 后续可增加调试预览，而不先开发完整编辑器。

JSON 只在确有需要时作为生成交换格式：

```text
Codex 生成 JSON
→ schema 校验
→ 导入类型化 Resource
→ Resource 交叉引用校验
→ 游戏内调试预览
```

JSON 不直接成为第二套长期内容库；导入后的类型化 Resource 才是静态配置来源。

### 2.2 静态定义不是运行时权威

静态定义回答“这种对象是什么”，运行时状态回答“这局发生了什么”。

| 领域 | 唯一权威 | 派生或只读数据 |
| --- | --- | --- |
| placement、建筑记录、占用格 | 现有 `ConstructionController` | 道路格集合、建筑运行原因 |
| 当前选择 | 现有 `BuildingSelectionController.selected_placement_id` | 描边、详情面板内容 |
| 输入 | 现有 `map_pan_controller.gd` | 控件消费结果 |
| 城市运行态 | P1 未来新增的单一城市状态所有者 | 容量剩余、可承担操作 |
| 道路连通 | 从 placement 派生 | 连通集合和可达路径 |
| 关卡静态内容 | `LevelDefinition` | 调试预览 |
| 关卡进度 | P1 未来单一进度所有者 | 首通／重打显示状态 |

Resource 不保存当前余额、当前日期、当前部队、已放置实例或已选中对象。运行时状态也不复制完整静态定义。

## 3. 稳定标识规则

- 所有定义使用稳定、小写、ASCII、命名空间化 ID，例如 `building.logging_camp.t1`。
- 显示名、时代皮肤和本地化文案不得充当主键。
- 时代变体通过稳定角色 ID 关联，例如 `unit_role.shield`。
- ID 发布后不得静默改义；需要替换时创建新 ID，并在正式存档阶段另行设计迁移。
- P1 内存态可以不实现迁移，但仍按未来可持久化的合同命名。

## 4. 核心定义语法

以下字段是 V0 规划，不要求 P1-00B 本轮创建脚本或 Resource 文件。

### 4.1 `BuildingDefinition`

描述一种可建或固定建筑：

```text
id
display_name_key
era_id
placement_kind
footprint_cells
road_anchor_offsets
requires_road
build_cost
capability_ids
visual_ref
tags
```

约束：

- `footprint_cells` 和道路锚点必须在同一网格坐标系。
- `placement_kind` 只能从已批准枚举选择，如 `building`、`road_segment`、`defense_segment`。
- `build_cost` 只能引用已批准资源。
- 固定建筑可以使用定义，但其场景节点和 placement 仍由现有统一记录注册。

### 4.2 `BuildingCapability`

组合通用功能，不为每个建筑创建专用系统。

V0 允许的能力类型：

- `road_root`
- `production`
- `storage`
- `defense`
- `recruitment_capacity`
- `training`
- `research`
- `date_control`
- `threat_overview`
- `campaign_launch`

公共字段：

```text
id
capability_type
parameters
requires_operational
stack_rule
```

`parameters` 必须由能力类型的类型化子资源或明确 schema 约束，不允许任意键静默改变规则。

示例：

```text
production:
  resource_id: resource.wood
  amount_per_day: 18

storage:
  resource_ids: [resource.wood, resource.food]
  capacity_delta: 120
```

### 4.3 `UnitRole`

描述跨时代稳定的战术角色：

```text
id
role_kind
counter_target_role_id
counter_bonus
countered_penalty
base_command_weight
allowed_equipment_slots
```

V0 角色：

- 第一时代 `unit_role.infantry_basic`，无克制；
- 后续 `shield`、`spear`、`cavalry`、`archer`；
- 辅助角色使用独立标签，不强行参加四角色循环。

### 4.4 `EraUnitVariant`

为稳定角色提供时代名称、视觉和数值：

```text
id
unit_role_id
era_id
display_name_key
visual_ref
hp
attack
armor
move_speed
recruit_cost
maintenance
```

它不能修改克制拓扑；克制关系属于 `UnitRole`。

### 4.5 `GeneralArchetype`

```text
id
display_name_key
command_limit
modifier_ids
allowed_unit_role_ids
visual_ref
```

首图只允许先锋官、守备官、辎重官三种原型和一个槽位。后续人物可以复用原型，个体叙事不应复制一套战斗公式。

### 4.6 `EquipmentTemplate`

```text
id
display_name_key
slot
era_id
modifier_ids
rarity
visual_ref
```

V0 预算：

- 武器：攻击 `+5%～12%`；
- 护甲：生命或防御 `+5%～12%`；
- 信物／辎重：指挥或后勤 `+5%～10%`。

首图不允许随机词条、随机稀有度、制作配方或掉落池。

### 4.7 `TechNode`

```text
id
display_name_key
branch_id
cost
prerequisite_ids
effect_ids
level_whitelist
```

约束：

- 先决条件必须无环；
- 首图只开放 2～3 个节点；
- 效果只能引用已批准 modifier 或 capability 参数；
- 关卡白名单决定本图可见节点，定义资源不保存玩家已研究状态。

### 4.8 `LevelDefinition`

```text
id
display_name_key
map_ref
map_bounds
player_spawn
road_root_refs
fixed_building_refs
buildable_definition_ids
tech_node_ids
initial_city_state
enemy_roster
threat_schedule_ref
objective_ids
reward_definition_ref
checkpoint_rules
replay_policy
```

它描述一张关卡允许什么，不保存当前局发生了什么。

### 4.9 `ThreatSchedule`

```text
id
max_day
events
enemy_reinforcements
harassment_events
day_limit_rule
public_forecast_fields
```

每个事件至少包含：

```text
day
event_type
preconditions
public_preview
effects
stable_target_rule
```

事件日期必须严格有效且可排序；相同日期事件使用显式优先级，不依赖资源文件加载顺序。

### 4.10 `RewardDefinition`

```text
id
first_clear_rewards
replay_rewards
canonical_history_effects
idempotency_key
```

约束：

- 首通奖励必须有唯一幂等键；
- 重打不得再次应用 `canonical_history_effects`；
- 奖励引用的资源、装备和解锁必须存在；
- V0 不允许把奖励逻辑散落在关卡脚本中。

## 5. 通用内容与时代复用

### 5.1 建筑

建筑由“定义 + 能力组合 + 时代外观”构成：

```text
伐木场名称与外观
+ production(resource.wood, 18/day)
+ requires_road
+ 2x2 footprint
```

后续时代可以替换名称、视觉、成本和数值，但不能为同一种生产能力重写结算、道路连通或存档规则。

### 5.2 兵种

`UnitRole` 保持战术身份和克制拓扑，`EraUnitVariant` 提供时代数值和表现。这样后续时代无需复制四套克制代码。

### 5.3 将领

将领个体引用 `GeneralArchetype` 和受控 modifier。叙事身份、姓名和图像可以变化，指挥与加成仍走统一预算。

### 5.4 装备

装备只组合已批准的槽位和 modifier。Codex 可以生成名称、时代描述和预算内数值，不能创造新槽位或新结算阶段。

### 5.5 科技

科技通过受控 effect 引用修改既有能力参数。新增科技节点不等于新增系统；无法用既有 effect 表达的科技必须进入用户方向门禁。

## 6. Codex 可自主编写的内容

在已获批的时代、预算和关卡目标内，Codex 可以：

- 根据固定角色生成时代名称、描述和视觉占位；
- 组合已批准的建筑能力；
- 在预算范围内拟定成本、产量和单位数值；
- 生成少量固定装备；
- 编写 `LevelDefinition`、`ThreatSchedule` 和敌军编组；
- 生成事件文案和公开预警；
- 运行结构校验、平衡模拟和调试预览；
- 修复引用、预算、可达性和时序错误；
- 在同一阶段内形成原子提交。

Codex 不得静默：

- 新增资源种类；
- 新增可独立写入的运行时权威；
- 改变道路、日期、胜负、首通或重打规则；
- 新增存档字段、迁移或兼容层；
- 新增依赖；
- 改变玩家主要目标、操作方式或信息架构；
- 用关闭校验器或降低阈值的方式让内容“通过”。

## 7. 内容预算

### 7.1 第一张地图预算

- 正式资源：木材、粮食。
- 第一时代核心兵种：一种步兵。
- 将领槽：一个。
- 将领原型：三个。
- 可选科技：定义 6 个，单局开放 2～3 个。
- 装备：仅少量固定模板；可以为 0。
- 生产建筑：伐木场、农田。
- 防御选择：瞭望塔；木栅可延后。
- 敌军时间线：第 1、5、8、10、12 日的已定义阶梯。
- 极限日期：12。

### 7.2 数值调整预算

- `P1_FIRST_MAP_VERTICAL_SLICE_V0.md` 中的校准值，真人测试后默认允许约 `±15%` 调整。
- 日期位置、极限日、玩家可提前进攻、极限日不清洗基地等结构性规则不属于数值微调。
- 超过预算或改变合理通关窗口时，必须记录模拟结果并进入用户体验门禁。

### 7.3 后续生成预算

- 时代变体必须复用已存在角色、能力和 modifier。
- 每个新关卡只能使用其 `LevelDefinition` 白名单中的内容。
- 敌军预算必须同时提供提前、推荐、极限三个窗口。
- 首通奖励必须唯一；重打奖励不得改变正史。
- 单个关卡不得为了“有特色”引入只服务本关的新资源或新权威状态。

## 8. 关卡生产管线

当前采用：

```text
设计目标
→ LevelDefinition 草案
→ Codex 编写类型化配置或 JSON 交换稿
→ schema 与引用校验
→ 导入／生成 Godot Resource
→ 结构与平衡校验
→ 游戏内调试预览
→ 自动 smoke
→ 用户实体游玩
→ 原子提交与阶段封存
```

### 8.1 配置校验器

至少检查：

1. ID 唯一且格式有效。
2. 所有 Resource 引用存在，引用类型匹配。
3. 地图边界、出生点和目标位置有效。
4. 固定节点、建筑 footprint 和事件占用不越界、不重叠。
5. 出生点与目标可达。
6. 道路根、建筑锚点和可建区域可以形成有效路径。
7. 敌军预算位于关卡难度范围。
8. 事件日期、优先级和前置条件有效。
9. 所有玩家惩罚均有公开预览字段。
10. 目标与奖励引用存在。
11. 首通奖励幂等键唯一。
12. 重打不修改正史和永久城市状态。
13. 提前、推荐和极限日期至少各有一个可通关窗口。
14. 第 12 日防死档入口完整。
15. 内容未引用本关卡白名单之外的资源、科技或单位。

### 8.2 平衡模拟

模拟器不是“好玩”的证明，只用于排除显然无解或无选择的配置。

至少覆盖：

- 最短伐木场接路路线；
- 先农田、先瞭望塔、先募兵等可行分支；
- 不足城防和达标城防；
- 提前攻击、推荐日期攻击、极限日攻击；
- 资源容量、维护粮食和训练上限；
- 紧急动员；
- 第 9 日检查点恢复后不可复制收益；
- 首通与重打幂等。

输出应说明成功路径、失败原因和关键资源余量，不能只给 PASS。

### 8.3 游戏内调试预览

调试预览只用于检查：

- 地图边界、出生点和目标；
- 道路根和建筑锚点；
- 事件时间线；
- 敌军预算；
- 当前关卡白名单；
- 首通／重打策略。

预览不能写入正式运行态或成为第二个地图编辑器。

## 9. 为什么现在不做完整地图编辑器

- 当前只有第一张地图的真实需求，编辑器字段尚未被多张地图验证。
- 过早制作编辑器会冻结尚未稳定的 Resource schema 和 UI 工作流。
- Codex 可以直接编写受类型和校验器约束的配置。
- 调试预览足以发现边界、可达性、引用和时序错误。
- 用户当前最重要的判断是首图玩法和压力是否成立，不是工具是否精致。

满足任一条件再重新评估编辑器：

- 有约 8 张关卡需要持续维护；
- 单张关卡的常规修改稳定超过 30 分钟；
- 同类坐标、路径或事件错误持续出现，文本配置和预览不足以避免；
- 非程序人员需要直接承担关卡生产；
- schema 已稳定到编辑器不会频繁重做。

评估编辑器本身属于独立阶段，不自动包含在内容生产授权内。

## 10. 首图与“告示板／历战”的现实边界

当前仓库没有告示板节点。内容语法可以预留关卡历史和重打规则，但本阶段：

- 当前主战目标只从军令台进入；
- 城市警报使用已有固定 UI；
- 不新增或重命名固定建筑；
- 不创建无法使用的“历战”按钮；
- 后续宿主必须由用户另行授权。

这不会阻断首图纵向切片，但会阻断“告示板右上角历战入口”的实际 UI 实现。

## 11. 回滚和版本边界

- 每个 P1 里程碑一个原子提交。
- 静态定义、运行时实现、校验器和验收文档按职责审查，不能混入未知修改。
- 类型化定义上线前，保留 P0 统一建筑记录和测试作为回归基线。
- 若新定义要求复制 placement、occupancy、选择或城市运行态，立即停止。
- 若需要正式存档迁移、新依赖或历史改写，立即停止。
- push、tag、Release、PR 和部署仍需明确授权。

## 12. 接受后的执行方式

用户接受 `FIRST_MAP_VERTICAL_SLICE_V0` 后，P1-A～P1-F 可作为一次连续授权：

```text
类型定义、道路、伐木场
→ 农田、粮食、日期
→ 威胁、城防、极限日
→ 募兵、将领、科技
→ 军令台、关卡定义、首图串联
→ 校验、模拟、用户实体体验门禁
```

Codex 在阶段内自主完成低风险工程选择、编码、测试、修复、文档和本地原子提交。只有触发 `docs/process/PROJECT_EXECUTION_GATES.md` 的停止条件，或到达最终实体体验门禁时返回用户。

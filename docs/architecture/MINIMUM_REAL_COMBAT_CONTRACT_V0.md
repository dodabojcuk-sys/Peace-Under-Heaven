# MINIMUM REAL COMBAT CONTRACT V0

状态：`PROPOSED / AWAITING USER DECISION`

用途：为 `P1-E` 定义一个真实、可交互、可重复验证的最小战斗事务边界。本文件只冻结契约，不代表运行时代码已实现。

## 1. 当前仓库事实

- 当前唯一主场景是 `res://scenes/blank_map.tscn`。
- `BlankMapRoot` 持有唯一 `_input` 路径；`ConstructionController` 持有城市资源、日期、步兵、将领、科技、威胁、placement 和占用格等运行时权威状态。
- 当前不存在战斗场景、战斗会话、结果回调、奖励执行器或跨场景事务。
- `CommandPlatform` 当前只显示“真实战役契约接入前不提供假入口”，没有攻击按钮。
- 当前没有正式存档；第 9 日检查点只是内存恢复快照。
- `P1_FIRST_MAP_VERTICAL_SLICE_V0` 的战备代理只用于自动平衡，不是运行时战斗公式。

## 2. 旧资料决策表

只读参考：

- `/Users/m1-meng/Documents/Codex_workspace/txwzs-rebuild-godot/docs/design/TXWZS_CANONICAL_FIRST_WAR_FULL_LOOP_001.md`
- `/Users/m1-meng/Documents/Codex_workspace/txwzs-rebuild-godot/docs/devlog/TXWZS_CANONICAL_FIRST_WAR_FULL_LOOP_001.md`
- `/Users/m1-meng/Documents/Codex_workspace/txwzs-rebuild-godot/docs/devlog/TXWZS_CANONICAL_FIRST_WAR_FULL_LOOP_001_TESTS.md`
- `/Users/m1-meng/Documents/Codex_workspace/txwzs-rebuild-godot/docs/design/TXWZS_DESIGN_DECISIONS.md`
- 旧项目 `AGENTS.md` 中的战斗状态和结算约束。

| 旧结论 | 决策 | 当前解释 |
| --- | --- | --- |
| `BattleRequest → 临时 BattleSession → BattleResult → 确认 → 返回` | 继续沿用 | 保留事务边界和单向生命周期。 |
| 出征兵力先预留，战前取消只释放一次 | 继续沿用 | 预留只改变“可用兵力”，不在战斗结束前扣除城市总兵力。 |
| 撤退、失败也是正式历史结果 | 继续沿用 | 二者都生成正式 `BattleResult`，幸存者只返回一次。 |
| 结果和首通奖励使用稳定 ID 幂等提交 | 继续沿用 | 采用 `result_id` 和 `first_clear_key` 双重门禁。 |
| 战场临时节点不能进入城市 placement | 继续沿用 | 战场节点、路线、门和临时单位不得注册到城市占用格。 |
| 结算浮层阻断点击穿透 | 继续沿用 | 结果确认前禁用战场和城市输入，返回后至少隔一帧恢复。 |
| 同一输入和初始状态得到同一结果 | 继续沿用 | 改用固定时间步和显式命令序列，不使用隐藏随机数。 |
| 聚合兵力而非逐兵 RTS | 修改后沿用 | 改为最多三个可命令的小队；每个小队仍用聚合生命和人数。 |
| 旧 `NationState v13` / `TheaterState` / resolver 直接作为当前架构 | 当前淘汰 | 当前权威状态在 `ConstructionController`，不得恢复旧 Project Dawn 状态树。 |
| 先计算结果，再播放只读战斗表现 | 当前淘汰 | 当前战场本身按玩家命令逐 tick 产生伤亡和胜负。 |
| 纯战力比较自动结算 | 当前淘汰 | 战备代理只能继续用于离线模拟，不得成为运行时胜负真相。 |
| 逐单位 RTS、主动技能、工程兵、复杂地形 | 当前淘汰（C0） | 不进入首个灰盒；只保留明确扩展点。 |
| 首通奖励的具体数值 | 尚未决定 | 当前 P1 基线未冻结奖励内容；候选值见规则文档，等待用户接受。 |
| 跨进程中断后的事务恢复 | 尚未决定 | 当前没有存档。C0 只保证同一运行进程内的原子性和幂等性。 |

旧资料只提供事务语义证据，不授权复制旧运行时代码或恢复旧状态架构。

## 3. 权威所有权

### 3.1 城市权威状态

`ConstructionController` 继续是城市运行态的唯一写入者。C0 可以在同一对象中增加最小字段：

- `active_battle_reservation`：当前唯一兵力预留摘要；空值表示没有出征事务。
- `committed_battle_result_ids`：本次运行内已经应用过的结果 ID 集合。
- `first_clear_keys`：本次运行内已经领取过的首通键集合。

这些字段不是第二套 `WorldState`。任何 UI、战场或结果页都不能直接写城市字段。

`FirstClearLedger` 在 C0 中是 `first_clear_keys` 的契约名称，不要求独立节点或独立可写对象。它是单调集合，不因第 9 日战备检查点恢复而回退。

### 3.2 战斗事务所有者

后续实现只能有一个 `CombatTransactionCoordinator`。它负责：

- 建立和取消请求；
- 请求城市权威对象建立或释放兵力预留；
- 冻结双方快照；
- 创建和销毁临时 `BattleSession`；
- 接收唯一 `BattleResult`；
- 调用唯一 `BattleResultApplier`；
- 控制战场、结果浮层和返回城市的输入生命周期。

它不是城市或国家状态，只能同时持有一个活动事务。事务完成或取消后，临时快照和会话必须销毁。

### 3.3 战场所有权

`BattleSession` 只拥有战场临时状态：

- 固定 tick；
- 路线、城门和临时小队；
- 当前生命、位置、命令和攻击冷却；
- 战斗事件日志；
- 尚未应用的结果。

它不能修改城市资源、步兵、placement、日期、首通或奖励字段。

### 3.4 输入所有权

当前 `BlankMapRoot._input` 继续是唯一原始输入所有者。C0 实现只能按当前事务阶段把意图路由给城市控制器或 `CombatTransactionCoordinator`，不能让战场脚本、每个小队或第二个地图根再实现一套 `_input`。

Godot 原生 `Button` 可以发出自身 GUI signal，但必须由事务协调器验证当前 phase；GUI signal 不是第二套游戏状态写入口。

## 4. 核心契约

### 4.1 BattleRequest

创建时机：玩家在军令台选择关卡、投入兵力并确认出征后。

必需字段：

```text
request_id
level_id
created_day
committed_total
selected_general_id
researched_tech_ids
supply_shortage
player_attack_multiplier
player_defense_multiplier
enemy_count
enemy_fortification
squad_deployments[1..3]
phase
```

`request_id` 在一次事务中稳定且唯一。`phase` 只能按以下方向变化：

```text
DRAFT → RESERVED → SESSION_ACTIVE → RESULT_PENDING → APPLIED
             └──────────────→ CANCELED
```

不得从 `RESULT_PENDING` 返回战斗，也不得复用已完成的 `request_id`。

### 4.2 CommittedForceSnapshot

创建时机：城市权威对象成功建立兵力预留之后、战场实例化之前。

不可变字段：

- `request_id`
- 1 至 3 个稳定 `squad_id`
- 各小队初始人数与路线
- 步兵定义 ID 和基础数值
- 已冻结的攻击、防御、移动修正
- 将领 ID 和实际采用的既有被动
- 科技 ID 和实际采用的既有效果

约束：

- 总投入必须大于 0；
- 总投入不得超过 `infantry_count - active_reserved_count`；
- 小队数量不得超过 3；
- 每名士兵只能属于一个小队。

### 4.3 EnemyForceSnapshot

创建时机：与 `CommittedForceSnapshot` 同一确认边界。

不可变字段：

- `level_id`
- `snapshot_day`
- `enemy_count`
- `fortification_level`
- 两条路线的守军人数
- 两座城门的基础生命和工事加成

日期、敌军数量和工事一旦冻结，推进城市日期或修改其他城市状态都不能改变活动战场。

### 4.4 BattleOrder

字段：

```text
order_id
session_id
squad_id
issued_tick
command = ADVANCE | HOLD | RETREAT
```

规则：

- 一个小队在同一 tick 最多接受一条有效命令；
- 命令在下一个固定 tick 开始时生效；
- `order_id` 单调递增，重复 ID 被拒绝；
- C0 不接受目标点、技能、路线切换或逐单位命令。

### 4.5 BattleSession

创建时机：双方快照完成且战场场景成功加载后。

可变性：只允许固定时间步更新自身临时字段；不能重读城市当前兵力、日期、将领或科技。

销毁条件：

- 结果已成功应用并返回城市；
- 战前取消且预留已释放；
- 场景创建失败并完成安全取消；
- 明确的同进程异常恢复已经回到城市。

### 4.6 BattleResult

战场满足终局条件后创建一次，随后冻结。

必需字段：

```text
result_id
request_id
session_id
level_id
outcome = VICTORY | DEFEAT | RETREAT
started_day
finished_tick
committed_count
survivor_count
casualty_count
enemy_casualties
breached_route
orders_digest
player_snapshot_digest
enemy_snapshot_digest
first_clear_key
```

校验恒等式：

```text
survivor_count + casualty_count == committed_count
0 <= enemy_casualties <= enemy_count
```

结果由实际 tick、命令和临时战场状态生成，不能由 UI 指定，也不能在结果页重新计算。

### 4.7 BattleResultApplier

这是唯一允许把结果写回城市的边界，可以是 `CombatTransactionCoordinator` 的窄接口，不需要第二个全局状态节点。

应用前必须同时验证：

1. `request_id` 与当前活动预留一致；
2. `result_id` 尚未在 `committed_battle_result_ids`；
3. 请求阶段是 `RESULT_PENDING`；
4. 双方快照摘要与会话创建时一致；
5. 兵力恒等式成立。

一次成功应用按不可分割顺序执行：

1. 把 `result_id` 写入已提交集合；
2. 从城市总兵力扣除 `casualty_count`；
3. 清除活动预留，使幸存者重新成为可用兵力；
4. 如果是未领取的首胜，则应用一次奖励并写入 `first_clear_keys`；
5. 保存结果摘要供城市 UI 显示；
6. 把请求标记为 `APPLIED`。

实现时必须先在局部变量中计算并验证全部新值，再在一个不包含 `await`、场景切换或中途 signal 的同步函数内完成赋值；完成后才发出 UI 更新 signal。任何前置检查失败都不得写入部分字段。

重复确认、重复返回或重复调用只返回原提交摘要，不再修改兵力、资源或首通集合。

### 4.8 SceneTransition / ReturnToCityContract

C0 推荐保留 `BlankMapRoot` 和城市权威节点，在其下临时挂载独立战斗 `PackedScene`：

```text
BlankMapRoot
├─ CityWorld / existing city UI          (hidden + input disabled in battle)
├─ CombatTransactionCoordinator
└─ BattleLayer
   ├─ BattleSessionScene                 (temporary)
   └─ ResultOverlay                      (temporary, modal)
```

这不是第二套地图或第二套城市状态。C0 不直接使用 `change_scene_to_file()` 丢弃城市根节点。

进入战斗：

1. 禁用城市 `_input` 的导航、选择和建造分支；
2. 创建战场；
3. 根输入所有者把战斗命令意图路由给事务协调器；
4. 只有战场 HUD 的 GUI 控件可产生战斗按钮 signal。

结果出现：

1. 停止 `BattleSession` tick；
2. 结果浮层设为 modal，并把输入标记为 handled；
3. 禁用确认按钮的重复触发；
4. 成功应用结果后释放战场；
5. 至少等待一个 process frame，再恢复城市输入，防止关闭结算的同一次点击穿透。

返回城市的重复触发由 `result_id` 幂等门禁吸收。

## 5. 兵力预留与取消

出征确认不会立即减少 `infantry_count`，而是在同一城市权威对象中建立：

```text
active_battle_reservation = {
  request_id,
  committed_count
}
```

此后城市可用兵力派生为：

```text
available_infantry = infantry_count - committed_count
```

训练、再次出征和其他消费兵力的操作必须使用 `available_infantry`。这样兵力不会同时留在城市和战场，战斗结束前也不会提前写入伤亡。

战前取消只允许发生在 `RESERVED` 且战场尚未开始时；它清除预留并标记 `CANCELED`。重复取消无效果。`SESSION_ACTIVE` 后的离开只能生成 `RETREAT` 或 `DEFEAT`，不能伪装成取消。

## 6. 异常和中断

### 同一进程内

- 预留后战场加载失败：释放全部预留，不生成历史结果。
- 会话状态无效且尚无结果：停止战场，释放全部预留，记录技术错误，不发奖励。
- 已生成结果但结果页加载失败：保留 `RESULT_PENDING`，不得清理会话或恢复城市输入；允许重新打开同一结果浮层。
- 结果已应用但返回动画或场景清理失败：重复返回只做清理，不重复结算。

### 进程被终止

当前工程没有正式存档，因此 C0 不能承诺跨进程恢复活动事务。V0 的安全边界是：

- 活动战斗期间不提供另存、读档或返回主菜单；
- 崩溃或强制退出会丢失本次进程内全部未持久化进度，而不会留下部分持久化战果；
- 未来若要求跨进程恢复，必须先设计存档版本和迁移协议；这会触发正式停止条件，不能暗中扩展 C0。

## 7. 明确不属于 C0

- 自动战斗或固定胜利；
- 战斗回放作为权威结果；
- 逐士兵微操；
- 主动技能、工程兵、修路、复杂地形、装备、后续兵种；
- 正式战斗 UI、美术、音效和 Figma；
- 多关卡进度、告示板和历战入口；
- 正式存档或迁移；
- 把战场临时单位注册到城市 placement。

## 8. 事实与设计判断

仓库事实：

- 城市状态权威、输入所有者、现有兵种和将领数值来自当前代码与资源；
- 仓库缺少战场和结果契约；
- 当前没有正式存档。

C0 设计判断：

- 采用单一事务协调器；
- 兵力用“预留可用性、结果时扣伤亡”实现；
- 城市根保留、战斗场景临时挂载；
- 使用下述双路线、固定 tick 规则；
- 首通奖励候选值尚待用户确认。

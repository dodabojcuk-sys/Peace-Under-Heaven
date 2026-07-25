# FIRST BATTLE GRAYBOX RULES V0

状态：`ACCEPTED / C0 GRAYBOX IMPLEMENTED`

目的：给首个真实战斗灰盒提供一套可执行、无隐藏随机数的 V0 规则。它是校准起点，不是最终平衡。

## 1. 战场范围

- 两条固定进攻路线：
  - `FRONT_GATE`：较短、门更坚固、守军占比更低；
  - `SIDE_GATE`：较长、门较弱、守军占比更高。
- 第一时代只有步兵。
- 玩家投入 1 至 3 个小队，总人数不能超过城市可用步兵和现有将领指挥上限。
- 每个小队在出征确认时选择一条路线；C0 战斗中不能换线。
- 敌军是每条路线上的聚合守军，不做逐兵 AI。
- 玩家只下达 `前进 / 坚守 / 撤退`。

两条路线验证的是“集中突破还是分兵试探”，不引入复杂地形。

## 2. 固定时间步

```text
TICK_SECONDS = 0.25
ATTACK_INTERVAL_TICKS = 4
MAX_BATTLE_TICKS = 720   # 180 秒
```

同一初始快照和同一 `BattleOrder` 序列必须得到完全一致的事件日志和结果。

每个 tick 的顺序固定为：

1. 应用本 tick 生效的命令；
2. 更新撤退和前进位置；
3. 根据 tick 开始时的状态建立所有攻击意图；
4. 同时应用双方伤害；
5. 更新存活人数；
6. 检查胜利、失败、撤退和超时。

同时结算避免“数组中先处理的一方先杀死对手，从而取消对方同 tick 攻击”的顺序偏差。

## 3. 单位和聚合生命

当前步兵静态定义直接沿用：

```text
HP_PER_MEMBER = 100
ATTACK_PER_MEMBER = 10
MOVE_SPEED = 1.0
ARMOR_PER_MEMBER = 0
```

小队字段：

```text
initial_members
total_hp = initial_members * HP_PER_MEMBER
alive_members = ceil(total_hp / HP_PER_MEMBER)
position
route_id
active_order
attack_cooldown_ticks
```

不保存逐个士兵对象。`total_hp <= 0` 时小队被消灭。

## 4. 路线和工事

| 路线 | 接敌位置 | 基础门生命 | 敌军占比 |
| --- | ---: | ---: | ---: |
| `FRONT_GATE` | 80 | 600 | 40% |
| `SIDE_GATE` | 120 | 360 | 60% |

敌军分配：

```text
front_enemy = ceil(enemy_count * 0.40)
side_enemy = enemy_count - front_enemy
```

工事只提高城门生命，不隐藏提高敌军攻击：

```text
gate_hp = base_gate_hp + 120 * fortification_level
```

当前冻结威胁快照：

| 日期 | 敌军 | 工事 | 正门 / 侧门守军 | 正门 / 侧门 HP |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 32 | 0 | 13 / 19 | 600 / 360 |
| 5 | 40 | 0 | 16 / 24 | 600 / 360 |
| 8 | 48 | 1 | 20 / 28 | 720 / 480 |
| 10 | 56 | 2 | 23 / 33 | 840 / 600 |
| 12 | 64 | 2 | 26 / 38 | 840 / 600 |

守军在 C0 中不移动。当玩家小队到达本路线城门时，守军开始攻击；玩家必须先破门，破门后才能伤害守军。

## 5. 三种命令

### ADVANCE / 前进

- 未接敌时每 tick 按 `position += MOVE_SPEED * TICK_SECONDS` 向城门移动；
- 接敌后停在城门；
- 攻击倍率 `1.00`；
- 承受伤害倍率 `1.00`；
- 城门存在时攻击城门，门破后攻击本路线守军。

### HOLD / 坚守

- 位置不前进；
- 已接敌时继续攻击；
- 攻击倍率 `0.85`；
- 人员承受伤害倍率 `0.75`；
- 未接敌时不会远程攻击。

### RETREAT / 撤退

- 每 tick 按 `position -= MOVE_SPEED * 1.25 * TICK_SECONDS` 向己方出发点移动；
- 不攻击；
- 人员承受伤害倍率 `1.15`；
- `position <= 0` 时该小队安全撤出，不再参与战斗。

默认命令是 `HOLD`。命令可以在战斗中改变，无资源消耗；同一小队同一 tick 的第二条命令被拒绝。

## 6. 伤害公式

所有浮点倍率先相乘，最后向下取整。最小有效伤害为 1。

### 玩家攻击

```text
raw_player_damage =
  alive_members
  * ATTACK_PER_MEMBER
  * city_attack_multiplier
  * order_attack_multiplier
  * supply_multiplier

player_damage = max(1, floor(raw_player_damage))
```

其中：

- 先锋官：`city_attack_multiplier × 1.10`；
- 队列操练科技：`city_attack_multiplier × 1.10`；
- 两者存在时相乘；
- 供给不足：`supply_multiplier = 0.90`，否则 `1.00`。

### 敌军攻击玩家

```text
raw_enemy_damage = enemy_alive_members * ATTACK_PER_MEMBER

player_personnel_damage =
  max(
    1,
    floor(
      raw_enemy_damage
      * incoming_order_multiplier
      / city_defense_multiplier
    )
  )
```

其中：

- 守备官：`city_defense_multiplier = 1.12`；
- 其他将领：`1.00`；
- `ADVANCE = 1.00`、`HOLD = 0.75`、`RETREAT = 1.15`。

### 城门

城门没有人员、护甲或反击。玩家对城门使用同一个玩家伤害公式。多支同路线小队的伤害相加。

### 辎重官

辎重官现有被动是城市每日维护降低 20%，不是战场伤害效果。C0 不发明额外战斗加成；它只通过战前能够维持更多部队间接影响出征。

## 7. 终局判定

每个 tick 结算伤害后按以下优先级判断：

1. `VICTORY`：任一路线城门生命为 0、该路线守军生命为 0，且至少一支该路线玩家小队仍存活并未撤出。
2. `DEFEAT`：所有投入小队都已被消灭。
3. `RETREAT`：至少下达过一次撤退命令，且所有未被消灭的小队均已安全撤出。
4. `DEFEAT`：达到 `MAX_BATTLE_TICKS` 仍未胜利；当前存活者作为幸存者返回。

`RETREAT` 和 `DEFEAT` 都是正式结果。失败不等于全军覆没，超时失败的幸存者仍返回；只有实际失去的聚合生命转换为伤亡。

幸存人数按结果时各小队 `ceil(total_hp / 100)` 求和。受伤但存活的人员回城后恢复为完整步兵；C0 不持久化伤员状态。

## 8. 玩家战略选择

- 集中正门：距离短、守军较少，但必须打掉更坚固的门。
- 集中侧门：距离长、门较弱，但守军主动集中在较脆弱入口。
- 分兵：可以观察两路进度并决定撤回弱势小队，但投入伤害被分散。
- `HOLD` 用于降低接敌后的人员损失，而不是免费远程输出。
- `RETREAT` 会暴露于更高伤害，但能保存成功撤出的幸存者。

C0 不承诺三种策略已经平衡。后续实现必须先用确定性模拟找出至少一个合理胜利窗口，再由用户判断节奏和可读性。

## 9. 首通奖励 V0 基线

用户已确认以下数值作为 C0/P1 首轮可调基线：

```text
first_clear_key = "first_map.main_assault.v0"
首次胜利：木材 +30，粮食 +20
重复胜利：0
```

处理规则：

- 只在首次胜利确认时应用一次；
- 奖励遵守当前容量上限；
- 结果摘要必须分别显示计划奖励、实际入账和容量溢出；
- ledger 先检查、一次应用、再写入 key，重复结果不再领取；
- 自动测试使用独立 fixture 验证幂等性，但不能替代用户对奖励节奏的体验判断。

该量级约等于部分早期建造或短期维护，不引入新资源类型，也不决定未来关卡奖励体系；它不是最终平衡。

## 10. 扩展点

只预留数据字段或接口位置，不在 C0 实现：

- `terrain_modifier_id`
- `active_skill_orders`
- `engineer_actions`
- `equipment_loadout`
- `unit_role_id` 的后续兵种

扩展点不能进入 V0 tick 公式，也不能生成空按钮。

## 11. V0 校准声明

以下全部是首轮可测试参数，不是最终平衡或存档承诺：

- 0.25 秒 tick；
- 180 秒上限；
- 路线长度；
- 城门生命；
- 正门 40%／侧门 60% 守军分配；
- 三种命令倍率；
- 供给不足倍率；
- 首通奖励 V0 基线。

调整这些值必须有模拟或实体测试证据。改变胜负条件、命令集合、权威所有权或兵力事务边界需要重新经过用户方向门禁。

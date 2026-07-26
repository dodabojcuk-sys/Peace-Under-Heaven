# Noticeboard Mission Pack V0

## 职责边界

- 告示板承载城内事件、居民委托、小型战斗、搜索与治安任务。
- 军令台继续独占北坡敌袭、主线战役和大型军事行动。
- 城主府继续承载城市治理、升级与全局信息。
- 三者是三个固定城市入口，不合并为通用任务面板。

## 运行时结构

`MissionDefinition` 是只读静态内容定义。告示板选择 `mission_id` 后，由唯一
`ConstructionController` 创建现有 `C0BattleGraybox`，后者仍通过
`CombatTransactionCoordinator → BattleSession → BattleResultApplier →
ReturnToCityContract` 完成兵力预留、战斗、幂等写回和返回。

任务只在当前进程保存 `AVAILABLE / IN_PROGRESS / COMPLETED` 状态。V0 不使用
`FileAccess`，不增加 save schema，也不建立第二套 CityState、资源账本或战斗状态。

## 三项任务

| mission_id | 目标 | 真实玩法差异 | 首胜奖励 |
|---|---|---|---|
| `noticeboard.outskirts_sweep.v0` | 消灭两条路线全部敌人 | 必须继续寻找并清除剩余敌军 | 木材 12、粮食 8 |
| `noticeboard.supply_relief.v0` | 固定粮车存活且来袭敌人清零 | 无人拦截的敌军会持续攻击粮车，目标摧毁立即失败 | 木材 8、粮食 16 |
| `noticeboard.missing_scout.v0` | 进入隐藏搜索区发现斥候，再让有效小队撤离 | 清敌不直接胜利；发现与撤离缺一不可 | 木材 16、粮食 6 |

三个任务共用 `res://scenes/c0_battle_graybox.tscn`，路线名称、距离、敌军部署、
特殊目标和奖励由定义加载，不复制战斗场景。

## 胜负、退出与奖励

- 战前返回取消 `RESERVED` 兵力预留，不生成战果。
- 战中退出继续使用 C0 安全退出确认，并设置正式全军撤退意图。
- 胜利、失败、撤退均生成一次正式 `BattleResult` 并返回同一城市。
- 奖励只来自现有木材、粮食，且只在每项任务当前进程首次胜利时发放一次。
- 失败、撤退和历史重玩胜利不发放首胜奖励。
- 结果 ID、transaction ID 和 first-clear key 共同防止重复确认、重复信号和重复返回。

## 瞭望塔目录资格

`BuildingDefinition.build_catalog_visible` 默认 `true`。瞭望塔定义设置为 `false`，
因此不再出现在玩家通用建造目录；定义、数值、占地和 fixture placement 仍可查询与
显示，未来可继续作为固定防御据点或战场内容。

## V0 限制

- 告示板任务状态仅为当前进程内存态。
- 粮道求援使用固定粮车，不实现移动护送 AI。
- 失踪斥候使用确定性隐藏搜索区，不实现复杂战争迷雾。
- 当前为 Graybox，不包含正式地图、美术、建筑移动或 CitySandboxV0。
- P1-F1B 原子道路事务仍未开始。

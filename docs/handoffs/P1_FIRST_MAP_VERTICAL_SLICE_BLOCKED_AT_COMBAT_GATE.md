# P1 首图纵向切片：战斗契约门禁交接

## 1. 状态

- 日期：2026-07-25
- 任务：`TXWZS-P1-FIRST-MAP-VERTICAL-SLICE-CONTINUOUS-IMPLEMENTATION`
- 基线：`FIRST_MAP_VERTICAL_SLICE_V0`
- 当前结论：`P1_CONTINUOUS_IMPLEMENTATION_BLOCKED_AT_P1_E_COMBAT_CONTRACT_GATE`
- P1-A 至 P1-D 已完成并形成独立本地提交。
- P1-E 未实现；P1-F 未开始。
- P1 运行时代码未 push，未创建 tag、Release 或 PR。

## 2. 已完成阶段

| 阶段 | 本地提交 | 完成内容 |
| --- | --- | --- |
| P1-A | `6fec5ca` | 类型化建筑定义、道路 placement、四向连通、伐木场启停与木材日产 |
| P1-B | `c953b9a` | 农田、粮食、仓库容量、确定的每日结算明细 |
| P1-C | `45acb9f` | 第 5／8／10／12 日压力、城防减损、第 9 日检查点、第 12 日推进门禁 |
| P1-D | `a685cb8` | 步兵征募与维护、一个将领槽、三个将领原型、三个科技节点、一次紧急动员 |

已接受的文档基线 `b3114c2` 已在开始实施前安全 push 到
`origin/main`；fetch 后确认远端没有分叉。以上四个运行时代码提交保留在本地，
没有 push。

## 3. P1-E 实际仓库证据

当前运行时表面只有：

- 唯一场景：`res://scenes/blank_map.tscn`
- 地图输入：`scripts/map_pan_controller.gd`
- 城市／建造运行态：`scripts/construction_controller.gd`
- 建筑选择：`scripts/building_selection_controller.gd`
- 静态内容定义脚本：建筑、能力、威胁、兵种、将领和科技 Resource

全仓库运行时代码与资源搜索未发现：

- 战斗场景或战斗会话；
- 攻击请求／出征命令契约；
- 胜利／失败结果对象或回调；
- 奖励执行器和首通幂等进度所有者；
- 战斗返回城市的场景切换契约。

现有军令台的权威说明为：

> 真实战役契约接入前不提供假入口

`P1_FIRST_MAP_VERTICAL_SLICE_V0` 中的确定性战备比只用于自动平衡代理，
文档明确它不是永久战斗公式。把该公式直接接成运行时胜负，或新增固定成功按钮，
都会发明新的胜负／结果契约并违反本任务的正式停止条件。

因此本轮没有新增：

- `LevelDefinition` 运行时攻击入口；
- 假军令台按钮；
- 固定成功或固定失败；
- 奖励状态；
- 第二套可写关卡进度；
- 告示板或历战入口。

## 4. 自动验证边界

阶段完成后，8 个 Godot smoke runner 全部通过：

1. `run_building_lifecycle_smoke.gd`
2. `run_building_selection_smoke.gd`
3. `run_construction_placement_smoke.gd`
4. `run_p1a_road_logging_smoke.gd`
5. `run_p1b_daily_economy_smoke.gd`
6. `run_p1c_threat_deadline_smoke.gd`
7. `run_p1d_army_tech_smoke.gd`
8. `run_unified_building_interaction_smoke.gd`

同时通过：

- Godot 4.5.1 headless 主场景 smoke；
- Godot 4.5.1 headless editor scan；
- `git diff --check`。

本次停止发生在 P1-E 入口，因此没有执行或声称完成：

- 提前、推荐日期和极限日真实进攻；
- 首通奖励唯一性；
- P1-F 六类确定性平衡模拟；
- AI 从建设到攻击的完整操作路径；
- P1 用户实体“是否好玩／是否易懂／压力是否合适”门禁；
- 运行窗口截图验收。

## 5. 继续实施所需门禁

继续 P1-E 前必须获得一个真实、单一的最小战斗／结果契约，至少明确：

1. 城市侧如何创建一次攻击请求。
2. 战斗侧接收哪些军队、将领、日期、敌军和工事字段。
3. 谁产生胜利／失败结果，结果的类型与生命周期是什么。
4. 失败后如何进入第 9 日检查点或重开，不复制消耗与已知结果。
5. 首通奖励由哪个唯一进度所有者执行幂等校验。
6. 如何从战斗返回当前城市运行态。

这属于产品和架构方向门禁，不能由阶段内 helper 命名或测试 fixture 代替。
契约获批后，才能继续 P1-E 串联、P1-F 平衡模拟和最终用户实体体验门禁。

# TXWZS V4 C0 City Time Settlement Implementation 001

## 结论与范围

本轮仅实现正式 C0 的城市时间结算；不恢复黑石堡视觉切片，也不改变战果、奖励、城市时间长度、存档、S1A.2 或 V5。实现完成后状态为：

```text
C0 result-source gate: CLEARED_AS_MISSCOPED
C0 city-time settlement: IMPLEMENTED_PENDING_INDEPENDENT_REVIEW
Blackstone visual slice: PAUSED_BY_C0_TIME_SETTLEMENT_REVIEW
V4 UI: REPAIR_REQUIRED
T-V4-003: NOT PASS
V5: FROZEN
```

前一轮诊断 `TXWZS_V4_C0_RESULT_TIME_DIAGNOSIS_001.md` 的结论保持不变：C0 战果来源 Gate 是误指向黑石堡的 Gate，并非本轮的改动对象。唯一实现目标是使正式 C0 的 canonical `BattleResult.finished_tick` 在首次 canonical result 提交时，按唯一 tick 来源结算城市时间。

## 开始身份与保护快照

本轮独立证据目录：

```text
/tmp/txwzs-v4-c0-city-time-settlement-implementation-001.20260729-220207
```

开始身份：`main`，`HEAD=64f37bda130397f08cdd012609dc2d3a5f5c6b99`，upstream 为 `origin/main`，ahead/behind 为 `29/0`，staged 为 `0`。开始时 tracked patch SHA-256 为：

```text
b3aec131692613e55058d38136907f1e637265d9cf8c4e7cb59211c786b32428
```

开始快照已保存 `pwd`、身份、status、working diff、cached diff、untracked manifest、受保护哈希和既有报告哈希。没有使用 `reset`、`checkout`、`clean` 或 `stash`。

三个既有 V4 dirty 文件在结束时仍与开始快照一致，且未被本轮编辑：

| 文件 | SHA-256 |
| --- | --- |
| `scenes/blackstone_expedition_mvp.tscn` | `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957` |
| `scripts/mvp/blackstone_expedition_mvp.gd` | `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393` |
| `tests/run_blackstone_playable_mvp_smoke.gd` | `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac` |

S1A.2 八个保护文件、原审查/修复/复审报告及两份既有 V4 报告均按开始快照保持不变。结束身份、哈希、范围和最终 diff 的复核记录在同一证据目录。

## 实现的唯一数据路径

```text
BattleSession._complete
  -> BattleResult.finished_tick
  -> BattleResult.get_duration_milliseconds()
  -> CombatTransactionCoordinator.confirm_result()
  -> BattleResultApplier.apply()
  -> ConstructionController.apply_battle_result_atomic()
  -> validation / committed-ledger check / in-flight guard
  -> _advance_city_time_for_battle_settlement()
  -> _advance_day_boundary(true) for crossed boundaries
  -> casualty / defense / enemy / reward writes
  -> committed result ledger and city summary
```

`BattleResult.get_duration_milliseconds()` 直接使用 `BattleSession.TICK_MILLISECONDS`。`ConstructionController` 中没有 250ms 或 0.25s 的并行常量或推算。所有新时间运算使用整数毫秒；`day_elapsed_seconds` 仅在最后一次换算回 UI/既有存储字段。

`apply_battle_result_atomic()` 的写入顺序是：

1. 验证 request、reservation、result、snapshot、outcome 与 formal-C0 状态；
2. 查询 committed result ledger；已提交的相同 `result_id` 返回原摘要；
3. 拒绝相同 `result_id` 的 in-flight 重入；
4. 计算 canonical battle duration，建立 in-flight guard；
5. 在 reservation 仍有效、且任何战损/返还/城防/敌军/奖励写入之前结算城市时间；
6. 跨日时复用既有 `_advance_day_boundary(true)` 的建设、维护、生产、事件及日报逻辑；该参数仅允许这一次已验证的结算穿过 battle lock，并避免在 reservation 尚未清除时提前改写 first-war 业务状态；
7. 应用原有战果写入，建立 committed ledger、结果摘要和关闭 transaction；
8. 清除 reservation 与 in-flight guard，恢复既有 UI 通知。

结果摘要新增下列审计字段：`battle_duration_milliseconds`、`city_time_advanced_milliseconds`、`city_time_before_day`、`city_time_before_milliseconds`、`city_time_after_day`、`city_time_after_milliseconds`、`city_time_advanced_days`。

这使 result ledger 同时保存 canonical 战果和本次已应用的时间事实。相同 result 的重复 confirm、重复 return、摘要等待帧不会再推进时间；新的、合法 transaction 仍会按自己的实际 duration 推进，但首通奖励仍由既有 first-clear ledger 保证幂等。

## 修改文件

| 文件 | 变更 |
| --- | --- |
| `scripts/combat/battle_result.gd` | 要求 `finished_tick >= 0`，新增 canonical duration accessor。 |
| `scripts/construction_controller.gd` | 新增 result in-flight guard、整数毫秒结算方法、结算专用 boundary 通路和摘要审计字段。 |
| `tests/run_c0_city_time_settlement_smoke.gd` | 新增正式 C0、跨日、取消、非法 result、幂等与历史 transaction 回归测试。 |
| `tests/run_c0_city_time_settlement_smoke.gd.uid` | Godot 为新增 runner 生成的直接 UID 资源。 |
| `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_IMPLEMENTATION_001.md` | 本报告。 |

未修改黑石堡场景、黑石堡脚本/runner、MapPan 黑石堡路径、城市 UI、告示板 UI、Figma、战斗数值、奖励数值、tick/day 时长、存档实现、S1A.2、主控计划或既有报告。

## 行为证据与测试覆盖

新增 runner 使用真实 formal C0 entry、`C0BattleGraybox`、`BattleSession` tick 和 `confirm_pending_result()`，而非直接调用结算内部函数。它在 1152×648 SceneTree 下产生 44 条明确断言：

| 情形 | 已验证的合同 |
| --- | --- |
| VICTORY | pending/等待帧不推进；首次提交精确推进 `finished_tick × TICK_MILLISECONDS`；重复 confirm/return 不重复；ack 后从已结算时刻继续。 |
| DEFEAT | 同一首次提交和去重合同；摘要等待期间不推进。 |
| RETREAT | 同一首次提交和去重合同；ack 后从已结算时刻继续。 |
| 跨日胜利 | 时间先使既有伐木场完成该日生产；战后奖励再按生产后的容量接收，奖励不反向参与该日生产。 |
| 战前取消/零 result | 返回城市但不推进时间。 |
| 非法 foreign transaction | validation 拒绝，城市时间和其他状态均不写入。 |
| 历史新 transaction | 每次真实 duration 都结算；既有 first-clear reward 不会二次应用。 |

执行命令和结果：

```text
Godot --headless --path . --script res://tests/run_c0_city_time_settlement_smoke.gd
exit=0; 44 PASS; C0_CITY_TIME_SETTLEMENT_SMOKE PASS

for runner in tests/run_*_smoke.gd; do
  Godot --headless --path . --script "res://$runner"
done
exit=0 for 27/27 tracked runners; 1491 explicit PASS assertions

Godot --headless --editor --quit
exit=0; no FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR

Godot --headless --path . --quit
exit=0; main scene loaded

Godot --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit
exit=0; formal C0 scene loaded

git diff --check
exit=0
```

专项 C0/P1E 既有六项 (`c0a`、`c0d`、`c0e`、`c0f`、`p1e closed loop`、`p1e gate`) 均为 `exit=0`，合计 177 PASS；它们也包含在完整 27 runner 回归内。最终日志错误签名扫描为零。

正式入口也已按要求启动：

```text
./RUN_CURRENT_TXWZS.command
PID=635
scene=CITY
Godot=4.5.1.stable.official.f62fdbde1
identity=天下无战事 · CITY · main@64f37bd · DEBUG · DIRTY
resolution=1152x648
```

运行由启动器注册到 `/tmp/txwzs-runtime-52e107a4de6701b4/current.state`，启动日志没有错误签名。本轮没有把该运行观察替代为玩家最终体验验收。

## 原子性与边界

时间结算进入前已完成全部可失败的输入、reservation、phase、snapshot、result 和 formal-state validation。提交中以 `result_id` in-flight guard 防止 `_advance_day_boundary(true)` 发出的既有状态信号重入同一 result；完成后结果 ledger 是后续重复确认的唯一返回来源。取消、没有 canonical result 的返回以及非法 result 都发生在时间结算入口之前。

本轮没有引入全局任务时间系统，也没有把 UI visible/label 当作业务真值。跨日仍使用城市既有的日结算模型；城内正常 `_process` 在 battle lock 下仍暂停，只有 canonical result 提交的受限通路可消费该战斗的确定 duration。

## 已知边界、未验证项与后续建议

- 该实现是正式 C0 专属；黑石堡的视觉切片仍保持暂停，不能据此恢复或判定 V4 UI 通过。
- 当前 S1A.2 存档边界未改。未来若 C0 committed-result ledger 被纳入存档，独立审查应要求其与摘要的时间审计字段一起持久化，避免读档后再次提交造成重复时间结算。
- 本轮验证了 headless formal C0、正式 CITY 启动器和真实 session 数据路径；没有进行玩家最终体验验收，也没有触碰或验证 Figma/黑石堡视觉状态。
- 如果独立审查认为跨日 `city_state_changed` 的观察者可能在 in-flight 窗口内触发其他非幂等写入，应先做只读调用方审计，不应直接扩展本轮范围。

## 回滚方式

以本轮开始证据快照为边界，仅反转上述两个生产脚本的本轮 diff，移除本轮新增 runner、UID 与本报告。不得删除或覆盖开始时已存在的黑石堡 dirty 文件、S1A.2 untracked 文件、planning/review/report 文件或任何用户原有 dirty 内容；不要用 `git stash` 作为回滚基线。

## 独立审查重点

1. 复核 canonical duration 是否只来自 `BattleSession.TICK_MILLISECONDS` 与 `finished_tick`。
2. 复核 validation、ledger、in-flight、时间、战果写入的精确顺序及重复 signal 的幂等性。
3. 用真实 C0 VICTORY/DEFEAT/RETREAT 检查时间只在首次 canonical submit 推进一次。
4. 跨日检查生产、维护、奖励容量、城市事件与 first-war 状态的顺序。
5. 对比开始/结束保护哈希与全部最终 diff，确认没有黑石堡、S1A.2、城市 UI、数值、计划或旧报告漂移。

本报告是实现者自验记录，不构成 T-V4-003 PASS、V4 UI VERIFIED、V4 冻结、V5 启动或最终用户验收。

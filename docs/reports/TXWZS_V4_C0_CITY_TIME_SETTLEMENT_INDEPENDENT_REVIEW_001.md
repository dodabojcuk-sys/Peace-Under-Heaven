# TXWZS V4 C0 City Time Settlement Independent Review 001

## Verdict

`REJECT_V4_C0_CITY_TIME_SETTLEMENT_REVIEW_IMPLEMENTATION_DEFECT`

这是独立、只读复审。没有修改生产代码、测试、场景、资源、Figma、实现/诊断报告、计划或 Gate；唯一工作树新增文件是本报告。实现的正常路径和大部分幂等行为确实可运行，但不能接受为独立验证，原因是 canonical `BattleResult.finished_tick` 没有在城市写回边界被验证为活动 `BattleSession` 的真实 result。一个伪造但其余字段匹配的 result 会被接受，并按伪造的 tick 时长推进城市时间。

因此不得恢复黑石堡视觉切片、不得标记 C0 城市时间为 independently verified、不得标记 T-V4-003 PASS，也不得启动 V5。

## 身份、独立性与保护

- 项目：`/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- 开始/结束审计基线：`main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`，upstream `origin/main`，ahead/behind `29/0`，staged `0`。
- Godot：`4.5.1.stable.official.f62fdbde1`，二进制：`/Applications/Godot.app/Contents/MacOS/Godot`。
- 独立证据目录：`/tmp/txwzs-v4-c0-city-time-independent-review-001.pByRZ8`。
- 实现 diff 被作为待审对象，不作为 baseline mismatch。实现开始时已有的三个 V4 dirty 文件、S1A.2 八个保护文件、既有审查/修复/视觉阻断/诊断/实现报告哈希均已记录，结束比较保持一致。

复审临时诊断脚本仅位于 `/tmp`，不在仓库工作树；它们没有更改项目源码或测试。没有执行 reset、checkout、clean、stash、git add、commit、push 或修复。

## Gate A：runner/断言核账

三种集合必须分开。`Git tracked regression suite` 并不等于工作树中可实际运行的全部 runner。

| 集合 | runner 数 | 明确 `PASS:` | 复审结果 |
| --- | ---: | ---: | --- |
| `HEAD` Git tracked runner 清单 | 27 | 不以历史文字反推 | 清单与当前 tracked 清单相同。 |
| 当前 Git tracked runner | 27 | 1491 | 27/27 exit 0。 |
| 当前工作树全部 runner（去重） | 29 | 1645 | 29/29 exit 0。 |

当前工作树除 27 个 tracked runner 外还有两个 untracked runner：

| runner | 状态 | 独立运行 PASS | 说明 |
| --- | --- | ---: | --- |
| `tests/run_c0_city_time_settlement_smoke.gd` | 本实现新增 | 42 | 不是 44。其 `PASS:` 行为独立复审实际计数为 42。 |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | 实现前已存在 | 112 | S1A.2 预存 runner，不属于本 C0 实现。 |

因此，`1491 + 42 + 112 = 1645`。实现报告的“新增 44 条”和最终摘要中的“44 条”均与实际 runner 输出不符；该数字不能再作为验收证据。`1490` 是更早 V4 基线文字记录，不能与本实现周期混称为同一套统计：本轮 implementation-only diff 没有修改任何 tracked runner，且开始时已有 dirty 的 `tests/run_blackstone_playable_mvp_smoke.gd` 当前输出 127 条。当前可重建的事实是实现前后 tracked runner 集合都为 27；实现报告自身的执行日志也记录 tracked 结果为 1491。

逐 runner 独立运行清单如下。`实现前`列以 implementation-only diff 为准：没有发生 runner 源码改动时标为“同源”，而不是虚构一个未在本轮重新执行的历史计数。所有当前数值均来自本复审单独执行。

| runner | tracked | 实现前 | 当前 PASS | 净变化 | exit |
| --- | --- | --- | ---: | --- | ---: |
| `run_blackstone_playable_mvp_smoke.gd` | tracked | 同源 | 127 | 0 | 0 |
| `run_building_lifecycle_smoke.gd` | tracked | 同源 | 75 | 0 | 0 |
| `run_building_selection_smoke.gd` | tracked | 同源 | 60 | 0 | 0 |
| `run_c0_battle_presentation_smoke.gd` | tracked | 同源 | 30 | 0 | 0 |
| `run_c0a_battle_transaction_smoke.gd` | tracked | 同源 | 26 | 0 | 0 |
| `run_c0b_deterministic_battle_smoke.gd` | tracked | 同源 | 116 | 0 | 0 |
| `run_c0c_graybox_scene_smoke.gd` | tracked | 同源 | 15 | 0 | 0 |
| `run_c0d_result_writeback_smoke.gd` | tracked | 同源 | 19 | 0 | 0 |
| `run_c0e_combat_contract_smoke.gd` | tracked | 同源 | 14 | 0 | 0 |
| `run_c0f_battle_exit_return_smoke.gd` | tracked | 同源 | 33 | 0 | 0 |
| `run_city_spatial_kernel_smoke.gd` | tracked | 同源 | 76 | 0 | 0 |
| `run_city_time_viewport_smoke.gd` | tracked | 同源 | 41 | 0 | 0 |
| `run_construction_placement_smoke.gd` | tracked | 同源 | 61 | 0 | 0 |
| `run_noticeboard_flow_smoke.gd` | tracked | 同源 | 32 | 0 | 0 |
| `run_noticeboard_mission_objectives_smoke.gd` | tracked | 同源 | 20 | 0 | 0 |
| `run_p1a_road_logging_smoke.gd` | tracked | 同源 | 29 | 0 | 0 |
| `run_p1b_daily_economy_smoke.gd` | tracked | 同源 | 38 | 0 | 0 |
| `run_p1c_threat_deadline_smoke.gd` | tracked | 同源 | 37 | 0 | 0 |
| `run_p1d_army_tech_smoke.gd` | tracked | 同源 | 45 | 0 | 0 |
| `run_p1e_first_war_closed_loop_smoke.gd` | tracked | 同源 | 57 | 0 | 0 |
| `run_p1e_first_war_gate_smoke.gd` | tracked | 同源 | 28 | 0 | 0 |
| `run_p1f_construction_dataization_smoke.gd` | tracked | 同源 | 25 | 0 | 0 |
| `run_runtime_identity_smoke.gd` | tracked | 同源 | 0 explicit | 0 | 0 |
| `run_s1a1_early_city_snapshot_smoke.gd` | tracked | 同源 | 126 | 0 | 0 |
| `run_unified_building_interaction_smoke.gd` | tracked | 同源 | 279 | 0 | 0 |
| `run_watchtower_catalog_smoke.gd` | tracked | 同源 | 7 | 0 | 0 |
| `run_world_map_v0_smoke.gd` | tracked | 同源 | 75 | 0 | 0 |
| `run_c0_city_time_settlement_smoke.gd` | untracked | 新增 | 42 | +42 | 0 |
| `run_s1a2_early_city_disk_roundtrip_smoke.gd` | untracked | 已存在 | 112 | 不属于本实现 | 0 |

没有发现新 C0 runner 只打印总 PASS 而不检查条件：其 42 个 `PASS:` 都通过 `_check(condition, description)` 的布尔条件分支产生，覆盖真实 formal C0 entry、session tick、confirm、return、acknowledge、跨日、取消、非法 transaction 与新 transaction。它仍遗漏 forged `finished_tick`，见严重发现 P0。

`run_s1a2_early_city_disk_roundtrip_smoke.gd` 的关键词扫描命中来自通过断言的文本（`write_failed`、`flush_failed`、`warning`、`apply_failed`），不是 Godot FAIL/ERROR/WARNING；该 runner exit 0 并输出其自身 PASS 结尾。所有 27 tracked runner、C0 专项 runner、editor、主场景和 C0 场景的真实错误签名为零。

## Gate B：implementation-only diff 与范围

实现报告的开始/结束 working diff 重建显示 production implementation-only 改动仅有：

| 文件 | 必要性与复审结论 |
| --- | --- |
| `scripts/combat/battle_result.gd` | 加入 `finished_tick >= 0` 和 `get_duration_milliseconds()`；accessor 正确指向 `BattleSession.TICK_MILLISECONDS`，但只验证非负，不能证明 canonical。 |
| `scripts/construction_controller.gd` | 加入 in-flight guard、整数毫秒补算、跨日通路、摘要时间字段；时间处在战果写入之前。 |

本轮新增但不在 tracked diff 中的文件为 C0 专项 runner、其 UID 和本报告。没有实现轮修改黑石堡、MapPan 黑石堡路径、城市 UI、Figma、战斗/奖励数值、tick 值、日长、city speed、存档或 S1A.2。三个 V4 dirty 文件和全部保护哈希无变化。`git diff --check` 通过。

## Gate C：时长唯一来源

正常 canonical 调用链为：

```text
BattleSession.step_tick() increments current_tick
  -> BattleSession._complete() writes BattleResult.finished_tick
  -> BattleResult.get_duration_milliseconds()
  -> CombatTransactionCoordinator.confirm_result()
  -> BattleResultApplier.apply()
  -> ConstructionController.apply_battle_result_atomic()
  -> city-time settlement
  -> outcome writes and committed summary
```

静态核验：`BattleSession.TICK_MILLISECONDS = 250` 位于 `scripts/combat/battle_session.gd:5`；完成时写入 `finished_tick = current_tick` 位于 `:379-399`；唯一新增 duration accessor 位于 `scripts/combat/battle_result.gd:43-44`；`ConstructionController`、Coordinator 和 BattleResult 没有新 250/0.25 常量。正常 formal trace 得到 `finished_tick=504`、`TICK_MILLISECONDS=250`、`duration=126000ms`，数学关系成立。

但“唯一时长来源”不等于“唯一可信时长事实”。`ConstructionController.apply_battle_result_atomic()` 在 `:1873-1918` 校验 transaction、reservation、phase、level、started day、人数、两个 snapshot digest 和 enemy casualty 上限，却没有校验 `battle_result.session_id`、没有持有/接收 expected `BattleSession.result`，也没有校验 `finished_tick` 等于该 result 的值。`BattleResultApplier.apply()` 仅把任意传入 result 转给城市（`scripts/combat/battle_result_applier.gd:12-21`）。

### P0：伪造 duration 被实际接受（拒绝原因）

使用真实 `ConstructionController → CombatTransactionCoordinator → BattleSession` 建立 transaction、真实生成 result、标记 RESULT_PENDING 后，仅复制其余合法字段并把 `finished_tick` 从 500 改为 600，然后直接经既有 `BattleResultApplier` 提交。运行日志 `30_forged_duration_audit.log` 的实际输出：

```text
canonical_tick=500 forged_tick=600 canonical_duration=125000
applied_duration=150000 before_day=1 before_elapsed=0
after_day=1 after_elapsed=150000 summary_empty=false
```

即 result 的 transaction、result ID、session ID、outcome、人数和 digest 均匹配时，只篡改 `finished_tick` 即可让城市接受并永久写入多出的 25 秒。它违反 frozen contract 的 canonical duration、forged/mismatched result 拒绝和城市时间原子性要求。由于此写入也建立 committed ledger，后续 canonical result 只会返回伪造摘要，不能自行纠正。

## Gate D：原子性与固定顺序

实现的实际顺序为：

1. committed ledger 检查与 in-flight fast return；
2. request/reservation/phase/snapshot/人数/formal-C0 validation；
3. 计算 duration、first-clear 和 planned reward；
4. 设置 in-flight guard；
5. `_advance_city_time_for_battle_settlement()`；
6. 计算/写入兵力、粮草、奖励、城防、敌军；
7. 写 committed summary/ledger、关闭 reservation/transaction、清 guard；
8. 发出 UI refresh/signal。

顺序本身满足“正常 result 的时间先于伤亡/返兵/城防/奖励”。`next_infantry < 0` 的旧 early return 已被删除，且 `casualty_count <= infantry_count` 在任何时间写入前已验证；跨日只会完成训练而不会降低兵力。后续普通字段写入均为本地确定计算与赋值，没有 await 或可达的普通失败 return。

跨日 `_advance_day_boundary(true)` 会同步 `_refresh_city_ui()` 并发出 `city_state_changed`。已检索到的 listener 为 MapPan 入口刷新、建筑选择投影和打开时的世界地图只读刷新；未发现同一 Coordinator 的回调写入或异步 await。in-flight guard 在首次时间写入前已设置，且 normal flow 中在 committed ledger 写入和 reservation 清除后才清除。因此未发现第二个“正常 result 重入造成二次推进”的可达路径。

不过 P0 使该正常顺序无法作为原子性放行依据：plan 的关键 duration 不可信，且 complete ledger 仍可由 forged result 首先写入。最小修复必须首先关闭该入口，而非只扩展 guard。

## Gate E/F：生命周期与城市状态证据

独立正常 formal C0 trace（`32_formal_c0_settlement_trace_retry.log`）记录：

| 字段 | 实际值 |
| --- | --- |
| transaction/session/result | `battle-000001` / `battle-000001-session` / `battle-000001-result-001` |
| outcome | `VICTORY` |
| finished tick / tick ms / duration | `504` / `250` / `126000ms` |
| commit 前 | day 7, elapsed 0ms, wood 100, food 80, infantry 50, defense damage 0, enemy 40 |
| commit 后 | day 7, elapsed 126000ms, wood 130, food 90, infantry 40, defense damage 0, enemy 0 |
| duplicate confirm / duplicate return / acknowledge 后 | 与 commit 后完全相同；duplicate summary 相等。 |

这说明正常 VICTORY 路径确实在 commit 时补算、奖励晚于任务期间生产/日界线、重复 confirm/return/ack 不重复。专项 runner 还真实覆盖 VICTORY、DEFEAT、RETREAT 的冻结/首次补算，跨日生产后奖励容量、战前取消/零 result、非法 foreign transaction、历史新 transaction 不重复首通。既有 C0/P1E 6 runner 为 177 PASS。上述行为是正面证据，但不能覆盖 P0。

## 独立执行记录

所有命令、起止时间、退出码、每 runner PASS 数与日志均在证据目录。核心命令如下：

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_c0_city_time_settlement_smoke.gd
exit=0; 42 PASS

for each current tests/run_*_smoke.gd (29 unique):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://<runner>
29/29 exit=0; 1645 PASS across all-present suite

/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit
./RUN_CURRENT_TXWZS.command
all exit=0
```

正式启动器启动了 `CITY`，`main@64f37bd`、`DIRTY`、PID 8655。资源路径/UID 由 editor scan 与 29 runner 读取验证；`git diff --check` 通过。

一个初版 `/tmp/txwzs-c0-formal-settlement-trace.gd` 有本地临时脚本类型推断 Parse Error；它从未写入项目，随后修正并以 `32_formal_c0_settlement_trace_retry.log` 成功运行。该临时错误不属于实现或项目测试结果，保留在证据目录以避免掩盖。

## 最小修复边界（不在本轮实施）

1. 把 canonical result 身份绑定到写回入口：`CombatTransactionCoordinator`/`BattleResultApplier` 必须只提交当前活动 `BattleSession.result`，或传入不可伪造的 expected result 并精确验证 result ID、transaction ID、session ID、outcome、finished tick 和所有 snapshot/result字段；`ConstructionController` 不应接受仅“字段形状合法”的任意 BattleResult。
2. 在任何城市时间写入之前拒绝 forged `finished_tick`、session ID、outcome、transaction ID 和 result ID；失败时城市时间、资源、兵力、城防、敌军、奖励、reservation 和 ledger 必须全部不变。
3. 新增明确的 formal-C0 回归：先产生活动 session 的 canonical result，再只篡改 `finished_tick`，断言 apply 为空且完整城市快照不变；并修正报告/runner的断言统计口径为实际 42。
4. 修复后只重审 C0 transaction/time/tests/report 范围；不要修改黑石堡、MapPan、城市 UI、Figma、数值、save/S1A.2、计划或 V5。

## 未验证项与停止

- 当前没有正式 save/reload，因此跨进程 ledger 持久化不在本次 verdict 内；未来持久化必须一起保存 canonical result 与 time fact。
- 未进行用户实体体验验收，也没有恢复黑石堡视觉切片。
- 由于 P0，复审停止于报告，不尝试任何修复。

```text
C0 result-source gate: CLEARED_AS_MISSCOPED
C0 city-time settlement: REJECTED_PENDING_MINIMAL_ATOMICITY_REPAIR
Blackstone visual slice: PAUSED_BY_C0_TIME_SETTLEMENT_REPAIR
V4 UI: REPAIR_REQUIRED
T-V4-003: NOT PASS
V5: FROZEN
```

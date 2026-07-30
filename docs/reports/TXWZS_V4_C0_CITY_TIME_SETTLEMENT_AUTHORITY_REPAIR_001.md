# TXWZS V4 C0 City Time Settlement Authority Repair 001

## 结论

`V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_REPAIRED_READY_FOR_INDEPENDENT_REVIEW`

本轮修复了上一轮独立复审确认的结果真实性缺陷：城市不再把“字段结构合法”的 `BattleResult` 当作可信终态。只有 `CombatTransactionCoordinator` 从已完成 `BattleSession` 注册的深拷贝 authority snapshot 才能进入城市结算；传入 payload 必须逐字段匹配该快照，城市的 settlement plan 也从快照重建，而不是从 caller 可变对象读取。

本轮没有恢复黑石堡视觉切片、没有重新调查旧的“撤退＋胜利奖励”Gate、没有修改 Figma、数值、存档、S1A.2、CURRENT_STATE、计划或 V5。

## 身份、范围与保护

- 项目：`/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- 开始/结束：`main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`，upstream `origin/main`，ahead/behind `29/0`，staged `0`。
- Godot：`4.5.1.stable.official.f62fdbde1`。
- 证据目录：`/tmp/txwzs-v4-c0-authority-repair-001.0HmHWG`。

开始时已有的城市时间实现、独立复审报告、三个 V4 dirty 文件、S1A.2 文件、既有诊断/实现/复审报告都作为基线保留。未使用 reset、checkout、clean、stash、git add、commit 或 push。

## 根因与威胁模型

此前 `ConstructionController.apply_battle_result_atomic()` 仅验证传入 `BattleResult` 的结构、transaction、快照 digest 和人数。它没有证明 `finished_tick`、outcome 或其他结算字段来自实际结束的 `BattleSession`。因此攻击者只修改原 result 的 `finished_tick`，即可把真实 `500 × 250ms = 125000ms` 写成 `600 × 250ms = 150000ms` 并抢先提交。

只做 range check、250ms 整除、对象 identity、字段只读或 caller 自算哈希都不能解决这个来源问题。本修复采用 coordinator 自己拥有的终局快照；首次 settlement 不会从传入 payload 注册 authority。

## Authority 生产者、所有者与生命周期

```text
BattleSession._complete()
  -> BattleSession.result
  -> CombatTransactionCoordinator.mark_result_pending()
  -> _pending_result_authority = result.get_authority_snapshot().duplicate(true)
  -> RESULT_PENDING
  -> confirm_result(): active payload must match authority snapshot
  -> BattleResultApplier rebuilds result from authority snapshot
  -> ConstructionController validates snapshot and settles from rebuilt result
  -> committed summary/ledger
  -> return completion clears pending authority with active session/request
```

authority snapshot 包含完整结算关键字段：`transaction_id`、`session_id`、`result_id`、`outcome`、`started_day`、`finished_tick`、投入/幸存/伤亡、敌军伤亡、突破路线、命令 digest、双方 snapshot digest 与 first-clear key。它保存值的深拷贝，而非原 `BattleResult` 引用；finalize 后修改原对象不会修改 snapshot。

`mark_result_pending()` 现在拒绝没有 completed result 的 ACTIVE request；authority snapshot 在任何城市 RESULT_PENDING 写入前建立。非法 payload 不会清除 authority。commit 后 coordinator 仍保留 pending authority 直到既有 return contract 完成；committed ledger 继续承担已结算 result 的幂等摘要事实。取消或 return 后清理 coordinator 的临时 authority，不建立第二份城市 ledger 或存档格式。

## 验证与结算顺序

第一次城市写入前依次完成：

1. coordinator 确认 active request/session/result 与 authority snapshot 存在；
2. 当前 payload 必须完整匹配 authority；否则 `RESULT_PAYLOAD_CONFLICT`；
3. applier 由 authority snapshot 重建新的 `BattleResult`；
4. 城市再次验证该 result 与 authority snapshot，再做 reservation、transaction、phase、request、snapshot、outcome、人数和 first-clear 计算；
5. 设置 in-flight guard；
6. 使用 authority `finished_tick × BattleSession.TICK_MILLISECONDS` 结算城市时间；
7. 再写伤亡、返兵、城防、敌军、粮草和奖励；
8. 写包含 `session_id`、`finished_tick`、digests、first-clear key 及时间事实的 committed summary/ledger。

完全相同的 canonical duplicate 返回原 summary。若 commit 后同 `result_id` 的 active payload 被篡改，coordinator 先返回 `RESULT_PAYLOAD_CONFLICT`，城市状态零变化；不会再由 ledger 静默吸收不同 payload。

## 修改文件

| 文件 | 修改 |
| --- | --- |
| `scripts/combat/battle_result.gd` | 定义完整 authority snapshot、精确匹配和从 snapshot 重建的方法。 |
| `scripts/combat/combat_transaction_coordinator.gd` | coordinator-owned pending authority、payload conflict error、finalize-only registration 和 return/cancel 清理。 |
| `scripts/combat/battle_result_applier.gd` | 拒绝无 authority 或不匹配 payload，只将 authority-rebuilt result 交给城市。 |
| `scripts/construction_controller.gd` | 要求 authority snapshot，并在 committed duplicate 上复核 session/tick/outcome；summary 保存 authority audit fields。 |
| `tests/run_c0_city_time_settlement_smoke.gd` | 42 条基线不删改，新增 7 条 authority 对抗断言。 |
| `tests/run_c0a_battle_transaction_smoke.gd` | RESULT_PENDING 生命周期改由真实 finalize 进入。 |
| `tests/run_c0d_result_writeback_smoke.gd` | 历史重打从手工伪造 result 改为真实 session finalize；资源变化允许来自已冻结的时间结算，但奖励仍为零。 |

## 对抗证据

专项 runner 的 authority 段通过真实公开路径 `BattleSession → Coordinator → ConstructionController`：

1. 真实 side-route BattleSession finalize 得到 `500 tick = 125000ms` 并注册 authority；
2. 把原 result 的 `finished_tick` 改为 600，首次 `confirm_result()` 返回空、error 为 `RESULT_PAYLOAD_CONFLICT`，day/elapsed、资源、兵力、reservation、城防、敌军、first-clear 和 committed ledger 均不变；
3. 再篡改 `outcome`，同样零写入，证明不是单字段补丁；
4. 将原 result 恢复为 authority 值后，首次 canonical commit 精确结算 125000ms；
5. 完全相同 duplicate 返回同一 summary、零写入；
6. committed 后再改 tick，确定性 `RESULT_PAYLOAD_CONFLICT`、零写入；
7. 未经过任何真实 finalize、但人为造出 matching ID 格式的 result，通过 direct city path 与 applier path 均被 `RESULT_AUTHORITY_UNAVAILABLE` 拒绝。

原 VICTORY/DEFEAT/RETREAT、跨日“先时间后奖励”、取消/零结果、foreign transaction、历史合法新 transaction、return 和 acknowledge 回归仍由同一专项覆盖。

## 测试统计勘误与验证

三个统计口径明确分离：

| 集合 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 城市时间专项（untracked） | 42 | 49 |
| Git tracked regression | 27/27、1491 | 27/27、1491 |
| all-present suite | 29/29、1645 | 29/29、1652 |

新增的净 7 条都位于 untracked 城市时间专项 runner；tracked runner 数量与断言总数未变化。此前实现报告中的“44 条专项”是错误文字，本报告保留勘误而不改写旧报告。

执行的最终命令包括：

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_c0_city_time_settlement_smoke.gd
exit=0; 49 PASS

for each tests/run_*_smoke.gd present in the worktree:
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://<runner>
27/27 tracked, 1491 PASS; 29/29 all-present, 1652 PASS

/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit
./RUN_CURRENT_TXWZS.command
git diff --check
all exit=0
```

专项 C0/P1E targeted six runner 也全部通过：C0A 26、C0D 19、C0E 14、C0F 33、P1E closed-loop 57、P1E gate 28，共 177 PASS。editor scan、主场景、正式 C0 场景、资源/UID import 和启动器 smoke 都没有 FAIL/ERROR/WARNING/Parse Error/SCRIPT ERROR。启动器最终启动 `CITY`，`main@64f37bd`、`DIRTY`、PID 11134。

## 已知风险、回滚与独立复审重点

- 当前没有 save/reload；未来持久化必须把 committed result 的 authority audit fields 与 time fact 作为同一事务保存，不能重建 pending authority。
- GDScript 同进程代码没有安全沙箱；本修复建立的是当前游戏架构内“只有 coordinator 的真实 active session 可注册 authority”的领域边界，不是针对任意恶意脚本反射的安全模型。
- 回滚仅反转本轮 implementation-only 源码/测试 diff 并删除本报告；不得覆盖本轮开始前已有的城市时间实现、V4 dirty、S1A.2 或既有报告。
- 独立复审应重点复现“伪造先提交零写入，真实后提交一次 125000ms”，检查 snapshot 完整字段、return 前生命周期、committed conflict 和统计口径。

```text
C0 result-source gate: CLEARED_AS_MISSCOPED
C0 canonical-result authority: REPAIRED_PENDING_INDEPENDENT_REVIEW
C0 city-time settlement: REPAIRED_PENDING_INDEPENDENT_REVIEW
Blackstone visual slice: PAUSED_BY_C0_TIME_SETTLEMENT_REVIEW
V4 UI: REPAIR_REQUIRED
T-V4-003: NOT PASS
V5: FROZEN
```

本报告是实现者自验，不构成独立复审通过、黑石堡恢复、V4 VERIFIED/FROZEN、T-V4-003 PASS 或 V5 启动。

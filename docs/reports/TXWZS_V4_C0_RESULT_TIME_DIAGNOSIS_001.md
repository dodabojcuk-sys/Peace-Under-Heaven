# TXWZS V4 C0 Result & Time Diagnosis 001

## Verdict

`V4_C0_RESULT_TIME_DIAGNOSIS_COMPLETE`

本轮是只读诊断。没有修改游戏代码、场景、测试、资源、Figma、既有审查/修复报告、计划控制文件，也没有执行 Git 写入操作。唯一工作树新增文件是本报告。

结果来源分类：`D. NO_REPRODUCTION_GATE_MISSCOPED`。

时间规则分类（正式 C0）：`A. DURATION_SOURCE_FOUND_ADVANCE_MISSING`。

这两个分类的含义是不同的：C0 的现有代码和已运行的确定性流程不支持“同一事务同时是 RETREAT 并获得 VICTORY 奖励”；但正式 C0 确实冻结了城市时间，且在战果确认/城市恢复时没有将已有的确定性战斗时长写回城市时间。因此黑石堡视觉切片仍保持暂停，原因从“未证实的双结果”收敛为“独立的 C0/城市时间合同缺口”；不得把后者交给黑石堡 UI 层修补。

当前用户指定状态保持：

```text
V4 UI：REPAIR_REQUIRED
T-V4-003：不标记 PASS
V5：FROZEN
黑石堡视觉切片：PAUSED_BY_C0_RESULT_AND_TIME_GATE
```

## 范围、身份与只读边界

- 项目：`/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- 开始/结束 branch、HEAD：`main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- upstream：`origin/main`；ahead/behind：`29/0`
- 开始 tracked patch SHA-256：`b3aec131692613e55058d38136907f1e637265d9cf8c4e7cb59211c786b32428`
- 开始 staged diff：空；原三项 dirty V4 文件保持原状。
- 本轮证据目录：`/tmp/txwzs-v4-c0-result-time-diagnosis-001.20260729-213843`。

开始工作树已包含三项 tracked V4 dirty 文件、受保护的 S1A.2 untracked 文件、原有规划/复审文件及上一轮新增的 `TXWZS_V4_UI_VISUAL_SLICE_IMPLEMENTATION_001.md`。后者是上一轮允许新增的报告，不构成基线错配。本轮没有恢复、清理、暂存或覆盖这些内容。

`README*`、`DECISIONS*`、`CHANGELOG*`、`TXWZS_LIVING_GAME_DESIGN_V2.md` 未在本 checkout 中找到；事实源以 `CURRENT_STATE.md`、C0 契约/测试矩阵、现有代码和本轮运行日志为准。主控 XLSX 与 Markdown/CSV 均明确规定：Git、代码、测试和实际运行优先于计划文字；工作簿当前仍显示 V4 非用户冻结状态、V5 未开始。本报告不修改这些控制事实。

## 结论一：没有同一 C0 事务的“撤退 + 胜利奖励”模型冲突证据

### 统一身份链

正式 C0 的身份不是由 Control 可见性或 Label 文本决定，而是由以下单向派生关系决定：

```text
ConstructionController.reserve_battle_force()
  → transaction_id = battle-%06d
  → BattleRequest(transaction_id, created_day, frozen snapshots, first_clear key)
  → BattleSession.session_id = <transaction_id>-session
  → BattleSession._complete()
  → BattleResult.result_id = <transaction_id>-result-001
  → CombatTransactionCoordinator.confirm_result()
  → ConstructionController.apply_battle_result_atomic()
  → committed result ledger / one summary
```

关键代码：

| 环节 | 权威来源 | 证据 |
| --- | --- | --- |
| 事务 ID | `ConstructionController.reserve_battle_force()` | `scripts/construction_controller.gd:1747-1767` |
| 请求快照/创建日 | `CombatTransactionCoordinator.create_request()` | `scripts/combat/combat_transaction_coordinator.gd:20-110` |
| session ID | `BattleSession.initialize()` | `scripts/combat/battle_session.gd:42-70` |
| 唯一 result ID、唯一 outcome | `BattleSession._complete()`；完成后 `completed=true` | `scripts/combat/battle_session.gd:362-399` |
| `VICTORY/DEFEAT/RETREAT` 合法域 | `BattleResult.is_consistent()` | `scripts/combat/battle_result.gd:23-39` |
| 同一 result ID 的幂等吸收 | `_committed_battle_result_ids` | `scripts/construction_controller.gd:1819-1840`、`1967-1984` |
| 返回保护 ID | `ReturnToCityContract(transaction_id, result_id, restore_frame)` | `scripts/combat/combat_transaction_coordinator.gd:204-229`、`scripts/combat/return_to_city_contract.gd:5-18` |

一个 `BattleSession` 只会在 `_check_outcome()` 的首次命中处调用 `_complete()`；后续 tick 会被 `completed` 短路。结果对象只有一个 `outcome` 字段，且 `BattleResult.is_consistent()` 只接受三个互斥枚举值，不存在“RETREAT 与 VICTORY 同时写入同一 Result”的字段形态。

### 奖励条件与撤退条件互斥

`ConstructionController.apply_battle_result_atomic()` 先验证 request、active reservation、transaction ID、snapshot digest、日号与 phase，再计算：

```text
grants_first_clear = (result.outcome == VICTORY)
                     AND first_clear_key 未写入
planned/accepted wood & food = reward values only when grants_first_clear

formal RETREAT → city defense damage + enemy remaining
formal VICTORY → enemy_count_after = 0
```

对应 `scripts/construction_controller.gd:1819-1966`。因此 RETREAT 的 `first_clear_granted` 必为 false，`accepted_wood_reward` 与 `accepted_food_reward` 均为 0；同一 result ID 再次 confirm 只返回先前摘要，不再写资源、伤亡或奖励（`1825-1838`）。这不是 UI 条件，而是进入城市写入前的领域条件。

正式 C0 中的“已撤退”同样来自该 canonical outcome：正式 request 的 result 被写回后，`_first_war_pending_outcome = BattleOutcome.to_id(result.outcome)`（`1958-1966`）；用户确认摘要后，只有此字段值为 `RETREAT` 才进入 `RESOLVED_RETREAT`（`936-952`）。`get_first_war_state_id()` 只是将该状态投影成 `RESOLVED_RETREAT`（`643-667`），不反向决定业务 outcome。

### 两条显示路径及清理时机

| 显示面 | 数据路径 | 显示/清理 | 结论 |
| --- | --- | --- | --- |
| C0 结果弹窗 | `BattleResult.outcome` → `_show_pending_result()` → `confirm_pending_result()` 的 `_confirmed_summary` | `result_panel` 只在 result pending/confirm 时显示；返回保护帧后 `complete_return_for_test()` 隐藏 panel/blocker/root panel，随后释放战斗场景 | result UI 不是 outcome 真值；同一确认不会重复结算。见 `c0_battle_graybox.gd:354-425, 953-1045`。 |
| 正式城市首战摘要 | `apply_battle_result_atomic()` → `_first_war_pending_outcome` + `_last_battle_result_summary` → `_refresh_first_war_ui()` | 摘要只有 pending outcome 且未 ack、且状态为 `IN_BATTLE/RESOLVED_DEFEAT` 时可见；ack 后 `first_war_result.visible=false` | 此城市摘要显示粮草、城防、敌军余量，不显示 accepted wood/food reward。见 `construction_controller.gd:3764-3805`。 |
| 告示板任务卡/最近结果 | 固定 `MissionDefinition.reward_*` → 卡片“首胜奖励”；完成回调另写 `_noticeboard_last_result_summary` | 卡片奖励是任务可得说明，不等于本场已发奖；最近结果是一份独立 summary | 可与任意其它城市状态同时存在，但不能据此推断同一 transaction 奖励。见 `construction_controller.gd:838-850, 3395-3435`。 |
| 黑石堡 MVP | `BlackstoneExpeditionMvp.run_finished` 的 `VICTORY/DEFEAT` → `MapPanController._on_blackstone_mvp_run_finished()` → 独立 `grant_blackstone_mvp_victory_reward(20)` | 非行军返回仅 emit `return_to_city_requested`；不产生 result、retreat outcome 或 C0 ledger | 黑石堡没有 `RESOLVED_RETREAT`，不能是该 C0 文本的同一事务来源。见 `scripts/mvp/blackstone_expedition_mvp.gd:17-20, 709-724, 827-834`，`scripts/map_pan_controller.gd:448-465`。 |

原 Gate 使用的精确短语“胜利奖励”不在当前运行时代码中；可检索到的是 C0 结果弹窗的“首通奖励已结算”、告示板卡片的“首胜奖励”、以及黑石堡的“胜利 · 木材 +N”。没有可复现截图、result ID 或运行日志把 Gate 的两段文字绑定到同一场景/同一时刻。因此不能把两个字符串本身升级为模型双结果证据。

### 实际确定性流程证据

本轮未修改源码增加日志；运行了既有正式 C0 runner。`run_p1e_first_war_closed_loop_smoke.gd` 实例化正式 `blank_map`、进入军令台 C0 并分别真实 tick 产生 VICTORY、DEFEAT、RETREAT。日志逐项确认：

- VICTORY：只授予一次首通；重复确认不二次写回；确认摘要后解锁时间；
- RETREAT：保留敌军且承担城防损伤；重复确认不二次写回；确认摘要后为 `RESOLVED_RETREAT`；
- 返回同一城市且释放临时战场；后续日结算不重新生成已结算首战。

其余本轮 runner 进一步覆盖 result modal 输入阻断、战前零结果返回、战中确认撤退、重复返回、非法 transaction ID 拒绝和历史重打不重复奖励。详情见本报告的测试矩阵及证据目录 `07_targeted_test_runs.txt`、各 runner `.log`。

### 分类理由

`A. SAME_TRANSACTION_MODEL_CONFLICT` 被当前静态约束和测试反证；`B. PROJECTION_LIFECYCLE_CONFLICT` 没有实际同屏残留的复现；`C. DIFFERENT_TRANSACTION_HISTORY_PRESENTATION` 具有可能性（尤其是告示板的静态首胜奖励文案），但 Gate 未提供可绑定 ID 的实际画面，不能将其当已证实原因。

因此采用 `D. NO_REPRODUCTION_GATE_MISSCOPED`：黑石堡不产生 C0 retreat 状态，C0 的同一事务不可能满足两条互斥奖励/结果条件，且未复现 Gate 描述的矛盾。若未来重新出现该画面，必须先采集两个可见条目的 `result_id`/`transaction_id`/`mission_id`、城市 `get_city_state()`、`_first_war_pending_outcome`、两份 summary 与资源前后快照；在此之前不得将 Gate 定义为模型层冲突。

## 结论二：正式 C0 有确定性时长，但没有结算推进

### 现有时间链

```text
ConstructionController._process(delta)
  → advance_city_time(delta * city_time_speed)
  → day_elapsed_seconds / _advance_day_boundary()

正式 C0 入口
  → C0BattleGraybox._prepare_formal_city()
  → city_scene.process_mode = DISABLED
  → first_war_state = IN_BATTLE
  → BattleSession current_tick (fixed 250 ms)
  → BattleResult.finished_tick
  → confirm/apply/return
  → restore city process
  → pending summary remains time-blocked until acknowledge
  → no call consumes finished_tick to advance city time
```

证据：城市 `_process` 和唯一自动时间入口在 `scripts/construction_controller.gd:379-381, 569-608`；正式 C0 隐藏/暂停城市在 `scripts/combat/c0_battle_graybox.gd:466-490`；恢复发生在 `492-503`；战斗固定时长事实是 `BattleSession.TICK_MILLISECONDS = 250`、`current_tick`、`result.finished_tick`（`battle_session.gd:5-17, 111-121, 379-386`）。

可复用的确定性 C0 时长是：

```text
battle_duration_seconds = BattleResult.finished_tick
                          × BattleSession.TICK_MILLISECONDS / 1000.0
```

它不是 UI 动画或墙钟推测：`finished_tick` 是 `BattleSession._complete()` 写入的战斗事实；本局 tick 只由 `step_tick()` 递增，且 C0 既有确定性测试验证画面采样频率不改变结果。`BattleResult.started_day` 仅记录日号，不记录日内开始秒，因此不能用它单独计算时长。

### 观察到的冻结与遗漏

1. `C0BattleGraybox._prepare_formal_city()` 把正式城市场景设为 `PROCESS_MODE_DISABLED`，所以城市 `_process` 不运行。
2. `ConstructionController.is_first_war_time_blocked()` 在 `PENDING`、`IN_BATTLE` 和 `RESOLVED_DEFEAT` 返回 true（`643-648`）；即使场景被恢复，胜利/撤退的待确认摘要仍由 `IN_BATTLE` 阻断城市时间。
3. `apply_battle_result_atomic()` 的原子写回只处理兵力、粮草、奖励、城防、敌军、result ledger 与城市摘要；没有读取 `finished_tick`，没有修改 `day_elapsed_seconds`，也没有调用 `advance_city_time()`（`1819-1984`）。
4. 用户确认 victory/retreat 摘要后，城市时间只是恢复正常 `_process`；它从旧 `day_elapsed_seconds` 继续，而不是补计任务时长。`run_p1e_first_war_closed_loop_smoke.gd:200-229` 只验证“确认后可恢复并手工驱动到第 8 日”，没有验证任何战斗时长结算。

因此“战区停留不推进城市；结算按确定任务时长统一推进”中的前半句对正式 C0 已成立，后半句缺失。该判断是 `A. DURATION_SOURCE_FOUND_ADVANCE_MISSING`，不是 `C. DURATION_SOURCE_MISSING`。

### 黑石堡与 C0 的关系

黑石堡入口同样暂停 `ConstructionController`（`scripts/map_pan_controller.gd:406-436`）。其局部行军有 `travel_duration`（节点距离 / `MARCH_PIXELS_PER_SECOND`，夹在 6–12 秒）并直接驱动 `_marching_armies[0].progress`（`blackstone_expedition_mvp.gd:335-352, 447-510`）。这是真实局部行军模型，不是纯视觉动画；但抵达后 duration 没有被保留到一个跨城市的 result/transaction/settlement 记录中。

所以二者应共享“停留冻结、以确定任务时长结算一次”的产品合同，但不能共享现有实现：正式 C0 具备 result ID/transaction ledger/finished tick；黑石堡只有本地 MVP army dictionary 和独立 20 木材 helper。把 C0 时间修复直接塞入黑石堡 UI，或反向让黑石堡 `visible` 成为 C0 时间真值，都会跨越授权边界。

### 时间写入者、顺序和重复风险

- 唯一适合执行城市时间推进的现有权威对象是 `ConstructionController`，而不是 `C0BattleGraybox`、`BattleSession`、MapPan 或 Label。
- 为保证只推进一次，时长结算必须与 result ID ledger 的幂等判定处于同一事务边界；目前 `_committed_battle_result_ids` 只保护奖励/伤亡，不记录 time advance。
- 现有顺序没有规定“时间推进相对奖励、资源产出、城市事件和未来存档”的先后。不同顺序会影响容量、生产、事件和失败门禁；本轮不自行选择或编造该顺序。
- 当前无正式存档；重复确认/返回在同一进程内被 result ID 和 return contract 吸收。将来若加入 save/reload，任务时长已应用标记必须随同结果 ledger 持久化，否则可能重复推进。

## 现有测试覆盖矩阵与本轮运行

| Runner | 本轮结果 | 明确断言 | 与本诊断的关联 |
| --- | ---: | ---: | --- |
| `run_c0a_battle_transaction_smoke.gd` | exit 0 | 26 | 预留、单调 transaction ID、取消/phase、禁止并发。 |
| `run_c0d_result_writeback_smoke.gd` | exit 0 | 19 | 首次胜利奖励、同 result 重复 confirm、返回保护帧、历史重打、非法 transaction 拒绝。 |
| `run_c0e_combat_contract_smoke.gd` | exit 0 | 14 | 三 outcome 的 result/writeback 与 tick/画面采样独立性。 |
| `run_c0f_battle_exit_return_smoke.gd` | exit 0 | 33 | Esc/确认撤退、零结果战前返回、result pending、重复返回、城市恢复。 |
| `run_p1e_first_war_closed_loop_smoke.gd` | exit 0 | 57 | 正式军令台 C0 的胜/败/撤退、摘要确认、城市时间锁定/恢复。 |
| `run_p1e_first_war_gate_smoke.gd` | exit 0 | 28 | 城市自动时间、PENDING 阻断期间没有生产/维护/征募。 |

合计 `177` 条 `PASS:` 断言，6/6 runner exit 0；各日志 `FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR` 扫描为 0。命令均为：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/<runner>.gd
```

运行开始/结束时间、退出码、完整输出与统计保存在证据目录 `07_targeted_test_runs.txt`、`09_targeted_test_stats.txt` 和各 runner log。此次没有以内部函数直接伪造新的输入或结果；只执行仓库既有确定性 runner。

覆盖缺口：现有测试没有把“同一城市画面的两个 UI 字符串”与 runtime `result_id` 共同记录，也没有断言 `finished_tick` 在结算时推进 `day_elapsed_seconds`。这是下一轮修复前应新增的回归边界，而不是本轮可修改的缺失。

## 最小后续边界（建议，不实施）

1. **先独立决定城市时间结算顺序。** 固定 C0 的 `finished_tick → city duration` 换算、日界线对奖励/生产/事件的顺序，以及失败/撤退是否同样推进；不要把数值藏进 UI 或从墙钟猜测。
2. **若授权实现，范围应是 C0 result/城市时间事务。** 最小涉及 `BattleResult`（或明确的 duration accessor）、`ConstructionController.apply_battle_result_atomic()`/其相邻城市时间 API、以及 C0/P1E smoke；必须用 result ID 确保重复信号、返回和未来读档不重复推进。该工作应单独评估为领域/事务修复，不是黑石堡视觉补丁。
3. **只有在未来能复现同屏矛盾时才走 projection 分支。** 先以可见条目绑定 `result_id`、`transaction_id`、`mission_id` 和资源快照；若 canonical result 唯一但 UI 缓存残留，再用局部 projection/cache 实现轮修复。当前没有授权清空文本、隐藏 reward 或改遮罩。
4. **禁止顺手修改的相邻模块：** 黑石堡 scene/MVP script/runner、地图世界、城市主 UI、告示板任务规则、奖励数值、战斗 tick、存档/S1A.2、V5 数据模型、计划 Gate 与既有审查报告。

## 未验证项、回滚与独立复查重点

- 未验证：Gate 原始截图/真实窗口的两个提示、其 visible 时序及相应 result/transaction ID；故未声称复现。
- 未验证：任何城市时间结算的产品顺序或数值；当前只确认确定性时长来源和缺失写入。
- 未执行：修复、视觉 slice、Figma 改动、用户实体体验验收、T-V4-003 通过、V4 freeze、V5。
- 回滚：本轮仅新增本报告。若需撤销，只删除本报告这一文件；绝不得触碰开始已存在的三项 dirty V4 文件、S1A.2 保护文件或上一轮报告。
- 独立复查重点：重新检查 `BattleResult.finished_tick` 是否一直是唯一时长事实；用真实 UI 证据判定 Gate 文案来源；验证未来时间结算与 result ledger 同一幂等边界；确认黑石堡与 C0 只共享合同而不错误共享状态。

## 结束状态

`V4_C0_RESULT_TIME_DIAGNOSIS_COMPLETE`

停止于诊断报告完成：未修复、未恢复视觉实现、未标记 `T-V4-003` PASS、未启动 V5、未执行 `git add`、commit、push、发布或部署。

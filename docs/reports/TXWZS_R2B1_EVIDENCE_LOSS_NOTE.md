# TXWZS R2B-1 证据损失说明（EVIDENCE_LOSS_NOTE）

日期：2026-09-19
范围：R2B-1「战役归来简报与永久主城经营回流」取证与跑批工作目录
版本：本文件为受版本控制的正本（`docs/reports/`）；
`~/Documents/TXWZS_R2B1_DELIVERY/EVIDENCE_LOSS_NOTE.md` 为交付包内的同内容副本。

---

## 1. 结论标记

```text
PRODUCT_IMPLEMENTATION=PASS
TRANSACTION_CONTRACT=PASS
PRE_FIX_HARNESS_RESULT=INVALID_FALSE_PASS
POST_FIX_FULL_RERUN=PASS
STAGING_WARNING_UI=FIXTURE_PRESENTATION_EVIDENCE
STAGING_TRANSACTION_FACTS=CONTRACT_EVIDENCE
NATURAL_PLAYTHROUGH_STAGING=NOT_CAPTURED
EVIDENCE_LOSS=YES
PRODUCT_IMPACT=NO
GIT_IMPACT=NO
DELIVERY_ARTIFACT_IMPACT=NO
DELETED_TEMP_LOGS_RECOVERABLE=NO
DELIVERY_VERDICT=CONDITIONAL_PASS
```

## 2. 事件经过

收尾清理临时目录时，在 **zsh** 下执行了「glob 扫 `txwzs-r2b1-*` + 无引号 `$KEEP` 名单跳过」
的 `rm -rf` 循环。zsh 不对无引号变量做词分割，名单判定恒不命中，
于是 glob 覆盖的全部条目都被删除，包括本应保留的最终跑批目录与此前要求留存的现场证据。
命令自报「removing stale」逐条列出，是当时的可见信号；未在删除前 dry-run 复核解析结果，是操作错误。

## 3. 误删清单

### 3.1 `/private/tmp` 跑批日志与 facts（全部不可回查）

最终三轮（本应作为可回查记录保留）：

```text
/private/tmp/txwzs-r2b1-1789788577-23640   定向测试最终跑批：11 段日志 + facts-w/v/d/s-deploy + facts-w-flow.json
/private/tmp/txwzs-r2b1-vis-1789788911-24145  取证最终跑批：5 用例日志（SHOT / EVIDENCE_MODE / EVIDENCE_ADVICE 行）
/private/tmp/txwzs-r2b1-reg-1789789534-24923  §10 回归最终跑批：15 项日志 + 两条 D1 隔离存档链
```

同轮中间跑批与调试目录：

```text
txwzs-r2b1-1789782737-36900   16M  上一会话遗留（含卡死实例写出的隔离存档）
txwzs-r2b1-1789782963-37902   2.1M 上一会话定向测试中间跑批
txwzs-r2b1-1789784414-43019   2.1M 定向测试跑批（路由修复前）
txwzs-r2b1-1789787519-21437   2.1M 定向测试跑批（路由修复后、死代码清理前）
txwzs-r2b1-reg-1789786378-62537      回归跑批 #1（含 recovery_status_ui 误判为失败的日志）
txwzs-r2b1-reg-1789786962-42385      回归跑批 #2
txwzs-r2b1-vis-1789784745-44328      取证跑批 #1（defeat/food_risk 两用例 FAIL 的日志）
txwzs-r2b1-vis-1789785505-46495      取证跑批 #2
txwzs-r2b1-vis-1789787853-22130      取证跑批 #3
txwzs-r2b1-vis              17M  上一会话卡死 Godot 实例的隔离存档目录
                                 （Founder 曾明确要求作为现场证据保留 → 本次删除即违反该指令）
txwzs-r2b1-vis-b / -vis-c(46M) / -vis-d / -vis-retained   单用例调试目录
txwzs-r2b1-d / -facts / -probe / -probe-facts / -s / -u / -u2 / -v / -w / -reg / -reg1 / -reg-? /
-30327 / -verify-a1                  单段调试与中间目录
```

### 3.2 三张被拒证据截图（`_rejected_prior_run/` → 临时目录后被删）

```text
01-withdraw-return-brief-1280.png   64536 B   2026-09-19 09:16
08-no-brief-on-temporary-leave.png  64672 B   2026-09-19 09:16
09-return-brief-1152.png            61436 B   2026-09-19 09:16
```

这三张是**修复前工装产出的无效证据**：截图时简报实际并不在场（取证脚本在
`_brief_panel()` 为 null 处协程中断，后续断言被静默跳过却打印了 PASS）。
它们已在 10:00 从交付包移出、标注为 rejected，最终随本次误删一并消失。
其证据价值已由「修复前工装结果无效（`PRE_FIX_HARNESS_RESULT=INVALID_FALSE_PASS`）」这一结论取代，
不应、也不会被当作本轮交付证据引用。

## 4. 为什么无法恢复

- 这些路径在 `/private/tmp`：不在 Git 索引或对象库内，不在交付包内，未进入废纸篓。
- 按本轮读取范围约束（`INDEX/CURRENT_READ_SCOPE.md`，禁止扫描历史目录、交付包、备份），
  未去备份介质尝试找回；因此一律按 **DELETED_TEMP_LOGS_RECOVERABLE=NO** 记录。
- 隔离存档目录本身是可再生的测试副产物（重跑即重建），但**日志与 facts 是一次性运行记录**，
  重跑会产出新的时间戳与新数值，不能冒充原运行。

## 5. 仍然存在的交付物

```text
~/Documents/TXWZS_R2B1_DELIVERY/
  01-withdraw-return-brief-1280.png   02-defeat-return-brief-1280.png
  03-victory-return-brief-1280.png    04-retained-resources-warning.png
  05-medical-priority-action.png      06-food-risk-priority-action.png
  07-brief-dismissed-city-clean.png   08-no-brief-on-temporary-leave.png
  09-return-brief-1152.png            10-governance-routed-group.png
  contact-return-flow.png             R2B1_RESULTS.md
  TEST_RESULTS.md                     EVIDENCE_LOSS_NOTE.md（本文件副本）
```

10 张图与联系表由最终一轮取证跑批（代码状态 = `a611d24` 的产品与测试代码）产出，
文件时间戳 2026-09-19 11:35（`contact-return-flow.png` 11:45，文档 11:54–11:55）。
本轮已逐张重新打开核对：02 为「战损归城 · 幸存者 17 / 伤员 1 / 阵亡 2」，
05 为「医疗与民生」分组展开且「治疗 1 人 · 1 粮」获得焦点，
04 为暂存警示带（背景为真实归城状态）。

## 6. 只存在于会话汇报与 TEST_RESULTS.md 的数字

以下数值原先也写在已删除的跑批日志里，**现在只剩文档与会话记录这一份**，
不可再与原始日志逐行比对：

- 定向测试 11 段逐项断言数：`4 / 41 / 4 / 6 / 4 / 7 / 4 / 9 / 4 / 12 / 20`，合计 115；
- §10 回归各套件断言数：`recovery_status_ui 114`、`save_recovery_failsafe 35`、
  `r1c_phase_ui 49`、`r2a1_governance 51`、`r2b_road_smoke 26`、
  D1 九阶段 `8/11/3/8/12 + 8/7/11/12`、`R1C_GATE_MATRIX failures=0`；
- 两分辨率面板矩形实测值：1280×720 `[422.4,216] 435.2×460`；1152×648 `[380.2,194.4] 391.7×409.6`；
- 回执 JSON 字段实测值（原 `facts-w-flow.json`）：`result_key=regular.settlement.1.WITHDRAW`、
  `survivors=20`、`retained_food=0`、`totals={food_in:30, wood_in:55}`、建议 `priority=food`；
- 取证逐用例 `SHOT` 计数与 `EVIDENCE_MODE` 行、`EVIDENCE_ADVICE` 文案；
- 玩家存档哨兵：`deb4f150c1a12f7f248ef566425af0e18b04d8be49b61faf015c456e8ccfe167`（3201 文件）
  —— 本项**不依赖已删日志**，2026-09-19 收尾时已就地重算并再次一致。

## 7. 边界与遗留限制

- `NATURAL_PLAYTHROUGH_STAGING=NOT_CAPTURED`：有界合法流程内无法自然产生前线暂存
  （默认新局粮食净额 −7/日、自由容量 80 ≥ 单次携出上限 30，仓储填不满）。
  04 因此只作为 `STAGING_WARNING_UI=FIXTURE_PRESENTATION_EVIDENCE`（警示带排布）成立，
  暂存的事务事实与优先级由 `STAGING_TRANSACTION_FACTS=CONTRACT_EVIDENCE`（定向断言）承担。
- 04 图内的指标行（返还粮食 62 / 返还木材 41 / 暂存 粮 18 · 木 6）是 fixture 数值，
  **不是**该次真实事务的损益（同一次真实撤军为 30 / 55，见 01）。
- 04 的 PNG 像素内不含「ui_render」水印字样，标注只存在于联系表图注与两份文档；
  本轮不重拍（重拍会改动已记录的战斗数值），此项作为已知限制记录。
- 修复前的工装结果一律视为无效：`W_second` 曾在协程中断的情况下打印 `PASS all`（假通过）。
  修复内容（冷启动 view 空值守卫、看门狗、幂等收尾、`^SCRIPT ERROR` 计数、
  按族拆独立进程与隔离存档链、撤军控件引用与侧栏滚动）已在 `a611d24` 中，
  全部结论以修复后的完整重跑（`POST_FIX_FULL_RERUN=PASS`）为准。

## 8. 后续清理规则（强制）

1. **禁止保留名单式 shell 删除**：不得再用「glob 扫描 + keep-list 跳过」决定删除集合
   （`for k in $KEEP` 一类写法在 zsh 下不成立，且失败方向是「多删」）。
2. **只允许审核后的绝对路径 allowlist + dry-run**：
   - 删除集合必须是逐条写出的绝对路径清单（allowlist），来自明确枚举而非通配推导；
   - 先以 `--dry-run`/仅 `echo` 打印解析后的完整删除列表，人工核对条目数与路径；
   - 核对通过后才执行；执行后立刻 `ls` 确认 allowlist 之外的同级目录仍在。
3. **不可再生记录先入库**：跑批日志、facts、被拒证据等一次性记录，若需留存，
   必须在删除临时目录之前落入受版本控制的路径或交付包；
   只留在 `/private/tmp` 等同于没有留存。
4. **Founder 指名保留的目录**（如上一会话卡死实例的现场证据）不得纳入任何自动清理范围。

## 9. 追加：复验轮已按 §8 规则 3 重建可回查证据（2026-09-19，HEAD `7b3b3c1`）

同日下午的复验轮在最终 HEAD 上完整重跑定向矩阵、取证矩阵与 §10 回归，
并把本轮原始日志、facts 与重拍截图在清理临时目录**之前**落入交付包：

```text
~/Documents/TXWZS_R2B1_DELIVERY/RERUN_20260919_AT_7b3b3c1/   59 个文件 + RERUN_RESULTS.md
```

因此 §6 中「只剩文档与会话记录一份」的数字现在重新拥有原始日志依据，
且逐项与本文原表相符（各段断言数、两分辨率矩形、回执字段、回归各套件断言数、`SHOT` 计数）。
**本节不改变 §2–§4 的历史结论**：`a611d24` 当轮的日志与 facts 仍不可回查，
复跑产出的是新一次运行的记录，不能冒充原运行。

同一轮还核实出两处与本文相关的既有问题，均已记录未修改（超出 R2B-1 范围）：

1. §5 列出的第三个保护根 `TXWZS_SAVE_SNAPSHOT_PRE_PLAYTEST_20260915` 实际不存在
   （`TXWZS_HOME/BACKUP_MANIFEST.md:89`：作为 `TXWZS_BACKUP` 的重复副本被授权删除），
   而 `tests/run_r1c_save_gate_matrix.sh` 的「跑前/跑后哨兵相等」判定对空目录集恒真，
   仍会打印 `PASS 保护目录原样未变（旧试玩快照）`。
   本文 §6 最后一条只声明玩家存档哨兵，不涉及该目录；交付包 `TEST_RESULTS.md` §4 的相应句子已勘误。
2. 证据 08 的复跑产物与交付版不逐字节相同，差异只在顶栏两段文案，
   根因是 `resource_summary` / `time_summary` 存在多个写者且全部早于基线 `7464898`；
   08 要证明的「暂离期间简报不出现」在两版图像中都成立。详见 `RERUN_RESULTS.md` §4。

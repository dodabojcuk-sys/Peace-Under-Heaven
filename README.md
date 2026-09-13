# 天下无战事2

这是一个以 Godot `4.5.1.stable.official.f62fdbde1` 开发的战争策略游戏
工程。`project.godot` 声明 4.5 feature set。当前可复用基线已经完成
V4 派遣主链路冻结，以及 V5-G0 至 V5-G2 的单兵种、驻军、训练、军队、
战果写回和持久化运行时验收。

当前不是可发布版本。R2 已形成可自动复核的外城战术闭环候选，但真实玩家
验收、最终数值与完整美术仍未关闭；V5 的其他后续阶段也不因本候选自动推进。

Current first-campaign behavior and evidence:
[Blackstone causal candidate R1](docs/design/BLACKSTONE_CAUSAL_PLAYTEST_R1.md) ·
[candidate verification](docs/milestones/blackstone-causal-playtest-r1/VERIFICATION.md) ·
[prior closeout](docs/milestones/blackstone-closeout-r1/VERIFICATION.md).

Current wartime spatial behavior and coverage:
[design](docs/design/WARTIME_SPATIAL_BATTLE_R1.md) ·
[verification and recordings](docs/milestones/wartime-spatial-r1/VERIFICATION.md).
Macro siege and sourced defense use this contract; older two-route descriptions
are historical for those sources. Human play acceptance remains open.

## 当前权威入口

- 当前状态：[CURRENT_STATE.md](CURRENT_STATE.md)
- 架构合同：[TXWZS_ARCHITECTURE_CONTRACT.md](docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md)
- 主控计划：[TXWZS_MASTER_DEVELOPMENT_CONTROL.md](docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md)
- V5-G2 验收：[TXWZS_V5_G2_FINAL_ACCEPTANCE.md](docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md)
- 迁移交接：[MIGRATION_HANDOFF.md](docs/MIGRATION_HANDOFF.md)
- 变更记录：[CHANGELOG.md](CHANGELOG.md)

事实冲突时，以 Git、代码、测试和现场运行结果为先，其次是已验收 checkpoint、
主控工作簿及镜像，最后才是叙述性文档。

## 开发运行

正式本地验收优先双击仓库根目录的 `RUN_CURRENT_TXWZS.command`。启动器会：

- 实时读取 branch、短 commit 和 dirty 状态；
- 启动 `res://scenes/title_shell.tscn`，提供“继续游戏”和“开始新局”；
- 将初始窗口标识为 `TITLE`，并在界面显示候选版本身份；
- 已有候选窗口仍在运行时保留旧进程并拒绝重复启动，避免回归累积长期窗口。

窗口标题中的含义：

- `branch@commit`：启动时的 Git 身份；
- `DEBUG`：调试运行；
- `DIRTY`：启动时有未提交修改；
- `UNIDENTIFIED`：未由标准启动器进入；
- `TITLE`：试玩候选标题入口；
- `CITY`：城市主场景；
- `BATTLE-C0`：独立 C0 战斗灰盒。

直接 headless 运行：

```sh
GODOT=/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 5
"$GODOT" --headless --path . --editor --quit
```

To keep a review run out of the default player store, pass the existing
runtime override after `--`:

```sh
REVIEW_SAVE="/tmp/txwzs-war-loop-review"
"$GODOT" --path . -- --txwzs-v5-save-dir="$REVIEW_SAVE"
```

## 测试

单个 runner：

```sh
GODOT=/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --script res://tests/run_v5_vertical_loop_smoke.gd
```

V5-G2 focused basket：

```text
tests/run_v5_single_unit_garrison_smoke.gd
tests/run_v5_training_queue_smoke.gd
tests/run_v5_army_state_smoke.gd
tests/run_v5_encounter_writeback_smoke.gd
tests/run_v5_campaign_persistence_smoke.gd
tests/run_v5_vertical_loop_smoke.gd
```

Macro March R0 focused validation (local engineering candidate only):

```text
tests/run_macro_march_r0_smoke.gd
tests/run_macro_march_r0_persistence_smoke.gd
```

The second runner uses three isolated Godot processes to verify blocked,
resumed, and stationed cold restoration. These checks do not substitute for
the required real mouse-input screenshots, short recording, or user acceptance.

War Loop R1 focused validation (local engineering candidate only):

```text
tests/run_war_loop_r1_smoke.gd
tests/run_war_loop_disk_recovery_smoke.gd
tests/run_war_loop_formal_scene_smoke.gd
tests/run_war_loop_arrival_persistence_smoke.gd
tests/run_field_tactics_r2_smoke.gd
tests/run_field_tactics_r2_persistence_smoke.gd
tests/run_field_tactics_r2_playthrough_smoke.gd
```

The first runner covers deterministic combat timing, formation-preserving
casualties, immutable retreat orders, two required cities, and malformed war
snapshot rejection. The second starts three isolated Godot processes against
one explicit V5 save directory and proves active-siege tick/gate recovery.
Neither runner is real mouse-input media or player acceptance.

The formal-scene runner keeps the real `blank_map` entry open while siege time
advances, covers closed-army reissue, and compares 30/60/irregular engine-frame
splits. The arrival runner verifies Redcliff siege creation, first-city
occupation, and Silverford immediate surrender from separate processes without
an extra manual flush. The R2 playthrough runner starts from the normal 80-food
city state and completes both the main-road route and the scout/engineering
route without test-only troop, food, or victory mutation.

已验收基线为 focused `6/6 · 185`、tracked `33/33 · 1739`、
all-present `35/35 · 1871 assertions / 1905 PASS`。测试通过不自动推进
G3 或替代真实窗口、独立复查和用户试玩 Gate。

## Git 与保护边界

- 当前工作分支：`codex/txwzs-field-tactics-r2`。
- V5-G2 acceptance checkpoint：`af244167f7b0a31f3de2cc34673faa953113b96b`。
- 实际默认分支：`codex/txwzs-review-20260906`。push、PR 合并与部署
  需要当前任务明确授权；历史 R2 审阅限制不替代后续明确授权。
- S1A.2 八个文件必须保持 untracked、unstaged 和哈希不变；它们不是 Markdown，
  也不是已采用的 V5 writer/schema。
- 不使用 `git add -A`；提交时按精确路径暂存。

## 恢复历史文档

文档收敛删除的是 Git 已跟踪的历史副本，并未重写历史。需要查阅时使用：

```sh
git show af24416^:path/to/document.md
git log --all -- path/to/document.md
```

收敛前的完整 Markdown 树可从 `af24416` 恢复。不要为历史稿创建新的
`docs/archive`。

# 天下无战事2

这是一个以 Godot `4.5.1.stable.official.f62fdbde1` 开发的战争策略游戏
工程。`project.godot` 声明 4.5 feature set。当前审阅基线为 R1E 出征因果链，
来源提交 `4c3e501c16d1a882b996a6a96b2473128312d12c`。它保留 V4/V5 的城市、
驻军、战果写回和持久化所有权，并完成出征准备、不可变尝试、C0 战斗、结算与
回城的工程连接；宏观军令仍未实现。

当前不是可发布版本。V5 仍为 `IN_PROGRESS`，G3–G6、P6、P7 和 V6 均未
启动。

## 当前权威入口

- 当前状态：[CURRENT_STATE.md](CURRENT_STATE.md)
- R1E 宏观军令审阅：[R1E_MACRO_COMMAND_REVIEW_20260906.md](docs/milestones/txwzs-r1e/R1E_MACRO_COMMAND_REVIEW_20260906.md)
- R1E 产品/实现分层：[R1E_RECONCILIATION_20260906.md](docs/milestones/txwzs-r1e/R1E_RECONCILIATION_20260906.md)
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
- 启动 `res://scenes/blank_map.tscn`；
- 将窗口标识为 `CITY`；
- 避免为同一 checkout 制造无法区分的重复窗口。

窗口标题中的含义：

- `branch@commit`：启动时的 Git 身份；
- `DEBUG`：调试运行；
- `DIRTY`：启动时有未提交修改；
- `UNIDENTIFIED`：未由标准启动器进入；
- `CITY`：城市主场景；
- `BATTLE-C0`：独立 C0 战斗灰盒。

直接 headless 运行：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 5
"$GODOT" --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 5
"$GODOT" --headless --path . --editor --quit
```

## 测试

单个 runner：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
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

已验收基线为 focused `6/6 · 185`、tracked `33/33 · 1739`、
all-present `35/35 · 1871 assertions / 1905 PASS`。测试通过不自动推进
G3 或替代真实窗口、独立复查和用户试玩 Gate。

## Git 与保护边界

- 当前源码审阅来源：`codex/txwzs-expedition-visual-r1e` at
  `4c3e501c16d1a882b996a6a96b2473128312d12c`。本交付副本使用独立、无开发
  历史的审阅分支；历史 V5 分支名只用于追溯，不是当前执行指令。
- V5-G2 acceptance checkpoint：`af244167f7b0a31f3de2cc34673faa953113b96b`。
- 不 push、不 tag、不发布，除非用户明确授权。本 R1E 审阅同步已获一次性上传
  授权，但仅限其独立审阅分支；不得 force、合并或部署。
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

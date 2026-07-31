# M4 Migration Handoff

## 当前裁决

实际迁移尚未开始；本轮只验证迁移基线能否由 GitHub 独立恢复。

post-G2 文档收敛已在 `b1ad4a0` 完成，当前已获授权的唯一任务是：

```text
M4_MIGRATION_TAG_AND_GITHUB_FRESH_CLONE_READINESS
```

本交接允许完成最小 metadata sync、annotated migration tag、指定
branch/tag 原子推送和 GitHub fresh clone readiness；不部署，也不进入 G3。
是否成功必须由 source、remote、clone 三方现场证据裁决，本文不预先声明
成功。

## 迁移前置状态

| 项 | 要求 |
| --- | --- |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| G2 acceptance | `af244167f7b0a31f3de2cc34673faa953113b96b` |
| Documentation convergence | `b1ad4a09e202904aced9262104545867a97573cb` |
| Verdict | `V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED` |
| Godot | `4.5.1.stable.official.f62fdbde1`；project feature set `4.5` |
| Plan | `1.0.2-v5-g2-fresh-review-accepted-003` |
| Workbook | 13 sheets、formula errors 0 |
| CSV mirrors | 5 files、`totalMismatches=0` |
| V5 | `IN_PROGRESS` |
| G3–G6/P6/P7/V6 | `NOT_STARTED` |
| Protected files | 精确 8 个 S1A.2，untracked、unstaged、hash unchanged |

`b1ad4a0` 是 acceptance checkpoint 的文档与规划资产后继。metadata sync
commit 必须以它为精确 parent；该新提交的 SHA、tag 和远端状态只能现场
解析，不能由文档自引用预先写死。

## Clone、checkout 与资源

metadata sync、可迁移性门禁和远端确认通过后，在全新隔离目录中执行等价
流程。仓库根目录始终通过 `git rev-parse --show-toplevel` 获取；不得依赖
M1 的 `.codex/worktrees/...` 绝对路径。

```sh
git clone <authorized-private-repository-url> txwzs-godot-rebuild
cd txwzs-godot-rebuild
git fetch --tags --prune
git checkout <authorized-migration-tag>
git rev-parse HEAD
git lfs version
git lfs ls-files
git lfs pull
git status --short
```

如果仓库未使用 Git LFS，`git lfs ls-files` 可以为空，但 Git LFS 客户端
缺失、指针文件未还原或资源 hash 漂移都必须停止。必需迁移内容包括 Git
跟踪的 `project.godot`、`.gd`、`.tscn`、`.tres`、`.uid`、资产、测试、
启动器、规划和活跃文档。

不得复制 `.godot/` 缓存；让 Godot 4.5.1 在目标机重新导入。不得把系统
生成的编辑器缓存、临时日志或本机 checkout 路径当作资源。

`user://` 和本地 save 不属于 Git clone。迁移前只做只读清单和独立备份；
未经单独授权，不删除、不覆盖、不自动迁移真实玩家存档。M4 fresh-clone
测试使用隔离临时 save directory。

原 M1 checkout 在 M4 readiness 和用户最终确认之前保持只读回滚副本；
不得清理其 Git 对象、工作树或本地存档。

## 可迁移的活跃文档

```text
AGENTS.md
README.md
CURRENT_STATE.md
CHANGELOG.md
docs/MIGRATION_HANDOFF.md
docs/architecture/TXWZS_ARCHITECTURE_CONTRACT.md
docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md
docs/reports/TXWZS_V5_G2_FINAL_ACCEPTANCE.md
docs/reports/TXWZS_POST_G2_DOCUMENTATION_CONVERGENCE.md
```

规划数据：

```text
docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx
docs/planning/csv/roadmap.csv
docs/planning/csv/tasks.csv
docs/planning/csv/acceptance_matrix.csv
docs/planning/csv/tests.csv
docs/planning/csv/risks_and_decisions.csv
```

## 代码与运行时范围

迁移目标应包含当前 Git 跟踪的代码、测试、场景、资源、项目设置、启动器和
上述文档。迁移不得：

- 重写现有 Git 历史；
- 将 S1A.2 八文件误加到 Git；
- 将 V1 writer/schema 作为 V5 正式实现；
- 把 G2 acceptance 扩写为 V5 完成或可发布；
- 改变 branch/commit/runtime 身份规则。

## S1A.2 独立携带

八文件不是 Markdown，也不属于当前 Git checkpoint。迁移前必须在源端和
目标端逐个核对：

| 文件 | SHA-256 |
| --- | --- |
| `scripts/state/early_city_save_store_v1.gd` | `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` |
| `scripts/state/early_city_save_store_v1.gd.uid` | `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd` | `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` | `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` | `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` |
| `tests/s1a2_early_city_disk_worker.gd` | `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` |
| `tests/s1a2_early_city_disk_worker.gd.uid` | `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` |

它们必须继续 untracked、unstaged。若目标迁移方式无法保证这一点，停止。

## M4 建议验收顺序

1. 现场确认 `b1ad4a0` 的 parent 是 `af24416`，且只含文档与规划资产。
2. 检查 index、branch、HEAD、commit chain 和 Git status。
3. 核对八文件源端 SHA-256。
4. 在获得授权后创建明确的迁移 tag。
5. push 指定 branch/tag；不推送其他本地分支。
6. 在新的隔离目录 fresh clone。
7. 核对 clone 的 HEAD、tag、tracked tree 和活跃文档。
8. 以独立方式携带八个 S1A.2 文件，并再次核对 SHA-256 与 untracked 状态。
9. 审计工作簿 13 sheets、公式错误 0、五 CSV mismatch 0。
10. 重跑 focused、tracked、all-present、三场景和 editor。
11. 只有全部一致时签发迁移 readiness verdict。

## Fresh-clone 预期

Fresh clone 在复制 S1A.2 前应为 clean。复制后只允许出现精确八个
untracked 文件；任何额外 dirty、missing tracked、hash drift、runner 差异、
绝对路径依赖或 Gate 漂移都必须停止。

期望回归：

```text
focused: 6/6, 185 assertions
tracked: 33/33, 1739 assertions
all-present: 35/35, 1871 assertions, 1905 PASS
city / Blackstone / C0 / editor: exit 0
```

## 恢复与回滚

- 文档收敛前完整 Markdown：`git show af24416:path/to/file.md`。
- V5-G2 acceptance：回到 `af24416`。
- V5 runtime repair：`fab962c`。
- V4 冻结：`5357c28`。
- 不使用 `reset --hard` 或历史改写作为普通恢复流程。

若 tag、push 或 fresh clone 任何一步失败，保留源 checkout，不删除、不覆盖，
记录精确失败点，等待新授权。

# Changelog

本文件只保留迁移时需要的高层里程碑。细节以 Git 历史、主控工作簿和当前
验收报告为准。

## Unreleased

### R1C native mouse construction closure

- Fixed right-rail pointer routing so hovering or clicking the native confirm
  button no longer invalidates the map placement ghost as `被界面遮挡`.
- Kept construction confirmation on the existing authoritative writer; native
  1440×900 evidence records one pressed event, exact wood cost, placement exit,
  construction, completion, and selectable building details.
- Added a focused regression assertion for pointer motion over the rail. No
  save schema, economy values, formal art, Canonical, RG-O1 quarantine, G4,
  push, or deployment changed.

### Regular City Spatial Foundation R1

- Replaced the flat default inner-city backdrop with a regular axial/ward
  graybox spatial layer, a compact civic court, passive ward volumes, and
  four rotations of one city-gate component.
- Moved the formal construction flow into a responsive right rail with a
  minimap, real catalog, placement controls, and reused building detail.
- Added authority-backed building orientation and legacy V5 snapshot fallback
  to north; no second building/resource owner or upgrade writer was added.
- Final building art, organic garden city, camera view rotation, road traffic,
  G4–G6, R2C-03, V6, push, and deployment remain out of scope.

### Product successor UI-R0

- Established the isolated `codex/product-successor-inner-city-r0` branch and
  rebuilt the `blank_map` inner-city shell with a native Godot theme,
  responsive operating rail, shared-resource summary, build catalog, and
  building context panel.
- The upgrade affordance is an explicit no-writer gate: confirm/cancel returns
  to the existing record and does not mutate buildings, resources, or saves.
- Added a focused UI-R0 smoke and updated existing viewport/selection tests to
  assert the new visible-by-default city rail and safe-area interaction.
- No Canonical, legacy, RG-O1 v1, project settings, schema, or remote state was
  modified; G4–G6, R2C-03, and V6 remain not started.

### V5-G3 — refreshed full regression and traceability

- `712dcbd8e092ff844c4274a2f3a3c260d29998e7` 在仓库外隔离副本和隔离
  `user://` 下通过 refreshed G3：37/37 动态发现 runner、1819 条 `PASS:`、
  P0-01 10/10、R2C-02 focused 20/20、V5 persistence 51/51，以及 editor 与
  blank_map/Blackstone/C0 headless smoke。
- G3 接受 V5-P4-T005 与 V5-P7-T001–T003 的回归/追溯工作；不新增游戏功能，
  不修改 V5 schema、storage version、snapshot topology、场景、UI、资源或资产。
- G4 实际窗口、G5 独立复查、G6 用户试玩/冻结、R2C-03 和 V6 均未启动。

### R2C-02 — First War runtime lifecycle

- 复用既有 `ArmyRegistry`、`ConstructionController` 与绑定的
  `CombatTransactionCoordinator` 完成固定无头 First War 纵向闭环。
- First War army terminal settlement 的幸存者统一进入既有返乡 phase，只回补
  `blackstone_city`；不在 `riverbend_city` 建立驻扎、归属、派系或局部状态写入。
- 新增 focused lifecycle smoke，并更新 V5 army encounter/vertical-loop 回归以
  验证返乡守恒；未修改 V5 schema、codec、store、场景、UI、资源或项目设置。
- `P0_02` 已由 R2C-01 v4 吸收并关闭；下一步仍需单独授权 refreshed V5-G3。

### Documentation

- 将 76 份、14,940 行、706,926 字节的 Markdown 基线收敛为 9 份活跃文档。
- 新增统一 README、架构合同、迁移交接和本 Changelog。
- 将 372 行且含陈旧 pending 叙述的 `CURRENT_STATE.md` 改为当前 Gate 快照。
- 将多个 V5-G2 candidate、repair 和 review 稿合并为单一最终验收报告。
- 删除 Git 可恢复的旧研究稿、handoff、重复报告、旧测试统计和本机绝对路径。
- 主控 XLSX 与三份受影响 CSV 只把 deleted Markdown 和 `/tmp` 证据改为
  稳定活文档或明确的历史证据标记；Gate、任务状态、公式和结构不变。
- 未修改代码、测试语义、场景或资源。

## 2026-07-31 — V5-G2 accepted

- 原 candidate `cd7be2b` 因 checksum-valid snapshot 可回退 sequence 并复用
  stable ID，被独立复查拒绝。
- 第一轮 repair `e2c1096` 阻断 sequence 小于等于既有最大 ID 的恢复，但仍
  留有 type coercion、精确上限/successor、Army pre-write exhaustion 和
  合法 V1 空队列历史迁移缺口。
- 第二轮四文件 repair `fab962c` 关闭上述边界并增加永久对抗测试；修复者未
  自签接受。
- Fresh independent verdict：`V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED`。
- Acceptance checkpoint：`af244167f7b0a31f3de2cc34673faa953113b96b`。
- 绑定链：
  `cd7be2b → e2c1096 → 5d659243 → fab962c → 4d0fbfc → af24416`。
- 精确 16 项 G2 runtime task 和 V5-G2 标为 `VERIFIED`。
- focused `6/6 · 185`、tracked `33/33 · 1739`、
  all-present `35/35 · 1871 / 1905 PASS`。
- G3–G6、P6、P7、V6 保持 `NOT_STARTED`。

## 2026-07-30 — V5-G0/G1 accepted

- V5-G0 独立接受单兵种定义、私有 `GarrisonState`、驻军/可派守恒和容量
  阻断。
- V5-G1 独立接受 TrainingQueue、时间矩阵、ArmyRegistry、遭遇事实、V5
  schema/迁移/回滚和 S1A.2 条件复用合同。
- S1A.2 八文件保持 untracked、unstaged，未成为 V5 writer/schema。

## 2026-07-30 — V4 frozen

- V4 派遣主链路完成独立复查、正式窗口证据和里程碑冻结。
- C0 城市时间、terminal authority、coordinator ownership、幂等重放和
  冲突拒绝进入冻结基线。
- V4 checkpoint：`5357c28`。

## 2026-07-25 至 2026-07-27 — P0/P1/C0 baseline

- 建立 Camera2D 导航、固定 UI、建造、选择、建筑生命周期和统一交互。
- 建立第一张地图的道路、生产、日期、威胁、训练、科技和军令台技术闭环。
- 建立 C0 确定性战斗灰盒和城市写回事务。
- S1A.1 内存快照 roundtrip 获得接受；S1A.2 留在保护边界外。

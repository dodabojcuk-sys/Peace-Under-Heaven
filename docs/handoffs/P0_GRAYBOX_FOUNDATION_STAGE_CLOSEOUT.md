# P0 灰盒基础阶段收尾交接

## 阶段结论

- 收尾日期：2026-07-25
- 阶段状态：P0 灰盒基础已封存，可作为后续独立功能研究的回滚基线。
- P0-06 验收边界：用户接受当前整体结果作为阶段版本；没有把该结论扩写成未提供的逐项实体测试。
- 本阶段目标是验证地图导航、静态 UI 壳、最小建造、建筑选择、运行时安全移除和统一建筑交互，不是正式游戏系统。

## P0-01 至 P0-06 真实状态

| 阶段 | 状态 | 已完成范围 |
| --- | --- | --- |
| P0-01A | 未通过，已替换 | 旧 `Control` / `PanContent.position` 实体拖动失败，不作为基线 |
| P0-01B | 用户实体验收 | 唯一 `Node2D + Camera2D` 导航；实体拖动与滚轮缩放成立 |
| P0-02B-S1 | 用户观察接受 | 固定 CanvasLayer UI 壳；顶部、左侧和小地图占位 |
| P0-03B-S1 | 用户接受 + 自动回归 | 40 单位网格、3 x 2 测试建筑、预览、放置、取消、占用拒绝 |
| P0-04B-S1 | 用户 10 项实体测试 + 自动回归 | 建筑选择、描边、右侧详情、点击／拖动分流和 UI 防穿透 |
| P0-05 | 用户 16 项总体通过反馈 + 自动回归 | 单调 placement ID、权威记录、运行时安全移除和意外离树清理 |
| P0-06 | 阶段整体接受 + 自动回归 | 固定／运行时建筑统一记录与选择；右侧建造入口；删除旧底栏 |

自动构造输入只用于回归辅助，不替代实体鼠标手感验收。

## 当前运行结构

- 唯一主场景：`res://scenes/blank_map.tscn`
- `BlankMapRoot`：唯一 `_input` 所有者，协调导航、选择和建造模式。
- `MapWorld`：唯一地图世界，包含底板、道路、区域、中心标记和六个固定灰盒建筑。
- `Camera2D`：唯一相机，负责拖动、滚轮缩放和边界。
- `ConstructionController`：唯一建筑记录、放置顺序、网格占用和运行时移除权威状态。
- `BuildingSelectionController`：只保存单一 `selected_placement_id`，负责命中、描边和详情展示，不拥有 `_input`。
- `UI/Shell`：唯一固定 UI 壳；右侧建造入口、模板列表和详情面板互斥。
- 原 `ContextBar`、临时底部建造入口及派遣／管理占位已删除。

权威建筑 Dictionary 和占用容器仅由 `ConstructionController` 内部修改。外部通过深拷贝记录、placement ID 副本和只读占用查询接口读取。

## 建筑能力

| 建筑 | kind | selectable | removable | movable |
| --- | --- | ---: | ---: | ---: |
| 城主府 L1 | fixed | 是 | 否 | 否 |
| 兵营 L1 | fixed | 是 | 否 | 否 |
| 粮仓 L2 | fixed | 是 | 否 | 否 |
| 学院 L1 | fixed | 是 | 否 | 否 |
| 城门 L1 | fixed | 是 | 否 | 否 |
| 军令台 L1 | fixed | 是 | 否 | 否 |
| 运行时测试建筑 | placed | 是 | 是 | 否 |

固定建筑以其灰盒矩形保守栅格化并写入占用表，阻止测试建筑重叠。这不是正式 footprint 或存档格式承诺。军令台没有正式功能，只显示中性说明。

## 输入与状态冻结项

- 地图导航保持左／中／右键拖动，8 px 阈值，滚轮缩放 `0.6–1.6`，每档 `0.1`。
- 真实鼠标移动使用相邻 `event.position` 差值，不依赖在该环境中恒为零的 `relative`。
- idle 小于阈值的左键释放用于建筑选择；超过阈值只拖动地图。
- placing 使用左键确认、中键拖动、滚轮缩放、右键或 `Esc` 取消。
- 选择、建造模板和 placing 互斥；进入建造清除选择，选中建筑退出建造交互。
- 固定建筑不可移除；运行时建筑必须经过确认才可移除。
- UI 遮挡动态读取真实 `Control.get_global_rect()`，不会永久写入世界占用。
- 不创建第二套地图、相机、输入、选择、建筑数据或 UI Shell。

## 自动验证入口

Godot 版本：4.5.1 stable。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2" --editor --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2" --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2" --script res://tests/run_construction_placement_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2" --script res://tests/run_building_selection_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2" --script res://tests/run_building_lifecycle_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2" --script res://tests/run_unified_building_interaction_smoke.gd
git diff --check
```

统一 smoke 覆盖六个固定建筑、能力限制、固定占用、选择／详情、右侧建造入口、防穿透、底栏删除和运行时移除回归。

## 已知限制与未实现

- 当前只有一个中性测试建筑模板，数据仅在内存中。
- 40 世界单位网格、3 x 2 footprint 和固定建筑保守占用均为 P0 参数。
- 左侧 152 px 城市栏覆盖地图边缘仍是 non-blocking deferred 项。
- 没有单栋建筑移动、批量移动或移除、连续工具模式、undo／redo、资源返还。
- 没有道路连接、生产、人口、耐久、升级、存档和多城市。
- 没有派兵、战役或军令台正式功能。
- 没有正式建筑目录、正式建造菜单、正式美术和最终 UI。

## 后续开始前先检查

1. `CURRENT_STATE.md`
2. `scenes/blank_map.tscn`
3. `scripts/map_pan_controller.gd`
4. `scripts/construction_controller.gd`
5. `scripts/building_selection_controller.gd`
6. `tests/run_unified_building_interaction_smoke.gd`
7. `docs/design/P0_06_UNIFIED_BUILDING_INTERACTION_RESEARCH.md`

下一候选方向仅建议研究“单栋建筑移动”，先冻结输入所有权、占用迁移、取消／确认和回滚规则；本阶段没有实现它，也没有重排后续完整路线图。

## Git 回滚与 GitHub 同步

- P0-06 原子实现提交：`3b45941` `feat: unify building interaction shell`
- 权威状态边界整理提交：`e71ea8f` `refactor: clean building interaction foundation`
- 稳定代码回滚点：`e71ea8f`
- 阶段收尾提交：包含本文件、message 为 `docs: close P0 graybox foundation stage`；可用 `git log -1 -- docs/handoffs/P0_GRAYBOX_FOUNDATION_STAGE_CLOSEOUT.md` 获取其 hash。
- 远端目标：`git@github.com:dodabojcuk-sys/txwzs-godot-rebuild.git` 的 `main`
- GitHub 同步必须在收尾提交后执行 `fetch`、确认 behind 为 0、普通 `push origin main`，再验证本地 `HEAD` 与 `origin/main` 相同。实际推送结果以本次收尾任务的最终运行报告为准。
- 不创建 tag、GitHub Release 或 PR，不改写历史。

# CURRENT_STATE

## 当前阶段

- `P0-01A_MAP_PAN`

## 当前实际交互与运行方式

- 仅新增地图平移（灰盒）交互。
- 中键或右键按住拖拽时，地图随鼠标平移。
- 松开后立即停止，不做惯性与缓动。
- 左键不参与地图拖拽。
- 项目启动主场景：`res://scenes/blank_map.tscn`（未更改）。

## 修改文件

- `project.godot`：`run/main_scene` 保持 `res://scenes/blank_map.tscn`。
- `scenes/blank_map.tscn`：新增 `PanContent` 节点、灰盒参照物、边界可视化线，并绑定脚本。
- `scripts/map_pan_controller.gd`：新增中键/右键平移输入脚本。

## 验证结果

- 基线环境可复现：`/Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 1`。
- 中键/右键拖拽为主行为入口，配套日志与截图序列已产出：
  - `非 headless` 直接启动 + 连续中键/右键拖拽。
  - `pre/mid/post` 截图差分显示有明显位移差异（`/tmp/p0_01a_focus2_pre.png`、`/tmp/p0_01a_focus2_mid.png`、`/tmp/p0_01a_focus2_post.png`）。
- 松开后：`is_dragging`/`dragging_button` 复位为非拖拽状态，停止移动。
- 左键动作不进入 `MOUSE_BUTTON_MIDDLE` 或 `MOUSE_BUTTON_RIGHT` 路径，但“左键像素级无移动”未能在当前自动截图链路中完全排除系统噪声；保留为人工复核项。

## 已知问题

- 未接入自动化鼠标操作脚本；完整“中键/右键实操 + 连续多向拖拽”需人工/交互环境下快速复核。
- 当前回合未实现缩放、边界回弹、惯性、建筑/道路/战斗/正式 UI。

## 灰盒视觉约定

- 正式 UI 与正式美术暂缓。
- 建筑以后统一先用色块和文字表示。
- 灰色表示未启用或未连接。
- 琥珀色边框表示选中。
- 红色表示非法或受损。
- 建筑等级不能只靠颜色区分，必须同时使用 `L1/L2/L3` 文字和一至三条等级标记。
- 每轮只能增加一个玩家可见行为，验收后才能继续。

## 下一轮候选任务

- `P0-01B 空地图缩放`

## 下一轮尚未授权执行

- 缩放、边界、惯性、建造、道路、战斗、正式 UI、状态化系统、存档/数据层等。

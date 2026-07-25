# P0-03A 建造系统研究

## 1. 研究边界

本文基于提交 `b7668d8953bf253506d17e9c9b022e7c75a10267` 的当前代码与场景结构，研究下一轮最小建造闭环。

本轮只形成方案，不实现建造，不修改场景、脚本或项目配置。

下一轮仍必须限制为：

- 一个中性测试建筑；
- 一次进入、预览、放置、取消流程；
- 仅保存在当前运行内存中；
- 不接资源消耗、升级、道路启用规则、施工时间、存档或多城市；
- 不制作正式建造菜单、建筑美术或完整建筑目录。

## 2. 当前结构与约束

### 2.1 场景结构

当前唯一主场景为 `res://scenes/blank_map.tscn`：

```text
BlankMapRoot (Node2D, map_pan_controller.gd)
├── MapWorld (Node2D)
│   ├── MapBoard (ColorRect, 2200 x 1400)
│   ├── 地图边界
│   ├── 两条灰盒道路
│   ├── 区域文字与中心标记
│   └── 六个灰盒建筑
├── Camera2D
└── UI (CanvasLayer)
    └── Shell (Control)
        ├── TopStatusBar
        ├── CityBar
        ├── MinimapPlaceholder
        └── ContextBar
```

项目当前没有第二个地图、第二个相机或第二个输入控制器。

### 2.2 相机与输入

`scripts/map_pan_controller.gd` 挂在 `BlankMapRoot`，通过唯一的 `_input` 接收鼠标事件：

- 左键、中键和右键都可以进入拖动候选；
- 累计移动超过 8 像素后开始拖动；
- 使用相邻 `InputEventMouseMotion.position` 的差值移动相机；
- 滚轮缩放范围为 `0.6–1.6`，步长 `0.1`；
- 缩放以鼠标所在世界位置为中心；
- Camera2D 根据 2200 x 1400 地图和当前视口动态 clamp。

建造功能不能再新增一个并行 `_input` 或 `_unhandled_input` 入口，否则会重新制造输入优先级和实体鼠标行为冲突。

### 2.3 固定 UI

固定 UI 位于 `CanvasLayer`，不受 Camera2D 影响。当前 1152 x 648 验收尺寸下的遮挡区为：

| 区域 | 屏幕坐标 Rect2 |
|---|---|
| 顶部状态栏 | `(0, 0, 1152, 48)` |
| 左侧城市栏 | `(0, 48, 152, 600)` |
| 小地图占位 | `(976, 64, 160, 100)` |
| 底部操作栏 | `(360, 588, 584, 44)` |

这些 Control 当前均为 `mouse_filter = IGNORE`，因此根节点 `_input` 仍会收到发生在 UI 上方的鼠标事件。建造确认不能依赖 GUI 自动拦截，必须显式检查屏幕遮挡区。

左侧 152 px 遮住地图边缘是已接受的 non-blocking 问题。建造系统不应通过裁剪或缩小 `MapWorld` 解决它，而应阻止不可见、不可确认的落点，并允许玩家把地图拖到安全可见区后放置。

## 3. 三种落点方案比较

| 方案 | 优点 | 主要问题 | 不同占地尺寸 | 道路与邻接 | 存档稳定性 | 当前成本 |
|---|---|---|---|---|---|---|
| 固定建筑槽位 | 最容易实现、碰撞和存档；落点始终可控 | 城市布局被槽位提前锁死；不同城市和后续道路布局扩展性差 | 可由槽位类型约束，但自由度低 | 需要额外定义槽位之间的连接图 | 很高 | 低 |
| 世界坐标网格吸附 | 放置可控；占地、碰撞、邻接、道路和存档都能使用同一离散坐标 | 需要选定格子尺寸，并处理现有灰盒元素不完全对齐的问题 | 天然支持 `Vector2i` footprint | 天然支持相邻格、保留格和道路格 | 很高 | 中 |
| 完全自由摆放 | 视觉自由度最高；不必决定网格尺寸 | 碰撞、旋转、间距、道路接入、精确点击和存档都更复杂；缩放时容易产生误放 | 需要连续几何碰撞 | 需要额外吸附点或连接器系统 | 中 | 高 |

### 3.1 固定建筑槽位

固定槽位适合城市布局完全预制、玩家只决定“在这个坑位建什么”的游戏。它能最快形成闭环，但会把当前尚未确定的城市规划提前写入场景。

本项目已经明确未来可能存在不同占地、道路连接和城市存档。若现在采用固定槽位，后续很可能需要把槽位图重构成空间网格，因此不推荐作为主方案。

### 3.2 世界坐标网格吸附

网格把连续世界坐标转换为稳定的 `Vector2i` 单元坐标：

- 建筑定义保存占地格数；
- 建筑实例保存左上角格坐标；
- 占用检测以格子为单位；
- 道路以后可以使用同一网格或其子集；
- 存档不依赖像素误差和 Camera2D 状态；
- 不同城市可以各自维护一张 occupancy 数据。

当前 MapBoard 为 2200 x 1400，两条灰盒道路宽度都是 40。P0 原型已接受 40 世界单位格长，可得到 55 x 35 的完整网格，规模小、容易检查，也便于未来表达道路宽度。

现有灰盒建筑使用 80、350、650 等位置和约 190 x 120 的尺寸，并未遵循统一 40 单位网格。它们只是旧灰盒表现，不应反向决定未来建造坐标。下一轮可将现有道路、中心标记和六个建筑保守栅格化为静态占用格，避免测试建筑与可见元素重叠，不需要移动这些现有节点。

### 3.3 完全自由摆放

自由摆放现在没有足够收益。它会立即引入连续碰撞、最小间距、像素级误差、道路入口吸附、旋转和更复杂的存档格式，难以在一个可回滚的小切片中可靠验收。

除非未来明确要求建筑可任意旋转并追求非网格化城市布局，否则不应在 P0 阶段采用。

## 4. 最终推荐

推荐采用**世界坐标网格吸附**。用户已接受 P0 原型逻辑格长为 40 世界单位，以及测试建筑占地为 3 x 2 格（120 x 80 世界单位）。

推荐原因：

1. 与当前 2200 x 1400 地图及 40 单位道路宽度相容；
2. 使用 `Vector2i` 保存位置，避免缩放、浮点误差和像素分辨率影响；
3. `footprint_cells` 可以直接支持不同建筑占地；
4. occupancy 可同时服务重复建造检查、道路邻接、升级扩地和城市存档；
5. 下一轮只需实现很小的数据结构和一个预览节点；
6. 若研究结论被推翻，删除建造控制器和测试节点即可回到当前 UI 基线。

40 单位和 3 x 2 占地只作为 P0 验证参数，不是正式建筑尺度、道路规则或存档兼容承诺。在正式建筑、道路和存档设计冻结前仍可调整。本切片不把完整网格画在地图上，也不把格坐标暴露给玩家。

## 5. 最小建造闭环

### 5.1 进入建造模式

下一轮暂时复用底部操作栏第一个 92 x 28 占位操作，将其从“查看”改成唯一的“建造”测试入口。

这样可以：

- 不增加正式建造菜单；
- 不扩大底栏；
- 保持入口可见；
- 避免使用隐藏快捷键作为唯一入口；
- 后续正式信息架构确定后再替换入口。

### 5.2 测试建筑

只定义一个中性测试建筑：

```text
id: test_building
display_name: 测试建筑
footprint_cells: Vector2i(3, 2)
world_size: Vector2(120, 80)
```

它只显示一个半透明灰盒矩形和“测试建筑”文字，不表达正式建筑类型。

### 5.3 预览

进入模式后，在 `MapWorld` 下创建或显示唯一预览节点：

- 预览随 Camera2D 平移和缩放；
- 根据鼠标世界坐标吸附到网格；
- 有效为低饱和绿色；
- 无效为低饱和红色；
- 无效时给出一个简短原因，例如“超出地图”“被界面遮挡”“位置已占用”；
- 不显示资源、施工时间或正式属性。

### 5.4 有效性判断

确认前必须同时满足：

1. 建筑世界矩形完全位于 MapBoard 的 2200 x 1400 范围内；
2. footprint 覆盖的所有格子均未被占用；
3. 不与现有灰盒建筑、道路或中心标记形成的静态 blocker 相交；
4. 建筑投影到屏幕后的完整矩形不与四个常驻 UI 遮挡区相交；
5. 鼠标当前不在交互 UI 控件上。

UI 遮挡判断应检查**整个建筑屏幕投影**，而不是只检查鼠标点。建议在 UI rect 外再加 8 像素安全间距，避免建筑紧贴面板边缘而难以点击。

### 5.5 确认与取消

- 左键单击有效预览：确认放置；
- 左键单击无效预览：不放置，保留无效反馈；
- `Esc`：取消建造模式；
- 右键按下：取消建造模式；
- 确认一次后保持建造模式，允许连续放置同一种测试建筑；
- 只有右键或 `Esc` 取消后回到普通导航模式；
- 确认后把占用格写入内存 occupancy；
- 同一轮或再次进入建造模式时，同一位置必须判定为已占用。

不增加二次确认对话框。玩家已经看到预览和有效性反馈，左键确认应使用同一个预览 intent，不能在确认时重新计算成另一个落点。

## 6. 坐标系统

### 6.1 三类坐标

1. **屏幕／视口坐标**
   `InputEventMouse.position`，原点为游戏内容区左上角。固定 UI 的 `Control.get_global_rect()` 也处于这一坐标系。

2. **世界坐标**
   MapWorld 与 Camera2D 使用的坐标。建筑预览和已放置建筑必须存放在 MapWorld 下。

3. **网格坐标**
   `Vector2i`，只用于逻辑占地、碰撞和未来存档，不直接显示给玩家。

### 6.2 屏幕与世界转换

推荐使用 Viewport 的 canvas transform，而不是复制一份 Camera2D 公式：

```gdscript
var canvas_transform := get_viewport().get_canvas_transform()
var world_position := canvas_transform.affine_inverse() * screen_position
var screen_position := canvas_transform * world_position
```

这样转换会自动包含 Camera2D 的 position 和 zoom。当前相机没有旋转，但该方法也避免以后 Camera2D 参数变化时建造控制器与导航公式分叉。

如果 MapWorld 以后获得额外 transform，再使用：

```gdscript
var map_local_position := map_world.to_local(world_position)
```

### 6.3 世界与网格转换

暂定：

```gdscript
const CELL_SIZE := 40.0
const GRID_ORIGIN := Vector2.ZERO

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floor((world_position.x - GRID_ORIGIN.x) / CELL_SIZE),
			floor((world_position.y - GRID_ORIGIN.y) / CELL_SIZE))

func cell_to_world(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * CELL_SIZE
```

建筑实例保存左上角 `origin_cell`。鼠标吸附时根据 footprint 将预览中心对齐到鼠标附近，再得到稳定的左上角格坐标。

### 6.4 UI 遮挡与缩放

建筑 footprint 的世界矩形需要把四个角转换成屏幕坐标，再生成屏幕轴对齐矩形。该矩形与以下动态读取的 UI rect 比较：

```gdscript
top_status_bar.get_global_rect()
city_bar.get_global_rect()
minimap_placeholder.get_global_rect()
context_bar.get_global_rect()
```

不要在建造逻辑里重复硬编码 152、48 等值；这些数值属于当前 UI 节点。文档中的固定 rect 只是当前验收基线。

常驻 UI 是屏幕空间遮挡，只在当前预览和确认时参与有效性判断：

- 不把投影在 UI 下方的世界格写入永久阻塞或 occupancy；
- 相机移动或缩放后必须重新计算建筑的屏幕投影；
- 同一世界格完整进入安全可见区后，可以重新接受确认；
- 已完成的建筑随地图移动到 UI 后方属于正常相机覆盖效果，不改变其世界占用。

## 7. 输入与导航共存

### 7.1 单一输入入口

`BlankMapRoot` 上的 `map_pan_controller.gd` 继续作为唯一 `_input` 入口。新增建造控制器不得自行实现 `_input`。

根输入入口按模式路由事件：

```text
普通模式
└── 保持现有左／中／右拖动和滚轮缩放

建造模式
├── 左键：确认当前预览
├── 中键拖动：移动地图
├── 滚轮：缩放地图
├── 右键：取消
└── Esc：取消
```

新增 `ConstructionController` 只接收根脚本转发的屏幕坐标和命令，负责预览、验证、occupancy 和放置，不拥有第二条事件监听链。

### 7.2 建造时是否允许导航

推荐在建造模式中：

- **允许中键拖动**：玩家可以把被 UI 覆盖的地图区域移到安全位置；
- **允许滚轮缩放**：玩家可以检查较大 footprint 和周围障碍；
- **禁用左键拖动导航**：左键专用于确认，避免拖动阈值与放置发生歧义；
- **禁用右键拖动导航**：右键专用于取消，保持取消操作即时可靠。

相机每次移动或缩放后，都从当前屏幕鼠标位置重新计算预览。现有 Camera2D clamp、缩放中心和范围保持不变。

## 8. 下一轮最小实现建议

### 8.1 文件范围

仅建议修改或新增：

1. `scenes/blank_map.tscn`
   - 增加建造控制器节点、预览层、已放置层；
   - 把底栏第一个占位操作改为临时“建造”入口；
   - 给现有灰盒道路、中心标记和六个建筑标记静态 blocker group。
2. `scripts/map_pan_controller.gd`
   - 保持唯一 `_input`；
   - 增加普通／建造模式事件路由；
   - 不修改现有拖动位移、阈值、zoom 或 clamp 公式。
3. `scripts/construction_controller.gd` 及 Godot 正常生成的 `.gd.uid`
   - 不实现 `_input`；
   - 负责网格、预览、有效性和内存 occupancy。
4. `tests/run_construction_placement_smoke.gd` 及正常 `.gd.uid`
   - 单一 headless runner；
   - 不引入测试框架或第三方依赖。

不修改 `project.godot`，不创建第二个场景、地图或 Camera2D。

### 8.2 建议节点结构

```text
BlankMapRoot (唯一输入入口)
├── MapWorld
│   ├── 现有地图节点
│   └── ConstructionLayer (Node2D)
│       ├── PlacedBuildings (Node2D)
│       └── Preview (ColorRect，默认隐藏)
├── Camera2D
├── ConstructionController (Node，无 _input)
└── UI / Shell
    └── ContextBar
        └── BuildTestButton
```

### 8.3 最小数据结构

```gdscript
const TEST_BUILDING := {
	"id": &"test_building",
	"display_name": "测试建筑",
	"footprint_cells": Vector2i(3, 2),
}

var placements: Array[Dictionary] = []
var occupied_cells: Dictionary = {} # Vector2i -> placement id
var static_occupied_cells: Dictionary = {}
var preview_origin_cell := Vector2i.ZERO
var preview_valid := false
var preview_invalid_reason := ""
```

后续正式阶段再把 definition 升级为 Resource，把 placement 升级为可序列化类型。下一轮不先建通用注册表、事件总线或存档模型。

### 8.4 验收标准

自动检查：

- 场景仍只有一个 MapWorld 和一个 Camera2D；
- 普通模式现有导航常量和 Camera2D clamp 未变化；
- 世界／网格转换在 0.6、1.0、1.6 zoom 下结果一致；
- 地图边界外无效；
- 静态 blocker、动态 occupancy 和 UI 遮挡区内无效；
- 放置后所有 footprint 格被占用；
- 取消后 placements 与 occupancy 不变化；
- `git diff --check` 通过；
- Godot 4.5.1 headless smoke 无错误。

用户实体检查：

- 点击“建造”能进入模式；
- 预览随鼠标吸附移动；
- 有效和无效状态容易区分；
- 左键只在有效位置放置；
- Esc 和右键立即取消；
- 同一位置不能重复放置；
- 建造模式中键拖动和滚轮缩放仍有效；
- 顶栏、左栏、小地图和底栏下方不能确认建造；
- 放置后建筑与 MapWorld 一起平移、缩放，固定 UI 不移动。

### 8.5 测试方式

1. 纯逻辑 smoke：直接调用坐标转换、snap、bounds、occupancy 和 UI overlap 方法。
2. headless 场景 smoke：加载唯一主场景，确认节点引用和预览节点状态。
3. 非 headless 辅助验证：观察 Camera2D、预览和放置节点的坐标变化。
4. 最终验收仍以用户实体鼠标完成完整进入、预览、放置、取消流程为准。

人工构造事件只能辅助，不替代实体输入验收。

### 8.6 回滚方案

- 下一轮实现形成单独原子提交；
- 未通过验收前不提交或先保留明确 checkpoint；
- 若方案失败，回退下一轮建造提交即可恢复到 UI Shell 基线 `b7668d8953bf253506d17e9c9b022e7c75a10267`；
- 不 reset、重写历史或长期依赖 stash；
- occupancy 仅在内存中，不涉及数据迁移或存档回滚。

## 9. 已接受的 P0 原型决策

用户已接受以下两项分叉：

1. **40 世界单位作为 P0 逻辑格长，测试建筑为 3 x 2 格。**
   它们用于验证 footprint、网格占用和坐标转换，但不冻结为正式建筑尺度、道路规则或存档合同。

2. **临时输入合同：底栏第一个占位改为“建造”，建造时左键确认、中键拖图、滚轮缩放、右键或 Esc 取消。**
   确认后保持建造模式以便连续验证占用冲突；右键或 `Esc` 才退出。本合同不是最终建造菜单。

## 10. 研究结论

P0-03A 采用 40 单位世界网格吸附作为 P0 原型基线。它在不同占地、道路邻接、占用检查和未来存档之间提供同一个稳定坐标合同，同时仍能把首次实现限制在一个灰盒建筑和一段内存态闭环。

第 9 节的两个关键分叉已经用户确认，可以进入 P0-03B-S1 最小建造闭环实现。所有参数在正式建筑、道路与存档设计前仍可调整。

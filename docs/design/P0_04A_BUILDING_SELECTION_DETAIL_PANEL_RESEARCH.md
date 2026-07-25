# P0-04A 建筑选择与右侧详情面板研究

## 1. 研究边界

本文基于已封存提交 `79e107a2e5285e5d884d9aa6e88536ff410423fa`，研究下一轮最小的：

```text
点击已放置测试建筑
→ 显示选中反馈
→ 显示固定右侧详情面板
→ 切换或取消选择
```

本轮只形成研究结论，不修改代码、场景、项目配置或 `CURRENT_STATE.md`，不实现功能。

下一轮仍必须限制为：

- 只选择 `MapWorld/ConstructionLayer/PlacedBuildings` 下的中性测试建筑；
- 只显示一个灰盒详情面板；
- 保持现有地图拖动、缩放和建造闭环；
- 不加入道路、资源、升级、拆除、生产、存档、多城市或正式建筑数据。

Git 身份阻断已在实现前解除：当前仓库已使用用户确认的本地 `user.name` 与 `user.email`；不修改全局配置，也不 amend 已有提交。

## 2. 当前真实结构

### 2.1 节点结构

当前唯一主场景为 `res://scenes/blank_map.tscn`：

```text
BlankMapRoot (Node2D, map_pan_controller.gd，唯一 _input)
├── MapWorld (Node2D)
│   ├── 现有灰盒地图内容
│   └── ConstructionLayer (Node2D)
│       ├── PlacedBuildings (Node2D)
│       │   └── TestBuildingNNN (运行时创建)
│       │       ├── Body (Polygon2D)
│       │       ├── Outline (Line2D)
│       │       └── Label (Label)
│       └── ConstructionPreview (Node2D)
├── Camera2D
├── ConstructionController (Node，无 _input)
└── UI (CanvasLayer)
    └── Shell (Control)
        ├── TopStatusBar
        ├── CityBar
        ├── MinimapPlaceholder
        └── ContextBar
            └── TemporaryBuildButton
```

当前只有 `scripts/map_pan_controller.gd::_input` 一个输入所有者。建造控制器只接收根脚本转发的命令。

### 2.2 已放置建筑的可识别数据

每次成功放置会创建一个 `TestBuildingNNN`：

- 节点位置是建筑左上角对应的 `MapWorld` 局部坐标；
- `origin_cell` metadata 保存左上角 `Vector2i` 网格坐标；
- `footprint_cells` metadata 保存 `Vector2i(3, 2)`；
- `Body.polygon` 当前为 120 x 80 世界单位矩形；
- `placements` 和 `occupied_cells` 仍只存在于运行内存中。

这些信息已足以显示：

- 名称：测试建筑；
- 类型：中性测试建筑；
- 网格位置：`origin_cell`；
- 占地：3 x 2；
- 状态：原型 / 运行中。

下一轮不需要建立正式建筑 Resource、注册表或存档 schema。

### 2.3 当前 UI 鼠标行为

- `UI/Shell` 和大部分静态占位 Control 使用 `MOUSE_FILTER_IGNORE`；
- `TemporaryBuildButton` 是当前唯一主动接收鼠标的 UI 控件；
- 根节点 `_input` 早于 GUI 分发收到事件，因此不能只依赖 `mouse_filter` 阻止地图逻辑；
- 建造有效性已经动态读取四个常驻 Control 的 `get_global_rect()`，而不是复制固定像素值。

右侧面板出现后仍需显式协调根输入，避免点击面板时同时点击或拖动其下方地图。

## 3. 左键点击与地图拖动冲突

### 3.1 现有真实实现

idle 状态下，左、中、右键共享现有拖动逻辑：

1. 按下时记录 `active_drag_button` 和 `last_pointer_screen`；
2. `MouseMotion.position` 相邻差值累加进 `pending_drag_delta`；
3. `pending_drag_delta.length() < 8` 时不移动 Camera2D；
4. 达到 8 px 后设置 `is_dragging = true`，并执行原 Camera2D 位移；
5. 对应按键释放时 `_stop_drag()` 清空状态。

当前小于 8 px 的按下 / 释放不会触发其他行为，正好可以承载“点击”语义。

### 3.2 推荐区分方式

保持现有 `DRAG_THRESHOLD := 8.0` 和拖动算法不变，只在左键释放前增加一次分流：

```text
idle + 左键释放
├── is_dragging == true
│   └── 只结束地图拖动，不执行选择
└── is_dragging == false 且 pending_drag_delta.length() < 8
    └── 把释放位置转发给选择控制器，执行一次点击命中
```

必须在 `_stop_drag()` 清空状态之前判断点击。

结果：

- 小于 8 px：作为点击；
- 达到或超过 8 px：只作为地图拖动；
- 按在建筑上后拖动：仍拖地图，不在释放时选中该建筑；
- 不更改拖动方向、阈值、缩放、缩放中心或 clamp；
- 不新增定时器、双击、长按或新的 InputMap action。

使用现有净位移阈值最符合当前代码合同。P0 阶段不另加累计路径长度或时间阈值。

## 4. 建筑命中检测方案比较

| 方案 | 正确性 | 当前复杂度 | 后续扩展 | 测试成本 | 主要风险 |
|---|---|---:|---|---:|---|
| 每栋建筑 `Area2D + CollisionShape2D`，统一 physics point query | 高 | 中 | 适合旋转、不规则碰撞和大量实体 | 中 | 引入碰撞层、物理同步和 shape 生命周期 |
| 统一选择控制器进行世界矩形查询 | 当前灰盒下高 | 低 | 支持不同矩形 footprint，可后续替换 | 低 | 若未来出现旋转或不规则形状，需要升级 |
| 每栋建筑使用 `_input_event`、`gui_input` 或独立信号争抢输入 | 中 | 中 | 差 | 高 | 输入顺序、拖动冲突和 UI 穿透重新分散 |
| 直接查询 `occupied_cells` 网格 | 中 | 低 | 与网格建筑一致 | 低 | 逻辑占用与视觉边界可能不同，难处理重叠层级 |

### 4.1 Area2D 方案

优点：

- Godot 原生物理查询；
- 支持以后旋转、不规则形状和碰撞层；
- 重叠对象可按 z 或优先级筛选。

当前代价：

- 每个运行时建筑需要创建 Area2D 和 CollisionShape2D；
- 需要维护 collision layer / mask；
- 查询结果受物理帧同步影响；
- 对当前唯一 120 x 80 矩形测试建筑过重。

P0-04B 不推荐先引入。

### 4.2 统一世界矩形查询

推荐新增一个职责单一、没有 `_input` 的 `BuildingSelectionController`：

1. 根 `_input` 只在 idle 的有效点击释放时转发屏幕坐标；
2. 选择控制器把屏幕坐标通过 `MapWorld.get_global_transform_with_canvas().affine_inverse()` 转成 MapWorld 坐标；
3. 只遍历 `PlacedBuildings` 的直接子节点；
4. 将点转换到候选建筑局部坐标，并检查建筑的本地选择矩形；
5. 若多栋重叠，按场景树反向顺序选择视觉上最后创建、最上层的一栋。

下一轮建议在创建建筑时增加一个中性 metadata：

```gdscript
building.set_meta(
	"selection_bounds",
	Rect2(Vector2.ZERO, TEST_BUILDING_WORLD_SIZE)
)
```

选择控制器读取 `selection_bounds`，不重复写死 120 x 80。未来不同矩形 footprint 仍可复用；若正式建筑需要旋转或不规则轮廓，再替换成 Area2D，不影响根输入合同。

### 4.3 推荐结论

P0-04B 推荐**统一选择控制器 + 建筑局部矩形命中**。

它满足：

- 单一 `_input`；
- 不让每栋建筑争抢事件；
- 自动包含 Camera2D 平移和 zoom；
- 不复制相机公式；
- 只需一个 metadata 和一个小控制器；
- 易于 headless 构造与断言；
- 失败时可完整移除，不影响建造 occupancy。

## 5. 选择状态模型

不建立通用状态机。下一轮只需要：

```gdscript
var selected_building: Node2D = null
```

状态行为：

| 操作 | 推荐结果 |
|---|---|
| idle 点击已放置测试建筑 | 选中并显示面板 |
| idle 点击另一测试建筑 | 原建筑恢复，切换到新建筑 |
| idle 点击空白地图且未拖动 | 清除选择并隐藏面板 |
| idle 拖动地图 | 保留当前选择 |
| idle 滚轮缩放 | 保留当前选择 |
| idle 按 `Esc` | 清除选择并隐藏面板 |
| 进入 placing | 先清除选择和面板，再进入建造 |
| placing 左键 | 只确认建造，不选择建筑 |
| placing 右键或 `Esc` | 只取消建造；返回无选择的 idle |

### 5.1 为什么拖动时保留选择

推荐拖动和缩放都保留选择：

- 玩家常需要移动地图查看所选建筑周围环境；
- 面板是当前上下文，不应因为导航动作意外消失；
- 选中反馈是建筑的世界子节点，会自然跟随相机；
- 空白单击、关闭按钮和 `Esc` 已提供明确取消入口。

### 5.2 建筑移动到 UI 后方

相机移动后，选中建筑可能被固定 UI 或详情面板遮住。推荐：

- 选择状态保持；
- 面板继续显示该建筑信息；
- 不自动移动相机、不自动取消选择；
- 被 UI 覆盖的建筑不可通过 UI 表面再次命中；
- 将地图拖回安全区域后，选中反馈仍与原建筑对齐。

自动取消会让导航过程不稳定，自动移动相机则会与用户拖动争夺控制权，两者均不推荐。

## 6. 建造与选择互斥

输入优先级保持明确：

```text
BlankMapRoot._input
├── ConstructionController.is_placing()
│   ├── 左键：确认预览
│   ├── 中键：拖动
│   ├── 滚轮：缩放
│   └── 右键 / Esc：取消建造
└── idle
    ├── 左 / 中 / 右：现有候选拖动
    ├── 左键未越过阈值的释放：建筑选择或空白取消
    ├── Esc：取消当前选择
    └── 滚轮：现有缩放
```

互斥规则：

- 进入 placing 前调用 `clear_selection()`；
- placing 期间选择控制器不接收任何点击；
- 成功放置后仍处于 placing，因此新建筑不能被立即选中；
- 右键或 `Esc` 退出 placing 后，用户需在 idle 中明确点击建筑；
- 不允许“同一次左键既放置又选中”。

## 7. 既有右侧面板设计依据

仓库文档没有记录右侧详情面板尺寸，但既有 Figma 文件已经包含：

- 文件：`TXWZS UI Shell P0-02A`
- Frame：`P0-02A-S2 Selected Target`
- Frame：1152 x 648
- 面板节点：`Context Panel / Selected Target`
- 节点链接：`https://www.figma.com/design/vZdn4XjXjX0hwkRqVEbXjX?node-id=11-2`

Figma metadata 的实际值：

| 属性 | 数值 |
|---|---|
| 面板位置 | `(856, 176)` |
| 面板尺寸 | `280 x 360` |
| 右侧间距 | 16 px |
| 与小地图底部间距 | 12 px |
| 与底部操作栏顶部间距 | 52 px |

小地图为 `(976, 64, 160, 100)`，底栏为 `(360, 588, 584, 44)`。面板不与二者重叠。

面板面积为 100,800 px²，约占 1152 x 648 全屏的 13.5%，约占当前 1000 x 600 地图视口的 16.8%。地图仍是主要视觉区域。

因此下一轮不需要重新提出一套尺寸。`280 x 360 @ (856,176)` 应作为既有低保真实现基线；Godot 运行后的视觉效果仍需用户实体观察确认。

## 8. 面板显示方式

### 8.1 推荐节点位置

```text
UI (CanvasLayer)
└── Shell (Control)
    ├── 现有固定 UI
    └── SelectedBuildingPanel (Panel，默认隐藏)
        ├── TargetName
        ├── TargetType
        ├── GridPosition
        ├── Footprint
        ├── PrototypeStatus
        └── CloseButton
```

面板必须：

- 位于现有 CanvasLayer / Shell；
- 固定在屏幕空间；
- 不随 Camera2D 移动；
- 默认 `visible = false`；
- 不创建第二套 UI Shell；
- 不为静态排版新增独立 UI 脚本。

### 8.2 覆盖地图，不缩小视口

推荐覆盖地图，不修改 Camera2D viewport，也不重新 clamp：

- 与已通过的 Figma S2 一致；
- 保持默认地图状态尺寸和导航合同；
- 避免选中时相机边界跳动；
- 避免重新布局地图、左栏、小地图和底栏；
- 隐藏面板后无需重建或恢复相机。

缩小地图视口会让选中状态改变可见世界范围和相机边界，超出本切片且破坏“地图优先”原则。

### 8.3 面板内容

严格限制为：

- 测试建筑；
- 类型：中性测试建筑；
- 网格位置：`(x, y)`；
- 占地：`3 x 2`；
- 状态：原型 / 运行中；
- 一个关闭按钮。

不显示升级、拆除、产出、建造时间、道路、等级、耐久、人口或其他不可用按钮。

### 8.4 显示与关闭

- 选中建筑：显示并刷新字段；
- 切换建筑：复用同一个面板并刷新；
- 空白单击：清除选择并隐藏；
- `Esc`：清除选择并隐藏；
- 关闭按钮：清除选择并隐藏；
- 地图拖动和缩放：保持显示；
- 面板隐藏后，其区域立即恢复地图点击、拖动和建造有效性。

推荐保留显式关闭按钮。空白点击和 `Esc` 虽然可关闭，但按钮能明确表达面板可退出，也便于鼠标用户和自动测试定位。

## 9. 动态 UI 遮挡与输入

### 9.1 面板自身

`SelectedBuildingPanel` 使用 `MOUSE_FILTER_STOP`，内部只有关闭按钮需要交互。

由于根 `_input` 仍会先收到事件，下一轮还必须在根输入分流中显式识别可见面板 rect：

- 从面板内开始的左键不启动地图拖动候选；
- 面板内左键不命中其下方建筑，也不触发空白取消；
- 面板关闭按钮只执行 `clear_selection()`；
- 面板内滚轮和中／右键是否穿透地图应保持简单：P0 建议全部不穿透，避免“操作面板时地图在动”。

该规则只针对实际可交互的详情面板，不要求重写现有静态 UI Shell 的导航行为。

### 9.2 选择点击的 UI 遮挡

选择控制器执行世界命中前，应动态读取：

- `TopStatusBar.get_global_rect()`；
- `CityBar.get_global_rect()`；
- `MinimapPlaceholder.get_global_rect()`；
- `ContextBar.get_global_rect()`；
- 可见的 `SelectedBuildingPanel.get_global_rect()`。

若点击点位于任一可见 UI rect：

- 不选择其下方建筑；
- 不把它解释为空白地图点击；
- 保留当前选择。

这样点击城市栏或面板不会意外关闭当前建筑上下文。

### 9.3 建造有效性

现有 `ConstructionController._get_ui_occlusion_controls()` 下一轮应加入 `SelectedBuildingPanel`。

该节点已经使用 `is_visible_in_tree()`：

- 面板可见：建筑预览投影与面板相交时无效；
- 面板隐藏：该区域立即恢复建造；
- 面板只影响当前投影，不写入 `occupied_cells`；
- 已放置建筑随相机进入面板后方不改变占用。

不得复制面板的 `(856,176,280,360)` 到脚本；必须读取实际 global rect。

## 10. 最小选中反馈

| 方案 | 优点 | 问题 | 推荐度 |
|---|---|---|---|
| 建筑描边 | 不改主体颜色；缩放、拖动自然跟随 | 需要独立选择描边，不能复用原常驻边框 | 高 |
| 半透明高亮 | 直观 | 容易与绿色有效预览混淆 | 低 |
| 选中框 / 四角框 | 与建筑颜色解耦 | 当前实现稍多于闭合描边 | 中 |
| 改变主体颜色 | 实现简单 | 破坏原灰盒颜色，取消时需恢复 | 不推荐 |

推荐使用**独立的低饱和暖黄或琥珀色闭合描边**：

- 不使用绿色或红色，避免与建造预览冲突；
- 作为选中建筑的世界子节点或统一反馈节点；
- bounds 来自同一 `selection_bounds`；
- z-index 高于建筑主体、低于建造预览；
- 取消或切换选择时隐藏 / 重挂，不修改 `Body.color`；
- Camera2D 平移和缩放后自然保持对齐。

P0 只需要一个闭合 `Line2D`。不加入呼吸动画、发光、粒子、正式图标或音效。

## 11. 下一轮最小实现范围

### 11.1 允许修改的文件

建议仅涉及：

1. `scenes/blank_map.tscn`
   - 增加默认隐藏的 280 x 360 详情面板；
   - 增加一个统一选择反馈节点；
   - 增加无输入的选择控制器节点。
2. `scripts/map_pan_controller.gd`
   - 在现有 8 px 左键候选释放处转发点击；
   - 保持唯一 `_input` 和原导航公式。
3. `scripts/construction_controller.gd`
   - 为新建筑写入 `selection_bounds`；
   - 将可见详情面板加入动态建造 UI 遮挡列表；
   - 进入 placing 时触发清除选择所需的最小协调。
4. 新增 `scripts/building_selection_controller.gd` 及 Godot 正常 `.gd.uid`
   - 不实现 `_input`；
   - 负责统一命中、选择状态、反馈和面板字段。
5. 新增或扩展一个最小 headless smoke runner 及 `.gd.uid`。

不修改 `project.godot`，不新增第二个场景、Camera2D、MapWorld、UI Shell 或输入系统。

仓库级 Git 提交身份已按用户确认值完成本地配置；后续提交继续使用该仓库身份。

### 11.2 明确不做

- 不让现有六个地图灰盒建筑可选；
- 不加入正式建筑类型或属性；
- 不加入升级、拆除、资源、道路、生产或存档；
- 不加入面板动画、响应式布局或通用窗口管理器；
- 不改变 40 单位网格、3 x 2 占地或导航参数；
- 不实现建筑移动、定位或镜头自动跟随。

## 12. 验收标准

### 12.1 自动验证

- 场景仍只有一个 MapWorld、一个 Camera2D、一个 `_input`；
- 创建两个测试建筑后，点击坐标能命中正确节点；
- 0.6、1.0、1.6 zoom 及相机平移后命中仍正确；
- 小于 8 px 的左键释放执行一次选择；
- 达到 8 px 的左键移动只拖地图，不执行选择；
- 从建筑开始拖动仍保留原选择；
- 点击另一建筑切换选择；
- 点击空白地图清除选择；
- `Esc` 在 idle 清除选择；
- 进入 placing 清除选择，placing 左键不触发选择；
- 选中时面板可见且字段来自建筑 metadata；
- 面板和关闭按钮点击不穿透地图；
- 面板可见时加入建造遮挡，隐藏后同一区域恢复；
- 选中、切换、取消均不改变建筑原始 `Body.color`；
- 原建造 smoke 和导航 smoke 全部继续通过；
- `git diff --check` 通过。

### 12.2 用户实体检查

1. 放置至少两个测试建筑并退出建造模式；
2. 单击建筑能选中并显示右侧面板；
3. 单击另一建筑能切换；
4. 单击空白地图能取消；
5. 从建筑或空白处拖动地图不会误触发选择；
6. 拖动和滚轮缩放后选中描边仍对齐；
7. 当前选择在拖动和缩放中保持；
8. `Esc` 和关闭按钮能取消选择；
9. 点击详情面板不会操作其下方地图；
10. 面板可见时建造预览不能在其下方确认；
11. 面板隐藏后该区域恢复地图与建造交互；
12. 面板不与小地图、底栏重叠，地图仍是主视觉。

自动事件注入只能作为辅助，不能替代以上实体操作。

## 13. 回滚方案

- 下一轮实现保持独立、未验收前不提交；
- 用户验收后形成一个原子提交；
- 若失败，删除选择控制器、反馈节点和详情面板，并恢复三处最小协调即可回到 `79e107a`；
- 不涉及存档或数据迁移，不需要兼容层；
- 不 reset、rebase、amend 或依赖长期 stash；
- 不改写已封存的 P0-03B-S1。

## 14. 已接受的关键视觉决策

现有 Figma 已确定面板位置和尺寸，用户同时接受以下两个低风险视觉选择：

1. **选中描边颜色**
   - 采用：低饱和琥珀 / 暖黄；
   - 理由：不与绿色有效预览、红色无效预览混淆。

2. **显式关闭按钮**
   - 采用：面板右上角保留一个简短关闭入口；
   - 同时保留空白单击和 `Esc` 取消；
   - 不增加其他按钮。

仓库级 Git 身份已完成本地配置；该配置只影响未来提交，不 amend 既有历史。

## 15. 研究结论

下一轮应采用：

- 现有 `BlankMapRoot._input` 继续作为唯一输入入口；
- 复用现有 8 px 候选拖动状态，在左键未拖动的释放时触发选择；
- 无 `_input` 的统一选择控制器执行建筑局部矩形命中；
- 选择和 placing 严格互斥；
- 拖动与缩放保留当前选择；
- 独立琥珀色描边作为最小反馈；
- 复用 Figma 已有 `(856,176,280,360)` 浮层面板；
- 面板位于 CanvasLayer，覆盖地图而不缩小视口；
- 面板可见时动态参与选择和建造 UI 遮挡，隐藏后立即恢复交互。

该方案能在不引入第二套输入、相机、地图或 UI Shell 的前提下，完成“点击建筑 → 显示详情 → 切换 / 取消”的最小灰盒闭环。

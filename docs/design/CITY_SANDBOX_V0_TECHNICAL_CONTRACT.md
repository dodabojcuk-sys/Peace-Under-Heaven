# CitySandboxV0 技术契约

## 1. 状态与范围

- 状态：`P1-F1A SPATIAL KERNEL IMPLEMENTATION`
- 本契约把 P1-F0 架构审计转换为可测试的空间规则边界。
- P1-F1A 只实现纯空间逻辑，不创建 `CitySandboxV0` 场景，不接入正式内城。
- `ConstructionController` 继续是唯一城市运行时权威；本轮不修改它。
- 本轮不实现资源事务、施工、每日结算、snapshot 或磁盘保存。

## 2. P1-F0 真实审计结论

当前正式城市只有一份运行时建设权威：

```text
map_pan_controller.gd 唯一 _input
→ ConstructionController 预览与校验
→ placement record / occupied_cells
→ 资源和施工生命周期
→ 四邻接道路连通
→ 每日结算
→ 第 6／7 日首战状态与战争阻断
→ C0 战果写回同一控制器
```

可以继续复用的语义：

- `Vector2i` 逻辑网格、footprint 和占用格；
- 类型化 `BuildingDefinition` / `BuildingCapability`；
- placement 记录和派生道路连通；
- 施工日界线、资源、时间、战争阻断和 C0 事务；
- 唯一输入所有者与现有 Camera2D 导航。

不能直接作为沙盘内核复用的部分：

- `ConstructionController` 直接引用旧主场景大量 NodePath，并创建灰盒表现节点；
- `blank_map.tscn` 中可见的两条 `ColorRect` 道路不是逻辑道路 placement；
- 当前第 9 日 readiness checkpoint 是不完整的进程内快照，不是正式保存；
- 固定建筑场景坐标还不是正式地图定义。

因此后续只能采用：

```text
ConstructionController 单一权威
→ 窄查询／提交适配层
→ CitySandboxV0 单一可写输入层
→ 可重建的表现投影
```

不得复制控制器、隐藏实例化旧主场景作为第二份城市，或允许新旧地图同时写入。

## 3. 四项修正

### 3.1 UI 遮挡不属于空间合法性

`UI_OCCLUDED` 只属于输入路由：

- UI 控件在屏幕空间决定点击是否进入地图；
- UI 位置不改变世界格、地形或 occupancy；
- 同一世界格不会因为面板开合变成合法或非法；
- P1-F1A helper 不访问 `Control`、Viewport 或屏幕坐标。

### 3.2 未接道路不阻止放置

建筑入口未接路时仍可合法放置：

- placement 成功并占用真实网格；
- 建筑进入施工或停用状态；
- `未接入道路` 是运行状态／警告；
- 道路接通后从既有规则恢复运行；
- P1-F1A 只计算入口外侧道路接触格，不决定能否提交。

### 3.3 表现节点不参与权威事务

后续权威提交不得依赖 Polygon2D、Sprite2D 或场景节点创建成功：

```text
校验 intent
→ 原子修改权威 placement / occupancy / resources
→ 发出 placement 结果
→ 表现层创建或重建节点
```

表现层删除或重建不得反向修改权威状态。P1-F1A 不创建任何表现节点，也不实现事务。

### 3.4 入口由格和朝向共同定义

入口模型：

```text
footprint_size: Vector2i
entrance_cell: Vector2i       # 占地内相对格
entrance_facing: Vector2i     # LEFT / RIGHT / UP / DOWN
orientation_quarters: 0..3   # 顺时针四分之一转
```

入口格必须位于 footprint 内，并处在与 facing 对应的外边界。

入口外侧道路格为：

```text
road_contact_cell =
    origin_cell
    + rotated_entrance_cell
    + rotated_entrance_facing
```

这里使用加法是因为 `entrance_cell` 是相对建筑原点的占地内坐标，`entrance_facing` 是从入口指向外侧道路的一格位移。使用减法会在左／上入口中得到建筑内部格。

本轮不修改 `BuildingDefinition`，只冻结并测试空间换算。

## 4. 坐标与旋转约定

- 逻辑坐标原点位于地图左上。
- `+X` 向右，`+Y` 向下。
- `orientation_quarters` 为顺时针旋转次数。
- 旋转发生在建筑自身 footprint 内，随后再加 `origin_cell`。
- 奇数次旋转交换 footprint 宽高。

方向顺时针旋转：

```text
UP → RIGHT → DOWN → LEFT → UP
```

非法情况必须返回明确错误：

- footprint 宽高非正；
- orientation 不在 `0..3`；
- entrance_cell 位于 footprint 外；
- entrance_facing 不是四方向；
- 入口格不在对应外边界。

## 5. 仿射视觉投影

空间内核使用用户冻结的形式：

```text
visual_position =
    visual_origin
    - basis_x * grid_x
    - basis_y * grid_y
```

说明：

- `basis_x`、`basis_y` 描述从视觉坐标指回逻辑正方向的基向量；
- 当前正交表现可使用 `(-40, 0)` 和 `(0, -40)`；
- 近俯视／伪等距可使用两个非正交基；
- basis 行列式接近零时拒绝正反转换；
- Camera2D、zoom、Viewport 和鼠标屏幕坐标位于后续输入／表现层；
- 逻辑记录不得保存投影后的像素位置。

默认吸附策略以单元格中心为锚点：

```text
cell_anchor = (0.5, 0.5)
cell = round(continuous_grid_position - cell_anchor)
```

## 6. 道路 draft

P1-F1A 只生成和查询临时道路 draft，不提交建设。

固定规则：

- 相邻路径只能四方向移动；
- 两个采样格之间使用 Manhattan 插值；
- 固定轴优先为 `X → Y`；
- 相同输入必须产生相同 ordered path；
- `ordered_cells` 保留真实拖动和回拖顺序；
- 相邻采样段共享的端点不重复写入；
- `unique_cells` 按首次出现顺序去重；
- 成本、占用校验和未来批量事务只使用 `unique_cells`。

道路 mask：

```text
N = 1
E = 2
S = 4
W = 8
```

mask、直路、弯道、丁字和十字只属于派生表现，不保存为权威状态。

道路 BFS：

- 输入只包含道路格集合和根格集合；
- 只检查四邻接；
- 不读取场景节点；
- 环路不得重复计数；
- 不存在于道路集合中的根格不得生成虚假连通。

## 7. 覆盖、边界与占用查询

空间内核提供：

- footprint 的稳定行优先 covered cells；
- footprint 是否完整位于 `Rect2i` 地图边界；
- covered cells 与只读 occupied dictionary 的冲突集合。

它不判断：

- UI 遮挡；
- 资源是否足够；
- 战争状态；
- 是否正在施工；
- 未接道路；
- 是否应创建或删除节点。

查询不得修改输入的 occupancy、道路或根格集合。

## 8. P1-F1A 文件和 API

### `CityGridRules`

- `get_rotated_footprint`
- `resolve_entrance`
- `get_covered_cells`
- `is_footprint_within_bounds`
- `find_occupied_conflicts`
- `get_road_mask`
- `get_connected_road_cells`

### `CityProjection`

- `is_basis_invertible`
- `grid_to_visual`
- `visual_to_grid`
- `visual_to_nearest_cell`

### `CityRoadDraft`

- `interpolate_segment`
- `build_ordered_cells`
- `get_unique_cells`
- `build_draft`

三个 helper 均继承 `RefCounted`，无成员状态，不访问 Node、UI、资源经济或 `ConstructionController`。

## 9. P1-F1A 自动验收

- 四种 footprint、入口格和入口朝向旋转；
- 非法 footprint、入口、方向和 orientation；
- 正交及近俯视投影 round-trip；
- 奇异 basis 拒绝；
- 快速拖动、反向拖动、回拖和重复采样；
- 路径确定性；
- 16 种道路 mask；
- 单路、分叉、环路、断开和重连 BFS；
- 多格建筑覆盖、边界和占用冲突；
- helper 无 Node 或权威状态副作用；
- 原有 P0／P1／C0 smoke 全部通过；
- 主场景、C0、editor scan 和资源引用无错误；
- `project.godot`、正式场景和控制器保持不变。

## 10. 后续门禁

P1-F1B 才允许研究：

- `ConstructionController` 的窄查询／提交接口；
- 原子道路批量事务；
- 权威提交后由表现层重建节点；
- 旧单格道路路径与新 draft 的兼容。

若 P1-F1B 需要迁移权威字段、复制城市状态、修改存档 schema 或让新旧地图同时可写，必须停止并重新进入用户门禁。

`CitySandboxV0.tscn`、snapshot、FileAccess 和正式保存／载入均不属于 P1-F1A。

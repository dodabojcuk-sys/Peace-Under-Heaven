# P1 城市时间与地图安全区修正收尾

日期：2026-07-26

状态：`READY_FOR_USER_GATE`

## 1. 范围与初始状态

本轮从 `main` 的 `9bdfdffcd799a0fac0c92f12c123035cd5e540a0` 开始；工作区初始 clean，`origin/main` 为 `b3114c24b3809fe1157a73905279a6543ee74e2e`，本地 ahead 11、behind 0。

只修正：

- 玩家可见的手动结束日；
- 城市自动时间与明确暂停；
- 左侧城市栏的展开／收起；
- Camera2D 地图安全矩形；
- 对应自动回归和文档。

没有恢复 P1-E/P1-F，没有修改 C0 战斗演算、数值、正式军令台、存档、placement、地图内容或美术。

## 2. 时间规则

`ConstructionController` 继续是日期、资源、威胁和城市运行态的唯一权威所有者。

- 正式 UI 已删除 `EndDayButton`，不存在玩家手动跨日入口。
- 顶栏同一位置改为 `PauseButton`；运行时显示“暂停”，暂停时显示“继续”。
- 城市默认运行。
- 暂停只冻结城市模拟增量；地图导航、建筑选择、建设规划、侧栏和普通 UI 不冻结。
- 面板、选择、侧栏和窗口焦点不会改变暂停状态。
- 恢复后沿用已有 `day_elapsed_seconds`。
- 日界线仍只有 `_advance_day_boundary()` 一条结算路径。
- 测试通过 `advance_city_time_for_test()` 或 `advance_one_day_for_test()` 驱动，不恢复玩家按钮。
- `SECONDS_PER_DAY = 60.0` 是唯一集中参数。它是保守的 V0 规划节奏，等待真人体验调整，不是最终平衡。
- 累计只使用 Godot 受控 `delta`；不使用系统墙钟，不离线追赶，不因重新聚焦补算。
- 大增量按顺序跨越各日界线；第 12 日停止，不重复生产、威胁或研究。

进入正式战斗后的跨场景城市时间策略仍未决定。本轮没有通过隐式暂停或第二套时钟替代该门禁。

## 3. 左侧栏与安全矩形

- `CityBar` 保持原 `152 x 600` 内容和位置，但默认隐藏。
- `CityBarToggle` 始终可见；收起时位于左上地图边缘，展开时移到栏外侧。
- 隐藏的 `CityBar` 子控件不再参与输入或建造遮挡。
- 展开／收起只调整 UI 可见性和 Camera2D 构图，不改建筑世界坐标、placement 或占用格。
- 安全矩形由当前视口减去顶部栏，并在侧栏展开时再减去左侧 `152 px`。
- 相机初始化、世界矩形聚焦、可选 zoom-fit 和 clamp 都使用同一安全矩形。
- 侧栏状态切换时保留旧安全区中心的世界点，避免建筑被新展开栏永久压住。
- 自动测试逐一聚焦六个固定建筑，确认它们都能完整进入展开侧栏后的安全矩形。

右侧详情面板仍是按需显示的 `280 x 360` 浮层，已有动态输入和建造遮挡；它不是永久侧栏，因此本轮未重排或重做。

## 4. 原子提交

- R1 `60cfd56`：自动时间、暂停状态和顶部控件。
- R2 `2f47bc0`：侧栏展开／收起和 Camera2D 安全矩形。
- R3：本文件、状态／设计文档、受控测试接口和全部回归测试更新。

所有提交只保留本地，不 push、不 tag、不创建 PR 或 Release。

## 5. 自动验证

Godot 版本：`4.5.1.stable.official.f62fdbde1`

完整回归：

- 14 个 `tests/run_*_smoke.gd` runner 全部 exit 0；
- 814 条 `PASS`，0 条失败；
- 覆盖 P0 建造／选择／生命周期、P1-A～P1-D、C0-A～C0-E 和本轮城市时间／安全区；
- 主场景 headless 启动通过；
- headless editor scan 无脚本、场景或资源错误；
- 节点唯一性：一个 `MapWorld`、一个 `Camera2D`、一个 `ConstructionController`、一个正式 `_input` 所有者；
- `git diff --check` 通过。

新增时间／安全区 runner 覆盖：

- 默认运行；
- 自动跨日；
- 暂停保留进度；
- 暂停期间导航、选择和建设入口；
- 普通面板与焦点不自动暂停；
- 不同 delta 分片结果一致；
- 大增量和第 5／8／10／12 日边界；
- 无玩家 `EndDayButton`；
- 侧栏默认收起、展开／收起、输入恢复和 placement 不变；
- 全部固定建筑可进入安全区；
- UI 不穿透；
- 地图、相机、控制器和输入所有者唯一。

## 6. 非 headless 运行

使用正式 1152 x 648 城市场景执行两次 Godot 4.5.1 非 headless smoke：

1. 录制运行、暂停、侧栏展开、侧栏收起和跨日后的可见序列。结果为 `day=2 paused=false sidebar=false`。
2. 不调用受控跨日接口，实际等待一个完整日长。结果：

```text
NON_HEADLESS_REAL_DAY PASS elapsed_ms=60892 day=2 food=76 tech=1
```

可见证据位于本机临时目录：

- `/tmp/txwzs-city-time-evidence/01-time-running.jpg`
- `/tmp/txwzs-city-time-evidence/02-time-paused.jpg`
- `/tmp/txwzs-city-time-evidence/03-sidebar-expanded.jpg`
- `/tmp/txwzs-city-time-evidence/04-sidebar-collapsed.jpg`
- `/tmp/txwzs-city-time-evidence/05-after-day-boundary.jpg`

这些截图只证明可见状态。脚本化 UI 状态和自动输入不替代用户实体体验。

## 7. 用户体验门禁

用户仍需实际确认：

1. 60 秒日长是否给规划留下合适时间；
2. 暂停／继续的状态是否一眼可懂，恢复是否符合预期；
3. 暂停时真实鼠标拖拽、缩放、建筑选择和建造是否保持顺畅；
4. 左栏展开／收起是否好用，收起后是否不再挡地图点击；
5. 展开栏时真实拖拽能否把所有需要操作的建筑带入无遮挡区域；
6. 右侧详情面板是否仍无同类永久遮挡问题。

本轮通过不等于 C0 真人体验通过，也不恢复 P1-E/P1-F。

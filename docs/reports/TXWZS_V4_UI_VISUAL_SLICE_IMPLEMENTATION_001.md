# TXWZS V4 UI Visual Slice Implementation 001

## Verdict

`V4_UI_VISUAL_SLICE_IMPLEMENTED_READY_FOR_INDEPENDENT_REVIEW`

本轮只完成黑石堡视觉切片实现、自验与独立复审交接。没有标记
`T-V4-003` PASS，没有标记 V4 UI VERIFIED，没有启动 V5，也没有执行
git add、commit、push、发布或部署。

## 目标、范围与非目标

目标是把已冻结的 Figma 基线映射到现有黑石堡数据模型，完整覆盖：

1. 默认／待命令；
2. 路线选择与调遣比例；
3. 行军进度；
4. 行军中的并发命令拦截；
5. 撤退确认；
6. 胜利结算；
7. 失败结算；
8. 返回城市与重新进入后的状态清理。

本轮只修改：

- `scenes/blackstone_expedition_mvp.tscn`
- `scripts/mvp/blackstone_expedition_mvp.gd`
- `tests/run_blackstone_playable_mvp_smoke.gd`
- 本报告

本轮没有修改 C0 结算、`BattleSession`、`BattleResult`、coordinator、城市时间、
战斗数值、路线规则、存档、主控计划、既有审查报告、Figma 或 V5。

## 开始与结束 Git 身份

证据目录：
`/tmp/txwzs-v4-ui-resume.XJ9jZq`

| 项目 | 开始 | 结束 |
| --- | --- | --- |
| branch / HEAD | `main` / `64f37bda130397f08cdd012609dc2d3a5f5c6b99` | 不变 |
| upstream | `origin/main` | 不变 |
| ahead / behind | `29 / 0` | 不变 |
| staged | `0` | `0` |
| Godot | `4.5.1.stable.official.f62fdbde1` | 不变 |
| 正式入口 | `./RUN_CURRENT_TXWZS.command` | 不变 |

开始时三个 V4 文件仍与暂停前记录一致：

| 文件 | 开始 SHA-256 | 结束 SHA-256 |
| --- | --- | --- |
| scene | `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957` | `7cea7eb63438cf6664034b1cf6e8f75597de8bc803590e7eb40313222cf2b319` |
| script | `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393` | `4fd566ae565af2074974daa42b009edc307feee2bcc6fc16220f7d363529e90e` |
| smoke | `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac` | `ac2bb4b68b201b14d19ebad79f56b59196a6ef919e3f9ee0f01dfaba23e251ac` |

开始快照保存了完整 status、tracked/cached diff、untracked manifest、三个 V4
源文件副本、S1A.2 八个保护文件哈希和既有报告哈希。没有执行 reset、
checkout、clean 或 stash。

## 暂停 Gate 的解除

暂停前的结果来源诊断已经判定为
`D. NO_REPRODUCTION_GATE_MISSCOPED`：黑石堡局部只有
`NONE / VICTORY / DEFEAT`，没有 `RESOLVED_RETREAT`，Figma 证据中的
“已撤退＋胜利奖励”来自正式 C0 的跨模块展示语境，不是黑石堡模型层双结果。

正式 C0 的 `BattleSession` 终局权威、coordinator 所有权与城市时间结算随后已经
完成 Repair 002–004，并由
`TXWZS_V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_INDEPENDENT_REVIEW_004`
独立接受。因此本轮恢复黑石堡切片时，不再触碰 C0。

黑石堡仍遵守原数据真值：

- `outcome` 是胜利／失败唯一业务真值；
- `ResultPanel.visible`、`Label.text` 和节点存在性都不参与 outcome 合法性；
- 主动撤退只发送返回意图，不伪造胜利、失败或奖励；
- 胜利来源文字只说明城市权威负责应用奖励，不硬编码奖励数值；
- 失败明确无胜利奖励；
- `_garrisons` 继续是唯一驻军位置真值；
- 路线继续显式携带 `source_node_id`；
- 没有恢复 `current_node_id` 或隐式唯一我军位置。

## Figma 只读基线与 Godot 映射

Figma 文件：
`YbPJuQhDwD9O5qrsSSgxjV`。本轮只读读取了：

- `01 · Evidence`
- `02 · Foundations`
- `03 · Components`
- `04 · Screens & States`
- `05 · Decisions & Gate`
- 变量、文字层级、效果样式与组件状态

实际读取的关键 Screens & States 节点：

- Order Pending `21:34`
- Marching `21:83`
- Victory Result `21:133`
- Confirm modal `16:6`
- Failure modal `16:34`

| Figma 合同 | 实际值 | Godot 映射 |
| --- | --- | --- |
| Canvas / Surface / Raised | `#e9e1cb` / `#f6f0e0` / `#fff9e9` | 根背景、任务面板／战区面板、调遣／行军／结果卡 |
| Strong / Primary | `#282a25` / `#566243` | 顶栏、主要动作、路线强调 |
| Success / Warning / Danger / Info | `#52725a` / `#b18a45` / `#a34a3f` / `#4f6b72` | 完成、待确认、失败／撤退、行军状态 |
| Overlay | `#1c1e1bb8`，72% | `ModalOverlay` 全屏遮罩，`MOUSE_FILTER_STOP` |
| Spacing | 4 / 8 / 12 / 16 / 24 / 32 | 面板内边距、状态区、动作区、场景分栏 |
| Radius | 4 / 8 / 12 / full | 标签、按钮、面板、圆形节点 |
| Type hierarchy | 24 / 18 / 15 / 14 / 12 | 标题、弹窗标题、正文、按钮、说明 |
| Button states | Primary / Secondary / Danger / Disabled | 调遣确认、比例、撤退、行军期禁用 |
| Progress | Info track / fill / percent | `MarchInfo/ProgressBar` |
| Result Modal | 标题、正文、来源状态、动作区分离 | 统一 `ResultPanel`，撤退／胜利／失败三种投影 |

仓库没有合法入库的 Noto Sans 字体文件。本轮没有下载字体；运行时优先请求
`Noto Sans`，再回退到 macOS 中文系统字体。Figma 的双层阴影由 Godot
`StyleBoxFlat` 的单层阴影近似；色彩、层级、实底和遮罩合同保持一致。

## 实现结果

### 场景与视觉层级

- 1152×648 基准视口使用 64px 顶栏、248px 任务面板、844px 战区面板。
- 四个真实游戏节点保留：我方营地、山路援军、黑石前哨、黑石堡。
- 原灰盒块状按钮改为语义化圆形节点、驻军标签、路线和柔和地形层。
- 右下使用统一 796×110 raised 面板承载路线、实际兵数提示、四个比例和确认动作。
- 行军态使用同一位置的进度面板，展示 source、target、人数、进度、ETA 和并发拦截标签。

### 弹窗与输入

- 撤退确认、胜利和失败共用 72% 全屏遮罩与不透明 440×272 卡片。
- 标题、正文、结果来源和动作区使用固定分区，正文不会进入按钮区。
- 遮罩层 z-index 高于战区与底部操作，鼠标过滤为 STOP。
- 弹窗打开时，真实 Viewport 左键不能触发底层节点或调遣按钮。
- Esc、关闭、取消和右键收口到既有取消意图；关闭后输入恢复。
- 同一个输入不会同时由弹窗与底层路线处理。

### 状态与清理

- 撤退确认不创建 outcome、不修改驻军、不创建行军、不发奖。
- 行军中第二条命令被拒绝，原行军继续。
- 胜利、失败与撤退确认三种投影互斥。
- 结果弹窗不产生第二次抵达或第二次结算。
- 返回城市后重新进入，驻军、pending、行军、modal 和 outcome 均恢复 V4 声明的初始状态。

## 本轮实现专属 diff

专属 diff 以本轮开始副本为左侧，不以 Git HEAD 为左侧，避免把用户原有 dirty
V4 内容混入本轮：

```text
git diff --no-index -- /tmp/txwzs-v4-ui-resume.XJ9jZq/pre/<file> <current-file>
```

| 文件 | 新增 | 删除 |
| --- | ---: | ---: |
| scene | 480 | 129 |
| script | 663 | 39 |
| smoke | 178 | 17 |
| 合计 | 1321 | 185 |

## 自动测试

所有日志位于：
`/tmp/txwzs-v4-ui-resume.XJ9jZq`

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| 修改前 Blackstone smoke | exit 0；126 条明确断言 | `20_baseline_blackstone.log` |
| 修改后 Blackstone smoke | exit 0；139 条明确断言＋1 summary | `30_blackstone_after.log` |
| Git tracked smoke | 27/27 runner；1504 PASS | `31_tracked_regression.tsv`、`tracked-*.log` |
| 当前工作树全部 smoke | 29/29 runner；1675 PASS | `32_all_present_regression.tsv`、`all-*.log` |
| Godot headless editor scan | exit 0 | `40_editor_scan.log` |
| 正式主场景 | exit 0 | `41_main_scene.log` |
| 黑石堡场景 | exit 0 | `42_blackstone_scene.log` |
| C0 场景 | exit 0 | `43_c0_scene.log` |
| 资源路径 | 45 引用；0 缺失 | `44_resource_refs.txt`、`45_missing_resources.txt` |
| UID | 65 个值；0 重复 | `46_uid_values.tsv`、`47_duplicate_uids.txt` |
| `git diff --check` | exit 0 | `48_git_diff_check.log` |
| 错误签名扫描 | 0 | `49_error_signatures.txt` |

错误签名包括：
`FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR`。

新增确定性合同覆盖：

- 1152×648 所有关键控件在视口内，无文字裁切；
- modal 正文区、来源区和动作区不重叠；
- 遮罩在底层 UI 之上并拦截鼠标；
- 关闭 modal 后输入恢复；
- 胜利、失败、撤退确认展示互斥；
- `visible` 不参与 outcome 合法性；
- 比例按钮右键取消继续通过真实 Viewport/SceneTree 分发；
- modal 打开时真实 Viewport 左键不能误触底层；
- 结果 modal 不引发重复抵达或重复结算。

## 正式窗口验证

正式入口：

```text
./RUN_CURRENT_TXWZS.command
```

实测身份：

| 项目 | 值 |
| --- | --- |
| 新 PID | `31093` |
| 窗口标题 | `天下无战事 · CITY · main@64f37bd · DEBUG · DIRTY` |
| Godot | `4.5.1.stable.official.f62fdbde1` |
| branch / HEAD | `main` / `64f37bd` |
| runtime log | `/tmp/txwzs-runtime-52e107a4de6701b4/current.log` |
| launcher log | `/tmp/txwzs-v4-ui-resume.XJ9jZq/50_formal_launcher.log` |

真实规则流程与截图：

| 状态 | 真实操作与结论 | 截图 |
| --- | --- | --- |
| 默认 | 从 CITY 正式入口进入；驻军 10，未创建命令 | `gui-01-default.jpg` |
| 路线／比例 | 营地拖到援军；显示 25/50/75/全部、实际人数提示 | `gui-02-dispatch.jpg` |
| 行军 | 50% 派出 5；进度、ETA、源和目标可见 | `gui-03-marching.jpg` |
| 并发拦截 | 行军中点击另一节点；原行军继续，显示阻止标签 | `gui-04-concurrency-blocked.jpg` |
| 撤退确认 | 打开统一遮罩；无背景穿透、重叠或误触 | `gui-05-retreat-confirm.jpg` |
| 失败 | 营地全部进攻前哨，再以幸存 5 进攻守军 8；真实失败 | `gui-06-failure.jpg` |
| 返回 | 确认撤退返回 CITY；没有结果或奖励投影 | `gui-07-return-city.jpg` |
| 重新进入 | 初始驻军、节点、pending、modal、outcome 全部重置 | `gui-08-reenter-reset.jpg` |
| 胜利 | 营地→援军→前哨→黑石堡；真实胜利，幸存 3 | `gui-09-victory.jpg` |

截图绝对目录：
`/tmp/txwzs-v4-ui-resume.XJ9jZq`

逐张人工检查结果：1152×648 下没有文字重叠、裁切、背景文字穿透或遮罩漏区；
按钮禁用态、驻军来源、路线层级、进度、结果来源与关闭后的输入恢复均符合合同。

项目没有声明全局 1280×720 拉伸策略；本轮没有为了补充分辨率 smoke 修改全局
窗口配置。1280×720 作为独立审查可选项，不影响 1152×648 基准结论。

## Figma 与 Godot 对照联系

| Figma 参考 | Godot 实现 | 人工结构结论 |
| --- | --- | --- |
| Order Pending `21:34` | `DispatchBar` | 路线摘要、比例、主动作层级一致 |
| Marching `21:83` | `MarchInfo` + `ProgressBar` | 行军成为视觉焦点，并发阻止不替换原进度 |
| Confirm modal `16:6` | retreat `ResultPanel` | 72% 遮罩、实底、四区分离、Danger 动作 |
| Victory Result `21:133` | victory `ResultPanel` | Success 状态、canonical 来源、返回动作 |
| Failure modal `16:34` | failure `ResultPanel` | Danger 状态、无胜利奖励、返回动作 |

不使用像素相似度替代结构检查。Godot 保留四个真实节点，Figma Screen 只是三节点
代表性构图；这是数据合同优先下的有意差异。

## 城市时间合同

正式 C0 城市时间已在 Repair 004 链路中独立验证。本轮黑石堡视觉切片不新增、
伪造或推测 mission duration，不修改城市时间、资源生产或结算事务。任务面板只展示
当前已锁定的语义：“战区停留期间城市暂停，结算只由真实结果触发”；不会把 UI
动画秒数当成城市领域时间。

## 已知偏差与未验证项

- 字体使用系统回退，具体栅格化可能与 Figma 的 Noto Sans 有平台差异。
- Godot `StyleBoxFlat` 以单层阴影近似 Figma 双层阴影。
- 底部面板为 796×110，而参考组件为 796×94；增加高度用于保留四个既有比例、
  关闭和确认动作，并确保 1152×648 下不重叠。
- 没有补做 1280×720 正式窗口截图。
- 本轮只做实现者自验；尚未由新线程完成独立视觉／代码复审。

## 回滚方式

只恢复本轮开始副本，不删除、不 reset、不覆盖用户此前 dirty 内容：

```text
/tmp/txwzs-v4-ui-resume.XJ9jZq/pre/blackstone_expedition_mvp.tscn
/tmp/txwzs-v4-ui-resume.XJ9jZq/pre/blackstone_expedition_mvp.gd
/tmp/txwzs-v4-ui-resume.XJ9jZq/pre/run_blackstone_playable_mvp_smoke.gd
/tmp/txwzs-v4-ui-resume.XJ9jZq/pre/TXWZS_V4_UI_VISUAL_SLICE_IMPLEMENTATION_001.md
```

回滚时必须逐文件比较并仅恢复上述四个目标；不得清理工作树或删除其他 untracked
文件。

## 独立审查重点

1. 使用正式入口重走九张截图对应的真实规则流程；
2. 核对 1152×648 的文字裁切、遮罩覆盖、输入拦截与关闭恢复；
3. 确认主动撤退不创建 outcome 或奖励；
4. 确认胜利／失败只来自 canonical outcome，`visible` 不参与业务真值；
5. 确认比例右键、空白右键、Esc、关闭按钮仍只取消当前意图；
6. 核对 `_garrisons` 与显式 `source_node_id` 没有回退；
7. 独立重跑 Blackstone、tracked 与 all-present smoke；
8. 确认 C0、BattleSession、coordinator、数值、存档、V5 和状态文件未被本轮修改。

## 结束状态

`V4_UI_VISUAL_SLICE_IMPLEMENTED_READY_FOR_INDEPENDENT_REVIEW`

`T-V4-003` 仍为 NOT PASS；V4 UI 仍未独立验证；V5 继续 FROZEN。

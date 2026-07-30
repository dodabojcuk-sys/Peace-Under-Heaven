# TXWZS V4 UI Visual Slice Repair 001

## Verdict

`V4_UI_VISUAL_SLICE_REPAIR_001_READY_FOR_INDEPENDENT_REVIEW`

本轮仅修复黑石堡 1152×648 路线与目标节点文字的几何冲突，并新增相应合同测试。
`T-V4-003` 仍为 `NOT PASS`，V5 仍为 `FROZEN`。

## 输入与范围

委派输入接受：
`V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_001_REPAIR_REQUIRED`。

该委派明确了复现路径：`我方营地 → 山路援军` 的默认／调遣高亮路线会压过
“山路援军”标题与说明。指定的独立复审报告路径在当前共享工作树中不存在；本轮没有
重建、修改或伪造该报告，而是以委派中给出的 verdict 和缺陷描述作为修复输入。

允许且实际修改的生产／测试文件：

- `scenes/blackstone_expedition_mvp.tscn`
- `scripts/mvp/blackstone_expedition_mvp.gd`
- `tests/run_blackstone_playable_mvp_smoke.gd`

新增文件仅为本报告。未修改 C0、`BattleSession`、coordinator、`BattleResult`、
数值、存档、状态文件、CURRENT_STATE、Gate、主控计划或 V5。

## 修复内容

### 路线投影

- 静态路线与调遣高亮路线不再以整个 Button 的中心作为视觉端点。
- 先以语义节点 Marker 作为路线源点；如果从该方向靠近目标 Marker 会穿过目标标题／
  说明的保护区，则路线在扩展后的信息区边界前结束。
- 信息区保护范围包含标题、说明、路线半宽和 8px 额外净空；这不是通过降低透明度
  掩盖问题。
- `CommandLine` 与箭头恢复到节点文字下方的同层绘制顺序，箭头由 22px 缩至 12px，
  仍保留方向语义但不会伸入文字区。
- 行军数据的 `source_position`、`target_position`、时长、驻军、路线关系和结算逻辑
  保持原状；改变的是 UI 投影端点，而非领域路线。

### 几何合同

Blackstone smoke 新增 11 条断言：

- 默认态四条路线分别不与各自目标的标题 rect 和说明 rect 相交（8 条）；
- 调遣态“营地 → 援军”高亮路线不与目标标题／说明相交（2 条）；
- 高亮箭头的全局 bounding rect 不与目标标题／说明相交（1 条）。

所有线段检查都使用实际全局坐标、实际 Line2D 宽度扩张后的 rect 和边界线相交计算，
并非只比较节点 ID 或颜色。

## 视觉证据

证据目录：`/tmp/txwzs-v4-ui-repair-001.dsbPhL`

| 画面 | 路径 | 检查结论 |
| --- | --- | --- |
| 修复前默认态（实施轮留存） | `/tmp/txwzs-v4-ui-resume.XJ9jZq/visual-default.png` | 营地→援军路线穿过目标文字区，是本轮修复对象。 |
| 修复后默认态 | `/tmp/txwzs-v4-ui-repair-001.dsbPhL/default-final.png` | 路线在文字保护区外结束；标题、说明完整可读。 |
| 修复后调遣态 | `/tmp/txwzs-v4-ui-repair-001.dsbPhL/dispatch-final.png` | 绿色高亮路线与短箭头均停在文字区外；调遣条、状态标签、Modal 结构未改变。 |

后两张截图由最终代码从正式 CITY 场景 `blank_map.tscn` 的军令台入口打开黑石堡后生成，
基准为 1152×648、Metal 渲染。人工复核确认默认态和调遣态均不存在穿字、贴字或由
路线抢夺文字层级的情况。

## 验证

Godot：`4.5.1.stable.official.f62fdbde1`。

| 命令／检查 | 退出码 | 结果 |
| --- | ---: | --- |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_blackstone_playable_mvp_smoke.gd` | 0 | 150 条明确断言；151 条 PASS 行（含 summary）。 |
| 全部 Git tracked `tests/run_*_smoke.gd` | 0 | 27/27 runner；1515 条 PASS 行。 |
| 当前工作树全部 `tests/run_*_smoke.gd` | 0 | 29/29 runner；1686 条 PASS 行。 |
| `Godot --headless --path . --scene res://scenes/blank_map.tscn --quit-after 60` | 0 | 主场景启动。 |
| `Godot --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 60` | 0 | 黑石堡场景启动。 |
| `Godot --headless --path . --editor --quit` | 0 | 最终 editor scan。 |
| `git diff --check` | 0 | 无空白错误。 |

专项基线为 139 条明确断言；本轮没有删除既有断言，新增 11 条后为 150 条。
此前报告口径中的 tracked `1504`／all-present `1675` PASS 行，本轮分别增加 11 至
`1515`／`1686`。

最终日志中的 `FAIL:`、`ERROR:`、`WARNING:`、`Parse Error:` 和 `SCRIPT ERROR:`
前缀扫描为 0；完整 runner 日志、场景日志和统计表均在上述证据目录。

正式入口 `./RUN_CURRENT_TXWZS.command` 已重新启动 CITY，运行身份为
`main@64f37bd · DEBUG · DIRTY`，PID `38893`，日志为
`/tmp/txwzs-runtime-52e107a4de6701b4/current.log`。

## 保持不变的合同

- Figma 的中立／警告／危险／成功色语义、72% 遮罩、Result Modal 和底部调遣区未改；
- 默认、调遣、行军、并发拦截、撤退、胜利、失败、返回与重进状态行为未改；
- 路线仍表示同一对节点关系，未修改可达性、兵力比例、旅行时长或战斗结果；
- 不以 `visible` 作为业务真值，不触及 city-time 或 C0 canonical settlement。

## 独立复审重点

1. 复跑 1152×648 默认与“营地 → 山路援军”调遣态，检查路线在文字保护区外结束；
2. 复核高亮箭头、路径层级和路线中断是否仍清楚表达可达关系；
3. 复跑 Blackstone、tracked、all-present 回归，确认 150 条专项明确断言、27/27、
   29/29 和 1515／1686 PASS 行；
4. 确认本轮 diff 只涉及黑石堡场景、脚本、测试与本报告；
5. 确认不因此推进 `T-V4-003` 或 V5。

## 结束状态

`V4_UI_VISUAL_SLICE_REPAIR_001_READY_FOR_INDEPENDENT_REVIEW`

未执行 git add、commit、push 或部署。

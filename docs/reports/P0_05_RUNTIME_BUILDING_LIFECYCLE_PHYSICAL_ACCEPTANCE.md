# P0-05 运行时建筑生命周期与安全移除实体验收

## 功能范围

本报告封存 `P0-05_RUNTIME_BUILDING_LIFECYCLE_AND_SAFE_REMOVAL`：

```text
运行时建筑权威记录
→ 选择后请求移除
→ 取消或确认
→ 精确释放目标占用格
→ 原位置通过普通建造流程重新使用
```

实现建立在已接受的地图导航、最小网格建造以及建筑选择与详情面板基线上，没有引入第二个地图、相机、输入入口、建筑记录所有者或 UI Shell。

## 自动验证

2026-07-25 使用 Godot 4.5.1 重新运行：

1. Headless editor scan。
2. 主场景 headless smoke。
3. `run_construction_placement_smoke.gd`。
4. `run_building_selection_smoke.gd`。
5. `run_building_lifecycle_smoke.gd`。
6. 资源引用检查。
7. MapWorld、Camera2D、UI Shell 唯一性检查。
8. `_input` 唯一性检查。
9. `git diff --check`。

自动验证用于检查建筑记录、节点、占用格、选择状态、输入分流和回归；它不替代用户的实体鼠标测试。

## 用户实体鼠标测试

测试日期：2026-07-25

用户完成 `P0_05_RUNTIME_BUILDING_LIFECYCLE_DEFERRED_PHYSICAL_TEST.md` 中列出的 16 项测试，反馈：

> 上面的我都测试了，暂时没发现什么问题。

因此记录：

- physical tests：16 / 16 completed；
- 用户未报告失败项；
- 不补写用户未提供的逐项观察细节。

## 已接受行为

- 运行时测试建筑可进入移除确认。
- 取消、`Esc`、关闭、空白单击、切换建筑和进入建造不会误删建筑。
- 确认移除只删除目标建筑。
- 其他建筑及其占用格保持不变。
- 删除后选择、描边和详情面板清除。
- 原位置可以通过普通建造流程重新放置。
- 重建建筑可以重新选择。
- 确认面板不会让鼠标或滚轮输入穿透地图。
- 地图导航、缩放、建造、选择和重复占用拒绝没有观察到回归。

以上为用户完成整组测试后的总体接受结论，不代表用户逐条提供了独立文字说明。

## 数据与生命周期边界

- `ConstructionController` 是运行时建筑记录、placement ID、放置顺序和占用格的唯一权威所有者。
- 节点 metadata 只保留 `placement_id`。
- 选择状态只保留 `selected_placement_id`。
- placement ID 删除后不复用。
- 移除和意外离树只释放仍属于目标 placement ID 的占用格。

## 未进入的系统

本阶段没有实现：

- 建筑移动、连续移除、批量操作或 undo/redo；
- 资源返还、建造成本、生产、升级或道路规则；
- 正式建筑目录、军令台功能、存档或多城市；
- 正式视觉与美术。

## 回滚方式

P0-05 实现、测试、状态和验收记录形成一个原子提交。后续若出现回归，应审查该提交并使用 `git revert`，不需要重写历史或迁移存档。

## Verdict

`ACCEPTED`

# TXWZS V4 UI Visual Slice Independent Review 002

## Verdict

`V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_002_ACCEPTED`

本复审只验证 Repair 001 的 P1 路线压字缺陷。1152×648 正式渲染中，
“我方营地 → 山路援军”的默认路线和调遣高亮路线均未穿过、压住或紧贴
“山路援军”的标题与说明文字；未发现由此修复引入的本范围内视觉或功能回退。

这不是 T-V4-003 的最终 Gate，也不推进 V5。

## 基线、输入与范围

- 隔离 worktree：`/tmp/txwzs-v4-ui-independent-review-002`；从候选工作树
  `main@64f37bd` 的完整 dirty snapshot 创建，未修改候选实现、测试或状态文件。
- 候选三个 UI 文件 SHA-256：
  - `scenes/blackstone_expedition_mvp.tscn`：`1100bf7cd58bfe482a3adbdbedd761eaeb490ea6e86848335d83dc1497446c2b`
  - `scripts/mvp/blackstone_expedition_mvp.gd`：`5b651e0381fd7c315ef388498aa46ce7b837b10f91ddfb5963edb8b7411ed65f`
  - `tests/run_blackstone_playable_mvp_smoke.gd`：`737d8c9384900bc62993e459d4e68d809e0ed262bf1c89ea534ab2a733062806`
- Git 对 `HEAD` 的总 dirty diff 还含既有 C0 文件；其不属于 Repair 001。Repair 001
  报告所述的本轮生产/测试范围是上述黑石堡 scene、script、smoke 三文件。候选中没有
  可供比对的 Repair-start snapshot，因此未把总 dirty diff 误判为 Repair 001 的新增范围。
- 委派指定的 `TXWZS_V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_001.md` 在候选工作树缺失。
  未补写或修改它；本复审按委派中的 P1 定义及 Repair 001 报告继续。

代码复核确认修复是显示投影：`_get_route_target_projection_local()` 以目标标题和说明
合并 rect、路线半宽及 8px 净空计算终点；静态和高亮 CommandLine 共用该投影。它没有
修改 route id、source/target node、驻军、时长、可达性或结算路径。

## 独立正式截图与人工目视

截图在隔离 worktree 中通过正式路径重新生成，而非复用实现轮图片：

`blank_map.tscn → 军令台 → 出征黑石堡`，Metal 渲染，1152×648。

| 状态 | 新生成证据 | 目视结论 |
| --- | --- | --- |
| 默认态 | `/tmp/txwzs-v4-ui-independent-review-002-evidence/default-final.png` | 营地→援军静态路线止于文字区左下方；标题“山路援军”和说明“待接应 · +6”完整、无贴线。 |
| 调遣态 | `/tmp/txwzs-v4-ui-independent-review-002-evidence/dispatch-final.png` | 绿色高亮线和短箭头止于同一保护区外；调遣条不遮挡目标文字，路线仍清晰表达营地→援军。 |

两态均未见路线抢夺文本层级、穿字或影响阅读的近贴。

## 几何合同

独立执行 Blackstone smoke：exit `0`，`151` 条 `PASS` 行（`150` 条明确断言加 summary）。

- 默认态四条路线分别与目标标题 rect、说明 rect 不相交；
- 调遣态营地→援军 CommandLine 与标题 rect、说明 rect 不相交；
- 调遣高亮箭头 bounding rect 也与上述两个 rect 不相交。

Repair 001 的基线为 139 条明确断言，新增 11 条后为 150；本次没有删除旧断言，专项
PASS 行数为预期的 151，没有减少。

## 回归与错误扫描

Godot `4.5.1.stable.official.f62fdbde1`，全部在隔离 worktree 独立执行：

| 检查 | 结果 |
| --- | --- |
| Blackstone 专项 runner | exit 0；151 PASS 行 |
| Git tracked `tests/run_*_smoke.gd` | 27/27 runner；1515 PASS 行 |
| 当前 all-present `tests/run_*_smoke.gd` | 29/29 runner；1686 PASS 行 |
| 正式主场景 `blank_map.tscn` | exit 0 |
| 正式黑石堡场景 | exit 0 |
| Godot headless editor scan | exit 0 |
| `git diff --check` | exit 0 |
| `FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR` 扫描 | 0 命中 |

Blackstone runner覆盖默认、调遣、行军、并发拦截、撤退确认、失败、胜利、返回及重进；
全套 runner 均通过。结合 scene/script 复核，未见 Repair 001 改变 Figma 色彩语义、
Result Modal、72% 阻断遮罩，或以上状态的领域行为。

## 允许的后续声明与停止点

本 verdict 允许声明：

- `Blackstone visual slice: INDEPENDENTLY_VERIFIED`
- `V4 UI: VISUAL_SLICE_ACCEPTED`
- `T-V4-003: PENDING FINAL V4 GATE`
- `V5: FROZEN`

本轮不修改 `CURRENT_STATE`，不将 `T-V4-003` 标为 PASS，不启动 V5，不执行暂存、提交、
push 或发布；报告完成即停止。

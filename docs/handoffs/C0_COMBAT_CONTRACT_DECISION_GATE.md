# C0 COMBAT CONTRACT DECISION GATE

状态：`AWAITING USER DECISION`

## 结论

P1-A 至 P1-D 已形成战前建设与备战层，但当前仓库没有真实战场、胜负生成、幂等结算或返回城市契约。P1-E/F 继续暂停是正确门禁。

本轮提出：

- `docs/architecture/MINIMUM_REAL_COMBAT_CONTRACT_V0.md`
- `docs/design/FIRST_BATTLE_GRAYBOX_RULES_V0.md`
- `docs/testing/C0_COMBAT_CONTRACT_TEST_MATRIX.md`

它们没有把战备代理升级为战斗公式，也没有建立假攻击入口。

## 推荐主方案

```text
城市权威状态
→ 建立唯一兵力预留
→ 冻结 BattleRequest / 双方快照
→ 临时挂载两路线 BattleSession
→ 玩家给最多三支步兵小队下达 ADVANCE / HOLD / RETREAT
→ 固定 tick 真实产生伤亡和终局
→ 冻结 BattleResult
→ 用户确认结果
→ BattleResultApplier 幂等写回
→ 隔一帧恢复城市输入
```

关键边界：

- `ConstructionController` 仍是城市唯一权威写入者；
- `CombatTransactionCoordinator` 只拥有一个临时事务，不是第二套 `WorldState`；
- 战斗开始前的预留只减少可用兵力，不提前写伤亡；
- 战场不能写资源、日期、placement、首通或奖励；
- 胜利、失败、撤退都生成正式结果；
- 幸存兵力、伤亡、首通奖励和返回只应用一次；
- 结果浮层阻止鼠标和滚轮穿透；
- 当前无存档，C0 只承诺同一进程内原子性；跨进程恢复需要单独存档门禁。

## 与旧方案的分界

继续：

- 请求、临时会话、结果、确认、返回的事务序列；
- 预留与一次释放；
- 撤退／失败正式化；
- 结果和首通幂等；
- 临时战场不污染城市；
- 结算输入保护。

淘汰：

- 先算胜负再播放；
- 纯战力自动结算；
- 旧 `NationState v13` / Project Dawn 运行时结构；
- 逐单位 RTS；
- C0 内主动技能、工程师、复杂地形、装备和后续兵种。

## C0 实现允许范围

- 一个军令台出征入口；
- 一个事务协调器；
- 一个独立临时战场场景；
- 两条路线／两座门；
- 最多三个步兵小队；
- 前进、坚守、撤退；
- 现有三个将领的既有被动边界；
- 固定时间步；
- 胜利、失败、撤退结果；
- 兵力和首通幂等写回；
- 最小结果浮层；
- 契约、确定性、输入和回归测试。

不允许：

- 自动胜利、纯数值结算或只播放动画；
- 新资源、正式美术、Figma 重设计；
- 主动技能、工程师、复杂地形、装备、新兵种；
- 告示板、历战、多关卡编辑器；
- 存档迁移；
- P1-A 至 P1-D 的无关重构。

## 当前 P1-A～P1-D 可视化 smoke

2026-07-26 使用：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2 \
  --resolution 1152x648
```

实际启动 Godot 4.5.1 非 headless 进程。启动输出只有引擎版本和 Metal 设备信息，没有脚本、场景或资源错误。可见窗口中确认：

- 城市灰盒地图、固定建筑和军令台存在；
- 顶部日期／资源壳、左侧城市栏、小地图和右侧建造入口存在；
- 军令台没有攻击按钮或固定胜利入口。

桌面上已有一个此前启动、标题相同的 Godot 调试窗口，桌面自动化无法可靠区分截图来自旧实例还是本轮新实例。因此这次截图只作为城市表面的可视化 smoke；不声称日期、资源、威胁、征募、将领和科技控件都经过了实体点击，也不是完整玩法验收。上述逻辑继续由 P1-A～P1-D 自动 smoke 覆盖。

截图保存在仓库外：

`/tmp/TXWZS_C0_P1_AD_visual_smoke_2026-07-26.png`

## 待用户接受的校准点

规则主案使用：

- 0.25 秒固定 tick；
- 正门 80 距离 / 600 基础 HP / 40% 守军；
- 侧门 120 距离 / 360 基础 HP / 60% 守军；
- 工事每级为每座门增加 120 HP；
- `HOLD` 攻击 0.85、承伤 0.75；
- `RETREAT` 速度 1.25、承伤 1.15；
- 180 秒未突破判失败，幸存者返回。

首通奖励独立候选为木材 30、粮食 20；它仍是 `CANDIDATE_AWAITING_USER_CONFIRMATION`，当前没有写入权威内容定义。

## 下一步门禁

用户当前只需决定：

> 是否接受 `MINIMUM_REAL_COMBAT_CONTRACT_V0` 和 `FIRST_BATTLE_GRAYBOX_RULES_V0`（包括把木材 30、粮食 20 作为首轮可调首通奖励候选），授权进入 C0 灰盒实现？

接受后建议使用 Terra 高连续实现。实现完成并通过自动测试后，必须返回用户进行真实战场命令、节奏、可读性和结果理解的实体体验门禁。正式 UI 设计仍放在灰盒可玩之后。

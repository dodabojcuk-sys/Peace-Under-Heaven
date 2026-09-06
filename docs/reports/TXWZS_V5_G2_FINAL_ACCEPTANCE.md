# TXWZS V5-G2 Final Acceptance

## Verdict

`V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED`

V5-G2 的 stable-ID、原子写入、V1→V2 迁移、正式 disk/codec/store/restore、
cold restore 和 generation fallback 边界已经由 fresh reviewer 独立接受。

本 verdict 只接受 V5-G2 runtime。它不启动或接受 G3–G6、P6、P7、V6、
第二兵种、多 active 军队、敌方 AI、攻城或新的战斗来源。

## 绑定身份

| 字段 | 值 |
| --- | --- |
| Reviewer | `/root/v5_g2_boundary_fresh_independent_reviewer_003` |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| Original candidate | `cd7be2b4e65f453889c5f49a4922f788cca08a68` |
| First repair | `e2c1096f858d571d4621b93174d3848406b42ffa` |
| Repair review checkpoint | `5d6592431e6f5f1c1bd3ddad408db942613b7e4a` |
| Boundary repair | `fab962c0a84024e7034c32e9d5c39debc1659c5f` |
| Review report checkpoint | `4d0fbfc5aefe07509db115f8f4f68e22aeda8a98` |
| Acceptance checkpoint | `af244167f7b0a31f3de2cc34673faa953113b96b` |

祖先链：

```text
cd7be2b
→ e2c1096
→ 5d659243
→ fab962c
→ 4d0fbfc
→ af24416
```

每条相邻边及完整链的 `git merge-base --is-ancestor` 均已通过。

## Findings 与 repairs

| 阶段 | 结论 |
| --- | --- |
| Original candidate `cd7be2b` | 拒绝：checksum-valid snapshot 可把 Training/Army next sequence 回退到既有 stable ID 以下，冷恢复后会复用 ID |
| First repair `e2c1096` | 恢复校验拒绝不大于既有最大 ID 的 sequence，并加入永久 rollback 对抗断言 |
| Independent re-review at `5d659243` | 仍发现 string/float coercion、精确上限与 successor、Army pre-write exhaustion、合法 V1 空队列历史迁移四类边界 |
| Boundary repair `fab962c` | 在四文件内关闭 type/range/sentinel/pre-write/V1 migration 边界并扩充永久 P5 runner |
| Fresh review at `4d0fbfc` | 无新实质缺陷，独立通过 |
| Acceptance `af24416` | 报告、状态、XLSX/Markdown/五 CSV 同步；精确 16 项与 V5-G2 `VERIFIED` |

两轮 finding 均由不同后续 checkpoint 保留；任何修复者都没有自签接受自己
的 repair。

## 四文件 repair

`5d659243..fab962c` 只修改：

| 文件 | `fab962c` blob |
| --- | --- |
| `scripts/army/training_queue.gd` | `3e8415d6bcf55fe39f57698a1298fb66ed369b45` |
| `scripts/army/army_registry.gd` | `074d9a6b1c93502e8664d5e1abd251e879143398` |
| `scripts/construction_controller.gd` | `997f43e142fdd172977d076801645796792a2f9a` |
| `tests/run_v5_campaign_persistence_smoke.gd` | `9df6fbed2ea844a4dce6e12c40831497bbe9f74f` |

Diff stat：613 insertions、1 deletion。范围只包含 stable-ID type/range/
exhaustion、Army pre-write failure、合法空队列历史迁移和永久对抗测试。

## 独立边界证据

fresh reviewer 创建并在运行后删除了临时 boundary probe。结果：

- `29/29` assertions；
- exit `0`；
- unexpected error signatures `0`。

独立确认：

1. string、float、null、array、dictionary、negative、zero 和 INT64 max
   sequence 均拒绝；
2. 每次拒绝均保持完整 live V5 authority snapshot 不变；
3. Training `MAX-1` 可分配一次并进入 exhausted sentinel，再创建零写入；
4. Army `MAX-1` 可分配一次并进入 exhausted sentinel；
5. Army exhaustion 在 reservation、transaction、registry 和 garrison
   写入前失败；
6. 合法 V1 空队列、`current_day=2`、`last_training_order_day=1` 迁移成功；
7. 非法 V1 迁移零写入；
8. store preflight 拒绝非法 snapshot，不发布下一代次。

## 正式持久化证据

永久 runner `tests/run_v5_campaign_persistence_smoke.gd`：

- `51/51` explicit assertions；
- runner exit `0`；
- V5 cold workers A/B/C `0/0/0`；
- unexpected error signatures `0`。

覆盖：

- `CampaignSnapshotV2` 领域 DTO；
- canonical envelope、lowercase SHA-256；
- `storage_version` 与 `schema_version`；
- immutable generation store；
- write/flush/reread/publish/final-reread；
- V1 read-only migration；
- cold-process continuation；
- whole-generation fallback；
- future-version block；
- live apply rollback。

关键观察：

```text
V5_STALE_TRAINING_COUNTEREXAMPLE load=false reused=false
V5_STALE_ARMY_COUNTEREXAMPLE load=false reused=false
V5_COLD_PROCESS_EXITS A=0 B=0 C=0
```

## 零部分写入

| 失败 | 已确认不变量 |
| --- | --- |
| malformed sequence restore | 完整 live campaign snapshot 不变 |
| stale stable-ID load | load 拒绝，历史 ID 不复用 |
| Training exhausted create | order、resource、ledger、sequence、city 全不变 |
| Army exhausted reservation | 无 reservation、transaction、ArmyState 或扣兵 |
| Training 资源/容量不足 | 完整 authority 不变 |
| Army 容量/active 阻断 | 完整 authority 不变 |
| invalid V1 migration | 输入与 live authority 不变 |
| invalid store preflight | 不发布新代次 |
| injected live apply failure | 完整恢复 pre-apply authority |

## 回归统计

| Basket | 结果 | 基线差异 |
| --- | --- | --- |
| G2 focused | 6/6；185 assertions | 0 |
| tracked | 33/33；1739 assertions | 0 |
| all-present | 35/35；1871 assertions；1905 PASS | 0 |
| V5 cold workers | A/B/C 0/0/0 | 0 |
| S1A.2 cold workers | A/B/C 0/0/0 | 0 |
| city / Blackstone / C0 | exit 0；signatures 0 | 0 |
| editor | exit 0；signatures 0 | 0 |
| diff checks | exit 0 | 0 |

Focused basket：

```text
tests/run_v5_single_unit_garrison_smoke.gd
tests/run_v5_training_queue_smoke.gd
tests/run_v5_army_state_smoke.gd
tests/run_v5_encounter_writeback_smoke.gd
tests/run_v5_campaign_persistence_smoke.gd
tests/run_v5_vertical_loop_smoke.gd
```

## 精确 16 项 runtime task

以下任务在 acceptance checkpoint 标为 `VERIFIED`：

```text
V5-P2-T002  V5-P2-T003  V5-P2-T005  V5-P2-T006  V5-P2-T007
V5-P3-T002  V5-P3-T003  V5-P3-T004  V5-P3-T005  V5-P3-T006
V5-P4-T002  V5-P4-T003  V5-P4-T004
V5-P5-T003  V5-P5-T004  V5-P5-T005
```

G1 合同任务已经单独接受，不重复计入这 16 项。

## S1A.2 保护边界

| SHA-256 | 路径 |
| --- | --- |
| `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` | `scripts/state/early_city_save_store_v1.gd` |
| `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` | `scripts/state/early_city_save_store_v1.gd.uid` |
| `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` | `scripts/state/early_city_snapshot_disk_codec_v1.gd` |
| `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` | `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` |
| `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` | `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` |
| `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` | `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` |
| `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` | `tests/s1a2_early_city_disk_worker.gd` |
| `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` | `tests/s1a2_early_city_disk_worker.gd.uid` |

八文件仍为唯一 untracked、unstaged；`CONDITIONAL_REUSE_ACCEPTED` 不等于
采用 V1 writer/schema。

## Gate 状态

- V4：`VERIFIED / FROZEN`
- V5-G0：`VERIFIED`
- V5-G1：`VERIFIED`
- V5-G2：`VERIFIED`
- V5：`IN_PROGRESS`
- G3–G6、P6、P7、V6：`NOT_STARTED`

本验收之后的唯一允许动作是已授权的 post-G2 文档收敛；不得据此直接进入
G3。

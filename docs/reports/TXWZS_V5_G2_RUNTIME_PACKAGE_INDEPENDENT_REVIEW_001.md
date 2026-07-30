# TXWZS V5-G2 Runtime Package Independent Review 001 — Stable-ID Repair Pending Fresh Review

## 1. Verdict

**`V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`**

Original candidate `cd7be2b4e65f453889c5f49a4922f788cca08a68`
does not qualify for acceptance. Independent adversarial review reproduced one
critical persistence invariant failure: a checksum-valid V2 snapshot could roll
back the next training-order or army sequence, load successfully, and then
reuse an existing stable ID.

This review task applied the smallest local repair and completed the regression
basket. Because the same reviewer authored the repair, these passing results
are `PASS_REPAIR_AGENT`, not an independent acceptance verdict. A fresh reviewer
must bind the repair checkpoint and rerun the defect probes and G2 basket.

No G3, G4, G5, G6, P6, or V6 work is authorized by this report.

## 2. Review identity and baseline binding

| Field | Bound value |
| --- | --- |
| Review ID | `RVW-V5-G2-001` |
| Reviewer task identity | `/root/v5_g2_independent_reviewer` |
| Original candidate | `cd7be2b4e65f453889c5f49a4922f788cca08a68` |
| Candidate parent | `ee32d8445b11260a26501768da2c58abca78a113` |
| Atomic repair commit | `e2c1096f858d571d4621b93174d3848406b42ffa`, parent `cd7be2b4e65f453889c5f49a4922f788cca08a68` |
| Reviewed chain | `bf32178 → 023f11a → a95f510 → 8a6e65a → ee32d84 → cd7be2b` |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| Tracked G2 scope | exact `bf32178..cd7be2b`, 40 files |
| Protected S1A.2 scope | exact eight untracked, unstaged files |
| README | absent from this repository; non-blocking because applicable instructions and evidence are present in `AGENTS.md`, `CURRENT_STATE.md`, architecture, testing, planning, handoff, and report files |

The checkout matched candidate and parent before review. The only pre-existing
worktree entries outside the candidate were the exact eight protected S1A.2
files listed below. They were not staged, edited, or adopted as V5 schema or
writer code.

## 3. Exact original candidate manifest

The following Git blob IDs bind the complete 40-file tracked scope at
`cd7be2b`; they are not hashes of the repaired working tree.

| Git blob | Path |
| --- | --- |
| `ba386f6178ff11c9468cf9391b7afaeea7e68cb8` | `CURRENT_STATE.md` |
| `585fb46faf38e5d8df1efe4b5cb14e8b92212f22` | `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md` |
| `24ddd252d4623c37973c7c54cef9b8f5df866e20` | `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx` |
| `5cc9af6846c2f4515092be7b35079cfaa86599cc` | `docs/planning/csv/acceptance_matrix.csv` |
| `1935ca04de522267b1b0cbf306eaba30db4958db` | `docs/planning/csv/risks_and_decisions.csv` |
| `a1cddbf0e892d135b3bfb8929bf82e5794b7e187` | `docs/planning/csv/tasks.csv` |
| `baa52a38a885da8406af5ddb1b078d9e8e58e0fa` | `docs/planning/csv/tests.csv` |
| `2080a290fa86173ac444d0710afb479564df7bf3` | `docs/reports/TXWZS_V5_G2_RUNTIME_PACKAGE_001.md` |
| `16f0079ef116d4be42e643e5af80d6991d3ca9ef` | `docs/reports/TXWZS_V5_P2_TRAINING_TIME_IMPLEMENTATION_001.md` |
| `aa0c20886eee1763f1537437cdb495ac2cd7772c` | `docs/reports/TXWZS_V5_P3_ARMY_STATE_IMPLEMENTATION_001.md` |
| `9849ca5089d988bad8b9e8b59d83da25015067c2` | `docs/reports/TXWZS_V5_P4_ENCOUNTER_WRITEBACK_IMPLEMENTATION_001.md` |
| `bb1d5ed09e5725c1712c475b70fe13e37030595d` | `docs/reports/TXWZS_V5_P5_CAMPAIGN_PERSISTENCE_IMPLEMENTATION_001.md` |
| `af7538cb1ee4b28185f4fcda99ab3034c36b3078` | `scripts/army/army_registry.gd` |
| `7670bd83c14bff79fbbdf587a17275d1d1653a30` | `scripts/army/army_registry.gd.uid` |
| `fe9c84fe6f5e54bd10dc6c16fa0c95e49de89f1c` | `scripts/army/training_queue.gd` |
| `f9dfd72035f34b8ada515e6a61be4b953ef211d4` | `scripts/army/training_queue.gd.uid` |
| `23b3dfa7a27920f1c7a8a9c02fc09494cb7ecd52` | `scripts/army/v5_army_dispatch_adapter.gd` |
| `e0ecc11be8dd389a83b97e3432f2e3077de2f9f7` | `scripts/army/v5_army_dispatch_adapter.gd.uid` |
| `65a937a39f946045ffb784947da68a5db776c9c6` | `scripts/combat/combat_transaction_coordinator.gd` |
| `1e9b2da03dc14033db4eae4d605472a85cdfe74d` | `scripts/construction_controller.gd` |
| `35280142191505c2bafb3e2f2b1e8c3f08aec53e` | `scripts/map_pan_controller.gd` |
| `5aa4ed6b01165a6e24a334dc5bde619b3ef87def` | `scripts/mvp/blackstone_expedition_mvp.gd` |
| `45acf81dd6d4d835185757cb88efcd37eefccabd` | `scripts/state/v5_campaign_save_codec.gd` |
| `0d937ce7d44b225ef64c28b1aed6b295436d0512` | `scripts/state/v5_campaign_save_codec.gd.uid` |
| `9a7e3b8126ae62ba275b2e7a1b4de376bb9f6782` | `scripts/state/v5_campaign_save_store.gd` |
| `a94eeb8a70cfbe487252f3587e84c8c98d181811` | `scripts/state/v5_campaign_save_store.gd.uid` |
| `0beaeddd8f3854055a5b923889fd151f580221ae` | `scripts/state/v5_campaign_snapshot.gd` |
| `c8ff8872a1495a7a3790c77f8ccfbb70b8805c71` | `scripts/state/v5_campaign_snapshot.gd.uid` |
| `12d3b6c1315e0c8205499ee8d3b694aa109d3bd0` | `tests/run_v5_army_state_smoke.gd` |
| `508cfd2df5bc845055da443a8eedeaa69fdd282c` | `tests/run_v5_army_state_smoke.gd.uid` |
| `fd85eb9d1191678f31af0aefa16c9ea0d6984250` | `tests/run_v5_campaign_persistence_smoke.gd` |
| `6c0cf832d97f42557ed830eb7086497d8eb136f2` | `tests/run_v5_campaign_persistence_smoke.gd.uid` |
| `4b3d944510b2922d35e218bc1f74dd474c763cf0` | `tests/run_v5_encounter_writeback_smoke.gd` |
| `fe96fc8741556846159f03f37fb1a057e31d14d3` | `tests/run_v5_encounter_writeback_smoke.gd.uid` |
| `03dea182b40ac7452b5ced18c0773e12b2f15ba1` | `tests/run_v5_training_queue_smoke.gd` |
| `2cd05d2e01e10521d3b11218979232601ee310b6` | `tests/run_v5_training_queue_smoke.gd.uid` |
| `683be009e4c2a517e42cadab69d6f1abda98070a` | `tests/run_v5_vertical_loop_smoke.gd` |
| `f8a8d9379060cf2875084c3b3b68d615542894ce` | `tests/run_v5_vertical_loop_smoke.gd.uid` |
| `206bb243c9cfd4cdcebd6e1bfbe54239c46fa345` | `tests/v5_campaign_save_worker.gd` |
| `a4c40c1bfbc2f55d84a3758480db7c62905f81ee` | `tests/v5_campaign_save_worker.gd.uid` |

## 4. Finding

### FINDING-V5-G2-001 — stable-ID sequence rollback after restore

**Severity:** critical

**Blocking:** yes for accepting original candidate

**Affected requirements:** `REQ-V5-007`, `REQ-V5-008`, `REQ-V5-010`,
`REQ-V5-011`, `REQ-V5-012`

`TrainingQueue.validate_snapshot()` and
`ArmyRegistry.validate_snapshot()` checked that their next sequence values
were positive, but did not prove those values were greater than all persisted
stable IDs. An attacker or damaged-but-rechecksummed save could therefore:

1. retain an existing `training.<city>.000001` or `army.<faction>.000001`;
2. set the corresponding next sequence back to `1`;
3. pass V2 checksum and snapshot validation;
4. load successfully;
5. create a new record with the same stable ID, overwriting historical state.

The defect violates stable identity, idempotency, cold recovery, and immutable
generation assumptions even though the envelope checksum is valid.

### Independent reproduction on original source

Two permanent adversarial assertions were first added to the P5 runner without
changing production code. Then:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tests/run_v5_campaign_persistence_smoke.gd
```

Result: exit `1`. Exactly these new checks failed:

- `V2 拒绝会在恢复后复用既有训练 order ID 的倒退序列`
- `V2 拒绝会在恢复后复用既有 army ID 的倒退序列`

The remaining P5 checks and the three cold-process workers A/B/C still exited
`0`, isolating the defect to the missing sequence invariant.

## 5. Minimal repair

The repair changes only:

- `scripts/army/training_queue.gd`
- `scripts/army/army_registry.gd`
- `tests/run_v5_campaign_persistence_smoke.gd`

Those exact three files form atomic repair commit
`e2c1096f858d571d4621b93174d3848406b42ffa`; no planning, report, or protected
S1A.2 file is part of that commit.

`TrainingQueue` now parses the exact
`training.<city_id>.<six-digit-sequence>` namespace, rejects malformed IDs,
requires `next_order_sequence` to be greater than the maximum persisted order
sequence, and requires `last_order_day` to equal the maximum persisted
`ordered_day`. The rejection ID is `TRAINING_SEQUENCE_MISMATCH`.

`ArmyRegistry` now parses the exact
`army.<owner_faction_id>.<six-digit-sequence>` namespace, rejects malformed
IDs, and requires `next_army_sequence` to be greater than the maximum
persisted army sequence. The rejection ID is `ARMY_SEQUENCE_MISMATCH`.

The two original red assertions remain as permanent regression coverage.

## 6. Architecture and ownership review

Twenty independent static checks passed after the repair:

- the accepted G1 report and six contract artifacts remain present;
- exactly one `TrainingQueue` and one `ArmyRegistry` production implementation
  exist;
- the city keeps one production infantry compatibility property;
- dispatch uses the authority/capacity gate rather than a duplicate count;
- strategic time preserves frame delta, 1×/2×/4× scaling, pause, and war block;
- the encounter path creates a real existing `BattleSession`;
- `BattleSession` does not depend on city, `GarrisonState`, `ArmyRegistry`,
  save store, or `FileAccess`;
- coordinator ownership remains private and settlement remains authoritative;
- V5 persistence uses a separate V2 writer/schema and does not turn protected
  V1 S1A.2 code into the V5 writer;
- envelope and snapshot versions, immutable publish, future-version rejection,
  and both repaired sequence guards are present.

P2 retained `TrainingQueue` as the source state; P3 retained a collection
container with a V5 single-active validator policy; P4 retained one
`BattleSession` terminal-fact path and one city-authority settlement path; P5
retained versioned DTOs, immutable generation publish, read-after-write
validation, V1 read-only migration, future-version rejection, cold-process
restore, fallback, and rollback.

No second unit, multi-active behavior, enemy AI, siege, second combat source,
P6 UI package, or V6 state was introduced.

## 7. Independent execution evidence

Godot binary:

```sh
/Applications/Godot.app/Contents/MacOS/Godot
```

All commands below were run from the repository root.

### Focused G2 runners

Each runner used:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script res://tests/<runner>.gd
```

| Runner | Exit | Explicit assertions |
| --- | ---: | ---: |
| `run_v5_single_unit_garrison_smoke.gd` | 0 | 27 |
| `run_v5_training_queue_smoke.gd` | 0 | 37 |
| `run_v5_army_state_smoke.gd` | 0 | 27 |
| `run_v5_encounter_writeback_smoke.gd` | 0 | 23 |
| `run_v5_campaign_persistence_smoke.gd` | 0 | 34 |
| `run_v5_vertical_loop_smoke.gd` | 0 | 20 |
| **Total** | **6/6** | **168** |

The P5 runner spawned independent Godot processes A/B/C. All three exited `0`.
The tested trajectory was 2500 ms in transit, restore and advance only the
remaining 3500 ms, then a further cold restore at exactly 6000 ms `ARRIVED`
without replay.

### Regression baskets

The tracked basket executed all 33 tracked runners in deterministic sorted
order with the same headless `--script` invocation:

- **33/33 runners**
- **1722 explicit assertions**
- **0 parse/script/error signatures**

The all-present basket added the two protected S1A.2 runners:

- **35/35 runners**
- **1854 explicit assertions**
- **1888 `PASS` lines**
- **0 parse/script/error signatures**

The two-assertion increase over the original published baselines
`166 / 1720 / 1852 / 1886` is expected and is exactly the permanent sequence
rollback coverage added by this review.

The focused, tracked, all-present, formal-scene, and editor results above are
bound as review-session command/exit/statistics records. No durable per-run log
directory was retained, so this report does not claim a repository or `/tmp`
evidence path for those logs. The durable evidence is the permanent
adversarial test, the atomic repair commit, and this review report.

### Formal scenes, editor, and source hygiene

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --scene res://scenes/blackstone_expedition_mvp.tscn --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --editor --quit
git diff --check
```

All five commands exited `0`; final error-signature scans found `0`.

## 8. Persistence failure and rollback evidence

The P5 focused runner and code audit cover:

- checksum mismatch rejection;
- unsupported future envelope/snapshot version rejection;
- V1 read-only migration into an empty V2 army and settlement collection;
- immutable generation directories;
- read-after-write validation before current-generation publication;
- interrupted generation write not becoming current;
- corrupted current generation falling back to the last valid generation;
- cold-process save/reload of training, garrison, ArmyState, logical
  route/node/progress, and settlement ledger;
- live-apply validation failure restoring the pre-load runtime snapshot;
- repeated terminal settlement remaining idempotent;
- newly added rollback-sequence rejection before load can reuse a stable ID.

## 9. Protected S1A.2 evidence

The exact SHA-256 values were unchanged before and after the adversarial probe,
repair, regression, planning synchronization, and final closeout:

| SHA-256 | Protected file |
| --- | --- |
| `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` | `scripts/state/early_city_save_store_v1.gd` |
| `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` | `scripts/state/early_city_save_store_v1.gd.uid` |
| `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` | `scripts/state/early_city_snapshot_disk_codec_v1.gd` |
| `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` | `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` |
| `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` | `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` |
| `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` | `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` |
| `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` | `tests/s1a2_early_city_disk_worker.gd` |
| `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` | `tests/s1a2_early_city_disk_worker.gd.uid` |

All eight remain untracked and unstaged. S1A.2 remains
`CONDITIONAL_REUSE_ACCEPTED`, not promoted to V5 writer/schema acceptance.

## 10. Planning-control synchronization

The canonical workbook was edited first with the bundled spreadsheet runtime,
then the Markdown and five CSV mirrors were synchronized from that revision.

- plan version: `1.0.1-v5-g2-repair-001`;
- 13/13 worksheets rendered and visually inspected;
- formula-error scan: `0`;
- workbook-to-five-CSV exact value comparison: `totalMismatches=0`
  (`roadmap.csv` was regenerated but remained byte-identical);
- 16 G2 runtime tasks remain `IMPLEMENTED_PENDING_REVIEW`;
- V5 remains 17/44 VERIFIED;
- V5-G2 remains `IMPLEMENTED_PENDING_REVIEW`, with review verdict
  `V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`;
- V4/G0/G1 remain unchanged;
- V6 remains `NOT_STARTED`;
- the review, finding, repair-agent test evidence, risk, and next fresh-review
  gate are recorded;
- five CSV mirrors were regenerated from the same workbook values.

## 11. Required next step

A different reviewer must:

1. bind the repair checkpoint and its parent;
2. confirm the exact three runtime/test repair files plus planning/report scope;
3. rerun both sequence rollback assertions;
4. rerun the six G2 focused runners and appropriate regression basket;
5. recheck the protected eight hashes and staging exclusion;
6. issue the acceptance or further-repair verdict.

Until then, the only valid status is:

**`V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`**

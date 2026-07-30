# TXWZS V5 P0/P1 Package Independent Review 001

## Verdict

`REVIEW_REQUIRED` on reviewed candidate `242f793`.

The review reproduced one blocking authority defect: `get_dispatchable_infantry_count()`
reported 10 dispatchable infantry after applying recruitment capacity, but
`CombatTransactionCoordinator.create_request(12)` still created a 12-infantry
reservation. The candidate therefore did not satisfy the stated conservation
and atomicity gate and was not accepted.

The same task then switched to implementer mode and applied a minimal repair.
Post-repair tests pass, but this task is not independent of that repair. The
final legal state is:

`REPAIRED_PENDING_INDEPENDENT_REVIEW`

`V5_P0_P1_PACKAGE_REVIEW_ACCEPTED` was not issued. V5-G0 and the eleven reviewed
P0/P1 tasks remain not VERIFIED. G1 was not started.

## Review identity and immutable binding

| Field | Value |
| --- | --- |
| Reviewer task identity | `/root`, delegated from Codex task `019fb1e2-de2a-7863-97e1-a828c14b5114` |
| Isolated review worktree | `/Users/m1-meng/.codex/worktrees/3f29/godot-天下无战事2` |
| Reviewed branch identity | `codex/v4-milestone-closure` at the source worktree; isolated review checkout was detached at the same commit |
| Reviewed commit | `242f79313b754894590c0f531998bf0517b3707d` |
| Reviewed parent | `5357c282e15cb8615398d3180738d60e64be3f3e` |
| Godot | `4.5.1.stable.official.f62fdbde1` |
| V4 boundary | `VERIFIED / FROZEN`; no V4 implementation was changed |
| External actions | no push, deploy, release, production mutation, or V6 work |

## Exact reviewed file manifest

The commit range `5357c28..242f793` contains exactly 15 files:

| File | SHA-256 at `242f793` |
| --- | --- |
| `CURRENT_STATE.md` | `01e70f296f578c0a4f6e42c87a8801bb9715b4e2208c51a1165628dd31dbbd4a` |
| `docs/architecture/V5_SINGLE_UNIT_WAR_FOUNDATION_CONTRACT_V0.md` | `6ffdd9b9a5839bf340492b44d961eb733be5072ce5d4125603747be930c21ed9` |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md` | `15dfeaf1a8c4060225e6512111300ca8671191d69a263001e79c1aa13003d852` |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx` | `de9b5b33a858f48f880a044e6e2a8b60f077368c85d9bcefa68c4b139f641ca5` |
| `docs/planning/csv/acceptance_matrix.csv` | `d4caaedbc3c3af8c25a0d164a06e9f45b2059810b9afc4d292e5a880d8abe92c` |
| `docs/planning/csv/roadmap.csv` | `82c60684417c883c1067bdfa1f4f93439dc76d01674325f0337069da7f7e2f01` |
| `docs/planning/csv/tasks.csv` | `c50ddfcf2b58e037d28650d7015f3b11bbe22286fe612e123703b1f54f4aacd1` |
| `docs/planning/csv/tests.csv` | `a5582b1dbada55046b2fe6d5c201269e0d1b588958a660038d286b89f64bfe6f` |
| `docs/reports/TXWZS_V5_SINGLE_UNIT_GARRISON_SLICE_001.md` | `b3945229b0a3ac549464980cb4c03c4302395e89535cde0d71d9ec1a304e90b4` |
| `scenes/blank_map.tscn` | `298c75d7d392ffa67df4c16cd55be72e27d1335c58b631d6009066289131c233` |
| `scripts/army/garrison_state.gd` | `6554b32b7bfe0ab248bb0393dc2dcae3db6784418604be3addea9a79992c1642` |
| `scripts/army/garrison_state.gd.uid` | `eb2d80773fe87fc91f7323494c81e06423d7c52f6a314531db42b6a5914ed500` |
| `scripts/construction_controller.gd` | `d7c22a401bb432f6ffa741ab3082f2cf682877e17d128d652b6d6f8dcc1ea83a` |
| `tests/run_v5_single_unit_garrison_smoke.gd` | `b774e7296fb96cd0ce1c0ed8feb82afc8e98f1058d70e4453d7bf816ef0fb1d2` |
| `tests/run_v5_single_unit_garrison_smoke.gd.uid` | `00f7d232f031ec93839d40255821df8915a6acf662282f3da6f693aa5a3844a7` |

## Findings and disposition

### V5-G0-REV-001 — BLOCKING — reservation could exceed authoritative dispatchable capacity

At `242f793`, the read model correctly defined dispatchable infantry as the
minimum of unreserved infantry, `recruitment_cap`, and effective command limit.
The write entry `reserve_battle_force()` separately checked unreserved infantry
and command limit, but omitted `recruitment_cap`.

Independent runtime reproduction:

```text
CAPACITY_PROBE dispatchable=10 configured=true request_created=true
reserved={ "transaction_id": &"battle-000001", "committed_count": 12, "phase": &"RESERVED" }
```

The probe intentionally exited 1 when the invalid request was created. This is
a real authority mismatch: UI/read API says only 10 are dispatchable while the
write path accepts and records 12.

Disposition:

- changed `reserve_battle_force()` to reject any request above
  `get_dispatchable_infantry_count()`;
- added an assertion that a 12-person request is rejected when capacity makes
  dispatchable count 10;
- added an assertion that the rejected request leaves reservation empty,
  infantry unchanged, and dispatchable count unchanged;
- removed the temporary diagnostic probe after transferring the case into the
  permanent V5 runner.

Repair-only runtime diff relative to `242f793` is 2 files, 14 insertions and
2 deletions:

| File | Post-repair SHA-256 |
| --- | --- |
| `scripts/construction_controller.gd` | `b57514d685816bf0e7946332fa1fd0924f447d9a19c9cf76bed9bf0c5c3a5611` |
| `tests/run_v5_single_unit_garrison_smoke.gd` | `bdcc3b27752d7eb5b0c9afc01f62d62982ac341c30937ebb15d0dbc42f58a960` |

### Non-blocking review conclusions

- `GarrisonState` is the only stored garrison-count source owned by
  `ConstructionController`; the repository has one `var infantry_count`
  declaration and it is a compatibility property proxying `_garrison_state`.
- `unit_role.infantry_basic` remains defined once in the existing
  `infantry_basic.tres`; V5 queries return that resource instead of duplicating
  unit data.
- Garrison snapshot dictionaries are deep copies; failed add/remove operations
  are zero-write.
- Reservation does not deduct total garrison early; cancel releases reservation;
  result application remains behind the existing coordinator and
  `BattleSession` authority.
- The city sidebar reads the same controller getters and does not introduce a
  mutable UI troop cache.
- V4 C0, `BattleSession`, Blackstone, rewards, city-time, and result-authority
  paths passed the complete tracked regression after repair.

## Protected S1A.2 boundary

The isolated worktree initially had no protected files. Exactly the eight
untracked S1A.2 files were copied byte-for-byte from the source candidate
worktree `/Users/m1-meng/.codex/worktrees/e1c8/godot-天下无战事2` so the
all-present suite could run. No other untracked source-worktree content was
copied.

| File | SHA-256 before and after |
| --- | --- |
| `scripts/state/early_city_save_store_v1.gd` | `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` |
| `scripts/state/early_city_save_store_v1.gd.uid` | `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd` | `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` | `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` | `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` |
| `tests/s1a2_early_city_disk_worker.gd` | `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` |
| `tests/s1a2_early_city_disk_worker.gd.uid` | `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` |

They remain untracked and unstaged. Running their runner is observation only;
this review did not issue the P5 reuse verdict.

## Workbook and mirror review

The XLSX imported successfully through the bundled spreadsheet runtime. All 13
sheets rendered, and the formula error scan returned zero matches. The
Markdown/CSV mirrors and workbook consistently describe the original
P0/P1 candidate as pending review rather than VERIFIED.

The workbook also contains known baseline fields that require the planned G1
same-revision update, including the earlier V4 parent/runtime baseline and
conceptual `GarrisonState` rows. Because G0 was not accepted, this task did not
enter the user-authorized second stage and did not modify XLSX, Markdown, or CSV
planning artifacts.

## Commands and results

| Command or command family | Exit / result |
| --- | --- |
| `git rev-parse HEAD` | 0; `242f79313b754894590c0f531998bf0517b3707d` before repair |
| `git rev-parse 242f793^` | 0; `5357c282e15cb8615398d3180738d60e64be3f3e` |
| `git diff-tree --no-commit-id --name-only -r 5357c28 242f793` plus per-blob SHA-256 | 0; exactly 15 reviewed files |
| source-worktree `git status` plus eight `shasum -a 256` checks | 0; exact protected manifest copied |
| first fresh-worktree V5 run before editor import | Godot process 0 but invalid evidence: 7 parse/error signatures from missing class cache |
| initial `Godot --headless --editor --path . --quit` | 0; 0 final error signatures |
| candidate V5 runner after import | 0; 25 assertions and summary PASS |
| temporary capacity probe | 1 by design; reproduced invalid 12-person reservation when dispatchable was 10 |
| repaired V5 runner | 0; 27 assertions and summary PASS |
| each of 29 Git-tracked `tests/run_*_smoke.gd` | 29/29 exit 0; 1601 assertion lines; 0 error signatures |
| each of 30 all-present `tests/run_*_smoke.gd` | 30/30 exit 0; 1713 assertion lines; 1742 PASS lines; 0 error signatures |
| `Godot --headless --path . --quit-after 5 res://scenes/blank_map.tscn` | 0; 0 error signatures |
| `Godot --headless --path . --quit-after 5 res://scenes/blackstone_expedition_mvp.tscn` | 0; 0 error signatures |
| final `Godot --headless --editor --path . --quit` | 0; 0 error signatures |
| `git diff --check` | 0; empty output |
| post-repair `FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR` scan | 0 matches |
| workbook import, 13-sheet render, formula-error scan | 0; 13/13 rendered; 0 formula-error matches |
| final `git diff --cached --name-only` | empty; staged count 0 |

Tracked runner details:

| Runner | Exit | Assertions |
| --- | ---: | ---: |
| `run_blackstone_playable_mvp_smoke.gd` | 0 | 151 |
| `run_building_lifecycle_smoke.gd` | 0 | 75 |
| `run_building_selection_smoke.gd` | 0 | 60 |
| `run_c0_battle_presentation_smoke.gd` | 0 | 30 |
| `run_c0_city_time_settlement_smoke.gd` | 0 | 59 |
| `run_c0a_battle_transaction_smoke.gd` | 0 | 26 |
| `run_c0b_deterministic_battle_smoke.gd` | 0 | 116 |
| `run_c0c_graybox_scene_smoke.gd` | 0 | 15 |
| `run_c0d_result_writeback_smoke.gd` | 0 | 19 |
| `run_c0e_combat_contract_smoke.gd` | 0 | 14 |
| `run_c0f_battle_exit_return_smoke.gd` | 0 | 33 |
| `run_city_spatial_kernel_smoke.gd` | 0 | 76 |
| `run_city_time_viewport_smoke.gd` | 0 | 41 |
| `run_construction_placement_smoke.gd` | 0 | 61 |
| `run_noticeboard_flow_smoke.gd` | 0 | 32 |
| `run_noticeboard_mission_objectives_smoke.gd` | 0 | 20 |
| `run_p1a_road_logging_smoke.gd` | 0 | 29 |
| `run_p1b_daily_economy_smoke.gd` | 0 | 38 |
| `run_p1c_threat_deadline_smoke.gd` | 0 | 37 |
| `run_p1d_army_tech_smoke.gd` | 0 | 45 |
| `run_p1e_first_war_closed_loop_smoke.gd` | 0 | 57 |
| `run_p1e_first_war_gate_smoke.gd` | 0 | 28 |
| `run_p1f_construction_dataization_smoke.gd` | 0 | 25 |
| `run_runtime_identity_smoke.gd` | 0 | 0 |
| `run_s1a1_early_city_snapshot_smoke.gd` | 0 | 126 |
| `run_unified_building_interaction_smoke.gd` | 0 | 279 |
| `run_v5_single_unit_garrison_smoke.gd` | 0 | 27 |
| `run_watchtower_catalog_smoke.gd` | 0 | 7 |
| `run_world_map_v0_smoke.gd` | 0 | 75 |

The all-present-only S1A.2 runner exited 0 with 112 assertions and one summary
PASS line. That observation does not accept or stage S1A.2.

## Required next review

A different reviewer task must bind the repair commit and its parent, re-run at
least the 27-assertion V5 runner, tracked and all-present suites, both scenes,
editor scan, diff check, error scan, protected hashes, and verify that no other
reservation entry bypasses `get_dispatchable_infantry_count()`.

Only that independent re-review may issue
`V5_P0_P1_PACKAGE_REVIEW_ACCEPTED`, mark V5-G0 and the covered eleven P0/P1
tasks VERIFIED, and authorize G1.

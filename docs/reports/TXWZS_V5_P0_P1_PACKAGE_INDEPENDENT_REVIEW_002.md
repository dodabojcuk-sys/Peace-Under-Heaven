# TXWZS V5 P0/P1 Package Independent Review 002

## Verdict

`V5_P0_P1_PACKAGE_REVIEW_ACCEPTED`

Reviewed repair candidate:
`bd15fcab1fef11841136ca900d6cce31db8966aa`.

Reviewed parent:
`242f79313b754894590c0f531998bf0517b3707d`.

This review independently accepts the repaired V5 P0/P1 package and marks
V5-G0 `VERIFIED`. The eleven P0/P1 tasks covered by the package are
independently accepted.

This verdict does not accept G1 or G2, does not authorize runtime work beyond
the G1 contracts, and does not accept the protected S1A.2 files as a save
baseline.

## Independent review identity

| Field | Value |
| --- | --- |
| Reviewer task | `/root`, delegated from Codex task `019fb280-8b12-7ce1-8e8e-c21e4ef918c5` |
| Review worktree | `/Users/m1-meng/.codex/worktrees/3231/godot-天下无战事2` |
| Initial checkout state | detached `HEAD` at the reviewed commit |
| Repair branch ref | `codex/v5-p0-p1-repair-review-001` points to the reviewed commit |
| Godot | `4.5.1.stable.official.f62fdbde1` |
| Durable evidence | this report, candidate commit, tests, and repository state |
| Session-local logs | `/tmp/txwzs-v5-g0-review-002.BlGA2l` |
| External actions | no push, deploy, release, production mutation, or V6 work |

The repository has no README file at this revision. `AGENTS.md`,
`CURRENT_STATE.md`, the V5 architecture contract, implementation report,
Repair Review 001, the full repair diff, runtime sources, and tests were read
directly.

## Immutable repair binding

`git show` and per-blob SHA-256 checks found exactly four files in
`242f793..bd15fca`:

| File | SHA-256 at `bd15fca` |
| --- | --- |
| `CURRENT_STATE.md` | `5f69e3557b5539e037db88397674ff882159f9fcb26ab40c3c7400e92b5ae53a` |
| `docs/reports/TXWZS_V5_P0_P1_PACKAGE_INDEPENDENT_REVIEW_001.md` | `68a00a69d56a5172d9cb45e11b65976cf1ea7e0e47cbb1ddc72182ee57f6d041` |
| `scripts/construction_controller.gd` | `b57514d685816bf0e7946332fa1fd0924f447d9a19c9cf76bed9bf0c5c3a5611` |
| `tests/run_v5_single_unit_garrison_smoke.gd` | `bdcc3b27752d7eb5b0c9afc01f62d62982ac341c30937ebb15d0dbc42f58a960` |

Repair Review 001 describes its repair-only runtime diff as two files and
separately contains the report/status update. The two recorded post-repair
runtime hashes match the blobs above exactly. The four-file commit manifest,
parent, subject, and report are therefore consistent.

## Independent authority audit

### Reservation write ownership

Repository-wide search found one production assignment that creates an active
battle reservation: `ConstructionController.reserve_battle_force()`.
`CombatTransactionCoordinator.create_request()` is the only production caller,
and the city method now rejects:

```gdscript
committed_count > get_dispatchable_infantry_count()
```

The formal first-war, noticeboard mission, retreat, and battle-scene UI paths
all terminate at that coordinator/city gate. Some preflight methods calculate a
display/eligibility count, but none can create a reservation or mutate the
garrison without the authoritative gate.

### Exact capacity boundary

A fresh independent probe configured:

- authoritative garrison total: 50;
- recruitment capacity: 10;
- selected-general command limit: 40;
- authoritative dispatchable query: 10.

Observed results:

1. `create_request(12)` returned `null`;
2. the full garrison snapshot before and after rejection was identical;
3. no active reservation was created and total remained 50;
4. `create_request(10)` returned a valid request;
5. accepted state was total 50, reserved 10, unreserved 40,
   dispatchable 10;
6. total equaled reserved plus unreserved and every count was non-negative;
7. cancellation restored total 50, reserved 0, unreserved 50.

The valid probe produced 10 explicit assertions and
`V5_G0_INDEPENDENT_PROBE PASS`.

The first probe draft had four test-script type-inference parse errors. Godot
returned process exit 0 despite those errors, so that run was explicitly
discarded. The corrected probe and all final scans had zero error signatures.
The temporary probe was removed before tracked/all-present enumeration.

### Single truth source and compatibility

- `GarrisonState._unit_counts` is the only stored garrison-count dictionary.
- The repository has one production `var infantry_count` declaration. It is a
  compatibility property whose getter and setter proxy the same private
  `GarrisonState`.
- Negative compatibility writes are rejected by `GarrisonState` without
  changing the existing count.
- Garrison read models are deep copies.
- Capacity, active reservation, and effective command limit are combined by
  `get_dispatchable_infantry_count()`.
- UI text reads the same authoritative getters; it has no mutable troop cache.

### V4 and C0 regression boundary

The complete tracked suite retained:

- C0 coordinator ownership and terminal `BattleSession` authority;
- result authorization, idempotent writeback, and conflict rejection;
- Blackstone dispatch, arrival, retreat, failure, victory, and return paths;
- city strategic time and battle blocking;
- S1A.1 snapshot behavior.

No V4 source, C0 source, `BattleSession`, Blackstone scene/script, or
S1A.1 source changed in `242f793..bd15fca`.

## Protected S1A.2 boundary

The review worktree initially did not contain the protected untracked files.
Exactly the eight files were copied byte-for-byte from
`/Users/m1-meng/.codex/worktrees/e1c8/godot-天下无战事2` so the all-present
suite could be observed:

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

They remained the only untracked files, were never staged, and retained these
hashes after every G0 test. Their runner result is observation only; the P5
reuse decision remains open for G1.

## Fresh commands and results

| Check | Exit / result |
| --- | --- |
| `git rev-parse HEAD HEAD^` | 0; exact candidate and parent above |
| `git diff --name-status 242f793..bd15fca` | 0; exact four-file manifest above |
| per-blob `shasum -a 256` | 0; hashes above |
| corrected independent 10/12 boundary probe | 0; 10 assertions; 0 final signatures |
| `run_v5_single_unit_garrison_smoke.gd` | 0; 27 assertions; 0 signatures |
| 29 Git-tracked `tests/run_*_smoke.gd` | 29/29 exit 0; 1601 assertions; 0 signatures |
| 30 all-present `tests/run_*_smoke.gd` | 30/30 exit 0; 1713 assertions; 1742 PASS lines; 0 signatures |
| formal `scenes/blank_map.tscn` | 0; 0 signatures |
| formal `scenes/blackstone_expedition_mvp.tscn` | 0; 0 signatures |
| final headless editor scan | 0; 0 signatures |
| `git diff --check` | 0; empty output |
| final `FAIL: / ERROR: / WARNING: / Parse Error / SCRIPT ERROR` scan | 0 matches |
| final staged file list | empty |

## Gate decision

- V4: `VERIFIED / FROZEN`
- V5-G0: `VERIFIED`
- V5 P0/P1 reviewed package: independently accepted
- V5-G1: not yet implemented or verified at this checkpoint
- V5-G2: unchanged; no new authorization
- V6: `NOT STARTED`

The independent repair gate is closed. The authorized next action is the six
G1 architecture contracts, their contract validation, and planning-control
synchronization without entering G2 runtime implementation.

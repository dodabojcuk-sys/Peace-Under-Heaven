# TXWZS V5-G2 Stable-ID Boundary Repair Fresh Independent Review 003 — Accepted

## 1. Verdict

`V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED`

Fresh reviewer
`/root/v5_g2_boundary_fresh_independent_reviewer_003` independently bound the
requested commit chain, reviewed the four-file repair, ran a new boundary
probe, reran the permanent persistence adversarial test, and reran the complete
G2 regression basket. No new material defect was found.

This verdict accepts V5-G2 runtime only. It does not start or accept G3–G6,
P6/P7, V6, a second unit type, multiple active armies, enemy AI, siege, or a
new battle source. The planning workbook, Markdown mirror, and five CSV mirrors
must record this acceptance in the same local acceptance checkpoint; they were
not edited by this reviewer task.

## 2. Reviewer identity and commit binding

| Field | Bound value |
| --- | --- |
| Reviewer identity | `/root/v5_g2_boundary_fresh_independent_reviewer_003` |
| Formal worktree | `/Users/m1-meng/.codex/worktrees/3231/godot-天下无战事2` |
| Branch at review | `codex/v5-g0-review-g1-contracts-001` |
| HEAD at review | `4d0fbfc5aefe07509db115f8f4f68e22aeda8a98` |
| Original candidate | `cd7be2b4e65f453889c5f49a4922f788cca08a68` |
| First repair | `e2c1096f858d571d4621b93174d3848406b42ffa` |
| Repair review checkpoint | `5d6592431e6f5f1c1bd3ddad408db942613b7e4a` |
| Boundary repair | `fab962c0a84024e7034c32e9d5c39debc1659c5f` |
| Boundary repair report checkpoint | `4d0fbfc5aefe07509db115f8f4f68e22aeda8a98` |

`git merge-base --is-ancestor` independently returned success for every edge:

```text
cd7be2b
→ e2c1096
→ 5d659243
→ fab962c
→ 4d0fbfc
```

The index was empty at review start. The only untracked files were the exact
eight protected S1A.2 files.

## 3. Exact four-file repair

`git diff --stat 5d659243..fab962c` reports 613 insertions and one deletion
across exactly four files:

| File | Blob at `fab962c` |
| --- | --- |
| `scripts/army/training_queue.gd` | `3e8415d6bcf55fe39f57698a1298fb66ed369b45` |
| `scripts/army/army_registry.gd` | `074d9a6b1c93502e8664d5e1abd251e879143398` |
| `scripts/construction_controller.gd` | `997f43e142fdd172977d076801645796792a2f9a` |
| `tests/run_v5_campaign_persistence_smoke.gd` | `9df6fbed2ea844a4dce6e12c40831497bbe9f74f` |

The production changes are bounded:

- Training and Army restore require an integer `next_*_sequence` in the exact
  JSON-safe persisted range.
- `MAX_EXACT_PERSISTED_SEQUENCE` is a valid exhausted sentinel.
- Allocation is permitted at `MAX-1`, advances to the sentinel, and then
  refuses another allocation without mutation.
- Army exhaustion is checked before dispatch reservation ID allocation,
  reservation publication, registry mutation, or garrison removal.
- Empty TrainingQueue snapshots may retain a validated historical
  `last_order_day`; non-empty snapshots retain strict equality with their
  maximum ordered day.

No unrelated production file, S1A.2 file, scene, project setting, UI package,
or G3+ artifact is in the repair.

## 4. Fresh independent boundary probe

The reviewer created a temporary Godot probe, ran it from the formal worktree,
recorded its output, and deleted the probe before final status review. It was
not staged or committed.

Result: `29/29`, exit `0`, unexpected error signatures `0`.

The probe independently established:

1. string, float, null, array, dictionary, negative, zero, and INT64-maximum
   Training/Army sequence values are rejected;
2. every rejected restore preserves the complete live V5 authority snapshot;
3. Training `MAX-1` restore creates the expected high stable ID, advances to a
   valid exhausted sentinel, and a second create is zero-write;
4. Army `MAX-1` restore creates the expected high stable ID and advances to a
   valid exhausted sentinel;
5. controller-level Army exhaustion returns before dispatch reservation,
   transaction sequence, registry, or garrison mutation;
6. a legal V1 empty queue with `current_day=2` and
   `last_training_order_day=1` migrates successfully, preserves that history,
   does not mutate the V1 input, and does not modify live authority;
7. invalid V1 migration is zero-write;
8. the formal store preflight rejects an invalid snapshot, retains generation
   1, and does not publish generation 2.

## 5. Formal disk, codec, store, restore, and fallback

The permanent `run_v5_campaign_persistence_smoke.gd` was rerun independently:

- 51/51 explicit assertions;
- runner exit `0`;
- V5 cold workers A/B/C exit `0/0/0`;
- unexpected error signatures `0`.

The dynamic run covered the production DTO codec, canonical envelope,
lowercase SHA-256, immutable generation store, write/flush/reread/publish/final
reread sequence, load-and-restore, cold-process continuation, and whole
generation fallback.

It independently observed:

```text
V5_STALE_TRAINING_COUNTEREXAMPLE load=false reused=false
V5_STALE_ARMY_COUNTEREXAMPLE load=false reused=false
V5_COLD_PROCESS_EXITS A=0 B=0 C=0
```

Checksum-valid but domain-invalid Training and Army rollback generations were
rejected before live restore. Bad latest generations fell back to a complete
earlier valid generation. Future versions blocked downgrade fallback. Injected
write, publish, final-reread, and mid-apply failures did not partially replace
the last valid authority state.

## 6. Zero-partial-write review

The combined fresh probe, permanent runner, and code review prove the requested
atomicity boundaries:

| Failure | Observed invariant |
| --- | --- |
| malformed sequence restore | complete live campaign snapshot unchanged |
| stale stable-ID sequence load | load rejected; historical ID not reused |
| Training exhausted create | order, resource, ledger, sequence, and city authority unchanged |
| Army exhausted reservation | no reservation, no transaction increment, no ArmyState, no garrison removal |
| insufficient Training resource/capacity | complete authority unchanged |
| Army capacity or active limit | complete authority unchanged |
| invalid V1 migration | input and live authority unchanged |
| invalid store preflight | no new generation published |
| injected live apply failure | pre-apply authority restored in full |

## 7. Complete regression

All commands used Godot
`/Applications/Godot.app/Contents/MacOS/Godot` in headless mode from the formal
worktree.

| Basket | Fresh result | Required baseline | Difference |
| --- | --- | --- | --- |
| G2 focused | 6/6; 185 explicit assertions | 6/6; 185 | none |
| tracked | 33/33; 1739 explicit assertions | 33/33; 1739 | none |
| all-present | 35/35; 1871 explicit assertions; 1905 PASS lines | 35/35; 1871; 1905 | none |
| V5 cold workers | A/B/C `0/0/0` | A/B/C `0/0/0` | none |
| S1A.2 cold workers | A/B/C `0/0/0` | A/B/C `0/0/0` | none |
| formal city scene | exit `0`; signatures `0` | exit `0` | none |
| Blackstone scene | exit `0`; signatures `0` | exit `0` | none |
| C0 scene | exit `0`; signatures `0` | exit `0` | none |
| Godot editor scan | exit `0`; signatures `0` | exit `0` | none |
| worktree `git diff --check` | exit `0` | exit `0` | none |
| repair `git diff --check` | exit `0` | exit `0` | none |

The focused basket was:

- `run_v5_single_unit_garrison_smoke.gd`;
- `run_v5_training_queue_smoke.gd`;
- `run_v5_army_state_smoke.gd`;
- `run_v5_encounter_writeback_smoke.gd`;
- `run_v5_campaign_persistence_smoke.gd`;
- `run_v5_vertical_loop_smoke.gd`.

Review-session logs are under
`/tmp/txwzs-v5-g2-fresh-review-003`. They are session-local evidence, not the
durable acceptance artifact.

## 8. Protected S1A.2 boundary

The exact eight files remained the only untracked and unstaged files. Their
review-start and post-regression SHA-256 values are identical:

| SHA-256 | Path |
| --- | --- |
| `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` | `scripts/state/early_city_save_store_v1.gd` |
| `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` | `scripts/state/early_city_save_store_v1.gd.uid` |
| `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` | `scripts/state/early_city_snapshot_disk_codec_v1.gd` |
| `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` | `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` |
| `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` | `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` |
| `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` | `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` |
| `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` | `tests/s1a2_early_city_disk_worker.gd` |
| `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` | `tests/s1a2_early_city_disk_worker.gd.uid` |

This acceptance does not adopt those V1 files as the V5 writer/schema.
`CONDITIONAL_REUSE_ACCEPTED` remains the precise S1A.2 reuse decision.

## 9. Planning and checkpoint boundary

At the bound review HEAD, the canonical planning XLSX still had 13 sheets and
zero formula-error matches; its Markdown and five CSV mirrors were still at the
pre-acceptance `1.0.1-v5-g2-repair-001` checkpoint. That no-change baseline was
verified before this report.

The local acceptance checkpoint must contain only:

- this fresh independent review report;
- `CURRENT_STATE.md`;
- the canonical planning XLSX;
- the planning Markdown mirror;
- the five existing CSV mirrors.

The planning synchronization must:

- mark the exact 16 V5-G2 runtime tasks `VERIFIED`;
- mark V5-G2 `VERIFIED`;
- record reviewer identity and this report;
- keep G3–G6, P6/P7, V6, and V5-P4-T005 not started;
- keep the eight S1A.2 files untracked and unstaged.

No runtime source, permanent test, protected S1A.2 file, unrelated Markdown
cleanup, push, deploy, or G3+ work belongs in that checkpoint.

## 10. Final verdict

`V5_G2_RUNTIME_PACKAGE_REVIEW_ACCEPTED`

The next operation is the bounded local acceptance control synchronization and
checkpoint. After that checkpoint, stop. Do not enter G3.

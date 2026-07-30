# TXWZS V5-G2 Stable-ID Sequence Repair Independent Re-review 002 — Boundary Repair Pending Fresh Review

## 1. Verdict

`V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`

Reviewer `/root/v5_g2_repair_independent_reviewer_002` independently reproduced
the original checksum-valid stable-ID rollback on `cd7be2b`, confirmed that
`e2c1096` rejects that exact rollback, and then found three additional material
boundary defects in the repair:

1. string and floating-point `next_*_sequence` values were accepted through
   `int(...)` coercion;
2. an unrepresentable/exhausted sequence could pass domain validation;
3. a valid V1 state with no active order but a retained
   `last_training_order_day` was rejected during V1→V2 migration.

This reviewer authored the minimal follow-up repair
`fab962c0a84024e7034c32e9d5c39debc1659c5f` and therefore cannot accept it.
The 16 G2 runtime tasks and V5-G2 remain pending. G3–G6, P6/P7, and V6 remain
not started.

## 2. Identity, worktree, and commit binding

| Field | Bound value |
| --- | --- |
| Reviewer task | `/root/v5_g2_repair_independent_reviewer_002` |
| Formal review worktree | `/Users/m1-meng/.codex/worktrees/3231/godot-天下无战事2` |
| Branch | `codex/v5-g0-review-g1-contracts-001` |
| Review baseline | `5d6592431e6f5f1c1bd3ddad408db942613b7e4a` |
| Original rejected candidate | `cd7be2b4e65f453889c5f49a4922f788cca08a68` |
| First repair | `e2c1096f858d571d4621b93174d3848406b42ffa` |
| Follow-up repair | `fab962c0a84024e7034c32e9d5c39debc1659c5f` |

The initial repository path supplied in the desktop context referred to a
different dirty checkout. Read-only worktree enumeration resolved the formal
target above: it was exactly at `5d659243`, had an empty index, and had only
the protected eight S1A.2 files as untracked entries. The original checkout
was not modified.

Both required chains were verified:

```text
023f11a → a95f510 → 8a6e65a → ee32d84 → cd7be2b
cd7be2b → e2c1096 → 5d659243 → fab962c
```

`cd7be2b..e2c1096` contains exactly:

- `scripts/army/training_queue.gd`
- `scripts/army/army_registry.gd`
- `tests/run_v5_campaign_persistence_smoke.gd`

`e2c1096..5d659243` contains only the disclosed report, state, planning
workbook/Markdown, and five CSV checkpoint changes; it contains no runtime
source or permanent test change.

### Original three-file hashes

Git blob IDs:

| Path | `cd7be2b` | `e2c1096` | follow-up repair content |
| --- | --- | --- | --- |
| `scripts/army/training_queue.gd` | `fe9c84fe6f5e54bd10dc6c16fa0c95e49de89f1c` | `85f9bb4beb1f20dcb0f7b40c40417eac9fb157e9` | `3e8415d6bcf55fe39f57698a1298fb66ed369b45` |
| `scripts/army/army_registry.gd` | `af7538cb1ee4b28185f4fcda99ab3034c36b3078` | `da12e082470ee563b3d075d60af86a82e705e475` | `074d9a6b1c93502e8664d5e1abd251e879143398` |
| `tests/run_v5_campaign_persistence_smoke.gd` | `fd85eb9d1191678f31af0aefa16c9ea0d6984250` | `cebc8b653a83db45e6c0f2949986c3c578b5bc29` | `9df6fbed2ea844a4dce6e12c40831497bbe9f74f` |

The follow-up repair additionally changes
`scripts/construction_controller.gd` (blob
`997f43e142fdd172977d076801645796792a2f9a`) so Army exhaustion is checked
before reservation/transaction authority is written.

## 3. Independent original-defect reproduction

The same reviewer probe was run in detached temporary worktrees at
`cd7be2b` and `e2c1096`. It used production `TrainingQueue`/`ArmyRegistry`
restore and create entry points.

On `cd7be2b`:

```text
training: restore=true, old=.000001, new=.000001, collection size=1
army:     restore=true, old=.000001, new=.000001, collection size=1
```

The updated permanent P5 runner was also transplanted without production
changes onto `cd7be2b`. It exited `1` and printed:

```text
V5_STALE_TRAINING_COUNTEREXAMPLE load=true reused=true old=training.blackstone_city.000001
V5_STALE_ARMY_COUNTEREXAMPLE load=true reused=true old=army.player.000001
```

Those counterexamples were encoded with the formal V5 typed DTO codec and a
fresh formal SHA-256, then loaded through `V5CampaignSaveStore.load_and_restore`.
They therefore establish `checksum valid + domain invalid`, not checksum
corruption or a test-only deserializer.

On `e2c1096`, the same rollback values produced `load=false`, `reused=false`.
The original high-water rollback was closed before any authority write.

## 4. New findings and minimal follow-up repair

### F1 — sequence type coercion

Both validators accepted string `"2"` and float `2.7` because the preflight
used `int(...)` without a `TYPE_INT` requirement. The follow-up repair requires
an integer variant before normalization. INT64 maximum is rejected because it
is outside the exact persisted integer domain.

### F2 — successor and exhausted-sentinel boundary

`next == MAX-1` previously created an object and advanced to a value rejected
by the validator, leaving an unsaveable authority state. The repaired rule is:

- exact persisted maximum is a valid exhausted sentinel;
- `next > maximum` is rejected at restore with a structured error and zero
  writes;
- Training creation at the sentinel returns structured
  `TRAINING_QUEUE_COMMIT` and changes no city, resource, order, ledger, or
  sequence state;
- Army allocation is checked before reservation and dispatch-transaction
  mutation, so sentinel failure changes no reservation, registry, garrison,
  ledger, or sequence state.

Permanent assertions cover `MAX-1 restore → create → valid exhausted
snapshot`, followed by a second zero-write create failure for both namespaces.

### F3 — legal empty V1 training history

V1 can retain `last_training_order_day > 0` after the active order is gone.
`e2c1096` required `last_order_day == maximum ordered day` even when
`orders_by_id` was empty, causing `INVALID_V2_CANDIDATE`. The follow-up repair
retains strict equality whenever any persisted order exists, while allowing an
empty migrated collection to preserve the validated V1 history day.

The permanent migration assertion proves:

- V1 source validation succeeds;
- the migration succeeds without modifying the V1 input;
- the V2 queue is empty and retains `last_order_day`;
- live authority remains unchanged.

## 5. High-water, format, ledger, and atomicity review

Training high water is derived from every persisted entry in
`orders_by_id`, including completed orders. Completion clears only
`active_order_id`; there is no per-order erase path. Army high water is
derived from every entry in `armies_by_id`, including `CLOSED` armies. Return,
loss, and settlement mutate the existing record; there is no per-army erase
path. Consequently, a settlement-ledger `army_id` cannot become the sole
surviving reference under the current G2 contract: the corresponding closed
ArmyState remains in `ArmyRegistry`. Result and transaction IDs use separate
namespaces and do not raise either allocator.

The parser accepts only the production formatter's complete
`training.<city>.<sequence>` and `army.<owner>.<sequence>` forms. Prefix
cross-contamination, negative values, non-integers, tail garbage, and
non-canonical formatting fail closed. Current objects empty with a completed
order/closed army, legal gaps, `next == maxUsed`, `next == maxUsed + 1`,
higher next values, non-integer values, and unrepresentable values were
covered by dynamic tests and code review.

Campaign restore validates TrainingQueue and ArmyRegistry before capturing and
applying the candidate. A candidate with one valid and one invalid aggregate
is rejected before `_apply_validated_v5_campaign_snapshot`; the existing
injected mid-apply failure assertion confirms complete rollback if apply
itself fails. City, garrison, queue, registry, ledgers, sequences, save files,
and last valid generation remain unchanged on rejection.

Legal high-water snapshots loaded through the formal disk boundary retained
historical `.000001` and created unique `.000002`. Before the successful
create, insufficient-resource, capacity, and single-active failures were
confirmed zero-write. The existing A/B/C cold-process path still saves,
destroys, restores, advances once, saves a new generation, destroys, and
restores again without ID or progress replay.

Bad latest generations remain immutable and fall back by whole generation;
there is no cross-generation aggregate splice. Future versions block.
V1→V2 migration is read-only and its failure does not publish a V2
generation or modify live state.

## 6. Permanent test discrimination

The repaired P5 runner has 51 explicit assertions. It passes at `fab962c`.
When the same test file is run against:

- `cd7be2b`: exit `1`; both formal rollback generations load and reuse
  `.000001`;
- `e2c1096`: exit `1`; the empty-history migration and upper-bound assertions
  expose the new repair regressions;
- `fab962c`: exit `0`; both rollback generations are rejected, legal higher
  sequences create `.000002`, and all new boundary/zero-write assertions pass.

The tests use formal codec/store/restore boundaries for the stable-ID
counterexamples. They do not accept a helper's own output as proof.

## 7. Regression evidence

Godot binary:

```text
/Applications/Godot.app/Contents/MacOS/Godot
```

All runner commands used:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . -s res://tests/<runner>.gd
```

| Basket | Result |
| --- | --- |
| G2 focused | 6/6; 185 explicit assertions |
| tracked | 33/33; 1739 explicit assertions |
| all-present | 35/35; 1871 explicit assertions; 1905 PASS lines |
| P5 cold workers | A/B/C exit 0/0/0 |
| formal city scene | exit 0 |
| Blackstone scene | exit 0 |
| C0 scene | exit 0 |
| Godot editor scan | exit 0 |
| `git diff --check` | exit 0 |
| final error signatures | 0 |

The +17 assertion change from `5d659243` is entirely within the P5 permanent
runner. G1, G0/P1, V4/C0, scene, and editor guards remain green.

Session logs were collected under
`/tmp/txwzs-v5-g2-review-002.GDjumX/final` during review. They are temporary
session evidence; the durable evidence is the permanent runner, commits, and
this report.

## 8. Protected S1A.2

The eight before/after SHA-256 values are identical:

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

They remain the only eight untracked files and are unstaged. They were not
absorbed by tests, report, planning, or commit. S1A.2 remains
`CONDITIONAL_REUSE_ACCEPTED`.

## 9. Workbook and gate status

The canonical XLSX, Markdown, and five CSV mirrors are byte-identical to the
validated `5d659243` planning checkpoint:

- plan version `1.0.1-v5-g2-repair-001`;
- 13 worksheet XML parts / 13 sheet declarations;
- formula error signatures `0`;
- prior exact workbook-to-CSV comparison remains
  `totalMismatches=0` because every compared artifact has the identical Git
  blob as that checkpoint;
- all exact 16 G2 runtime tasks remain
  `IMPLEMENTED_PENDING_REVIEW`;
- V5-G2 is not VERIFIED;
- V5-P4-T005, P6, P7, G3–G6, and V6 remain NOT_STARTED.

The spreadsheet dependency loader did not return during this review, so no
workbook authoring or redundant re-export was attempted. This report records
the stronger no-change proof rather than claiming a new visual render.

## 10. Required next gate

The unique next gate is:

`V5-G2 Stable-ID Boundary Repair Fresh Independent Review`

A different reviewer must bind `fab962c` and its parent, rerun the formal
rollback/type/migration/exhaustion probes and complete regression basket, then
either accept G2 or issue another repair verdict. G3 must not start first.

Final verdict:

`V5_G2_REPAIRED_PENDING_INDEPENDENT_REVIEW`

# TXWZS V5 S1A.2 Read-Only Reuse Decision 001

## Verdict

Task: `V5-P5-T001`

`CONDITIONAL_REUSE_ACCEPTED`

Accepted for V5:

- the immutable-generation publication pattern;
- preflight validation before directory mutation;
- temporary write, flush, reread, publish, and final reread sequence;
- lowercase SHA-256 payload integrity;
- explicit float64 bit encoding where exact float compatibility is required;
- exclusive writer-lock behavior;
- recovery to a previous valid generation;
- failure propagation and no-overwrite rules;
- S1A.2 V1 reading as an explicit legacy import input.

Not accepted as the V5 writer/schema:

- `EarlyCitySnapshotDiskCodecV1` exact payload shape;
- `EarlyCitySaveStoreV1.load_and_restore()` as a V5 restore entry;
- the early-city-only scope and hard-coded `txwzs_early_city_save` kind;
- direct staging or absorption of the eight protected files in G1.

The precise verdict is: reuse the proven storage mechanics and retain a
read-only V1 compatibility path; do not treat the exact eight files as an
already accepted V5 save implementation.

## Reviewed immutable manifest

| File | SHA-256 |
| --- | --- |
| `scripts/state/early_city_save_store_v1.gd` | `c751fe6c3fcedfb50d7db3c1af16a56b6c2cf0ed1eadeb42c6b849328ebf5d98` |
| `scripts/state/early_city_save_store_v1.gd.uid` | `8ec3208713fc5a9d53246b776a51789fc3f12512ce75443ac20dee3d2ad2ce5b` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd` | `3901e1e8526c4ba76f1d89214b644a4332c06dee60e08defe30fc3071d2154a2` |
| `scripts/state/early_city_snapshot_disk_codec_v1.gd.uid` | `4a9e8af7f5e92ec16dd273d90a0cf2807f31d16999d5469e995beb43333cb91a` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd` | `6912b485c6784c6832ca25883b3179a56e8faa988f18e2418eb534dc8daa03b0` |
| `tests/run_s1a2_early_city_disk_roundtrip_smoke.gd.uid` | `3d13df34c2c938cbe7f50e83bd064b97d8cb4ca79c2310675ef0583dea138e30` |
| `tests/s1a2_early_city_disk_worker.gd` | `6ef1b3a0559679d20c13678f0aef4f5d25c690ae3ce4acc4b5376e08f236eb87` |
| `tests/s1a2_early_city_disk_worker.gd.uid` | `a51e76f958ebce3933ca4091a9acb45ba50047f1ca5e32c6f41c7d3360c96764` |

The files were reviewed and executed without edits. They remain untracked and
unstaged.

## Positive evidence

Fresh all-present execution produced:

- runner exit 0;
- 112 explicit assertions and one summary PASS;
- zero final `FAIL:`, `ERROR:`, `WARNING:`, `Parse Error`, or `SCRIPT ERROR`
  signatures;
- three cold-process worker modes completing through the runner contract;
- no change to the real save-directory fingerprint;
- cleanup of the isolated temporary test directory.

The test matrix covers strict canonical JSON, exact integer decoding, exact
float64 roundtrip, invalid/unknown fields, checksum failure, temporary-file and
target collisions, open/write/flush/rename/final-reread failures, writer-lock
conflicts, multiple invalid generations, previous-generation recovery,
restore-apply failure, cleanup warnings, and cold-process roundtrip.

## Why direct V5 reuse is blocked

The exact V1 codec:

- requires `storage_kind == txwzs_early_city_save`;
- requires `storage_version == 1` and snapshot schema 1;
- accepts exactly the S1A.1 root/city/placement keys and rejects unknown keys;
- stores a single `infantry_count`, not the accepted GarrisonState shape;
- stores the three legacy training fields, not TrainingQueue;
- contains no ArmyRegistry or applied-result ledger;
- supports only Blackstone day 1 through day 6 before battle transactions;
- restores through `validate_early_city_snapshot()` and
  `restore_early_city_snapshot()`.

Those restrictions are correct for a compatibility reader and incompatible
with a direct V5 writer.

## Allowed G2 reuse path

1. Keep the V1 codec/store immutable for legacy detection and import.
2. Read V1 bytes without modifying or deleting the source generation.
3. Validate the V1 snapshot with its original validator.
4. Migrate into a temporary V5 schema candidate.
5. Validate the complete V5 candidate, including garrison, TrainingQueue,
   ArmyRegistry, and settlement ledgers.
6. Publish a new V5 generation through the proven write/flush/reread/publish
   mechanics.
7. Restore live authority only after durable V5 publication and validation.

Extraction or generalization of the store mechanics must occur in a named G2
implementation diff. G1 does not modify or stage the protected files.

## Stop conditions

Stop and require a new review if G2 proposes to:

- overwrite a V1 generation in place;
- call V1 restore and then partially patch V5 fields;
- delete the source after migration;
- accept unknown future versions;
- store Node, pixel, scene, or UI state;
- stage the protected eight files without a separately reviewed adoption diff.

## Status

The read-only reuse decision is complete, but the whole G1 contract package
remains `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`.

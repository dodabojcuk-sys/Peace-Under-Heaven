# TXWZS V5 P5 Campaign Persistence Implementation 001

## Verdict

`V5_P5_IMPLEMENTED_PENDING_G2_INDEPENDENT_REVIEW`

This checkpoint implements `V5-P5-T003` through `T005`. It adds the V5
campaign snapshot, codec, immutable-generation store, read-only V1 migration,
and atomic live restore. It does not accept V5-G2, replace the protected
S1A.2 implementation, or authorize V5-G3.

## Runtime result

- `CampaignSnapshotV2` persists one city identity, exact integer strategic
  time, placements, the unique `GarrisonState`, `TrainingQueue`, the
  collection-based `ArmyRegistry`, and the authoritative settlement ledger.
- The snapshot rejects `Node`, `Resource`, `Callable`, pixel coordinates,
  camera state, selection, and UI state.
- `SaveEnvelopeV1` stores a canonical typed payload, SHA-256 checksum, city
  identity, storage version, and monotonically increasing generation.
- Save uses an exclusive writer lock, private temporary file, flush, checksum
  reread, atomic rename, and final reread. Published generations are
  immutable and older valid generations remain available.
- Load rejects future storage/schema versions instead of silently
  downgrading. Corrupt newest generations explicitly recover the newest prior
  valid generation.
- V1 migration is read-only, deterministic, and idempotent. Legacy infantry
  and training projections migrate only into the existing GarrisonState and
  TrainingQueue sources.
- Restore validates before the first write, captures a complete rollback
  snapshot, applies all authorities, verifies the exact postcondition, and
  restores the pre-apply state when an injected mid-apply failure occurs.

## Verification

| Check | Result |
| --- | --- |
| V5 campaign persistence runner | exit 0; 32 explicit assertions |
| Cold process A / B / C | exits 0 / 0 / 0 |
| V1 migration | active, empty, invalid, repeated-source checks pass |
| Memory codec roundtrip | canonical DTO, checksum, exact typed equality pass |
| Disk generations | save, immutable prior generation, writer lock pass |
| Recovery | corrupt newest, multiple corrupt generations, future version pass |
| Live apply rollback | injected post-city failure restores complete authority |
| Forbidden persistence values | no runtime or presentation state detected |

The three worker executions are independent Godot processes. Process A saves a
marching Army at 2500 ms; process B cold-loads it, advances only the remaining
3500 ms, and saves generation 2; process C cold-loads the exact 6000 ms
`ARRIVED` state without duplicate advancement.

## S1A.2 decision

The G1 decision remains `CONDITIONAL_REUSE_ACCEPTED`. V5 reuses the accepted
ideas—strict validation, immutable generations, reread-before-publish, and
read-only migration input—but not the S1A.2 files or its V1 schema/writer.
All eight protected files remain byte-identical, untracked, and unstaged.

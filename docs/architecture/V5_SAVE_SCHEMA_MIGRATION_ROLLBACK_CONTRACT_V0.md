# V5 Save Schema, Migration, Failure, and Rollback Contract V0

## Status and scope

Task: `V5-P5-T002`

Status: `IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

This contract defines the versioned V5 persistence boundary after the S1A.2
reuse decision. It does not implement a writer, migration command, save UI,
autoload, runtime restore, or V5-G2.

## Version layers

V5 keeps transport and domain versions separate:

```text
SaveEnvelopeV1
  storage_kind: txwzs_campaign_save
  storage_version: 1
  city_id: stable String
  save_sequence: positive exact integer
  payload_json: canonical String
  payload_sha256: lowercase SHA-256

CampaignSnapshotV2
  schema_version: 2
  snapshot_kind: campaign_authoritative
  city_id
  city
  placements
  next_placement_id
  garrison
  training_queue
  army_registry
  settlement_ledger
```

`schema_version == 2` is intentional: schema 1 is the accepted S1A.1
early-city shape and its S1A.2 disk encoding. V5 must not silently reinterpret
schema 1 bytes as schema 2.

## V5 source sections

### City

Persist the existing stable city/economy/construction facts and exact strategic
time. Do not persist `infantry_count` as an independent V2 city field; infantry
comes from `garrison`.

### Garrison

```text
schema_version
city_id
unit_counts_by_definition_id
```

Reservation, unreserved, dispatchable, capacity, and command limit are
validated lifecycle/derived facts, not duplicate saved totals. Any live
reservation must be represented by the transaction/army/settlement records
that own it.

### TrainingQueue

Use the shape and stable IDs from
`V5_TRAINING_QUEUE_SOURCE_STATE_CONTRACT_V0.md`. Do not save the three legacy
training fields independently.

### ArmyRegistry

Use the collection shape from
`V5_ARMY_STATE_COLLECTION_CONTRACT_V0.md`. V5 applies the at-most-one-active
validator without changing the collection schema.

### Settlement ledger

Persist canonical identifiers and committed summaries needed to prevent
duplicate result, transaction, first-clear, reward, casualty, and strategic
time application.

## Forbidden fields

No persistence object may contain:

- `Node`, `NodePath` to a live instance, RID, `Callable`, signal, or scene
  object;
- pixel coordinates, camera state, marker/tween state, hover/selection, panel
  visibility, or translated display text;
- `BattleSession` or a mutable duplicate BattleResult;
- derived read-model values that can drift from source state.

Building `origin_cell` remains an accepted logical grid coordinate from S1A.1;
world/map marker pixels do not.

## Schema 1 to schema 2 migration

Migration input must first pass the immutable schema 1 validator.

Deterministic mapping:

1. copy validated city/economy/time/placement fields;
2. move `city.infantry_count` to
   `garrison.unit_counts_by_definition_id["unit_role.infantry_basic"]`;
3. create TrainingQueue with a deterministic stable order ID only when
   `training_queued_count > 0`; otherwise create an empty collection;
4. set `next_order_sequence` after any migrated order;
5. create an empty ArmyRegistry because accepted S1A.1 scope forbids battle
   transactions and armies;
6. create an empty settlement ledger for the same reason;
7. validate all V2 invariants before any live-state write.

The legacy `last_training_order_day` is used only to validate or construct the
migrated order. It is not retained as a second V2 source field.

## Migration transaction

```text
read immutable source bytes
  -> verify envelope/checksum
  -> validate source schema
  -> migrate into isolated V2 candidate
  -> validate complete V2 candidate
  -> publish and reread new V2 generation
  -> capture live rollback snapshot
  -> apply through authoritative adapters
  -> verify postconditions
  -> mark migration successful
```

No step may overwrite the legacy generation.

## Failure and rollback

| Failure point | Required outcome |
| --- | --- |
| unknown storage/schema version | reject; source and live state unchanged |
| checksum/canonical parse failure | reject or load earlier valid generation |
| source domain validation failure | reject; no V2 file |
| migration mapping failure | reject; no V2 file |
| V2 validation failure | reject; no V2 file |
| write/flush/reread/publish failure | preserve previous valid generations |
| live apply failure | restore complete pre-apply authority snapshot |
| rollback failure | hard error; keep source/V2 bytes; no success marker |
| postcondition mismatch | rollback and report apply failure |

Migration success is not recorded until durable publication, live apply, and
postcondition validation all succeed.

## Generation and recovery rules

- Use immutable, monotonically increasing generations.
- Retain at least the latest two valid generations.
- A temporary file is never loadable.
- Latest invalid generation falls back to the previous valid generation with
  explicit recovery status.
- Unknown future versions are not skipped into a partial load.
- Cleanup failure is a warning only after a new valid generation is durable.
- Writer-lock ownership cannot be stolen or silently deleted.

## Compatibility policy

- V1: read-only import and recovery source.
- V2: only V5 write target.
- Future schema: reject until a named forward migration exists.
- No downgrade from V2 to V1.
- No automatic source deletion after migration.

## G2 acceptance cases reserved by this contract

1. empty and active training queues migrate deterministically;
2. infantry migrates to GarrisonState without duplicate city storage;
3. ArmyRegistry and settlement ledger start empty for valid V1 input;
4. V2 roundtrip preserves stable IDs and exact time/progress;
5. each failure row above leaves source bytes and live authority unchanged;
6. duplicate migration is idempotent and does not publish conflicting records;
7. no forbidden runtime/presentation fields enter canonical payload.

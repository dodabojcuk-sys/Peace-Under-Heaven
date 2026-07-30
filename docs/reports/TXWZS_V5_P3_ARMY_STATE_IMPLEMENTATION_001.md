# TXWZS V5 P3 ArmyState Implementation 001

## Verdict

`V5_P3_IMPLEMENTED_PENDING_G2_INDEPENDENT_REVIEW`

This checkpoint implements `V5-P3-T002` through `T006` against the accepted
ArmyState collection contract. It does not implement a second simultaneous
army, enemy AI, pathfinding, siege, or P4 encounter settlement.

## Runtime result

- `ArmyRegistry` persists `armies_by_id` plus a monotonic sequence. V5 applies
  a one-active-army validator policy without encoding a singleton field.
- The existing Blackstone UI receives a narrow runtime adapter. It can query
  the real city garrison and submit authority commands, but the adapter and UI
  do not own the registry.
- Dispatch first creates a city reservation. Cancellation releases it without
  changing garrison.
- Confirmation atomically creates a stable `army.player.NNNNNN` record,
  removes the committed units from the existing `GarrisonState` once, and
  enters `MARCHING`.
- A confirmation failure restores the complete registry snapshot, including
  its sequence, and retains the reservation for authorized cancellation.
- Progress uses exact integer milliseconds and an expected-progress guard.
  Arrival is the one-time `MARCHING -> ARRIVED` transition.
- Persistent ArmyState contains only stable faction/city/node/route/unit,
  transaction, phase, result-link, duration, and progress facts. Pixel,
  camera, scene, UI, and Node state are excluded.
- The V4-compatible marching projection is a deep-copy read model derived
  from stable IDs and integer progress.

## Verification

| Check | Result |
| --- | --- |
| V5 ArmyState runner | exit 0; 27 explicit assertions |
| Existing Blackstone playable runner | exit 0; 151 explicit assertions |
| Existing V5 garrison runner | exit 0; 27 explicit assertions |
| Existing V5 P2 runner | exit 0; 37 explicit assertions |
| Formal city, Blackstone, and C0 scenes | all exit 0; no final error signatures |
| Godot editor scan | exit 0; no parse/script errors |
| `git diff --check` | exit 0 |

The new runner covers dispatch boundary 10/12, cancel, duplicate confirmation,
single-active enforcement, rollback after garrison failure, stable scene
re-entry, partial progress, duplicate-frame rejection, one-time arrival,
conservation, multiple CLOSED records, persistence exclusions, and a lifted
validator accepting two active records without a schema change.

## Protected boundary

The S1A.2 eight-file basket remains hash-identical, untracked, and unstaged.
No P3 runtime or test depends on those files.

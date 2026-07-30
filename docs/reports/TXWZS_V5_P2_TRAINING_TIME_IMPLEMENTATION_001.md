# TXWZS V5 P2 Training and Time Implementation 001

## Verdict

`V5_P2_IMPLEMENTED_PENDING_G2_INDEPENDENT_REVIEW`

This checkpoint implements `V5-P2-T002`, `T003`, `T005`, `T006`, and
`T007` against the independently accepted G1 contracts. It does not accept
V5-G2 and does not enter P3/P4/P5 scope.

## Runtime result

- `TrainingQueue` is the only live training-order aggregate.
- `training_queued_count`, `training_complete_day`, and
  `last_training_order_day` are read-only compatibility projections.
- The city authority validates unit identity, authoritative batch quantity,
  daily limit, battle lock, supply, recruitment capacity, command limit, and
  food before allocating one stable order ID.
- Food is deducted from the existing city resource truth exactly once after
  the queue commit succeeds; failed orders do not allocate an ID or mutate
  food.
- Only the strategic day boundary may complete an order. Completion writes
  through the existing `GarrisonState`, retains a completed fact, and is
  idempotent.
- A completion-time capacity or command failure is detected before the day
  boundary mutates city state.
- Normal frame time is consumed in exact integer milliseconds. The existing
  seconds field remains a V1 compatibility projection.
- Existing army UI exposes the structured training blocked reason without
  owning or changing queue state.

## Verification

| Check | Result |
| --- | --- |
| V5 P2 training runner | exit 0; 37 explicit assertions |
| Existing P1-D army/tech runner | exit 0; 45 explicit assertions |
| Existing S1A.1 snapshot runner | exit 0; 126 explicit assertions |
| Existing V5 garrison runner | exit 0; 27 explicit assertions |
| Existing C0 city-time runner | exit 0; 59 explicit assertions |
| Formal city, Blackstone, and C0 scenes | all exit 0; no final error signatures |
| Godot editor scan | exit 0; no parse/script errors |
| `git diff --check` | exit 0 |

The P2 runner covers stable identity, atomic resource commitment, duplicate
rejection, 1x/2x/4x, pause one millisecond before a boundary, war block,
presentation switch, replay idempotency, structured capacity/supply failures,
UI projection, and completion-boundary failure injection.

## Protected boundary

The eight S1A.2 files remain untracked and unstaged. Their SHA-256 values are
unchanged from the accepted G1 review. This checkpoint does not import or
modify the protected V1 disk writer.

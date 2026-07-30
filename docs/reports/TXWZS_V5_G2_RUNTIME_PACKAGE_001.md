# TXWZS V5 G2 Runtime Package 001

## Verdict

`V5_G2_IMPLEMENTED_PENDING_INDEPENDENT_REVIEW`

The authorized P2/P3/P4/P5 runtime scope and the automated vertical loop are
implemented. This main-agent verdict is not an independent acceptance and
does not mark V5-G2 `VERIFIED`.

## Checkpoints

| Package | Local checkpoint | Result |
| --- | --- | --- |
| G1 review | `bf32178` | Six contracts independently accepted |
| P2 | `023f11a` | TrainingQueue and strategic time |
| P3 | `a95f510` | Persistent ArmyRegistry and dispatch |
| P4 | `8a6e65a` | Battle facts and authoritative settlement |
| P5 | `ee32d84` | V2 campaign persistence and migration |
| G2 package | this revision | Vertical loop, full regression, planning sync |

## Runtime package

- `TrainingQueue` owns stable orders and is advanced only by city strategic
  time. Legacy training fields are read-only compatibility projections.
- `ArmyRegistry` is a persisted collection. V5 validates at most one active
  army without encoding a singleton data model.
- Dispatch reserves through the authoritative dispatchable query, deducts
  garrison only on confirmation, advances by integer milliseconds, and
  performs each arrival once.
- Existing `BattleSession` remains the sole terminal-fact producer. It has no
  city, garrison, ArmyRegistry, UI, or save writer.
- The coordinator-bound city adapter applies victory, retreat, or defeat once
  and rejects forged, stale, conflicting, or repeated results without partial
  state writes.
- `CampaignSnapshotV2` persists city strategic state, placements, the unique
  garrison, TrainingQueue, ArmyRegistry, and settlement ledger. It rejects
  Node, Resource, Callable, pixel, camera, selection, and UI state.
- `SaveEnvelopeV1` uses canonical typed DTOs, SHA-256, immutable generations,
  writer locking, flush/reread/atomic publish/final reread, future-version
  blocking, corrupt-generation recovery, and complete live-apply rollback.
- V1 migration is deterministic, idempotent, read-only, and maps the legacy
  infantry/training projections only into the existing V5 authorities.

## Automated vertical loop

`tests/run_v5_vertical_loop_smoke.gd` covers:

1. training order and resource commitment;
2. a capacity failure at the strategic-day boundary with settlement,
   garrison, and queue zero writes;
3. successful one-time completion into the unique garrison;
4. reservation, dispatch confirmation, partial march, and arrival;
5. real BattleSession victory facts and authoritative settlement;
6. identical-result replay without a second write;
7. V5 save publication and exact restore into a new runtime;
8. persisted closed Army/result ledger and troop conservation;
9. absence of runtime and presentation objects from the snapshot.

Result: exit 0, 20 explicit assertions.

## Verification

| Check | Result |
| --- | --- |
| V5 focused | 6/6 runners; 166 explicit assertions |
| P5 cold process | A/B/C exits 0/0/0 |
| Tracked basket | 33/33 runners; 1720 explicit assertions |
| All-present basket | 35/35 runners; 1852 explicit assertions; 1886 PASS lines |
| Formal city scene | exit 0 |
| Blackstone scene | exit 0 |
| C0 scene | exit 0 |
| Godot editor scan | exit 0; no parse/script errors |
| Planning workbook | 13/13 sheets rendered; 16 G2 task rows pending review; 5 CSV mirrors exact; 0 formula errors |
| `git diff --check` | exit 0 |
| Final error signature scan | 0 unexpected signatures |

Session evidence: `/tmp/txwzs-v5-g2-full.M4M7T7`.

## Protected and excluded scope

S1A.2 remains `CONDITIONAL_REUSE_ACCEPTED`. Its eight protected files are
byte-identical, untracked, unstaged, and excluded from every checkpoint.

This package does not implement P6 UI, G3/G4, a second troop type, multiple
active armies, enemy strategic AI, siege, a second battle source, V6, push,
deployment, or release.

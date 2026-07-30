# TXWZS V5 P4 Encounter Writeback Implementation 001

## Verdict

`V5_P4_IMPLEMENTED_PENDING_G2_INDEPENDENT_REVIEW`

This checkpoint implements `V5-P4-T002` through `T004`. It reuses the
existing `BattleSession`, `BattleResult`, coordinator binding, result applier,
and committed-result ledger. It does not add another battle fact source,
enemy AI, siege, or save writer.

## Runtime result

- `CombatTransactionCoordinator` can create an army encounter request from
  one `SETTLEMENT_PENDING` ArmyState while retaining the existing bound-city
  ownership handshake.
- BattleSession remains the sole producer of terminal battle facts. It has no
  city, garrison, ArmyRegistry, or save dependency.
- The city settlement adapter verifies coordinator, army, transaction,
  request, session, terminal fact, digest, composition, count, and phase
  identity before any write.
- Victory policy closes the expedition record with survivors stationed at the
  stable target node.
- Retreat policy writes survivors to `RETURNING`, swaps stable source/target
  IDs, resets integer progress, and returns survivors to the existing
  GarrisonState only at authorized arrival.
- Defeat closes the record with an empty survivor composition.
- The result ledger stores the canonical battle fact snapshot and derived
  settlement summary. Identical replay returns that summary; forged,
  conflicting, stale, or repeated writes are rejected.
- Strategic battle duration is applied once by the existing city settlement
  time entry and is not multiplied by UI speed.

## Verification

| Check | Result |
| --- | --- |
| V5 encounter writeback runner | exit 0; 23 explicit assertions |
| Existing C0 result writeback runner | exit 0; 19 explicit assertions |
| Existing C0 city-time runner | exit 0; 59 explicit assertions |
| Existing first-war closed-loop runner | exit 0; 57 explicit assertions |
| Existing Blackstone playable runner | exit 0; 151 explicit assertions |
| Existing V5 ArmyState runner | exit 0; 27 explicit assertions |
| Formal city, Blackstone, and C0 scenes | all exit 0; no final error signatures |
| Godot editor scan | exit 0; no parse/script errors |
| `git diff --check` | exit 0 |

The P4 runner uses three real deterministic sessions for victory, retreat, and
defeat. It also checks the exact fact-key boundary, forged terminal payload,
identical replay, conflicting result ID, return idempotency, and troop
conservation after casualties.

## Protected boundary

The S1A.2 basket remains hash-identical, untracked, and unstaged. P4 does not
read or write its disk format.

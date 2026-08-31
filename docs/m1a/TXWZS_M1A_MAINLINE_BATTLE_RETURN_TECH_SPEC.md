# TXWZS M1A Current Mainline Battle Settlement Return Loop R0

## Scope

M1A closes one player-visible loop on top of
`cafe26cbe544e68ae2f57a3ba12c1976eec13f8a`:

```text
permanent city current-mainline entry
→ existing C0 battle scene and unique attempt
→ read-only result preview
→ one authorized atomic confirmation
→ same permanent city return
```

It reuses the existing north-slope current-mainline battle. It does not add a
new battle mode, a new Save owner, an alternate resource path, or any
construction, road, placement, queue, or army-progression rule.

## Authority map and stop-gate result

| Concern | Existing authority retained | M1A role |
| --- | --- | --- |
| National wood and food | `NationState.commit_resource_transaction` via `ConstructionController` | no new mutation API |
| City time, build slot, first-war state, V5 snapshot | `ConstructionController` | keeps the existing battle-duration settlement rule |
| Battle attempt / commands / facts | `BattleAttemptState`, `BattleSession` | remains attempt-local |
| Unique request, result authorization, return contract | `CombatTransactionCoordinator` | reused unchanged |
| Battle result writeback and idempotency ledger | `ConstructionController.apply_battle_result_atomic` | extends its already-authorized success branch |
| Current-mainline pressure and permanent losses | `CurrentMainlineLevel` | clear only after successful victory settlement |

The required stop gates are clear: there is one national resource owner, one
formal-city coordinator binding, result-ID idempotency, and an existing V5
mainline snapshot. No battle/save/schema migration is required.

## Product and layout contract

The current-mainline action is a child of the existing deadline-and-pressure
top-bar region, not a sixth floating status region. It is shown beside the
current deadline/pressure information and calls the existing
`enter_first_war_battle` gate. Before the battle is pending it explicitly says
when the action opens; while a request, result summary, or cleared state blocks
entry it is disabled with that state visible.

The top bar keeps the five R0C.1 ownership regions. The deadline-and-pressure
region has two text rows plus a separate action row, so the action cannot cover
date/settlement or speed/pause controls. All geometry derives from the viewport;
no font reduction or resolution-specific coordinates are used.

## Settlement and return contract

- Result preview reads `BattleResult` only and performs no city mutation.
- Confirm reaches the existing result-ID ledger and resource transaction once.
- For a formal current-mainline **victory**, the same successful atomic
  settlement marks `CurrentMainlineLevel` cleared before its summary is exposed.
  Retreat and defeat never clear it.
- Existing permanent pressure losses remain recorded; future pressure events
  and pressure modifiers stop once cleared.
- The existing C0 return contract restores the original city scene and input
  after its guard frame. City wall-clock processing stays disabled while C0 is
  visible; the existing settlement applies the deterministic battle duration to
  strategic time once on confirm.
- V5 persists the returned city state, settlement ledger, mainline state, build
  slot, training queue, and army registry. Saving a live C0 attempt is not a
  supported M1A promise because a battle session is attempt-local and is not a
  V5 snapshot field.

## Verification plan

The M1A focused smoke covers the entry, input blocker, preview non-mutation,
one-time confirmation, victory/retreat/defeat semantics, build-slot and
training preservation, V5 cold restore, injected atomic failure, and the
three target layouts. Native captures cover 1152x648, 1280x720, and 1440x900;
the continuous journey is separately recorded from the real formal-city path.

R0C (33 assertions), R0C.1 (57 assertions), formal-scene smokes, editor parse,
and the complete dynamic runner set are re-run after the focused evidence.

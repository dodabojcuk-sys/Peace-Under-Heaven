# TXWZS V4 C0 City Time Settlement Authority Repair 002

## Verdict

`V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_REPAIR_002_READY_FOR_INDEPENDENT_REVIEW`

Repair-002 changes provenance, not another field comparison. `BattleResult` is
now an untrusted mutable display/confirmation DTO; city settlement only derives
from a terminal record frozen by the exact `BattleSession` bound to the active
coordinator.

## Baseline and scope

- Repository: `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Start/end: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`, `origin`, no staged changes.
- Start tracked-patch hash: `193fff8290a57f18d9b30cdb6016f50c8d3a7352ba4e25f52dac3f7cbf9768c2`.
- Godot: `4.5.1.stable.official.f62fdbde1`.
- Evidence: `/tmp/txwzs-v4-c0-authority-repair-002.esAVtU`.
- Repair-002-only diff: 461 lines, SHA-256 `2e0c9440d7ee3a9fa0b060fdceaed1490ebc3ca491fdbea627507fb4181bb4ba`.

Modified only: `battle_session.gd`, `battle_result.gd`,
`combat_transaction_coordinator.gd`, `battle_result_applier.gd`,
`construction_controller.gd`, the C0 city-time/C0A/C0D runners, and this
report. Blackstone, city UI, save format, V4 protected dirty files, S1A.2,
CURRENT_STATE, plans, existing reports, Figma, tick/day/time/reward/combat
numbers, V5 and V6 were not changed. The three V4 protected dirty-file hashes
and all eight S1A.2 hashes are unchanged.

## Why repair-001 failed

The independent review reproduced a true 500-tick result changed to 600 before
repair-001's first snapshot, which advanced 150000ms instead of 125000ms. It
also proved that caller-built result plus matching caller-built dictionary could
write City/Applier. A `BattleResult` snapshot was only self-consistency evidence,
not proof of origin.

## New trust boundary

| Role | Responsibility |
| --- | --- |
| `BattleSession` | Produces terminal facts and freezes them before external completion visibility. |
| Coordinator | Pre-binds the exact session, registers its frozen record, compares optional untrusted payload, and exposes canonical settlement by IDs only. |
| `BattleResult` | Mutable DTO; never authority source. |
| Applier/City | Consume coordinator canonical data; accept no result payload, snapshot, or caller-built plan. |

`BattleSession._complete()` now: calculates terminal values; creates a terminal
result; deep-copies it into private `_terminal_authority_record` along with
copied completion context; marks completed; creates a separate UI DTO; then
emits `terminal_completed(result_payload, terminal_record_copy)`. Getters return
deep copies. The terminal record contains only copied primitives, Dictionary and
Array values and no UI DTO reference.

`create_session()` records `_bound_session`. `mark_result_pending()` requires
that `active_session` is that same completed instance and reads only
`get_terminal_result_snapshot()`, with transaction/session/result identity
checks. It cannot read the public DTO as authority or overwrite an existing
different authority record.

`confirm_result(payload = null)` rejects a mismatching supplied DTO with
`RESULT_PAYLOAD_CONFLICT` and zero writes; confirmation without a payload
consumes the canonical frozen record. The old external sink shapes were removed:

- `Applier.apply(result, request, snapshot)` is now
  `apply_authorized(coordinator, transaction_id, result_id)`.
- `City.apply_battle_result_atomic(result, request, snapshot)` is now
  `apply_battle_result_atomic(coordinator, transaction_id, result_id)`.

The City asks the named coordinator for its own bound record. A caller can only
request IDs, so knowing IDs can at most trigger the canonical plan; it cannot
replace time, outcome, reward, or other plan fields. Caller-built records and
snapshots have no sink parameter.

## P0 regression evidence

The city-time authority runner now proves:

1. A completion-signal callback changes exposed `finished_tick` from 500 to
   600 and appends to its nested route array. Internal terminal authority remains
   500; payload confirmation rejects with zero settlement writes; canonical
   confirmation advances 125000ms exactly once.
2. Mutating a nested getter-returned record leaves the later terminal getter
   unchanged.
3. A different `BattleSession` with the correct session ID cannot register,
   because it is not the pre-bound instance.
4. A non-finalized self-made result plus a self-consistent DTO snapshot cannot
   write City or Applier. Their new ID-only calls return empty and preserve state.
5. Outcome mutation, exact duplicate, and same-result-ID changed-payload
   conflict retain their required zero-write/idempotent behavior.

At first City write, the bound session, completion, terminal record, IDs,
optional DTO comparison, reservation, request snapshots, outcome/count bounds,
and first-clear state have already been verified. Existing city order is
unchanged: canonical tick time first, force/defense/enemy changes next, reward
and first-clear next, then summary/ledger and return lifecycle. No settlement
write reads caller DTO data.

## Validation

| Check | Result |
| --- | --- |
| City-time authority runner | exit 0, 49 assertions |
| C0A/C0D/C0E/C0F | exit 0; 26/19/14/33 assertions |
| P1E closed-loop/gate | exit 0; 57/28 assertions |
| All tracked runners | 27/27, 1491 assertions, zero error signatures |
| All current runners | 29/29, 1652 assertions; untracked city-time 49, S1A.2 112 |
| Headless editor | exit 0, no signatures |
| C0 scene headless | exit 0, `BATTLE-C0` identity |
| Formal launcher | exit 0; CITY PID 14861; `main@64f37bd`, dirty=1 |
| UID/path scan and `git diff --check` | no missing UID; clean |

The static caller search finds no production City/Applier sink that accepts
`BattleResult + snapshot`. DTO snapshot use remains confined to Session record
creation and DTO comparison tests.

## Risks, rollback, and review focus

Underscore fields are GDScript encapsulation, not a hostile-code sandbox. This
repair establishes the normal production-domain boundary; a malicious in-process
mod/code-injection threat model is separately out of scope. Terminal authority
is memory-only; save/reload of an in-flight pending authority remains a future
boundary.

For rollback, restore only the eight allowed pre-repair files from
`/tmp/txwzs-v4-c0-authority-repair-002.esAVtU/pre_repair/` and remove this
report. Do not restore the worktree.

Independent review should independently rerun both P0 public paths, inspect the
sink search, check no time write precedes a remaining reject path, and verify
runtime identity. Blackstone stays paused; V4 UI remains `REPAIR_REQUIRED`,
T-V4-003 is `NOT PASS`, and V5 remains `FROZEN`.

`V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_REPAIR_002_READY_FOR_INDEPENDENT_REVIEW`

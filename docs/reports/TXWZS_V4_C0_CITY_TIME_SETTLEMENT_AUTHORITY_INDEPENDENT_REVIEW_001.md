# TXWZS V4 C0 City Time Settlement Authority Independent Review 001

## Verdict

`REJECT_V4_C0_TIME_AUTHORITY_REVIEW_IMPLEMENTATION_DEFECT`

The authority repair rejects a payload mutated after pending registration, but it does not establish an authority boundary. Two public production-call paths commit a forged duration and payload. No implementation, test, scene, resource, Figma, plan-state, or existing report was changed in this review.

## Scope and identity

- Repository: `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Start/end: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`, remote `origin`, no staged changes.
- Start tracked-patch SHA-256: `193fff8290a57f18d9b30cdb6016f50c8d3a7352ba4e25f52dac3f7cbf9768c2`.
- Godot: `4.5.1.stable.official.f62fdbde1`.
- Evidence: `/tmp/txwzs-v4-c0-authority-independent-review-001.HKJLCk`.

The expected V4 three-file hashes remained `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957`, `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393`, and `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac`. The S1A.2 eight protected files and prior reports retained their start/end hashes. The only workspace write of this review is this report.

## Repair scope reviewed

The repair changes seven implementation/test files plus its report:

| Purpose | Files |
| --- | --- |
| Snapshot | `scripts/combat/battle_result.gd` |
| Transaction authority | `scripts/combat/combat_transaction_coordinator.gd` |
| Settlement entry | `scripts/combat/battle_result_applier.gd`, `scripts/construction_controller.gd` |
| Runners | `tests/run_c0_city_time_settlement_smoke.gd`, `tests/run_c0a_battle_transaction_smoke.gd`, `tests/run_c0d_result_writeback_smoke.gd` |
| Repair record | `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_AUTHORITY_REPAIR_001.md` |

Unrelated pre-existing Blackstone V4 and S1A.2 dirty files were untouched. `git diff --check` is clean.

## Authority path and findings

Intended chain:

`BattleSession._complete()` -> public `BattleSession.result` -> public `CombatTransactionCoordinator.mark_result_pending()` -> `_pending_result_authority` -> `BattleResultApplier.apply()` -> `ConstructionController.apply_battle_result_atomic()`.

`BattleResult` exposes mutable fields at `scripts/combat/battle_result.gd:5-20`; `get_authority_snapshot()` simply returns those values at `:47-69`. `BattleSession` exposes `result` and `run_until_complete()` returns it (`scripts/combat/battle_session.gd:19-30`, `:134-139`). No immutable authority record is created at completion.

### P0-1: finalize-to-snapshot window is exploitable

`mark_result_pending()` obtains its first snapshot only when a caller invokes it, from the mutable current result (`scripts/combat/combat_transaction_coordinator.gd:265-283`). Although `advance_battle_tick()` calls it synchronously in one production path (`:164-172`), the supported public `create_session()` / `run_until_complete()` / `mark_result_pending()` flow has an intervening mutation window; current runners use it (`tests/run_c0_city_time_settlement_smoke.gd:320-325`).

The temporary audit harness `/tmp/txwzs-c0-authority-public-bypass-audit.gd` (final SHA-256 `bccef8a58fd1ba0a8fbea3fc92fd752ddf130db685a86dfef35710414f6d4f14`) used only public APIs. It created a real city reservation, request and session, produced genuine victory tick 500, changed `finished_tick` to 600 before the first `mark_result_pending()`, and called `confirm_result()`.

```text
AUTHORITY_AUDIT_WINDOW={"canonical_tick_before_mutation":500,"forged_tick_registered":600,"mark_pending_accepted":true,"confirm_nonempty":true,"settled_duration_ms":150000,"settled_finished_tick":600,"last_error":""}
```

The forged 600 tick is recorded as authority and advances city time 150000ms, rather than the real 125000ms. This fails the atomic finalize-to-authority requirement.

### P0-2: City and Applier accept a self-consistent forged snapshot

`BattleResultApplier.apply()` accepts a caller-provided `authority_snapshot` and only checks result equality (`scripts/combat/battle_result_applier.gd:13-38`). `ConstructionController.apply_battle_result_atomic()` accepts the same caller-provided dictionary and same equality condition (`scripts/construction_controller.gd:1854-1865`). Neither proves coordinator origin.

The same harness used a real active request/reservation, built an internally consistent fake 600-tick victory and passed its own snapshot directly to City, then separately to Applier. Both committed:

```text
AUTHORITY_AUDIT_DIRECT_CITY={"pending_accepted":true,"confirm_nonempty":true,"settled_duration_ms":150000,"settled_finished_tick":600}
AUTHORITY_AUDIT_APPLIER={"pending_accepted":true,"confirm_nonempty":true,"settled_duration_ms":150000,"settled_finished_tick":600,"last_error":""}
```

This is not private-container injection or a UI workaround. The new snapshot is a caller-constructible capability. The later-mutation check in coordinator `confirm_result()` (`combat_transaction_coordinator.gd:197-208`) and committed-result idempotency (`construction_controller.gd:1866-1882`) are correct but too late: both P0 payloads become alleged authority before those checks.

City time arithmetic remains tied to whichever accepted `finished_tick` it receives (`construction_controller.gd:1926-1945`), so the trust failure reaches time, production ordering, reward and ledger settlement.

## Verification

| Evidence | Result |
| --- | --- |
| City-time runner | 49/49 PASS |
| C0A transaction runner | 26/26 PASS |
| C0D writeback runner | 19/19 PASS |
| All tracked `tests/run_*_smoke.gd` | 27/27 runners, 1491 PASS, no error signatures |
| Current untracked city-time and S1A.2 runners | both PASS; 49 and 113 assertions |
| Headless editor scan | exit 0; no error signatures |
| C0 scene headless smoke | exit 0; `BATTLE-C0` runtime identity |
| `./RUN_CURRENT_TXWZS.command` | exit 0; CITY PID 13140; `main@64f37bd`; dirty=1 |
| `git diff --check` | clean |

The normal city-time runner's authority test registers pending authority before it mutates the result (`tests/run_c0_city_time_settlement_smoke.gd:320-356`) and tests an unfinalized direct result without providing a self-consistent snapshot (`:388-417`). Its pass therefore cannot establish either P0 requirement.

## Required next repair boundary (not implemented)

1. Bind final-result registration to real simulation completion in one coordinator-owned, non-interruptible transition; no public caller can choose the first snapshot after completion.
2. Remove caller-controlled snapshot capability from City and Applier, or replace it with a coordinator-owned settlement record with transaction/session/result identity checks at every write.
3. Preserve duplicate idempotency while rejecting pre-registration, late-registration, replay and direct City/Applier submissions.
4. Add deterministic P0 regressions proving zero writes to city time, rewards, resources, summary, first-clear state and committed ledger for both reproduced paths.

Do not resume Blackstone V4 visual work, mark `T-V4-003` PASS, or start V5. This review stops without a repair.

`REJECT_V4_C0_TIME_AUTHORITY_REVIEW_IMPLEMENTATION_DEFECT`

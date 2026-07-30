# TXWZS V4 C0 City Time Settlement Authority Independent Review 002

## Verdict

`REJECT_V4_C0_TIME_AUTHORITY_REVIEW_002_IMPLEMENTATION_DEFECT`

Independent read-only review. The only workspace write is this report.

## Identity and diff

- Repo: `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Start/end: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`; no staged changes.
- Current patch SHA-256: `14e7c8a933bfe7212ffb2c87ab60ff187ce4a19e12213cd7ad6f9f3456f2d934`.
- Godot: `4.5.1.stable.official.f62fdbde1`.
- Evidence: `/tmp/txwzs-v4-c0-authority-independent-review-002.sxDCK8`.

The preserved pre-repair copies independently reconstruct the claimed 461-line
Repair-002 diff and SHA-256 `2e0c9440d7ee3a9fa0b060fdceaed1490ebc3ca491fdbea627507fb4181bb4ba`.
V4 protected hashes and the Repair-002 report start hash match. `git diff --check`
is clean.

## Test delta

Repair-002 is in allowed files. No V4 protected, S1A.2, UI, Figma, save, number,
plan, or old-report change was found. The authority runner remains 49 assertions
because it replaces tests: new signal/deep-copy cases replace old post-pending
DTO mutation. Duplicate, lifecycle, and cross-day checks remain. The new direct
sink test only uses a coordinator without terminal authority; it does not test
a second real completed coordinator against an active target City.

## Session freeze

`BattleSession._complete()` freezes its copied terminal record before `completed`,
the separate UI DTO, and `terminal_completed` (`battle_session.gd:368-426`). The
signal/getter mutation test correctly preserves internal tick 500. This is not
the rejection cause.

## P0 reproduced: caller-selected coordinator replacement

`ConstructionController.apply_battle_result_atomic(coordinator, transaction_id,
result_id)` accepts a caller's coordinator and asks it whether it points to this
City (`construction_controller.gd:1854-1869`). City has no pre-bound coordinator.
Public `CombatTransactionCoordinator.configure()` replaces its City target
(`combat_transaction_coordinator.gd:18-20`); Applier forwards the same caller
coordinator (`battle_result_applier.gd:13-29`).

Temporary harness `/tmp/txwzs-c0-coordinator-replacement-audit.gd` SHA-256
`4b3f6ced949916716e3e5bf61de0f8b2b30b57e1c8543bf064ff87b712637613` exited 0.
Using public production APIs only, it created target City A/coordinator A pending
and source City B/coordinator B completed at 500 ticks. Both first transactions
naturally have matching `battle-000001` IDs. It then called public
`B.configure(target_city_A)` and submitted B plus B's IDs to target City's sink,
then repeated through Applier.

```text
COORDINATOR_REPLACEMENT_DIRECT={"owner_and_replacement_transaction_match":true,"settlement_nonempty":true,"settled_duration_ms":125000,"target_state_changed":true,"target_reservation_after":{},"via_applier":false}
COORDINATOR_REPLACEMENT_APPLIER={"owner_and_replacement_transaction_match":true,"settlement_nonempty":true,"settled_duration_ms":125000,"target_state_changed":true,"target_reservation_after":{},"via_applier":true}
```

B settled and cleared A's reservation. No Dictionary forgery, private-container
injection, test-only entry, or code injection was used. This is a P0 first-submit
write: City accepts a self-consistent but caller-selected trust anchor.

## Atomicity, statistics, and repair boundary

No old `BattleResult + snapshot` sink remains. Session fields and existing City
reservation/count/outcome checks are correct, but result/request provenance comes
from the wrong coordinator. Time, reward, force, first-clear, defense/enemy,
summary and ledger can therefore be written from B. The in-flight guard is too
late to cure missing coordinator identity verification.

The claimed 27/27 tracked / 1491 and 29/29 current / 1652 counts agree with
manifests and test delta, but author logs were not reused. The confirmed Gate-C
P0 stops the long suite as required.

Minimal repair only: City must pre-bind the exact coordinator at reservation
activation and verify object identity/lifecycle at settlement; active coordinator
reconfigure/replacement must fail; Applier must obtain the target City's bound
coordinator instead of receiving caller choice. No repair was made.

Blackstone remains paused; V4 UI `REPAIR_REQUIRED`; T-V4-003 `NOT PASS`; V5
`FROZEN`.

`REJECT_V4_C0_TIME_AUTHORITY_REVIEW_002_IMPLEMENTATION_DEFECT`

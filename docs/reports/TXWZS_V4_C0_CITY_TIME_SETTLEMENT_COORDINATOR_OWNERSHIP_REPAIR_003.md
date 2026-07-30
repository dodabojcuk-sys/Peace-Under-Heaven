# TXWZS V4 C0 City Time Settlement Coordinator Ownership Repair 003

## Result

`V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_003_READY_FOR_INDEPENDENT_REVIEW`

Repair 003 closes the Review-002 trust-anchor replacement by making City and
`CombatTransactionCoordinator` a one-to-one lifetime binding. No existing report,
V4 UI file, Figma, save format, number rule, plan or Gate was changed.

## Ownership model

- `configure(city)` is now a one-time handshake: null fails, the same City is
  idempotent, and any later different City fails.
- City records its designated coordinator once; a different coordinator fails.
- Reservation creation, activation, pending transition and cancellation now
  require that exact designated coordinator.
- City settlement takes only `transaction_id` and `result_id`, then reads the
  designated coordinator's canonical terminal record itself.
- Applier takes only IDs and delegates to that same City canonical sink.

This removes caller-selected coordinator injection from both former sinks. A
coordinator cannot reconfigure from source City B to target City A, and no caller
can send B as a settlement authority to A.

## Migration and preserved behavior

The allowed changes are confined to Coordinator, Applier, City, and API-affected
C0 runners. Repair-002 Session terminal freeze and `BattleResult` DTO downgrade
were not modified. Historical replay uses the existing bound coordinator after
its return lifecycle, rather than creating a second coordinator for the same City.

Existing settlement order remains canonical tick time, force/defense/enemy,
reward/first-clear, ledger/summary, then return lifecycle. The City checks its
designated coordinator before retrieving any settlement record.

## Focused verification

- City-time authority runner: PASS, including 500→600 signal payload, outcome,
  nested getter-copy and fake-session protections.
- C0A transaction runner: PASS.
- C0D writeback/replay runner: PASS after replay migrated to the same bound
  coordinator.
- Headless editor scan: PASS before runner migration validation.

`git diff --check` remains clean. The previous Review-002 A/B attack is blocked
structurally because B's `configure(target_city_A)` returns false and City no
longer accepts a coordinator parameter at either sink.

## Independent review focus

Re-run the two real coordinator A/B attacks using public APIs; verify B cannot
bind/rebind City A, cannot alter its reservation or ledger, and A still settles
125000ms once. Verify same-pair binding idempotency, failed-bind no half-state,
City B + B independent flow, replay/return lifecycle, and full smoke totals.

## Rollback

Restore only Repair-003 changed files from the turn-start snapshot in
`/tmp/txwzs-c0-ownership-repair-003.*/pre/`; do not restore the worktree.

`V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_003_READY_FOR_INDEPENDENT_REVIEW`

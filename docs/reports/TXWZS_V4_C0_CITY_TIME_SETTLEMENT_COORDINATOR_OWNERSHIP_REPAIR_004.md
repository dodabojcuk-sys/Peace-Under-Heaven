# TXWZS V4 C0 City Time Settlement Coordinator Ownership Repair 004

## Result

`V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_004_READY_FOR_INDEPENDENT_REVIEW`

Repair 004 closes the half-binding sequence reproduced by Independent Review
003. City and `CombatTransactionCoordinator` now establish one synchronous,
two-way object binding. A one-sided City bind is no longer a public production
entry, failed binding leaves the coordinator unbound, and every reservation
mutator plus the canonical settlement sink verifies both object references.

This is implementer self-verification only. It does not mark C0 independently
verified, resume Blackstone, pass T-V4-003, freeze V4, or start V5.

## Scope

Modified only:

- `scripts/combat/combat_transaction_coordinator.gd`
- `scripts/construction_controller.gd`
- `tests/run_c0_city_time_settlement_smoke.gd`

Added only:

- `docs/reports/TXWZS_V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_004.md`

Not modified:

- `scripts/combat/battle_session.gd`
- `scripts/combat/battle_result.gd`
- `scripts/combat/battle_result_applier.gd`
- battle tick, day length, city time speed, force, reward or production values
- save format and S1A.2 files
- Blackstone scene/script/test
- UI, Figma, CURRENT_STATE, Gate, master plan, V5/V6
- existing implementation, repair or independent-review reports

No `reset`, `checkout`, `clean`, `stash`, `git add`, commit, push, publish or
deployment was performed.

## Start identity

- Working directory:
  `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Branch: `main`
- HEAD: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Upstream: `origin/main`
- Behind/ahead: `0/29`
- Staged files: `0`
- Repair 004 start tracked patch SHA-256:
  `ab3bdf882853115fd0fa5340df0d2eef47a2d70d1efb6c5ce59938abc63a6771`
- Turn snapshot:
  `/tmp/txwzs-c0-ownership-repair-004.7dfrcx/pre/`

The existing dirty and untracked worktree was preserved.

## Root cause

Repair 003 committed the two ownership edges in independent public calls:

```text
City.bind(coordinator)
coordinator.configure(City)
```

City accepted the coordinator without requiring the coordinator to point back to
that City. A caller could therefore produce:

```text
City A -> coordinator A
coordinator A -> City B
City B -> coordinator A
```

City reservation and settlement validation compared only the coordinator object
against City's pointer. It did not check the reverse coordinator-to-City edge,
so self-consistent City B terminal authority could write City A.

## Atomic binding implementation

`CombatTransactionCoordinator.city_controller` was replaced by the internal
`_city_controller`. Read-only inspection is available through
`get_bound_city()` and `is_bound_to_city(city)`.

`configure(city)` now performs this synchronous sequence:

1. reject null or incompatible City objects;
2. accept the same pair only when the Applier exists and City confirms the same
   exact coordinator;
3. reject any later different City when already bound;
4. construct the candidate Applier without committing it;
5. tentatively point the coordinator at the candidate City;
6. call City's internal
   `_accept_combat_transaction_coordinator_binding(coordinator)`;
7. City accepts only if the coordinator already points back to that exact City;
8. on rejection, coordinator clears its tentative pointer;
9. verify the two-way postcondition, then commit the Applier.

There is no signal, `await`, callback or domain write inside the handshake. The
former public `bind_combat_transaction_coordinator` method no longer exists.
Calling City's internal acceptance step without the reverse pointer fails with
zero City change.

The resulting invariant is:

```text
city.is_combat_transaction_coordinator_bound(coordinator)
==
city.designated coordinator is coordinator
and coordinator.is_bound_to_city(city)
```

## Enforcement points

The two-way invariant is checked before:

- `reserve_battle_force`
- `activate_battle_reservation`
- `mark_battle_result_pending`
- `cancel_battle_reservation`
- `apply_battle_result_atomic`

The settlement sink checks the invariant before retrieving terminal authority,
therefore before the first city-time or other domain write.

No unbind, rebind, reset-owner or transaction-lifecycle path was added.
Transaction cancellation, return and acknowledge continue to clear transaction
state only; lifetime ownership remains.

## Formal attack regressions

`run_c0_city_time_settlement_smoke.gd` now contains both Independent Review 003
attack families.

### Half-binding and cross-City terminal result

The runner verifies:

- the former public City bind method is absent;
- direct one-sided internal acceptance without a reverse pointer fails and
  leaves City unchanged;
- the coordinator then binds only Source City;
- Source-bound coordinator cannot reserve force in Target City;
- Source City creates a real request, real BattleSession and canonical terminal
  result;
- submitting Source IDs through both Target City and a Target Applier returns
  empty and leaves Target state/ledger unchanged;
- Source reservation remains `RESULT_PENDING`;
- Source coordinator then legally settles Source City exactly once for
  `125000ms`.

### Second coordinator and rollback

The runner also verifies:

- same City/coordinator bind is idempotent;
- a second coordinator cannot bind an owned City;
- failed attacker remains unbound;
- attacker reserve, activate, pending and cancel all fail;
- City time, full City state, owner and reservation are unchanged;
- failed attacker can subsequently bind a fresh City;
- original owner can still cancel its reservation.

Successful execution increased the runner from `49` to `59` explicit PASS
assertions. Source contains 12 new `_check` call sites; 10 execute on the normal
successful path and two are setup-failure sentinels.

## Repair-only diff and hashes

Repair-only combined diff SHA-256:

`4ee9ebd119b90be2e8aae796b12be4ff4dd1d8acddb3bc1792b02b2638ae937b`

| File | Before SHA-256 | After SHA-256 |
|---|---|---|
| `scripts/combat/combat_transaction_coordinator.gd` | `0e2c9bc8c391e273825b57b477a8bdee3b565cde31cf14b956f1102ad65b185a` | `51720c5849039eb139fb40e5b77b1d9b90ef297765552f9af4292bcffa4fad5e` |
| `scripts/construction_controller.gd` | `baebc9210633e6ad59b9c66ff66962b6e463fd7c8738c4178021ea48d6c8e240` | `2712794392af1b7e78e8bdb5d050db7e1e7f8e3ad9dfd860cc188131726b7b13` |
| `tests/run_c0_city_time_settlement_smoke.gd` | `f5bd8a743195d0e9e2e9a466b2cfb7f42f27678eda83c85cc0e812bb78b2f838` | `9626e188692e5a41fe6693aa8303e27b16a605273f86bf539e9a7b541eda0cd1` |

## Verification

Godot:

`4.5.1.stable.official.f62fdbde1`

### Focused runner

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2 \
  --script res://tests/run_c0_city_time_settlement_smoke.gd
```

Result:

- exit `0`
- `59` explicit PASS
- error signatures `0`
- log:
  `/tmp/txwzs-c0-ownership-repair-004.7dfrcx/run_c0_city_time_settlement_smoke_final.log`

### Complete current-worktree regression

Every current `tests/run_*_smoke.gd` was independently launched through Godot
headless.

| Set | Runners | Explicit PASS | Nonzero | Error signatures |
|---|---:|---:|---:|---:|
| Git tracked | 27 | 1491 | 0 | 0 |
| Current untracked | 2 | 171 | 0 | 0 |
| All present | 29 | 1662 | 0 | 0 |

Final per-runner command, timestamps, exit codes and counts:

`/tmp/txwzs-c0-ownership-repair-004.7dfrcx/full_regression_final_summary.tsv`

The error scan covered:

`FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR`

### Scene and editor smokes

The following final production code state checks exited `0` with zero error
signatures:

- headless main scene: `res://scenes/blank_map.tscn`
- headless C0 scene: `res://scenes/c0_battle_graybox.tscn`
- headless editor scan

Logs:

- `/tmp/txwzs-c0-ownership-repair-004.7dfrcx/main_scene_smoke.log`
- `/tmp/txwzs-c0-ownership-repair-004.7dfrcx/c0_scene_smoke.log`
- `/tmp/txwzs-c0-ownership-repair-004.7dfrcx/editor_scan_final.log`

`git diff --check` passed.

## Protection

Unchanged hashes:

| Protected item | SHA-256 |
|---|---|
| `scenes/blackstone_expedition_mvp.tscn` | `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957` |
| `scripts/mvp/blackstone_expedition_mvp.gd` | `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393` |
| `tests/run_blackstone_playable_mvp_smoke.gd` | `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac` |
| `scripts/combat/battle_session.gd` | `8b7cc9a9f3a9d247efc3484c03ad91b13970c2c89223fc8f147e4829b1071e0c` |
| `scripts/combat/battle_result.gd` | `5371f4131e38df0daa40e16037c5db8ff20cf741448d2ce53519d8c17ad92897` |
| Independent Review 003 report | `ce83ae6523255234f8b4e815385941bbff77716bd9b9527aed422a92ab9d923c` |

## Rollback

Restore only the three Repair 004 files from:

`/tmp/txwzs-c0-ownership-repair-004.7dfrcx/pre/`

Then remove only this Repair 004 report. Do not restore or clean the broader
worktree and do not delete user pre-existing dirty or untracked work.

## Independent review focus

The next reviewer should use fresh objects and public production APIs to verify:

1. former public City bind is absent;
2. a one-sided acceptance attempt is zero-write;
3. failed City acceptance leaves coordinator unbound;
4. failed coordinator can bind a fresh City;
5. same pair is idempotent;
6. coordinator cannot replace its City;
7. second coordinator cannot replace City's owner;
8. every reservation mutator verifies both object edges;
9. Source terminal result cannot write Target through City or Applier;
10. Source legally settles `125000ms` once after the attack;
11. ownership persists across cancel, return, acknowledge, idle and replay;
12. no caller-selected coordinator reappears at the settlement sink.

Only an independent acceptance may clear the C0 ownership and city-time gate.

`V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_REPAIR_004_READY_FOR_INDEPENDENT_REVIEW`

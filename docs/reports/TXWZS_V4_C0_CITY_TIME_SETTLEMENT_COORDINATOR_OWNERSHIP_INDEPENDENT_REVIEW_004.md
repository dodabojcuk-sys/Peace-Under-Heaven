# TXWZS V4 C0 City Time Settlement Coordinator Ownership Independent Review 004

## Verdict

`V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_INDEPENDENT_REVIEW_004_ACCEPTED`

Repair 004 independently blocks the Independent Review 003 half-binding and
cross-City settlement sequence. No production, test, scene, state, Blackstone,
UI, Figma, or V5 file was modified by this review. The only workspace write is
this report; the independent harness and all logs are under `/tmp`.

## Independence and scope

This was a read-only independent review. Repair 004's prior test logs and its
conclusion were not used as execution evidence. A new harness was created at
`/tmp/txwzs-repair004-review.DXXGmW/independent_ownership_review_004.gd`; it
constructs fresh City scenes and coordinators through existing public production
APIs. It does not read or write private fields, patch production objects, or
add a production test entry. It finished with exit `0`, `15` independent PASS,
and zero error signatures:

`/tmp/txwzs-repair004-review.DXXGmW/07_independent_harness.log`

No `git add`, commit, push, reset, checkout, clean, stash, Blackstone resume,
CURRENT_STATE/Gate edit, UI/Figma action, or V5 action occurred.

## Baseline

| Item | Observed |
|---|---|
| Working directory | `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2` |
| Branch / HEAD | `main` / `64f37bda130397f08cdd012609dc2d3a5f5c6b99` |
| Upstream | `origin/main`; behind `0`, ahead `29` |
| Godot | `4.5.1.stable.official.f62fdbde1` |
| Staged | `0` |
| Start worktree | 10 pre-existing tracked modifications and the recorded planning/report/S1A.2 untracked set; preserved unchanged by this review |

The start and final porcelain manifests, commands, and Godot version are in
`/tmp/txwzs-repair004-review.DXXGmW/01_baseline.txt` and
`/tmp/txwzs-repair004-review.DXXGmW/12_final_checks.txt`.

### Repair-only reconstruction and protection

The Repair 004 pre-image directory exists at
`/tmp/txwzs-c0-ownership-repair-004.7dfrcx/pre/`. Its three pre-image hashes
and the current hashes exactly match the Repair 004 report:

| File | Before SHA-256 | After SHA-256 |
|---|---|---|
| `scripts/combat/combat_transaction_coordinator.gd` | `0e2c9bc8c391e273825b57b477a8bdee3b565cde31cf14b956f1102ad65b185a` | `51720c5849039eb139fb40e5b77b1d9b90ef297765552f9af4292bcffa4fad5e` |
| `scripts/construction_controller.gd` | `baebc9210633e6ad59b9c66ff66962b6e463fd7c8738c4178021ea48d6c8e240` | `2712794392af1b7e78e8bdb5d050db7e1e7f8e3ad9dfd860cc188131726b7b13` |
| `tests/run_c0_city_time_settlement_smoke.gd` | `f5bd8a743195d0e9e2e9a466b2cfb7f42f27678eda83c85cc0e812bb78b2f838` | `9626e188692e5a41fe6693aa8303e27b16a605273f86bf539e9a7b541eda0cd1` |

Plain `diff -u` of those three pre-images against the current files, concatenated
in the report's stated order, reproduces the reported repair-only SHA-256:
`4ee9ebd119b90be2e8aae796b12be4ff4dd1d8acddb3bc1792b02b2638ae937b`.
The reconstructed patch and reconciliation output are:

- `/tmp/txwzs-repair004-review.DXXGmW/diff_plain_absolute.patch`
- `/tmp/txwzs-repair004-review.DXXGmW/13_diff_hash_reconciliation.txt`

The following protection hashes remained unchanged and equal the Repair 004
report: Blackstone scene/script/smoke, `BattleSession`, `BattleResult`, and
Independent Review 003 (`ce83ae6523255234f8b4e815385941bbff77716bd9b9527aed422a92ab9d923c`).

## Source review

The legacy public `bind_combat_transaction_coordinator` entry has no production
definition or call site. `CombatTransactionCoordinator.configure(city)` is the
public binding entry. It rejects incompatible candidates, accepts a same-pair
call only if City confirms the pair, rejects a different City once bound,
tentatively points to the candidate City, invokes City's internal acceptance,
clears the temporary pointer on rejection, then commits the Applier only after
the two-way postcondition.

City's internal acceptance requires `coordinator.is_bound_to_city(self)` before
it can store its designated coordinator. `is_combat_transaction_coordinator_bound`
then requires both object references. Therefore a City cannot obtain a one-sided
owner, a second coordinator cannot claim an owned City, and a rejected second
coordinator remains available for a fresh City.

`reserve_battle_force`, `activate_battle_reservation`,
`mark_battle_result_pending`, and `cancel_battle_reservation` all gate on the
two-way predicate. `apply_battle_result_atomic` gates on the same predicate
before requesting terminal authority. Before its first City-domain write it
also obtains terminal authority, rejects duplicate/in-flight submissions, checks
the terminal result, transaction, reservation, request, and mission invariants,
validates duration, and computes planned rewards; only then does it advance City
time and commit settlement state. `BattleResultApplier` still delegates only to
that City sink by transaction/result ID; it has no caller-selected coordinator.

`cancel_request`, return completion, and formal acknowledge clear transaction or
result-lifecycle state only. They do not add unbind/rebind behavior; the harness
verified binding after cancellation, return guard completion, and acknowledge.

Source and call-site evidence:

- `/tmp/txwzs-repair004-review.DXXGmW/05_detailed_source_lifecycle.txt`
- `/tmp/txwzs-repair004-review.DXXGmW/06_snapshot_apis.txt`

## Independent public-API reproduction

### Path A: former half-binding sequence

Fresh City A, City B, and coordinator A were created. City A exposed no public
one-sided bind method and remained an unbound, zero-change City. Coordinator A
then bound City B atomically. It could not reserve City A, but created a real
City B transaction, reservation, `BattleSession`, and terminal result.

The result completed at exactly `500 × 250ms = 125000ms`. Submission through
both City A's canonical sink and `BattleResultApplier.new(City A)` returned
empty. City A's complete public state snapshot, active reservation, committed
summary for that result, resources, rewards, pending state, and time remained
unchanged. City B alone accepted the legal submission and advanced exactly
`125000ms` (the harness records the City B settlement delta). Exact duplicate
returned the original summary; a same-result-ID modified payload produced
`RESULT_PAYLOAD_CONFLICT`; return protection and completion did not reapply
time or clear binding.

### Path B: second coordinator

Fresh City A first bound coordinator A and held A's real reservation. Coordinator
B's bind, reserve, activate, pending, cancel, and settlement attempts all failed.
City A's full public state snapshot—including reservation, pending status,
ledger-visible committed IDs/summary, time, resources, and original owner—was
identical before and after the attack. B had no residual City reference and then
successfully bound a fresh City B. Coordinator A subsequently settled its own
legal result once and could create/cancel a later reservation without losing its
permanent City A ownership.

### Formal lifecycle

A separate fresh City used `enter_first_war_battle` and the formal C0 scene. Its
canonical result, exact duplicate, return contract, return completion, and
`acknowledge_first_war_result` were exercised. The latter three lifecycle steps
did not apply settlement again or erase the formal coordinator-to-City ownership.

## Regression and final checks

| Check | Exit | Result | Log / manifest |
|---|---:|---|---|
| Independent Path A/B/formal harness | 0 | 15 PASS; 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/07_independent_harness.log` |
| `tests/run_c0_city_time_settlement_smoke.gd` | 0 | 59 PASS; 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/08_run_c0_city_time_settlement_smoke.log` |
| All Git-tracked `tests/run_*_smoke.gd` | 0 | 27 runners; 1491 PASS; 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/09_tracked_regression.tsv` |
| All current-worktree `tests/run_*_smoke.gd` | 0 | 29 runners; 1662 PASS; 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/10_all_present_regression.tsv` |
| Formal main scene (`--headless --quit-after 120`) | 0 | 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/12_main_scene_smoke.log` |
| Formal C0 scene (`--headless res://scenes/c0_battle_graybox.tscn --quit-after 120`) | 0 | 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/13_c0_scene_smoke.log` |
| Godot headless editor scan (`--headless --editor --quit`) | 0 | 0 signatures | `/tmp/txwzs-repair004-review.DXXGmW/14_headless_editor_scan.log` |
| `git diff --check` | 0 | clean | `/tmp/txwzs-repair004-review.DXXGmW/15_git_diff_check.log` |

The complete per-runner command output, exit codes, assertion counts, and
signature scan are in `/tmp/txwzs-repair004-review.DXXGmW/11_regression_summary.txt`.
The full invocation/protection status record is
`/tmp/txwzs-repair004-review.DXXGmW/12_final_checks.txt`.

## Remaining risk and boundary

This acceptance covers the two known coordinator-ownership failure sequences,
canonical City settlement isolation, and current smoke/scene/editor regression.
It does not expand into a new C0 architecture audit or claim untested future
ownership APIs. It makes no player-experience, Blackstone visual, V4 UI, Figma,
or V5 implementation change.

`V4_C0_CITY_TIME_SETTLEMENT_COORDINATOR_OWNERSHIP_INDEPENDENT_REVIEW_004_ACCEPTED`

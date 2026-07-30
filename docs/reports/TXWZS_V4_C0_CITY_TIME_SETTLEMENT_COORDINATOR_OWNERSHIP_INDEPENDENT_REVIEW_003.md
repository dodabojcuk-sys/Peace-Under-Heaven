# TXWZS V4 C0 City Time Settlement Coordinator Ownership Independent Review 003

## Verdict

`REJECT_V4_C0_COORDINATOR_OWNERSHIP_REVIEW_003_IMPLEMENTATION_DEFECT`

Repair 003 does not establish a one-to-one lifetime binding. A public, one-sided
City binding can be followed by a successful coordinator binding to a different
City. The resulting coordinator is accepted as the designated authority by both
Cities and can settle one City using the other City's canonical terminal result.

This is a reproduced P0 trust-root defect. Per the review stop rule, the complete
tracked/all-present long regression and GUI smokes were not run. At the user's
follow-up request, the existing C0 ownership/settlement specialty runners,
necessary C0/P1E regressions and final-state editor scan were run; all passed.
Those results do not negate the independently reproduced missing attack case.

## Independence and permissions

This was an independent read-only review. The Repair 003 author's PASS claims and
logs were not reused as review evidence. Production source, tests, scenes and
configuration were not modified. The only workspace write is this report.

Two temporary harnesses and their logs were created under `/tmp`. They call only
existing public production APIs. They do not inject private fields, patch
production code, or add a test-only production entry.

No `reset`, `checkout`, `clean`, `stash`, `git add`, `commit`, `push`, UI/Figma
work, Blackstone resume, Gate change, or V5 work was performed.

## Start identity

- Working directory:
  `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Branch: `main`
- HEAD: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Upstream: `origin/main`
- `origin/main...HEAD`: behind `0`, ahead `29`
- Godot: `4.5.1.stable.official.f62fdbde1`
- Staged files: `0`
- Current tracked patch SHA-256:
  `ab3bdf882853115fd0fa5340df0d2eef47a2d70d1efb6c5ce59938abc63a6771`
- Tracked `tests/run_*_smoke.gd`: `27`
- All-present `tests/run_*_smoke.gd`: `29`
- Independent evidence directory:
  `/tmp/txwzs-c0-ownership-review-003.CJV2bI`

The dirty worktree present at review start was preserved. Tracked changes were:

- `scenes/blackstone_expedition_mvp.tscn`
- `scripts/combat/battle_result.gd`
- `scripts/combat/battle_result_applier.gd`
- `scripts/combat/battle_session.gd`
- `scripts/combat/combat_transaction_coordinator.gd`
- `scripts/construction_controller.gd`
- `scripts/mvp/blackstone_expedition_mvp.gd`
- `tests/run_blackstone_playable_mvp_smoke.gd`
- `tests/run_c0a_battle_transaction_smoke.gd`
- `tests/run_c0d_result_writeback_smoke.gd`

The untracked manifest included the planning package, existing C0/V4 reports and
reviews, S1A.2 state scripts, the untracked C0 city-time runner, S1A.2 runners
and UID sidecars. The exact start status and manifest are recorded in
`/tmp/txwzs-c0-ownership-review-003.CJV2bI/start_identity.txt`.

## Baseline and protection checks

The live identity is consistent with the recorded Repair 003 candidate. No
baseline mismatch was found before the P0 reproduction.

| Protected item | SHA-256 |
|---|---|
| `scenes/blackstone_expedition_mvp.tscn` | `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957` |
| `scripts/mvp/blackstone_expedition_mvp.gd` | `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393` |
| `tests/run_blackstone_playable_mvp_smoke.gd` | `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac` |
| `scripts/combat/battle_session.gd` | `8b7cc9a9f3a9d247efc3484c03ad91b13970c2c89223fc8f147e4829b1071e0c` |
| `scripts/combat/battle_result.gd` | `5371f4131e38df0daa40e16037c5db8ff20cf741448d2ce53519d8c17ad92897` |
| Repair 003 report | `cf0723ee06e82b9212f3a7267022b2a30ec3879105ace9c2c48781dd7220fa82` |

The Session terminal-freeze and BattleResult DTO files match the Repair 002 end
state recorded for this candidate. Repair 003 did not change their current
hashes. The P0 stopped the broader end-to-end protected-file revalidation.

## Repair-003-only diff reconstruction

The Repair 003 snapshot pointer resolves to
`/tmp/txwzs-c0-ownership-repair-003.8DppdB/pre/`. Five pre-repair files exist and
are distinguishable from current files:

| File | Pre SHA-256 | Current SHA-256 | Rebuilt diff SHA-256 |
|---|---|---|---|
| `scripts/combat/combat_transaction_coordinator.gd` | `1d8df34e482f5621cf19f7f90a474e890d97855b848ef4ab03bc888028c4072e` | `0e2c9bc8c391e273825b57b477a8bdee3b565cde31cf14b956f1102ad65b185a` | `2962f148f74ed2cac3b01e61a07d3decb88f86469376511ca3806de71669acc0` |
| `scripts/combat/battle_result_applier.gd` | `6c4d9b4193c72b4774d502bc38fb0d44c5aee7519eb5c26b3add003d47e48e63` | `a0f6cd3d164b3e80b9f46bb1a5c38019023d7f7c408f69d660e6d683b57a1e56` | `30bd8f127c3e9d09e30fc68925615ffa18d36741e13e410d3131632c55015551` |
| `scripts/construction_controller.gd` | `a429f60bf360e3666022be60b42f312a3385ff22364870bbd8821f5821984b75` | `baebc9210633e6ad59b9c66ff66962b6e463fd7c8738c4178021ea48d6c8e240` | `ba32932a63a659a7fef7af85b63904e6ebdd8c836be22e66e705ca42f00baa53` |
| `tests/run_c0_city_time_settlement_smoke.gd` | `6dbcdad8b115ea1abdfd1201d485ed026aa863e3ec2c63df15569f939e4ae490` | `f5bd8a743195d0e9e2e9a466b2cfb7f42f27678eda83c85cc0e812bb78b2f838` | `d639070af60a50237b39d9c55ef159ce186176d5910e83e0b846b09ba1fe8184` |
| `tests/run_c0d_result_writeback_smoke.gd` | `3950aab03619f7c9908a6605868c0e6d2c35ab73354bc52f279fae3205fc1d9f` | `c33ffba335789166332fb5c1a1011472389c722b59278aa3bedecaa6fbac96c1` | `41974ed3ded12011fa121eb13a22e5889a2383804b60474b4c26166dd3667dad` |

`tests/run_c0a_battle_transaction_smoke.gd` is also modified for the new API, but
Repair 003's pre snapshot omitted it. Therefore the complete Repair-003-only diff
cannot be reconstructed from that snapshot alone. This is a report-evidence gap,
but it does not make the security result inconclusive: the current candidate
itself is independently exploitable.

## Repair 003 report evidence gaps

The implementation report does not contain Git identity, start/end status,
repair-only diff, protection hashes, commands, exit codes, log paths,
runner/assertion totals, post-repair A/B transcripts, a final-state editor scan,
tracked/all-present full regression, or launch smokes.

Its statement that the prior attack is “structurally blocked” is contradicted by
the current public API. Its editor scan explicitly predates the final runner
migration, so it is not final-state evidence.

For the two snapshot-covered modified runners, `_check(` counts are unchanged:

- C0 city-time: `36 -> 36`
- C0D writeback: `21 -> 21`

Current C0A has `27` checks, but its pre-repair copy is absent. No current C0
runner contains the required two-City half-binding or cross-City coordinator
attack. Repair 003 therefore migrated API coverage without adding a regression
that exercises its core ownership claim.

## Binding state machine reconstructed from source

### Intended composition

Normal C0 composition calls `coordinator.configure(city)` from
`c0_battle_graybox.gd:501` and `:514`. The retreat path creates a coordinator and
calls `configure(self)` at `construction_controller.gd:919-922`.

`CombatTransactionCoordinator.configure()` currently implements:

1. null City: reject;
2. same `city_controller`: return true;
3. any already stored different City: reject;
4. otherwise call City's public
   `bind_combat_transaction_coordinator(self)`;
5. on success, store the City and create the Applier.

See `combat_transaction_coordinator.gd:18-29`.

City's public bind implements:

1. null coordinator: reject;
2. same designated coordinator: return true;
3. any already designated different coordinator: reject;
4. otherwise store the coordinator and return true.

See `construction_controller.gd:1783-1793`.

### Defect

The two methods commit their own halves independently. City bind does not verify
`coordinator.city_controller == self`, and coordinator configure does not verify
that it was not previously designated by another City. No rollback or completed
bidirectional postcondition exists.

This reachable state is therefore valid to the implementation:

```text
City A._designated_coordinator = coordinator A
coordinator A.city_controller = City B
City B._designated_coordinator = coordinator A
```

Reservation creation, activation, pending and cancellation only compare the
caller object with City's one-sided designated pointer
(`construction_controller.gd:1796-1867`). They do not verify the reverse
coordinator-to-City edge. Transaction reset/return clears transaction state but
does not repair this split ownership (`combat_transaction_coordinator.gd:243-274`).

The City settlement sink similarly reads its one-sided designated coordinator
without checking that coordinator's `city_controller` is the same City
(`construction_controller.gd:1888-1897`). The remaining transaction, result and
snapshot checks are self-consistency checks, not origin checks.

## Public API reproduction 1: simultaneous reservation authority

Harness:

- Path: `/tmp/txwzs-c0-ownership-half-binding-audit.gd`
- SHA-256:
  `d6e7fa96fdce84ac93dcce32ad251da0029d971d0b175c56d2ee74b57825d2c6`
- Log:
  `/tmp/txwzs-c0-ownership-review-003.CJV2bI/half_binding_harness.log`
- Start: `2026-07-30T07:40:10+0800`
- End: `2026-07-30T07:40:12+0800`
- Exit: `0`

Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2 \
  --script /tmp/txwzs-c0-ownership-half-binding-audit.gd
```

Public API sequence:

1. `City A.bind_combat_transaction_coordinator(A)` returned true.
2. `A.configure(City B)` returned true.
3. `A.create_request(10)` created a live City B reservation.
4. `City A.reserve_battle_force(10, A)` also created a live City A reservation.
5. Both reservations were `RESERVED`, both had ID `battle-000001`, and both
   changed domain state.

The log reports:

```text
both_cities_hold_live_reservations_for_same_coordinator=true
coordinator_a_bound_city_is_b=true
OWNERSHIP_HALF_BINDING_DEFECT_CONFIRMED=true
```

This already violates one-to-one ownership, half-bind rollback and cross-City
reservation isolation.

## Public API reproduction 2: cross-City canonical settlement

The stronger replay used two fresh Cities and one fresh coordinator. It
half-bound target City A, fully bound the coordinator to source City B, created
matching real reservations, ran a real BattleSession to its terminal result, put
both reservations into `RESULT_PENDING`, then called City A's ID-only sink.

Final harness:

- Path:
  `/tmp/txwzs-c0-ownership-half-binding-settlement-audit.gd`
- SHA-256:
  `da6675c19c5a4e3fb1bb92a3985048efe08e3429abf7b0b150e956b8b6638c8b`
- Log:
  `/tmp/txwzs-c0-ownership-review-003.CJV2bI/half_binding_settlement_harness_final.log`
- Start: `2026-07-30T07:42:27+0800`
- End: `2026-07-30T07:42:28+0800`
- Exit: `0`

Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2 \
  --script /tmp/txwzs-c0-ownership-half-binding-settlement-audit.gd
```

Observed:

```text
target_half_bound=true
source_full_bound=true
coordinator_bound_city_is_source=true
transaction_ids_match=true
source_pending=true
target_pending=true
settlement_nonempty=true
settled_duration_ms=125000
target_state_changed_by_source_authority=true
source_state_unchanged_by_target_submit=true
target_reservation_after={}
source_reservation_after={phase: RESULT_PENDING, ...}
OWNERSHIP_HALF_BINDING_SETTLEMENT_DEFECT_CONFIRMED=true
```

City A consumed its reservation and advanced time by `125000ms` using the
terminal authority held by the coordinator bound to City B. City B remained
pending. Thus Repair 003 reproduces the same class of trust-anchor replacement
through a new public entry: caller-selected coordinator was removed from the
settlement signature but remains selectable through the one-sided bind.

An earlier draft of this second harness produced GDScript type-inference parse
errors and was excluded. A corrected intermediate run settled `86000ms` because
the route was configured after activation; it also demonstrated the defect but
exited `2` due the harness's stricter `125000ms` expectation. The final harness
sets the route through the public coordinator API before activation and is the
evidence used above. All attempts and metadata remain in the independent
evidence directory.

## Second coordinator rejection and zero-write check

This check separates the simple same-City replacement case from the half-binding
defect above. It first establishes a normal `City A + coordinator A` binding and
a live A reservation, then attacks with a fresh coordinator B.

- Harness: `/tmp/txwzs-c0-second-coordinator-zero-write-audit.gd`
- SHA-256:
  `00eb8a82b08f2579d489fcb963f986f09522e93438986062696e767178073b64`
- Log:
  `/tmp/txwzs-c0-ownership-review-003.CJV2bI/second_coordinator_zero_write_harness.log`
- Start: `2026-07-30T08:19:05+0800`
- End: `2026-07-30T08:19:07+0800`
- Exit: `0`

Observed:

```text
second_coordinator_bind_rejected=true
second_coordinator_remains_unbound=true
second_coordinator_reserve_rejected=true
second_coordinator_activate_rejected=true
second_coordinator_pending_rejected=true
second_coordinator_cancel_rejected=true
reservation_unchanged=true
city_state_unchanged=true
city_time_unchanged=true
owner_can_still_cancel=true
SECOND_COORDINATOR_ZERO_WRITE_PASS=true
```

Thus the ordinary `B.configure(City A)` path is fail-closed once City A and
coordinator A are normally bound, and B's rejected reserve/activate/pending/cancel
calls do not change time or the owner's reservation. This local success does not
cover the public one-sided bind sequence; that separate sequence still creates
split ownership and commits cross-City settlement.

## Existing specialty and necessary regression

All commands used:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2 \
  --script res://<runner>
```

| Runner | Start | Exit | Explicit PASS | Error signatures |
|---|---:|---:|---:|---:|
| `run_c0_city_time_settlement_smoke.gd` | `08:19:24` | `0` | `49` | `0` |
| `run_c0a_battle_transaction_smoke.gd` | `08:19:26` | `0` | `26` | `0` |
| `run_c0d_result_writeback_smoke.gd` | `08:19:26` | `0` | `19` | `0` |
| `run_c0e_combat_contract_smoke.gd` | `08:19:27` | `0` | `14` | `0` |
| `run_c0f_battle_exit_return_smoke.gd` | `08:19:28` | `0` | `33` | `0` |
| `run_p1e_first_war_closed_loop_smoke.gd` | `08:19:29` | `0` | `57` | `0` |
| `run_p1e_first_war_gate_smoke.gd` | `08:19:30` | `0` | `28` | `0` |

All times are `2026-07-30 +0800`. The exact start/end timestamps and per-runner
log paths are in
`/tmp/txwzs-c0-ownership-review-003.CJV2bI/targeted_regression_summary.tsv`.
All seven runners exited `0`; total explicit PASS lines were `226`; the scan for
`FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR` found `0`.

The final candidate was also scanned with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2
```

It ran from `08:19:45` to `08:19:49`, exited `0`, and had `0` error signatures.
Log:
`/tmp/txwzs-c0-ownership-review-003.CJV2bI/final_headless_editor_scan.log`.

These tests prove existing legal and simple rejection paths remain green. None
contains the half-binding order or cross-City settlement used by the independent
harness, so their PASS status cannot close the P0.

## Public API and canonical sink audit

Repair 003 did improve the surface signatures:

- City sink:
  `apply_battle_result_atomic(transaction_id, result_id)`
- Applier:
  `apply_authorized(transaction_id, result_id)`
- Applier delegates to City's single sink and does not accept a coordinator,
  BattleResult, snapshot, Dictionary or settlement plan.

No legacy settlement signature, compatibility wrapper, default coordinator
argument, `callv` bypass, or coordinator global registry was found in the current
GDScript search.

These improvements do not close the trust boundary. The public
`bind_combat_transaction_coordinator()` is itself a caller-selected authority
entry, and the City sink trusts its result without a reverse-edge check.

The first settlement mutation is the time advance at
`construction_controller.gd:1984-1986`, followed by force/resource/ledger writes
at `:2076-2103`. Before that first write, the code validates IDs, terminal
payload consistency, reservation phase and counts, but does not validate:

```text
designated_coordinator.city_controller == self
```

The attack therefore passes every self-consistency check and reaches the
canonical write block.

## Gate results

| Gate | Result | Evidence |
|---|---|---|
| A — identity and candidate baseline | Pass for defect review | Live identity and hashes recorded |
| B — one-time bidirectional binding | **P0 fail** | Public half-binding reaches two Cities |
| C — public API and unique sink | Partial | ID-only sink is unique; public one-sided bind remains an authority-selection entry |
| D — Review 002 attack replay | **P0 fail** | City A accepts and commits City B coordinator authority |
| E — lifecycle/cross-City isolation | **P0 fail** | Same coordinator holds two live reservations |
| F — legal 125000ms flow after attacks | Not reached as acceptance gate | Attack itself commits 125000ms to the wrong City |
| G — first-write owner validation | **P0 fail** | Reverse City identity is unchecked before time write |
| Targeted/necessary regressions | Pass | 7 runners, 226 explicit PASS, 0 error signatures |
| Final-state editor scan | Pass | Exit 0, 0 error signatures |
| Complete tracked/all-present regression and GUI smokes | Not run | P0 remained after requested targeted runs |

Because the P0 causes real time, reservation, result-summary and ledger writes,
ordinary runner PASS results cannot make this candidate acceptable.

## Findings by severity

### P0 — one-sided public bind permits cross-City settlement

`ConstructionController.bind_combat_transaction_coordinator()` commits City
ownership without proving the coordinator points back to that City. The same
coordinator can subsequently configure another City and obtain authority over
both. With naturally colliding per-City transaction IDs and matching legitimate
state, one City's canonical terminal result settles the other City.

### P1 — reservation mutators validate only one edge

Reserve, activate, pending and cancel compare exact coordinator object identity,
but only against City's pointer. They do not require
`coordinator.city_controller == self`. The exact object comparison therefore
gives false confidence in a split-brain graph.

### P1 — required ownership attack is absent from formal regression

The API-migrated runners do not exercise a public one-sided bind followed by a
different-City configure, two live reservations, or cross-City settlement. The
Repair 003 report's core “structurally blocked” claim was not executable evidence.

## Minimal repair boundary

The next repair should remain limited to ownership composition and its focused
tests:

1. Replace the independently callable two-step commit with one atomic binding
   operation controlled by the composition owner.
2. Do not expose a standalone City operation that can permanently commit only
   one edge.
3. Commit both object references only after both sides can accept the pair; on
   any failure, leave both sides unchanged.
4. Make the postcondition explicit:
   `city.designated_coordinator == coordinator` and
   `coordinator.city_controller == city`.
5. Verify that exact two-way postcondition on every reservation mutator and at
   the City settlement sink before retrieving authority.
6. Add formal public-API regressions for the two reproduced harnesses, including
   failed-bind zero residue, coordinator recovery to a fresh City, two-City
   isolation, and zero writes before/pending/committed phases.

Do not change BattleSession terminal freeze, BattleResult DTO, tick duration,
city-time arithmetic, rewards, force values, save format, Blackstone, UI/Figma,
Gate state or V5 as part of that repair.

## Unverified due mandatory stop

- Remaining lifecycle matrix after return, acknowledge, idle and committed replay
- Independent legal City A + A and City B + B complete flows
- Full Repair 002 tamper matrix
- Full tracked and all-present runner totals/assertions
- Main scene, C0 entry and `RUN_CURRENT_TXWZS.command` smokes
- UID/resource scan and complete final protection matrix

These omissions do not weaken the rejection: the current public API already
performs the forbidden cross-City domain write.

## End state

End identity remained:

- Branch: `main`
- HEAD: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Upstream: `origin/main`
- Behind/ahead: `0/29`
- Staged files: `0`
- Tracked patch SHA-256:
  `ab3bdf882853115fd0fa5340df0d2eef47a2d70d1efb6c5ce59938abc63a6771`

The tracked patch and protected hashes are identical to the start snapshot. The
only new workspace path from this review is this allowed report. `git diff
--check` passed, and the untracked report's trailing-whitespace check passed.
Exact end status is in
`/tmp/txwzs-c0-ownership-review-003.CJV2bI/end_identity.txt`.

No implementation was repaired. Blackstone remains paused; V4 UI remains
`REPAIR_REQUIRED`; T-V4-003 remains `NOT PASS`; V5 remains `FROZEN`.

`REJECT_V4_C0_COORDINATOR_OWNERSHIP_REVIEW_003_IMPLEMENTATION_DEFECT`

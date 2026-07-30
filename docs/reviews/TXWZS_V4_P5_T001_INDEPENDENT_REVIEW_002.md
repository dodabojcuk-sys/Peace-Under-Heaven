# TXWZS V4-P5-T001 Independent Review 002

## Verdict

`ACCEPT_V4_P5_T001_READY_FOR_USER_STAGE_TEST`

`V4-P5-T001-REPAIR-001` 的三个既有 IMPORTANT 已由本轮独立证据关闭。本轮没有发现修复补丁引入的新 BLOCKER 或 IMPORTANT。

本结论只放行 `V4-P6-T001` 用户实体试玩，不代表用户已经接受，不标记 `T-V4-003` 或 `V4-G6` 通过，不冻结或提交 V4，不启动 V5/V6。

## Review identity

- Review ID: `RVW-V4-P5-002`
- Reviewer task: `/root`
- Delegation source thread: `019f9683-4880-7490-9c72-9a62bb47769e`
- Repository: `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Review date: `2026-07-29`
- Evidence directory: `/tmp/txwzs-v4-p5-review-002.KefVHg`
- Godot: `4.5.1.stable.official.f62fdbde1`
- Formal launcher: `./RUN_CURRENT_TXWZS.command`

## Baseline gate

The candidate baseline matched before review:

| Field | Observed |
| --- | --- |
| Branch | `main` |
| HEAD | `64f37bda130397f08cdd012609dc2d3a5f5c6b99` |
| Upstream | `origin/main` |
| Ahead / behind | `29 / 0` |
| Staged | `0` |
| Tracked V4 patch SHA-256 | `b3aec131692613e55058d38136907f1e637265d9cf8c4e7cb59211c786b32428` |
| Exact patch evidence | `/tmp/txwzs-v4-p5-review-002.KefVHg/05a_current_tracked_v4.patch` |

The three reviewed files matched the supplied hashes:

| File | SHA-256 |
| --- | --- |
| `scenes/blackstone_expedition_mvp.tscn` | `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957` |
| `scripts/mvp/blackstone_expedition_mvp.gd` | `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393` |
| `tests/run_blackstone_playable_mvp_smoke.gd` | `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac` |

The start control state also matched:

- `V4-P5-T001` was the only `READY`;
- `T-V4-003 = NOT_RUN`;
- `V4-P6-T001/T002 = NOT_STARTED`;
- `V4-G6 = NOT_STARTED`;
- all 44 V5 tasks were `NOT_STARTED`;
- V4 remained `IMPLEMENTED_PENDING_REVIEW`.

No `BLOCKED_V4_P5_T001_REVIEW_002_BASELINE_MISMATCH` condition occurred.

## Required material

The review fully read the repository-provided `AGENTS.md`, `CURRENT_STATE.md`, all five `docs/handoffs/*.md`, the master planning XLSX/Markdown/CSV/ZIP family, `TXWZS_MASTER_PLAN_STATE_SYNC_001.md`, the prior independent review, the repair report, the three V4 files, and the relevant launcher/input/city dependencies.

Repository-wide presence checks confirmed that `README`, `README.md`, `DECISIONS.md`, `CHANGELOG.md`, and `TXWZS_LIVING_GAME_DESIGN_V2.md` do not exist in this checkout. Their absence was recorded rather than replaced with inferred content. Evidence: `25_required_file_presence.log`.

The repairer's old PID `69937` was first bound to `main@64f37bd` and `dirty=1`, then its Godot window was normally closed. All GUI evidence below came from a new formal process.

## Finding closure

### A. Right-click cancellation — CLOSED

Code review:

- the battlefield root handles pending right-click in `_gui_input`;
- `DispatchBar`, its background, close button, and all four percentage buttons route `gui_input` to `_cancel_pending_order_from_mouse`;
- Esc and the close button converge on the same pending-order cancellation transition;
- cancellation clears `_pending_order`, hides `DispatchBar`, clears route visuals, and transitions to `IDLE`;
- cancellation does not write `_garrisons`, create a march, resolve arrival, or deduct troops;
- handled events are accepted or marked handled, while non-pending right-click is not consumed by this scene;
- the city root `_input` owns Esc while the V4 scene is open and deliberately does not compete for mouse input.

Independent automation:

- the V4 runner dispatched battlefield, bar-background, and percentage-button right-click through the real `Viewport.push_input` / `SceneTree` input path;
- it did not substitute a direct cancellation call for those interaction assertions;
- left-click 25/50/75/100 dispatch remained functional.

Independent real window:

- battlefield blank;
- `DispatchBar` background;
- 25%, 50%, 75%, and all buttons;
- Esc;
- close button.

All eight cancellation paths returned to a clean non-pending state with the original garrison count, no march, no deduction, and no settlement. Fresh screenshots: `gui-05` through `gui-09`.

### B. `result_panel` is presentation only — CLOSED

- Production reads of `result_panel.visible` occur only in `_refresh_result_presentation`.
- Command legality and state transitions depend on `outcome`, `_interaction_state`, and marching state, not panel visibility.
- Independent tests forced the panel visible while `outcome == NONE`; model-legal commands remained legal.
- Independent tests forced the panel hidden while an outcome existed; commands remained rejected.
- Presentation refresh restored panel visibility from `outcome`.
- No second outcome or interaction-state truth was introduced.

### C. `_garrisons` is the sole garrison-location truth — CLOSED

- Production code contains no `current_node_id`, replacement scalar location field, or implicit default source.
- All route queries pass an explicit `source_node_id`.
- empty, enemy, and zero-garrison sources are rejected;
- partial dispatch leaves nonzero garrisons at both source and destination when the rules produce that result;
- two nonzero friendly garrison nodes independently open legal routes;
- the most recent arrival does not invalidate an older nonzero source;
- garrison counts and `◆ 可发兵` presentation derive from `_garrisons`;
- the single-position `◆ 我军` marker was removed;
- no parallel troop-position field was introduced.

Automation covered both-source routing, stale pending revalidation, zero source rejection, transfer conservation, and removal of the old marker. The real window independently showed camp `5` plus reinforcement `11`, and opened legal routes from both nodes.

## Full V4 chain review

The exact current patch (`05a_current_tracked_v4.patch`, 2,738 lines) and the three current files were reviewed in full.

The reviewed chain satisfies:

- source ownership and route legality are explicit;
- percentage dispatch is rounded, bounded, and revalidated at commit;
- invalid input fails without state mutation;
- source deduction occurs once at command creation;
- an active march blocks concurrent commands without stopping the original march;
- progress is clamped to `[0, 1]`, is monotonic, and only the active unresolved object advances;
- arrival is guarded by unique ID and `resolved`, then removes the completed object before settlement;
- repeated confirm, repeated advance, and post-outcome input do not repeat deduction, reinforcement, reward, or settlement;
- UI emits intents and projects state; it does not own garrison, outcome, or interaction truth;
- V4 remains scene-local prototype state and does not create a competing persistent V5 world model;
- no debug bypass, fake PASS branch, dead legacy location field, or hidden default route source was found.

## Automated validation

All commands used Godot 4.5.1 and returned exit code 0.

| Check | Time (Asia/Shanghai) | Result |
| --- | --- | --- |
| `Godot --headless --path <repo> -s res://tests/run_blackstone_playable_mvp_smoke.gd` | 16:52:52–16:52:54 | 126 explicit assertions + 1 summary; 0 failure |
| all Git-tracked `tests/run_*_smoke.gd` | 16:53:18–16:53:43 | 27/27 runners; 1490 explicit assertions + 27 summaries |
| `Godot --headless --editor --path <repo> --quit` | 16:54:41–16:54:47 | editor scan PASS |
| main scene, `--quit-after 2` | 16:54:47–16:54:48 | PASS |
| Blackstone scene, `--quit-after 2` | 16:54:48 | PASS |
| C0 scene, `--quit-after 2` | 16:54:48–16:54:49 | PASS |
| resource/UID/static audit | 16:56:04–16:56:05 | 45 resource refs, 0 missing; 64 UID files, 0 duplicate |
| `git diff --check` | 16:56:05 | exit 0 |
| error-signature scan | after all runs | `FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR = 0` |

No runner was missing, no assertion count decreased, and no runner consisted only of a summary PASS.

Primary logs: `07_v4_runner.log` through `13_static_project_checks.log`.

## Fresh formal-window validation

The formal entry produced:

- launcher: `./RUN_CURRENT_TXWZS.command`;
- new PID: `77081`;
- title: `天下无战事 · CITY · main@64f37bd · DEBUG · DIRTY`;
- branch/commit/dirty: `main / 64f37bd / 1`;
- runtime log: `/tmp/txwzs-runtime-52e107a4de6701b4/current.log`;
- startup and runtime error signatures: none.

Independent player-path results:

1. all required right-click positions, Esc, and close-button cancellation passed without changing garrisons;
2. 50% support dispatched 5 and left 5 at camp;
3. arrival produced camp 5 and reinforcement 11, with both nodes showing real garrisons and `◆ 可发兵`;
4. legal routes opened independently from camp and reinforcement;
5. a later 50% camp attack dispatched 3, left 2, and reached the outpost once;
6. a concurrent reinforcement command was rejected with a readable “抵达前不能再次下令” message while the original march continued;
7. the attack arrival settled once;
8. the identical post-arrival state remained after more than four seconds;
9. return to city and re-entry reset the V4 scene to camp 10, no pending order, no march, and no old route highlight.

Twenty-one new game screenshots (`gui-01` through `gui-18`, including four separate `gui-07` percentage-button variants) and the raw runtime log are bound in `24_gui_evidence_manifest.log`. PID `77081` was normally closed after evidence capture.

## Non-blocking observation

The city clock/resource display differed between the pre-entry and return screenshots. This is not classified as a repair regression or an open V4-P5 IMPORTANT because:

- the behavior is outside the three-file repair patch;
- the city controller and `scripts/map_pan_controller.gd` are byte-identical to HEAD;
- the required V4 re-entry reset passed;
- this review did not establish whether continued city-time progression during a battle visit is intended product behavior.

If the intended rule is “city time must freeze while V4 is open,” that should become a separate, explicitly scoped city-time test before freeze. It does not change this repair-only technical verdict.

## Control-state synchronization

Because all technical gates passed, the existing workbook-first control family was mechanically synchronized:

- `V4-P5-T001 = VERIFIED`;
- `V4-G0` through `V4-G5 = VERIFIED`;
- `V4-P6-T001 = READY` and is the only READY task;
- `V4-P6-T002 = NOT_STARTED`;
- `V4-G6 = NOT_STARTED`;
- `T-V4-003 = NOT_RUN`;
- all 44 V5 tasks and all seven V5 gates remain `NOT_STARTED`;
- V4 phase remains `IMPLEMENTED_PENDING_REVIEW`.

Post-sync validation:

- 13/13 sheets rendered with visible content;
- 5,204 populated cells;
- 137 formula cells and 0 formula errors;
- five XLSX↔CSV mappings have 0 mismatch;
- ZIP↔standalone CSV byte mismatches: 0;
- workbook status audit has exactly one READY task, `V4-P6-T001`.

Evidence: `21_post_sync_final_planning_audit.log`, `22_post_sync_control_state.log`, `23_post_sync_zip_csv_audit.log`, and `workbook-contact-sheet.png`.

Post-sync artifact hashes:

| Artifact | SHA-256 |
| --- | --- |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx` | `1ad86b76c461b1c085155a40dd034688412cf6a7799a884292ca2a32920b0ff0` |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md` | `735b44d30c7a10731dfff911362eb1b85445b853d98584598d6bac564cadd412` |
| `docs/planning/csv/roadmap.csv` | `ca8bc563ebc19a96e7e14951cdd31fa9ef92ab85b4a65beda70110a352592230` |
| `docs/planning/csv/tasks.csv` | `abc57877c324f4cd1bc897cd716ecb02d65f2b7856b9dfd10093a3a77de35cb1` |
| `docs/planning/csv/acceptance_matrix.csv` | `eb264b81c5931c9b186853951caa3bc27658af8182acbb6048779134c4be83ec` |
| `docs/planning/csv/tests.csv` | `bf91c8a40b1f068a77f2ce98dcf7b73926c6cf7e78c8dd6abb91b69169231425` |
| `docs/planning/csv/risks_and_decisions.csv` | `f40b3582617480a952de9cd701d4780e16b848935623a883f7efa0624c5504fa` |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL_CSV.zip` | `251c13825c49e9519e97b43e16d5b72832eb35101c7df4ac1207e00b52bf6572` |

## End protection

The end comparison must retain:

- branch `main`;
- HEAD `64f37bda130397f08cdd012609dc2d3a5f5c6b99`;
- upstream `origin/main`;
- ahead/behind `29/0`;
- staged `0`;
- tracked V4 patch SHA-256 `b3aec131692613e55058d38136907f1e637265d9cf8c4e7cb59211c786b32428`;
- the three V4 file hashes listed above;
- all eight protected S1A.2 file hashes;
- prior independent review hash `f06145ad040da6b9d48126755da5f4c11c56fb30af6deae0b1eca507cee3c1bc`;
- repair report hash `f95987e6b08511ad0d4d0fe555aad73c25515d846a95d72da0d31b3b2ef0e42b`.

No game source, scene, test, original review, repair report, or protected S1A.2 file was modified by this review.

## V4-P6-T001 user playtest card

Target duration: 5–10 minutes. Use only the formal entry `./RUN_CURRENT_TXWZS.command`.

1. Confirm the title contains `main@64f37bd · DEBUG · DIRTY`.
2. Enter Blackstone from the city command platform.
3. Open one pending route and right-click once on a percentage button. Confirm the bar and route disappear and troops do not change.
4. Reopen the route and dispatch 50%. Confirm the source retains troops and the march remains readable.
5. After arrival, confirm both nonzero friendly nodes show their own garrison and can independently open a legal route.
6. Start one attack. During the march, try a second order. Confirm it is rejected while the first march continues.
7. Wait for arrival, read the result, then wait four more seconds. Confirm no second settlement or troop change occurs.
8. Return to city, re-enter, and confirm the V4 battlefield resets to camp 10 with no pending route or march.

User records only one result:

- `ACCEPT_V4_P6_T001_USER_STAGE_TEST`, or
- `REJECT_V4_P6_T001_USER_STAGE_TEST: <one concrete blocking observation>`.

Do not mark `T-V4-003` or `V4-G6` passed until the user gives the explicit acceptance result.

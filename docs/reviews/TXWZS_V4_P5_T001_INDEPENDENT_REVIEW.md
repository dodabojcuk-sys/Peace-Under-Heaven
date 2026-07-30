# TXWZS V4-P5-T001 Independent Review

## Verdict

`REJECT_V4_P5_T001_REPAIR_REQUIRED`

V4 的专项测试、全量回归、连续行军和一次性抵达结算均通过独立复跑，
但审查仍发现 3 个未关闭的 `IMPORTANT`。按照 V4-P5-T001 的放行规则，
不得释放 V4-P6-T001，不得把本轮技术窗口检查记作 T-V4-003。

## Repository Identity

- Repository:
  `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Branch: `main`
- HEAD: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Upstream: `origin/main`
- Ahead / behind: `29 / 0`
- Staged files: `0`
- Tracked V4 dirty files:
  - `scenes/blackstone_expedition_mvp.tscn`
  - `scripts/mvp/blackstone_expedition_mvp.gd`
  - `tests/run_blackstone_playable_mvp_smoke.gd`
- V4 dirty patch SHA-256:
  `0bb163b1da93caa45daa8c55f8decfa9a4fe76348a5d698af3aea67abebf10d5`
- Godot:
  `4.5.1.stable.official.f62fdbde1`
- Evidence directory:
  `/tmp/txwzs-v4-p5-t001-review.LROOa0`

The eight untracked S1A.2 protected files were not modified. The planning and
review artifacts that existed at the start were not used as game-state truth
and were not modified by this rejected review.

## Task, Tests, and Gates

The reviewed control package defines:

- Task: `V4-P5-T001`
- Tests:
  - `T-V4-001`
  - `T-V4-002`
  - `T-REG-001`
- Gates:
  - `V4-G1` state ownership and data contract
  - `V4-G2` minimum-loop automated tests
  - `V4-G3` full regression
  - `V4-G4` real-window technical verification
  - `V4-G5` independent review

`T-V4-003` was not executed. It remains the later user physical-mouse
playtest for V4-P6-T001 / V4-G6.

## Findings

### IMPORTANT 1: Right-click cancellation is not reliable across the promised UI

The scene tells the player `Esc / 右键取消`, and the pending-order status also
promises right-click cancellation. The implementation handles the right mouse
button only in the root `Control._gui_input()`.

`DispatchBar` uses `mouse_filter = STOP`, and its child buttons also stop mouse
propagation. Therefore a right click inside the dispatch bar does not reach the
root handler.

This was reproduced in the real launched window:

1. Dragged `我方营地` to `山路援军`.
2. Confirmed that the pending route and four ratio buttons were visible.
3. Right-clicked inside the dispatch bar.
4. The bar, route highlight, and `ORDER_PENDING` presentation remained visible.

Evidence:

- `scripts/mvp/blackstone_expedition_mvp.gd:128-160`
- `scenes/blackstone_expedition_mvp.tscn:246-327`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-right-click-dispatch-bar.jpeg`

The smoke test only right-clicks outside the dispatch bar, so it does not catch
this real input-routing defect.

Minimum repair:

- Route cancellation through one input owner that receives right-click
  regardless of the hovered child control, or explicitly forward right-click
  from the dispatch bar.
- Add a regression that right-clicks both inside and outside the dispatch bar.
- Keep the visible promise and implemented cancellation area identical.

### IMPORTANT 2: A presentation node participates in the command-validity rule

`begin_command_interaction()` refuses a command when
`result_panel.visible == true`.

Normal paths currently set `outcome` and the panel together, but the visible
state of a UI node is nevertheless a second rule gate. If presentation and
`outcome` desynchronize, the UI can reject an otherwise legal command. This
violates the task requirement that UI only sends intent and does not become a
state truth owner.

Evidence:

- `scripts/mvp/blackstone_expedition_mvp.gd:197-203`
- `scripts/mvp/blackstone_expedition_mvp.gd:811-824`

Minimum repair:

- Determine command legality from the interaction/outcome model only.
- Make panel visibility a projection of that model.
- Add a focused contract test proving that changing presentation visibility
  does not change domain command legality.

### IMPORTANT 3: `current_node_id` is a competing location source

The actual force distribution is stored in `_garrisons`, and V4 permits several
friendly nodes to retain nonzero garrisons after partial dispatch. A separate
single `current_node_id` is also mutated on arrivals, used as the default source
for `get_available_node_ids()`, and drives the single `◆ 我军` marker.

The real mouse path passes an explicit source, so this did not cause a wrong
deduction during the reviewed happy path. It still creates an ambiguous second
location truth and a V5 takeover risk: one scalar cannot represent multiple
friendly garrisons.

Evidence:

- `scripts/mvp/blackstone_expedition_mvp.gd:82-101`
- `scripts/mvp/blackstone_expedition_mvp.gd:621-638`
- `scripts/mvp/blackstone_expedition_mvp.gd:721-808`
- `scripts/mvp/blackstone_expedition_mvp.gd:867-874`

Minimum repair:

- Derive all selectable sources and location markers from `_garrisons`.
- Remove the no-source route-query fallback or make the caller provide the
  source explicitly.
- Do not let a singular marker imply that only the last-arrived node holds the
  player force.

### OPTIONAL: Invalid API-input coverage can be more explicit

The implementation rejects unsupported percentage values because no matching
enabled choice is found, but the smoke runner does not directly exercise
`0`, negative, or values above `100`. This is not the release blocker while the
three `IMPORTANT` findings remain open.

## Automated Evidence

### T-V4-001

Command:

```text
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2 \
  -s res://tests/run_blackstone_playable_mvp_smoke.gd
```

Result:

- Exit code: `0`
- Explicit assertions: `115 PASS`
- Runner summary: `1 PASS`
- `FAIL / ERROR / Parse Error / SCRIPT ERROR`: `0`

The runner covers actual `InputEventMouseButton` and
`InputEventMouseMotion` delivery to the scene handler, pending-order creation,
four percentage choices, consecutive rendered frames through
20/50/80/100-percent progress, extra release during marching, arrival cleanup,
failure, victory, reward, and re-entry reset.

### T-V4-002 and T-REG-001

The same independent execution of all Git-tracked
`tests/run_*_smoke.gd` provides both full-runner requirements.

Result:

- Tracked runners: `27 / 27`, all exit code `0`
- Explicit assertion lines: `1479 PASS`
- Runner summaries: `27 PASS`
- `FAIL`: `0`
- `ERROR / Parse Error / SCRIPT ERROR`: `0`

Raw per-runner results:

`/tmp/txwzs-v4-p5-t001-review.LROOa0/all-runners-summary.tsv`

### Project and Scene Checks

All commands exited `0`:

- Godot headless editor scan
- Main scene headless startup
- `res://scenes/blackstone_expedition_mvp.tscn` headless startup
- `res://scenes/c0_battle_graybox.tscn` headless startup
- Resource-path check
- duplicate `.gd.uid` check
- `git diff --check`

No `ERROR`, `SCRIPT ERROR`, or `Parse Error` signature was found in these logs.

## Real Godot Window Evidence

The formal launcher was used:

```text
./RUN_CURRENT_TXWZS.command
```

Runtime identity:

- PID: `64459`
- Scene: `CITY`
- Branch / commit: `main@64f37bd`
- Dirty: `1`
- Window title:
  `天下无战事 · CITY · main@64f37bd · DEBUG · DIRTY`
- Runtime log error signatures: `0`

Technical path executed with the real Godot window:

1. Selected `军令台 L1`.
2. Clicked the visible `出征黑石堡` button.
3. Entered the Blackstone battlefield with 10 soldiers.
4. Dragged camp to reinforcement and saw all
   25/50/75/100-percent options with actual dispatched/remaining counts.
5. Cancelled through the visible close control; state stayed at 10.
6. Reopened the pending order and reproduced the right-click failure inside the
   dispatch bar.
7. Issued a legal 50-percent reinforcement command:
   source changed from 10 to 5 and a five-soldier marker moved continuously.
8. Arrival produced camp 5, reinforcement 11, total 16.
9. Issued a three-soldier attack and attempted a concurrent command while it
   marched; the status explicitly rejected the second order.
10. The attack arrived once and failed against five defenders; camp remained 2,
    reinforcement remained 11, and total force became 13.
11. Waited four additional seconds; the same values remained, providing
    no-duplicate-arrival evidence.
12. Returned to the city and re-entered; the battlefield reset to camp 10 with
    no route, pending order, or marching presentation.

Screenshots:

- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-city-start.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-city-command-platform.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-battle-start.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-dispatch-pending.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-dispatch-cancelled.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-right-click-dispatch-bar.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-march-early.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-march-concurrent-attempt.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-march-arrived.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-post-arrival-stable.jpeg`
- `/tmp/txwzs-v4-p5-t001-review.LROOa0/gui-reentered-fresh.jpeg`

This was V4-G4 technical evidence. It was not the user physical-mouse
acceptance represented by T-V4-003.

## Boundary Review

- V4 remains limited to one active marching object and blocks concurrent
  dispatch. That is allowed by the frozen V4 scope.
- No persistent army collection, second troop type, V5/V6 state migration, or
  S1A.2 save integration was added or claimed.
- The current V4 scripts remain scene-local and do not create a second
  `CityState` or `WorldState`.
- The three `IMPORTANT` findings must be repaired without expanding into V5.

## Control-State Decision

No control artifact was synchronized.

- `V4-P5-T001` must not be marked `VERIFIED`.
- `V4-P6-T001` must not be released as `READY`.
- `T-V4-003` remains `NOT_RUN`.
- V5 remains `NOT_STARTED`.

## Remaining Verification

Not performed:

- User V4-P6-T001 physical mouse playtest.
- T-V4-003.
- V4 freeze commit.
- V5 or V6 implementation.
- S1A.2 review or modification.

The next authorized action should be one narrow V4 repair round covering the
three `IMPORTANT` findings, followed by a new independent V4-P5 review.

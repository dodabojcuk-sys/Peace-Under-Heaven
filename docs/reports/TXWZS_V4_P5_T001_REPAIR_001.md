# TXWZS V4-P5-T001 Repair 001

## Status

- Task: `V4-P5-T001-REPAIR-001`
- Baseline branch: `main`
- Baseline HEAD: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Original tracked V4 patch SHA-256:
  `0bb163b1da93caa45daa8c55f8decfa9a4fe76348a5d698af3aea67abebf10d5`
- Repaired tracked V4 patch SHA-256:
  `b3aec131692613e55058d38136907f1e637265d9cf8c4e7cb59211c786b32428`
- Final V4 file SHA-256:
  - scene:
    `d92de13adb05d3da12642341861a29d0bca6cf993782f7bf0e40ebf010290957`
  - script:
    `381d5d5acbb36178fd4c127638af1d44240bbbce5ceb03eca85e7b2ecd19a393`
  - smoke:
    `e2754c360f8b828fa31ae10458ecf48ccc65cbde38b560abcc4830a2aaee3eac`
- Result:
  `V4_P5_T001_REPAIR_001_COMPLETE_READY_FOR_INDEPENDENT_REVIEW`

This repair does not verify `V4-P5-T001`, release `V4-P6`, run
`T-V4-003`, or start V5.

## Closed Findings

### 1. Right-click cancellation over child Controls

`DispatchBar`, its close button, and all four percentage buttons now route
their `gui_input` right-click events to the same
`cancel_pending_order()` action used by Esc and the close button.

The battlefield root continues to handle right-clicks received through its
own `_gui_input`. Only `ORDER_PENDING` consumes a right-click. A handled
cancel clears the pending order, hides the dispatch bar, removes route
visuals, and leaves garrisons and marching armies unchanged.

This preserves the existing single `_input` owner in the main scene. The
first attempted global `_input` approach was rejected by the existing
city-time and world-map ownership regressions; it is not present in the
final candidate.

The V4 runner sends right-clicks through `Viewport.push_input()` at:

- battlefield blank space;
- DispatchBar background;
- the 50% percentage button.

It does not call the cancellation method directly for these three checks.

### 2. Presentation no longer controls command legality

`result_panel.visible` was removed from command legality. The model decision
now depends on interaction state, `outcome`, active marches, routes, and
garrisons.

`_refresh_result_presentation()` projects `outcome` and `last_summary` into
the result panel. Bidirectional regression checks prove:

- forcing the panel visible cannot reject an otherwise legal command;
- hiding the panel cannot permit a command after an outcome exists;
- refreshing presentation resynchronizes visibility with the model.

### 3. Garrison distribution is the sole location truth

Production code no longer contains `current_node_id` or
`get_current_node_id()`.

- `_garrisons` determines every friendly occupied location.
- `get_available_node_ids(source_node_id)` requires an explicit source and
  returns no routes for an empty, hostile, or zero-garrison source.
- Arrival updates garrisons, enemies, friendly ownership, interaction state,
  and outcome only.
- The single `Battlefield/ArmyMarker` node was removed.
- Every friendly node renders its own garrison count and `◆ 可发兵` marker
  when its garrison is nonzero.

The V4 regression creates nonzero garrisons at both camp and outpost,
queries each source independently, starts and cancels commands from both,
and confirms that neither operation mutates the garrison model.

## Automated Verification

Godot version:

```text
4.5.1.stable.official.f62fdbde1
```

| Check | Result |
| --- | --- |
| V4 runner | exit 0; 126 explicit assertions |
| All tracked `tests/run_*_smoke.gd` | 27/27 exit 0 |
| Full explicit assertions | 1490 PASS, up from 1479 |
| Runner summaries | 27 PASS |
| Total PASS lines | 1517 |
| FAIL / ERROR / Parse Error / SCRIPT ERROR | 0 |
| Headless editor scan | exit 0 |
| Headless main scene | exit 0 |
| Headless Blackstone scene | exit 0 |
| Headless C0 scene | exit 0 |
| Missing `res://` resource references | 0 |
| Duplicate script UID values | 0 |
| `git diff --check` | exit 0 |

Primary raw evidence:

```text
/tmp/txwzs-v4-p5-repair-001.hgAGDL/
```

The final editor scan used:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --editor --path . --quit
```

The forced `--quit-after 2` exploratory scan emitted the expected
`Scan thread aborted` shutdown warning, so it was replaced by the clean
`--quit` scan above. The final scan has no warning or error.

## Real Window Verification

The old PID `64459` window was identified as
`CITY · main@64f37bd · DEBUG · DIRTY` and closed through its macOS close
button before editing.

The final candidate was started through `RUN_CURRENT_TXWZS.command`:

```text
PID: 69937
Title: 天下无战事 · CITY · main@64f37bd · DEBUG · DIRTY
Scene: CITY
```

Observed with real mouse input:

1. right-click battlefield blank space cancels;
2. right-click DispatchBar background cancels;
3. right-click the 50% button cancels without dispatching;
4. Esc cancels;
5. the close button cancels;
6. 50% dispatch leaves 5 at camp and moves 5 to reinforcement;
7. after arrival, camp 5 and reinforcement 11 both display per-node
   `◆ 可发兵` and no single army-location marker exists;
8. reinforcement can independently start a route to outpost;
9. an attempted second command during a 3-soldier march is rejected while
   progress continues;
10. the failed arrival applies once, leaves camp at 7, and remains unchanged
    after more than four additional seconds;
11. returning to the city and entering again resets the battlefield to camp
    10 with no pending order or march.

The runtime log contains no `ERROR`, `SCRIPT ERROR`, `Parse Error`, or
warning.

Selected screenshots:

```text
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-rightclick-battle-cancel.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-rightclick-dispatch-background-cancel.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-rightclick-percent-cancel.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-after-concurrent-attempt.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-second-source-pending.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-concurrency-blocked-during-march.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-arrival-once.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-arrival-after-4s.jpeg
/tmp/txwzs-v4-p5-repair-001.hgAGDL/gui-reentry-reset.jpeg
```

This is implementation-loop evidence, not the independent review and not
the user's `T-V4-003` physical acceptance gate.

## Scope Integrity

- Modified tracked V4 files:
  - `scenes/blackstone_expedition_mvp.tscn`
  - `scripts/mvp/blackstone_expedition_mvp.gd`
  - `tests/run_blackstone_playable_mvp_smoke.gd`
- Added this report only.
- The eight protected S1A.2 files have byte-identical SHA-256 values before
  and after the repair.
- `docs/reviews/TXWZS_V4_P5_T001_INDEPENDENT_REVIEW.md` is byte-identical.
- Planning control files were not modified.
- `V4-P5-T001` remains `READY`.
- `T-V4-003` remains `NOT_RUN`.
- V4-P6 tasks and all V5 tasks remain `NOT_STARTED`.
- Nothing was staged, committed, or pushed.

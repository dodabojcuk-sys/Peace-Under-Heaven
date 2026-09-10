# Command feedback and candidate-stall observation

## Scope

This checkpoint is limited to Macro March command feedback and observation of
the existing `58be81e` candidate. It does not add gameplay, alter the
candidate process, clear its save directory, or claim a simulation-stall fix.

## Feedback repair

`MacroMarchR0` now keeps a rejected confirmation message above per-frame
context refresh until the player starts a new command decision or explicitly
cancels. Right-click cancels only the unconfirmed drawing/draft state and
retains the selected city formation. An explicit second click on that same
formation remains the separate deselection action.

The new graphical, isolated-process regression records these four states:

1. confirmation fails with no food: the visible error survives a refresh and
   no army or food transaction is created;
2. cancel: the formation remains selected, the draft is cleared, confirmation
   is disabled, and the error is cleared;
3. explicit second formation click: selection becomes empty;
4. retry: reselecting, holding, drawing and using the visible confirmation
   control creates one army and deducts its previewed food cost once.

It then pauses the issued order and verifies unchanged progress, resumes at
1x, and verifies the same order advances without another food transaction.

## Commands and results

Godot executable:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| editor import/parse | PASS |
| `tests/run_macro_march_command_status_graphical_smoke.gd` with an empty temporary V5 store | PASS, 1 composite GUI-event assertion and four `COMMAND_CANCEL_TRACE` records |
| `tests/run_macro_march_low_poly_graphical_smoke.gd` with an empty temporary V5 store | PASS, 18 assertions |
| `tests/run_macro_march_r0_smoke.gd` with an empty temporary V5 store | PASS, 30 assertions |
| `tests/run_field_tactics_r2_smoke.gd` with an empty temporary V5 store | PASS, 71 assertions |
| `tests/run_field_tactics_r2_persistence_smoke.gd` with an empty temporary V5 store | PASS; includes transfer, waiting, return and resumed-order recovery in independent processes |

The command-status test is deliberately a separate graphical process. The
full graphical suite contains fixtures that dispatch formations, so running
this command-state contract inside that same process would inherit a spent
roster and would not be a valid retry test.

## Candidate observation

The unmodified candidate is still PID `60772`, launched as:

```text
Godot --path /Users/m4-zhi/Documents/codex-workspace/txwzs-field-tactics-r2 \
  --scene res://scenes/blank_map.tscn --resolution 1152x648 -- \
  --txwzs-v5-save-dir=/tmp/txwzs-58be81e-review-H7q2Iw \
  --txwzs-branch=codex/txwzs-field-tactics-r2 --txwzs-commit=58be81e
```

At observation it was alive (`S` state), writing generations through
`campaign_000000000199.json`, and the runtime log had no matching script or
persistence errors. The snapshot has `city_time_paused=false`, `1x` speed and
no active macro armies. Therefore it does not contain a live order whose
phase/progress could prove a stalled simulation. A different, older Godot
candidate owned the frontmost window, so desktop responsiveness of the
`58be81e` window was not observed. The reported stall remains **NOT
REPRODUCED / NOT DIAGNOSED**.

This is read-only process/save/log evidence. It is not normal system-input
play evidence and does not close player acceptance.

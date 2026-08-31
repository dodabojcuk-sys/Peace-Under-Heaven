# TXWZS M1A.1 Live Closure Report

## Result

```text
RESULT=FAIL
BASE_HEAD=d3bea9549a6d2663987dc836efc8e8c6ff336930
FINAL_HEAD=01d84df397bf4015dcc05e1dfee941eeb4ff12e9
GODOT=4.5.1.stable.official.f62fdbde1

SKILLS_ACTUALLY_USED=GodotPrompter:godot-testing,input-handling,responsive-ui;AwesomeGamedev:game-ui-ux,game-feel;gstack-game:game-visual-qa,playtest-framework;Godot-official-4.5-UI-Containers-multiple-resolutions-signals
EXTERNAL_SOURCES_PINNED=PASS;see_docs/engineering/EXTERNAL_INTELLIGENCE_REGISTRY.md
AUTOMATION_RESULT=PASS_M1A1_31;PASS_M1A_24;PASS_R0C1_57;PASS_R0C_33;PASS_FULL_51_OF_51;PASS_EDITOR_IMPORT;PASS_MAIN_SCENE_HEADLESS;PASS_DIFF_CHECK

REAL_INPUT_MOUSE_KEYBOARD=PASS_OS_LEVEL_AUTOMATION_NOT_HUMAN
SINGLE_UNEDITED_CAPTURE=PASS
FULL_PLAYER_FLOW=PASS_TO_COLD_RESTART_OBSERVATION
COLD_RESTART_IN_SAME_VIDEO=FAIL_RUNTIME_STATE_RESETS
SCREENSHOT_COUNT=0_CURRENT_ACCEPTANCE_SET
CONTACT_SHEET=NOT_CREATED_BECAUSE_COLD_RESTART_GATE_FAILED
VIDEO_DECODE_CHECK=PASS
OBVIOUS_OVERLAP_OR_CLIPPING=NO_OBSERVED_IN_LIVE_1152x648_FLOW
OBVIOUS_WORLD_INTERPENETRATION=NO_OBSERVED_IN_LIVE_1152x648_FLOW
WORKTREE_CLEAN=YES_BEFORE_REPORT_COMMIT
PUSH=NO
MERGE=NO
DEPLOY=NO
```

## Actual flow and first blocking result

The final capture starts from the standard launcher at clean `01d84df`, records
the native Godot city window, expands the city information, shows the real
`驻军 20 · 可派 20 · 指挥上限 50`, repeats the current-mainline click, deploys
the second squad to the front route, starts the battle, reaches a real victory
at tick 384 with 8 survivors and 12 casualties, confirms settlement once, and
returns to the same city. The returned city shows `主线已完成 · 压力解除`, wood
130, and food 96.

The same uncut capture then closes Godot and starts the same clean commit again.
The new process shows day 1, active mainline, wood 100, and food 80. This is
the first remaining acceptance blocker: the runtime scene has no disk-backed
V5 save/load lifecycle even though V5 codec/store cold-process runners pass
their isolated in-memory and test-root contracts. It is not valid to label that
as a successful game cold restart.

## Live-input repair made during this task

The first exploratory live runs exposed a separate player-visible gap. The
existing normal-20 victory smoke submitted three `ADVANCE` orders in the same
battle tick through direct test calls. A real mouse can select only one squad
at a time; the first squad reached the gate early, took all enemy damage, and
the advertised 20-person route failed. Commit `01d84df` changes only the real
Start button path: when the player has already deployed every squad on the
front route, it queues all three existing advance orders in the same start
tick. Non-concentrated deployments and programmatic `start_battle()` callers
retain their existing command semantics. It does not add units, alter resources,
or change settlement, build, road, placement, or save ownership.

The focused smoke now asserts that this explicit concentrated deployment
creates one advance order per real squad; the final live capture confirms the
8-survivor victory route.

## Recording integrity

```text
RECORDING_METHOD=macOS_screencapture_-v_-C_-k_-D1;whole-file_stream-copy_remux
RAW_RECORDING=m1a1-live-os-input-final-01d84df-raw.mov
RAW_RECORDING_SHA256=249b739cd4d9a767906c3a41a20eff63ed3bf2085463c8bb485d1760e23e607f
RAW_DURATION=237.186667_SECONDS
FINAL_MP4=m1a1-live-os-input-final-01d84df.mp4
FINAL_MP4_SHA256=913d00ff5dbce6af6e9ad2750c74357835bf96d55cfa5f0f9c9902572c390241
FINAL_DURATION=237.215990_SECONDS
VIDEO_CODEC=H264_MAIN
VIDEO_PIXEL_FORMAT=YUV420P
VIDEO_RESOLUTION=1920x1080
VIDEO_FRAMES=10327
VIDEO_FULL_DECODE=PASS_FFMPEG_NULL_OUTPUT
VIDEO_DTS_MONOTONIC=PASS
```

The raw recording and MP4 are deliberately held outside the Git worktree at
the user-accessible evidence delivery location. The MP4 is a one-stream
container remux; no trim, frame rearrangement, speed change, or static-frame
encoding was applied.

## Evidence decision

No current ten-image set or contact sheet is claimed. Creating them after the
recorded cold-restart reset would misrepresent a failed milestone as a closed
one. The live 1152x648 frames observed during this flow show no obvious HUD
overlap, clipping, button escape, or world-object interpenetration, but that
does not substitute for the required three-resolution L2 package.

The next task must wire the existing V5 save store into the normal runtime
lifecycle without adding a second Save owner, then make one new clean live
capture and its ten-image/contact-sheet package.

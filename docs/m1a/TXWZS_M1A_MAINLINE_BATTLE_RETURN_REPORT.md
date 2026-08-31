# TXWZS M1A Current Mainline Battle Settlement Return Loop R0

```text
PARENT=cafe26cbe544e68ae2f57a3ba12c1976eec13f8a
SCOPE=CURRENT_MAINLINE_ENTRY_TO_EXISTING_C0_TO_ATOMIC_SETTLEMENT_TO_SAME_CITY_RETURN
CANDIDATE_VERDICT=FAIL_REAL_INPUT_FLOW_BLOCKED_BEFORE_BATTLE_AND_COLD_RESTART

RESOURCE_OWNER=NationState_ONLY
CITY_TIME_AND_V5_OWNER=ConstructionController_ONLY
BATTLE_FACT_OWNER=BattleSession_ATTEMPT_LOCAL
RESULT_AND_RETURN_OWNER=CombatTransactionCoordinator
MAINLINE_OWNER=CurrentMainlineLevel

TOP_BAR_REGIONS=resources,city,date_and_settlement,deadline_and_pressure,speed_and_pause
MAINLINE_ENTRY_REGION=deadline_and_pressure
NEW_RESOURCE_OR_SAVE_OWNER=NO
SAVE_SCHEMA_CHANGE=NO
IN_PROGRESS_BATTLE_SAVE=NOT_SUPPORTED_ATTEMPT_LOCAL_SESSION

M1A_FOCUSED=PASS_24_ASSERTIONS
R0C1_FOCUSED=PASS_57_ASSERTIONS
R0C_FOCUSED=PASS_33_ASSERTIONS
P1E_FORMAL_CITY_LOOP=PASS
COORDINATOR_CITY_TIME_SETTLEMENT=PASS
FULL_DYNAMIC_REGRESSION=PASS_50_OF_50_RUNNERS
EDITOR_PARSE_IMPORT=PASS
NATIVE_PNGS=PASS_10_REQUIRED_PLUS_JOURNEY_FRAMES
SCREENSHOT_CONTACT_SHEET=PASS_NATIVE_GODOT_IMAGE
REAL_INPUT_MOUSE_KEYBOARD=PASS_FOR_RECORDED_CITY_OPERATIONS
SINGLE_UNEDITED_CAPTURE=PASS_MACOS_SCREENCAPTURE_V
FULL_PLAYER_FLOW=FAIL_REAL_ENTRY_BLOCKED_AT_20_OF_50_AVAILABLE_FORCE
COLD_RESTART_IN_SAME_VIDEO=FAIL_NOT_REACHED_AFTER_ENTRY_BLOCK
RAW_RECORDING_SHA256=531cfd45b206db8c90a251cdb9c4925e8320e3989cc8ddd8ad38995acc266270
FINAL_MP4_SHA256=dc01412ac661ec149546d358397b8d7ff489e4903f4cf33660892b2ccd7c1e4e
VIDEO_DURATION=149.44_SECONDS_RAW_149.466667_SECONDS_FINAL
VIDEO_CODEC=H264
VIDEO_PIXEL_FORMAT=YUV420P
VIDEO_DTS_MONOTONIC=PASS_5541_PACKETS
VIDEO_DECODE_CHECK=PASS_FFMPEG_FULL_FILE
VISUAL_INSPECTION_EACH_IMAGE=PASS_10_OF_10_NATIVE_RENDER_REVIEW
OBVIOUS_OVERLAP_OR_CLIPPING=NO_OBSERVED
OBVIOUS_WORLD_INTERPENETRATION=NO_OBSERVED
REAL_MOUSE_JOURNEY=PASS_PARTIAL_CITY_INPUT_RECORDED

PUSH=NO
MERGE=NO
DEPLOY=NO
```

## Result

The permanent city now presents a current-mainline action inside its existing
deadline-and-pressure region. It reaches the existing C0 formal-city scene,
creates the existing single coordinator-bound attempt, presents the terminal
facts before persistence, and returns through the existing guarded return
contract.

A winning result now marks the persistent current-mainline level cleared in
the already-authorized settlement path, after the national resource transaction
succeeds and before the settlement summary is exposed. Therefore pressure
modifiers stop on that one confirm; pressure losses already committed remain.
Retreat and defeat do not clear the level. A settled retreat exposes a fresh
top-bar retry against the remaining current threat without resetting time or
deadline; city defeat remains a loss state rather than a fabricated retry.

## Evidence

- [01 city mainline entry — 1152x648](evidence/01-city-mainline-entry-1152x648.png)
- [02 battle entry — 1152x648](evidence/02-battle-entry-1152x648.png)
- [03 battle running — 1152x648](evidence/03-battle-running-1152x648.png)
- [04 settlement preview — 1152x648](evidence/04-settlement-preview-1152x648.png)
- [05 explicit non-victory feedback — 1152x648](evidence/05-settlement-error-or-nonvictory-1152x648.png)
- [06 returned city / pressure cleared — 1152x648](evidence/06-returned-city-cleared-1152x648.png)
- [07 cold restart preserved — 1152x648](evidence/07-cold-restart-preserved-1152x648.png)
- [08 longest state — 1280x720](evidence/08-longest-state-1280x720.png)
- [09 longest state — 1440x900](evidence/09-longest-state-1440x900.png)
- [10 post-battle build state — 1440x900](evidence/10-build-state-after-battle-1440x900.png)
- [player-flow contact sheet](evidence/m1a-current-mainline-return-loop-r0-contact-sheet.png)
- [raw macOS system recording (MOV)](evidence/m1a-real-input-raw.mov)
- [final whole-file remux (MP4)](evidence/m1a-real-input-player-flow.mp4)

All ten required PNGs were captured by the running Godot scene and individually
reviewed. The review found no visible UI overlap, text clipping, off-screen
button, scene-UI residue, unreadable settlement number, or obvious world-object
interpenetration in those sampled states.

On 2026-08-31, a 149.44-second macOS `screencapture -v -C -k -D1` recording
was started before all recorded player interactions. It shows the desktop,
visible pointer movement/click feedback, native Godot city window, actual mainline
entry click, city-panel expansion, and the existing recruitment action. It was
manually watched from start to finish in QuickTime. The final MP4 is a whole-file
stream-copy remux of that raw MOV: no trim, speed change, frame extraction, or
reordering. It decodes fully as one H.264/yuv420p 1920x1080 stream; video DTS is
monotonic across 5,541 packets.

The attempt does **not** satisfy the end-to-end gate. At normal city state the
sidebar showed only `20/50` available troops; the mainline action did not enter
the battle after real clicks, and the normal recruitment action created its
existing queue without making additional troops available during the recorded
attempt. No test interface, signal injection, fixture, debug shortcut, or save
mutation was used to bypass that state. Consequently battle, settlement, return,
and cold restart were not reached, and the candidate remains **FAIL**. This is
engineering evidence, not a Founder playtest or authorization for push, merge,
deployment, or further warfare scope.

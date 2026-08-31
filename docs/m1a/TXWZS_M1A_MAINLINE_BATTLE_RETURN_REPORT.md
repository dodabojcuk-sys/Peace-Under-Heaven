# TXWZS M1A Current Mainline Battle Settlement Return Loop R0

```text
PARENT=cafe26cbe544e68ae2f57a3ba12c1976eec13f8a
SCOPE=CURRENT_MAINLINE_ENTRY_TO_EXISTING_C0_TO_ATOMIC_SETTLEMENT_TO_SAME_CITY_RETURN
CANDIDATE_VERDICT=FAIL_CONTINUOUS_REAL_PLAYER_FLOW_RECORDING_NOT_PROVIDED

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
CONTINUOUS_VIDEO=FAIL_NOT_A_SINGLE_UNEDITED_REAL_INPUT_PLAYER_FLOW
VIDEO_DECODE_CHECK=PASS_FFPROBE_H264_YUV420P_1152X648
VISUAL_INSPECTION_EACH_IMAGE=PASS_10_OF_10_NATIVE_RENDER_REVIEW
OBVIOUS_OVERLAP_OR_CLIPPING=NO_OBSERVED
OBVIOUS_WORLD_INTERPENETRATION=NO_OBSERVED
REAL_MOUSE_JOURNEY=UNVERIFIED

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
- [continuous journey MP4](evidence/m1a-current-mainline-return-loop-r0.mp4)

All ten required PNGs were captured by the running Godot scene and individually
reviewed. The review found no visible UI overlap, text clipping, off-screen
button, scene-UI residue, unreadable settlement number, or obvious world-object
interpenetration in those sampled states. The MP4 is a continuous 7-second,
H.264/yuv420p, 1152x648 encoding of sequential native Godot captures of the
real formal-city scene path; `ffprobe` confirms that it decodes as H.264 and
`yuv420p`.

Its progression is script-driven and composed from sequential captures, so it
is not a single, unedited, real-input player-flow recording. Under the mandatory
visual-evidence gate this makes the candidate **FAIL**, despite valid H.264
decoding and visually reviewed stills. Computer Use could only access a
pre-existing Godot project-manager window, not this isolated game process; true
native-input recording therefore remains open. This is engineering evidence,
not a Founder playtest or authorization for push, merge, deployment, or further
warfare scope.

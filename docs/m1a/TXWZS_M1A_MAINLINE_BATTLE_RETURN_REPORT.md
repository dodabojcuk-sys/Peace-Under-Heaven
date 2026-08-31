# TXWZS M1A Current Mainline Battle Settlement Return Loop R0

```text
PARENT=cafe26cbe544e68ae2f57a3ba12c1976eec13f8a
SCOPE=CURRENT_MAINLINE_ENTRY_TO_EXISTING_C0_TO_ATOMIC_SETTLEMENT_TO_SAME_CITY_RETURN

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
NATIVE_PNGS=PASS_8
CONTINUOUS_VIDEO=PASS_H264_YUV420P_1152X648_5_SECONDS

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

- [1152x648 city entry](evidence/city-entry-1152x648.png)
- [1280x720 city entry](evidence/city-entry-1280x720.png)
- [1440x900 city entry](evidence/city-entry-1440x900.png)
- [battle result preview](evidence/journey-03-result-preview.png)
- [returned city with pressure stopped](evidence/journey-04-city-return-pressure-stopped.png)
- [cold restart](evidence/journey-05-cold-restart.png)
- [continuous journey MP4](evidence/m1a-current-mainline-return-loop-r0.mp4)

The MP4 is generated from sequential native Godot captures of the real
formal-city journey, encoded H.264/yuv420p at 1152x648. It is engineering
evidence, not a Founder playtest or authorization for push, merge, deployment,
or further warfare scope.

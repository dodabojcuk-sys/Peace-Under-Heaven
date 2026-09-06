# TXWZS M1A.1-R2 V5 Runtime Persistence Lifecycle

## Result

```text
RESULT=ENGINEERING_PASS_L3_EVIDENCE_BLOCKED
BASE_HEAD=fb6ef755ceef61bb7e71f957f652659c9704a715
GODOT=4.5.1.stable.official.f62fdbde1
PRODUCT_SCHEMA_CHANGED=NO
CANONICAL_OWNER_CHANGED=NO
```

## Authority Call Chain

| Boundary | Existing authority / API | Runtime lifecycle use |
| --- | --- | --- |
| Live canonical state | `ConstructionController` | The only city-state owner; exports, validates, and atomically restores `CampaignSnapshotV2`. |
| Domain snapshot | `V5CampaignSnapshot` | Schema `5` structural validation and existing V2/V3/V4 migration; no schema change. |
| Envelope | `V5CampaignSaveCodec` | Canonical JSON, `storage_version=1`, SHA-256, and future-version rejection. This is distinct from campaign `schema_version=5`. |
| Disk generation | `V5CampaignSaveStore` | Existing write → flush → reread → publish → final-reread, immutable generations, and whole-generation fallback. |
| Runtime composition | `MapPanController` / `blank_map.tscn` | Creates exactly one `RuntimeCampaignPersistenceCoordinator` after the city controller is ready. |
| City-to-battle | `ConstructionController.enter_first_war_battle` → `CombatTransactionCoordinator` → `C0BattleGraybox` | Existing reservation, result confirmation, and same-city return remain the only battle transaction path. |
| Normal exit | `MapPanController._notification(NOTIFICATION_WM_CLOSE_REQUEST)` | Performs a final V5 flush before `SceneTree.quit()`. `_exit_tree` is not relied upon for saving. |

`CampaignSnapshotV2`, V5 product naming, envelope `storage_version`, campaign
`schema_version`, and prior R0C schema history remain separate version axes.

## Lifecycle Contract Implemented

1. GUI startup opens the V5 store. A valid latest generation is fully decoded
   and applied through the existing rollback-safe controller restore API before
   `MapPanController` attaches its root presentation listeners.
2. An absent store alone creates and publishes one initial generation. Future,
   corrupt-all, or apply-failed stores are logged and write-blocked; they are
   never replaced with a new city.
3. Canonical `city_state_changed` marks the runtime dirty and performs a
   debounced write; it does not write per frame. Explicit callers can flush a
   stable generation at a product boundary, and normal window close synchronously
   flushes pending state.
4. Existing store failures keep the preceding published generation. The
   coordinator reports `push_error` and does not publish a partial snapshot.
5. Headless scene runners without `--txwzs-v5-save-dir` are explicitly disk
   disabled, so regression tests cannot touch a player's `user://` campaign.
   The new lifecycle runner passes an isolated directory through the normal
   product startup argument.

## RED Then Green Cross-Process Evidence

The new `run_m1a1_runtime_persistence_lifecycle_smoke.gd` initially failed on
the baseline because the normal scene lacked `get_runtime_persistence_status`.
It now starts three separate Godot processes and never invokes a test-only
load/apply method:

| Process | Normal product path | Required observation |
| --- | --- | --- |
| A | Empty normal city → build slot → daily settlement → current-mainline battle → victory confirm → return → normal runtime flush | An initial generation plus a stable returned-city generation. |
| B | Normal `blank_map` startup | Automatic latest-generation load restores date, build slot, cleared pressure, and one settlement ledger. |
| C | Corrupt only the latest isolated generation before normal startup | Automatic whole-generation fallback restores the previous complete city, without mixing generations. |

The runner records three different Godot PIDs. It covers state creation, normal
entry, real C0 victory, result commit, returned-city persistence, startup load,
and fallback. Existing V5 persistence smoke continues to cover V1 read-only
migration, future-version block, stale IDs, injected apply rollback, and
published-generation write failures.

## Verification

```text
M1A1_RUNTIME_PERSISTENCE_LIFECYCLE_SMOKE=PASS
M1A1_NORMAL_ENTRY_COLD_RESTART_SMOKE=PASS_31_ASSERTIONS
V5_FOCUSED_BASKET=PASS_6_OF_6
M1A_FOCUSED=PASS
R0C1_FOCUSED=PASS
R0C_FOCUSED=PASS
FULL_DYNAMIC_REGRESSION=PASS_52_OF_52_RUNNERS
EDITOR_IMPORT=PASS
MAIN_SCENE_HEADLESS_SMOKE=PASS
C0_HEADLESS_SMOKE=PASS
GIT_DIFF_CHECK=PASS
```

## L3 Evidence Status

```text
REAL_INPUT_MOUSE_KEYBOARD=FAIL_GAME_WINDOW_NOT_FOCUSABLE_THROUGH_CURRENT_UI_CHANNEL
SINGLE_UNEDITED_CAPTURE=NOT_CREATED
FULL_PLAYER_FLOW=NOT_CREATED
COLD_RESTART_IN_SAME_VIDEO=NOT_CREATED
SCREENSHOT_COUNT=0_CURRENT_ACCEPTANCE_SET
CONTACT_SHEET=NOT_CREATED
VIDEO_DECODE_CHECK=NOT_APPLICABLE
PUSH=NO
MERGE=NO
DEPLOY=NO
```

The project-manager window remained above the separately launched native Godot
game window. The permitted macOS UI channel could inspect and capture the game
window but could only route input to the manager window. No background or
script-driven click sequence was represented as a player run, and no replacement
MP4 or contact sheet was manufactured. The prior failed recording remains valid
defect evidence; it is not superseded by a false PASS.

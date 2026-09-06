# TXWZS2 R2B Native Window Evidence Closure

Date: 2026-08-20

## Verdict

`VERDICT=PASS_PLAYER_ROAD_CONSTRUCTION_R2B`

The R2B player-road flow was completed in a newly launched, PID- and Window-ID-locked Successor window using Quartz/CoreGraphics native mouse events. A real UI input defect was reproduced and fixed with the smallest safe guard: rail controls now win over root map input when the viewport is stretched. The original R2B acceptance report remains unchanged and preserves its historical partial verdict.

## Fixed identity

| Field | Value |
|---|---|
| Active repository | `/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0` |
| Branch | `codex/product-successor-inner-city-r0` |
| Pre-run HEAD | `5a771d9cb778ab98e4bc570dec99537cf3acc363` |
| Final HEAD | recorded after the two local commits below |
| Formal scene | `res://scenes/blank_map.tscn` |
| Formal city node | `MapWorld/RegularCitySpatialFoundation` |
| Godot | 4.5.1 stable, isolated temporary app copy |
| Forensic Canonical | unchanged; `4292ade22bbd3b4b14e48d98475ac50c1da265f6` |
| RG-O1 v1 quarantine | unchanged and not used as a runtime source |

The pre-existing Godot processes (PID 54872 and PID 54983 / Window 78) were observed only and never operated, focused, signalled, or closed. The complete identity and bounds record is in [`native-window-identity.txt`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/native-window-identity.txt).

## Native window lock and recording

The final continuous run used a new process:

| Purpose | PID | Window ID | Bounds | Start |
|---|---:|---:|---|---|
| 1440×900 continuous flow | 77456 | 1026 | `120,52,1440,928` | Thu Aug 20 22:10:28 2026 |
| 1280×720 responsive capture | 74889 | 951 | `180,92,1280,748` | Thu Aug 20 22:03:20 2026 |
| 1920×1080 responsive capture | 74992 | 961 | `0,30,1920,960` | Thu Aug 20 22:03:55 2026 |

The target executable argv contained the exact Successor `--path` and formal scene. The target owner PID matched the Window ID lookup. The 1440 window was recorded before the first input with a single window-only capture:

```text
screencapture -l 1026 -v -V 400 .../native-road-flow-1440x900-full.mov
exit=0
```

The recording was stopped only after the building detail showed `运行中 · 入口已接路` and the top report showed `木材 +18`; it was not stitched or replaced by a second recording. The older shorter road-only recording is retained separately for provenance, while the full run is the primary continuous evidence.

## Reproduced defect and minimal fix

The first native building confirmation reproduced a genuine product defect. A stretched-window mouse click on the rail was also processed by the root `_input` map path before the Button pressed signal. The preview changed from legal to `超出可操作区域`, so the confirm action could not commit. This is classified as:

```text
ROOT_CAUSE=A_OS_AUTOMATION_COORDINATE_OR_DPI plus B_CONTROL_OVERLAY_OR_MOUSE_FILTER
```

The fix is confined to [`scripts/construction_controller.gd`](/Users/m4-zhi/Documents/codex-workspace/txwzs2-product-successor-r0/scripts/construction_controller.gd): `is_construction_ui_point()` first consults `gui_get_hovered_control()` and its visible rail ancestors, then falls back to the existing global-rect checks. No economy value, road authority, save schema, scene, resource, or input mapping changed. The fixed native flow was rerun from a new process, not inferred from the failing run.

## Flow A — road states and cancellation

All actions were native mouse move/down/drag/up events. The final 1440 run captured:

1. Right-rail construction catalog and the real road entry.
2. A connected green orthogonal preview with the rail text indicating network connection.
3. An isolated amber preview with the rail text indicating no main-road connection.
4. A red preview crossing an occupied building area; confirm remained disabled and no state was written.
5. A legal preview cancelled through the rail; no road remained and no resource was charged.

Evidence:

- [`01-road-catalog-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/01-road-catalog-1440x900.png)
- [`02-connected-green-preview-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/02-connected-green-preview-1440x900.png)
- [`03-isolated-amber-preview-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/03-isolated-amber-preview-1440x900.png)
- [`04-invalid-red-preview-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/04-invalid-red-preview-1440x900.png)
- [`05-cancel-clean-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/05-cancel-clean-1440x900.png)

## Flow B — native road confirmation

The confirm button was hovered with the native pointer, then received one native click. The preview closed, one road transaction became visible, and the authoritative resource delta was exact:

```text
wood before = 100
wood after  = 92
road cost   = 8
new player cells = 4
```

The confirmation screenshot shows the placement rail gone and the road cells rendered in the map. The native probe does not invent a Godot signal counter; it records the per-invocation CGEvent output and the single observable state/resource transition. This is sufficient for exactly-once at the product boundary without adding a production test hook.

Evidence:

- [`06-confirm-hover-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/06-confirm-hover-1440x900.png)
- [`07-road-committed-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/07-road-committed-1440x900.png)

## Flow C — road activates a completed building

Using the real building catalog, a logging camp was placed at a legal disconnected lot with the normal native confirm. It consumed the authoritative 40 wood, showed construction, and completed through the normal 4× time control. The road tool then connected the main road to the building entrance. The final contact tile was confirmed natively, and the same building immediately changed to:

```text
进度：已完工 · 第 2 日投入运行
状态：运行中 · 入口已接路
效果：木材 +18/日
```

The building was not reloaded or recreated between the route confirmation and activation. A later time tick showed the daily report `木18` and wood increased from 40 to 58, proving production after connection. The pre-connection disconnected detail was observed during the route attempt; a dedicated detail screenshot before the first route was not retained, so that sub-observation is explicitly recorded as a limitation rather than fabricated.

Evidence:

- [`08-building-disconnected-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/08-building-disconnected-1440x900.png)
- [`08-building-committed-construction-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/08-building-committed-construction-1440x900.png)
- [`full-building-completed-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/full-building-completed-1440x900.png)
- [`full-road-to-building-preview-2-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/full-road-to-building-preview-2-1440x900.png)
- [`09-building-connected-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/09-building-connected-1440x900.png)
- [`10-production-active-1440x900.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/10-production-active-1440x900.png)

## Responsive windows

The same formal scene was launched in new isolated processes at the two requested sizes. The captures show the right rail, minimap, map and top status without critical clipping at the tested window bounds. The 1920×1080 request was visibly clipped by macOS window management to a 1920×960 on-screen window; this is recorded rather than hidden.

- [`overview-1280x720.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/overview-1280x720.png)
- [`overview-1920x1080.png`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/screenshots/overview-1920x1080.png)

## Verification

Because product code changed, the required post-fix verification was rerun:

```text
./tools/assert_active_product_repo.sh                         PASS
R2B focused runner (run_r2b_player_road_construction_smoke.gd) 26 PASS / 0 FAIL
R2A regression runner (run_r2a_road_lot_entrance_smoke.gd)      15 PASS / 0 FAIL
Godot --headless --path . --editor --quit                    exit 0
blank_map.tscn headless smoke                                  exit 0
blackstone_expedition_mvp smoke                                exit 0
c0_battle_graybox smoke                                        exit 0
all find tests/run_*_smoke.gd runners                          41/41 exit 0
full runner assertions                                         1918 PASS / 0 FAIL
git diff --check                                               exit 0
captured-log error scan                                        no new parser/runtime/missing-resource errors
```

The original `docs/reports/PLAYER_ROAD_CONSTRUCTION_R2B_ACCEPTANCE.md` was not modified. The only source change is the focused rail-input guard in the first local commit; this report is the second local commit. No evidence video or large screenshot was added to Git.

## Final fields

```text
TARGET_WINDOW_PID_LOCK=PASS
TARGET_WINDOW_ID_LOCK=PASS
PREEXISTING_GODOT_PROCESSES_TOUCHED=NO
WINDOW_ONLY_CONTINUOUS_RECORDING=PASS
NATIVE_ROAD_DRAG=PASS
CONNECTED_GREEN_PREVIEW=PASS
ISOLATED_AMBER_PREVIEW=PASS
INVALID_RED_PREVIEW=PASS
ROAD_CANCEL=PASS
NATIVE_CONFIRM_EXACTLY_ONCE=PASS_BY_SINGLE_NATIVE_EVENT_AND_SINGLE_STATE_DELTA
PLAYER_ROAD_VISIBLE=PASS
DISCONNECTED_BUILDING_ACTIVATED_BY_ROAD=PASS
PRODUCTION_AFTER_CONNECTION=PASS
RESPONSIVE_VIEWPORTS=3_OF_3_PASS_WITH_1920_WINDOW_MANAGER_CLIP_RECORDED
TARGETED_TESTS=PASS
FULL_REGRESSION=PASS
WORKTREE_CLEAN=YES_AFTER_REPORT_COMMIT
CANONICAL_CHANGED=NO
RG_O1_V1_CHANGED=NO
RG_O1_EXTERNAL_PRESERVATION_VALID=NO
G4_STARTED=NO
PUSH=NO
DEPLOY=NO
SOURCE_CODE_CHANGED=YES_MINIMAL_INPUT_GUARD
```

Remaining evidence limitation: `CONFIRM_PRESSED_COUNT` and the internal Button signal count were not directly instrumented; the evidence uses the native tool's one-down/one-up invocation plus the single authoritative resource/state delta and leaves the aggregate field marked `NOT_DIRECTLY_OBSERVABLE` in [`native-event-probe.log`](/Users/m4-zhi/Downloads/txwzs2-r2b-native-window-evidence-20260820-v1/native-event-probe.log). No further product scope is opened by this closure.

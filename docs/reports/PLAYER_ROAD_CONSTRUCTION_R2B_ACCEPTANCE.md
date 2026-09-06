# Player Road Construction R2B Acceptance

## Result

```text
VERDICT=PARTIAL_WITH_EXACT_ROAD_TOOL_BLOCKERS
ACTIVE_SUCCESSOR_VERIFIED=YES
PRE_HEAD=7133cbd24971cb97c144c6bf678aee7ca99124bb
IMPLEMENTATION_COMMIT=3b6099f
NATIVE_MOUSE_EVIDENCE=NOT_OBTAINED
AUTOMATED_ROAD_AUTHORITY=PASS
G4_STARTED=NO
PUSH=NO
DEPLOY=NO
```

The authoritative player-road slice is implemented and passes the headless
contract and regression suite. The result is intentionally not a product PASS:
the required real-window mouse hover, drag, and single-click evidence could not
be safely obtained in this session. Automated authority tests are not used as a
substitute for that evidence.

## Scope and authority

Player roads are a delta over the formal 55x35 road projection owned by
`RegularCitySpatialFoundation`. `ConstructionController` remains the sole
runtime placement writer. The union of formal and player roads is consumed by
the preview, topology renderer, entrance/connectivity checks, production
activation, minimap, and V5 snapshot export. Derived connectivity is not
persisted and the V5 schema version is unchanged.

The right rail is the only road entry point. A drag creates one contiguous
axis-aligned segment; diagonal input is rejected. Confirmation allocates one
placement record per new cell inside one existing national-resource transaction.
Invalid paths roll back atomically, existing formal/player road cells do not
incur duplicate cost, and a legacy snapshot with no road placements restores an
empty player-road delta.

R2B does not include road deletion or upgrades, traffic/pathfinding, bridges or
slopes, curved roads, full-map rotation, organic garden-city generation, final
building art, G4, push, or deployment.

## Implemented files

- `scenes/blank_map.tscn` adds the road-preview visual to the formal scene.
- `scripts/city_sandbox/city_road_draft.gd` validates contiguous orthogonal
  segments and reports explicit invalid reasons.
- `scripts/city_sandbox/road_preview_visual.gd` renders N/E/S/W topology with
  green, amber, and red states.
- `scripts/construction_controller.gd` owns road mode, validation, preview,
  atomic confirmation, persistence projection, and rail state.
- `scripts/map_pan_controller.gd` routes map drag/release, cancel, and confirm
  interactions without bypassing the controller.
- `scripts/regular_city_spatial_foundation.gd` and `scripts/city_minimap_r1.gd`
  render the same player-road projection.
- `scripts/inner_city_ui_r0.gd` exposes the road-specific rail copy and states.
- `tests/run_r2b_player_road_construction_smoke.gd` adds the focused contract.
- `tests/run_city_spatial_kernel_smoke.gd` records the intentional diagonal
  rejection contract.

No `project.godot`, scene resource outside the formal scene, save schema,
autoload, remote, Canonical repository, or RG-O1 quarantine was modified.

## Automated verification

All commands below were executed from the active successor after the
implementation commit.

| Check | Command/result |
| --- | --- |
| Repository identity | `./tools/assert_active_product_repo.sh` -> `ACTIVE_PRODUCT_REPOSITORY_ASSERTION=PASS` |
| Focused R2B contract | `run_r2b_player_road_construction_smoke.gd` -> exit 0, 26 PASS, 0 FAIL |
| R2A regression contract | `run_r2a_road_lot_entrance_smoke.gd` -> exit 0, 15 PASS, 0 FAIL |
| Road logging regression | `run_p1a_road_logging_smoke.gd` -> exit 0, 29 PASS, 0 FAIL |
| Spatial R1 regression | `run_regular_city_spatial_r1_smoke.gd` -> exit 0, 39 PASS, 0 FAIL |
| UI-R0 regression | `run_inner_city_ui_r0_smoke.gd` -> exit 0, 11 PASS, 0 FAIL |
| Full dynamic suite | 41/41 `tests/run_*_smoke.gd`, exit 0, 1918 PASS, 0 FAIL |
| Editor parse/import | `Godot --headless --path . --editor --quit` -> exit 0 |
| Formal scene smokes | `blank_map`, `blackstone_expedition_mvp`, `c0_battle_graybox` with `--quit` -> all exit 0 |
| Diff hygiene | `git diff --check` -> exit 0 |

Focused R2B assertions cover orthogonal and diagonal draft behavior, topology,
formal/reserved/wall/occupied blockers, right-rail entry, map input routing,
single authoritative confirmation, duplicate confirmation protection, cancel
semantics, isolated amber state, connected activation, next-day production,
V5 snapshot schema 3 round-trip, and legacy snapshots without roads.

## Native-window evidence status

An isolated copy of the existing Godot 4.5.1 editor was used outside the
repository at `/private/tmp/txwzs2-r2b-editor-live.o02pgw/Godot-R2B.app`. The
fresh runtime processes recorded the exact Successor `--path` in their argv and
the clean PTY logs contain `TXWZS_RUNTIME_IDENTITY 天下无战事 · CITY · DEBUG ·
UNIDENTIFIED`.

The Computer Use accessibility target remained the existing system Godot
application and reported `Godot Engine - 项目管理器`; the temporary bundle was
not targetable as an app. Because the desktop also contained pre-existing Godot
windows, no coordinate click was safe to attribute to the new runtime. The
following native evidence was therefore **not executed**:

```text
NATIVE_MOUSE_HOVER=NOT_EXECUTED
NATIVE_MOUSE_SINGLE_CLICK=NOT_EXECUTED
NATIVE_ROAD_DRAG=NOT_EXECUTED
NATIVE_CONFIRM_EXACTLY_ONCE=NOT_EXECUTED
NATIVE_CONSTRUCTION_VISIBLE=NOT_EXECUTED
NATIVE_COMPLETION_AND_DETAIL=NOT_EXECUTED
NATIVE_1280_720_AND_1920_1080=NOT_EXECUTED
NATIVE_CONTINUOUS_RECORDING=NOT_AVAILABLE
```

The `open`-launched probe logs also contain environment-level `getcwd` and
editor-settings-save errors; those logs are not treated as product runtime
success evidence. The clean PTY/unique logs have no parser, missing-resource,
or signal errors.

## Frozen boundaries and remaining gate

The remaining blocker is specifically the real-window road tool evidence, not a
known authority or persistence defect. A separate evidence pass must safely
target one fresh isolated runtime and record the uninterrupted flow:

```text
right-rail road entry
-> orthogonal drag with green preview
-> invalid/amber or red feedback
-> native mouse hover
-> one native click
-> placement exit and visible construction
-> normal time progression and connected-state result
```

That pass must also provide the required 1280x720 and 1920x1080 screenshots and
continuous recording. Until then, do not promote this result to
`PASS_PLAYER_ROAD_CONSTRUCTION_R2B`.

Canonical and RG-O1 v1 were not accessed for mutation. No existing Godot
process was operated, no save data was injected, no G4 gate was started, and
`MEMORY.md` was not modified.

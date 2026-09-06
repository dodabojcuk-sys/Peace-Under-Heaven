# TXWZS M0 R0C Build Queue and Ready Placement Report

```text
RESULT=PASS
VERDICT=ENGINEERING_PASS_PENDING_FOUNDER_LIVE_SMOKE

R0B_BASE_HEAD=3acb5834b0ff907e7f76b8cce9e03e98fff8163e
R0C_HEAD=eb3abe0e566da5e3a60acb68d27a867a6b68ba5d
WORKTREE_CLEAN=YES
CANONICAL_SOURCE_UNCHANGED=YES

R0B_DIRECT_FOUNDATION_CONTRACT_REMOVED=PASS
SINGLE_CITY_BUILD_SLOT=PASS
SECOND_PROJECT_BLOCKED=PASS
CONSTRUCTION_PRIORITY_REMOVED_FROM_NEW_FLOW=PASS

ZERO_RESOURCE_WAITING_NO_FOUNDATION=PASS
INCREMENTAL_RESOURCE_DEDUCTION=PASS
PARTIAL_PROGRESS_MISSING_RESOURCE_BLOCK=PASS
MISSING_RESOURCE_AUTO_RESUME=PASS
GLOBAL_PAUSE_NO_PROGRESS_OR_DEDUCTION=PASS
PRESSURE_SPEED_MODIFIER_PRESERVED=PASS
EXACT_FINAL_COST=PASS

READY_TOKEN_EXACTLY_ONE=PASS
READY_STATE_NO_WORLD_OBJECT=PASS
PLACEMENT_NO_SECOND_PAYMENT=PASS
INVALID_PLACEMENT_RETAINS_TOKEN=PASS
VALID_PLACEMENT_CREATES_COMPLETED_BUILDING=PASS
DOUBLE_CLICK_NO_DUPLICATE=PASS
ROTATE_R=PASS
CANCEL_PREVIEW_RIGHT_CLICK=PASS
CANCEL_PREVIEW_ESC=PASS
UI_CLICK_DOES_NOT_PLACE=PASS

PROJECT_CANCEL_EXACT_REFUND=PASS
REFUND_CAPACITY_EDGE_LOSSLESS=PASS
ROAD_FLOW_INDEPENDENT=PASS
ROAD_OVERLAP_RULE_PRESERVED=PASS

SAVE_SCHEMA=5
SAVE_EACH_R0C_STATE=PASS
PLACEMENT_LOADS_AS_READY=PASS
SCHEMA4_LEGACY_FOUNDATION_BRIDGE=PASS
V2_V3_MIGRATION=PASS
SAVE_ROUNDTRIP=PASS
OFFLINE_TIME_ADVANCE=ZERO

REAL_INPUT_TEST_1152X648=PASS
LAYOUT_1280X720=PASS
LAYOUT_1440X900=PASS
FULL_REGRESSION=PASS_48_OF_48_2321_ASSERTIONS
GODOT_HEADLESS=PASS
MAIN_SCENE_SMOKE=PASS
GIT_DIFF_CHECK=PASS

STATIC_EVIDENCE=PASS
CONTINUOUS_VIDEO=PASS
VIDEO_CONTAINER=MP4
VIDEO_CODEC=H264_HIGH
VIDEO_PIXEL_FORMAT=YUV420P_TV_RANGE
FOUNDER_LIVE_SMOKE=PENDING
FOUNDER_EXPERIENCE_ACCEPTANCE=PENDING

LOCAL_COMMIT_CREATED=YES
PUSH=NO
MERGE=NO
DEPLOY=NO

REPORT=/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0/docs/m0/TXWZS_M0_R0C_BUILD_QUEUE_READY_PLACEMENT_REPORT.md
STATE_AND_RESOURCE_MAP=/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0/docs/m0/TXWZS_M0_R0C_STATE_AND_RESOURCE_MAP.md
LEGACY_SAVE_MIGRATION_MAP=/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0/docs/m0/TXWZS_M0_R0C_LEGACY_SAVE_MIGRATION_MAP.md
TEST_AND_EVIDENCE_INDEX=/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0/docs/m0/TXWZS_M0_R0C_TEST_AND_EVIDENCE_INDEX.md
SCREENSHOTS=/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0/docs/m0/evidence/r0c
VIDEO=/Users/m4-zhi/Documents/codex-workspace/txwzs-m0-time-build-pressure-r0/docs/m0/evidence/r0c/m0-r0c-continuous-player-journey.mp4

FILES_CHANGED=41_IMPLEMENTATION_TEST_DOCUMENTATION_AND_EVIDENCE_FILES_PLUS_REPORT_CLOSURE
BLOCKERS=none
UNVERIFIED=FOUNDER_SUBJECTIVE_CLARITY_DENSITY_AND_INTERACTION_FEEL
NEXT_RECOMMENDED_STEP=Founder perform the one-minute R0C queue-to-placement smoke; do not start new gameplay
```

## Engineering outcome

The R0B order path created a timed placement record on the map before its
incremental resource ticks ran. Consequently, a zero-resource order could own
occupancy and draw a foundation even though progress and payment were blocked.
R0C removes that new-flow write path instead of masking the foundation visual.

The current city now has one off-map build slot. The existing strategic clock,
pressure modifier, and `NationState` transaction advance progress and cumulative
payment atomically. Zero materials remain at 0%; partial payment stops at the
last paid progress; refill resumes automatically; 100% produces one persistent,
fully paid ready token. Only a legal ready-placement click creates a normal
completed placement record, and that click performs no resource transaction.

Roads remain on the direct map-drag flow because they are zero-duration spatial
segments whose continuous drawing interaction is materially different from a
one-at-a-time building product. They reuse the same legality and resource
authorities but never occupy or produce a ready token in the building slot.

## Verification scope

Automation proves state transitions, proportional payment, exact and atomic
refunds, pressure speed, road independence, spatial conflicts, actual Godot
input routing, every persistent slot state, schema migration, and 48-runner
non-regression. Physical Computer Use proves that a native zero-material catalog
click enters the R0C slot, a map click creates no foundation, and cancel returns
to idle. The schema tests prove exact schema 5 roundtrips, placement-active
normalization, non-destructive single and multiple schema 4 foundations, and one
ready token across three cold processes.

The uncut 16.466-second MP4 contains 494 frames at 30 FPS. `ffprobe` reports an
MP4 container, H.264 video, 1152x648, and `yuv420p` TV range. Ten native Godot
screenshots cover all required states and three target sizes.

## Founder summary

R0B 出现“没木材也能铺地基”，根因是旧流程在下单时先创建地图施工记录，资源
则等后续施工 tick 才扣；所以资源不足只能阻止进度，不能阻止已经出现的地基。

R0C 改为建筑先在城内唯一建造位中生产，材料随进度陆续扣除；材料为零时显示
“未开工”、0%、准确缺口和“等待材料”，地图没有地基。中途缺料显示“缺料暂停”，
并停在最后已付款进度；全局暂停只是独立覆盖提示，不改变项目主状态，且不推进、
不扣料。达到 100% 后才得到一栋待放置成品，合法左键会直接生成完成建筑，且不
再次扣料。

成品放置失败不会丢失：道路重叠等非法点击保留同一枚 token 和全部已付款状态；
右键或 `Esc` 只退出预览并回到待放置。道路不进入队列，因为它仍是零工期的地图
连续拖线工具；它复用相同合法性和资源账本，但不占建筑建造位。

自动化验证了状态机、资源、道路、压力、输入和全量回归；真实鼠标验证了原生目录
点击、零材料登记、地图无地基与取消回空闲；存档迁移验证了 schema 5 各状态、三次
冷进程和 schema 4 旧地基非破坏兼容。Founder 仍需亲自完成一分钟“入队列 ->
缺料 -> 补料 -> 完成 -> 非法放置 -> 合法放置”，判断信息是否一眼可懂、面板是否
拥挤、放置手感是否自然。在此之前不合并，也不开始新玩法。

```text
ENGINEERING_CANDIDATE=PASS
FOUNDER_EXPERIENCE_ACCEPTANCE=PENDING
MERGE=HOLD
```

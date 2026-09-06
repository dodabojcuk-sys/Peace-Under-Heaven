# TXWZS M0 R0C Test and Evidence Index

## Automated verification

- `tests/run_m0_r0c_build_queue_ready_placement_smoke.gd`: 33 focused
  assertions at 1152x648. It uses real Godot input dispatch for catalog clicks,
  ready placement, pointer motion, map clicks, `R`, right click, and `Esc`.
- Full dynamic discovery: 48/48 `tests/run_*_smoke.gd` runners pass with 2,321
  explicit `PASS:` assertions and zero failed runners.
- `tests/run_v5_campaign_persistence_smoke.gd`: three independent Godot
  processes save and restore the same paid ready token without duplication.
- Editor parse/import and `git diff --check` pass. Formal main-scene checks are
  included in the dynamic suite and were not weakened or removed.
- The R0B building-direct-foundation runner is explicitly
  `SUPERSEDED_BY_R0C`; conflicting tests now assert the queue-first contract.

## Native physical-mouse verification

Computer Use drove the native 1152x648 Godot window backed by
`tests/run_m0_r0c_real_mouse_fixture.gd`. The fixture creates a fresh in-memory
Blackstone scene with zero wood and never reads or writes the formal save.

The physical pointer opened the build catalog, selected the lumber camp, and
observed `未开工`, `0%`, `缺少：木材 40`, and no map foundation. A subsequent
map click created nothing, and the physical `取消项目` click returned the slot
to idle. A stale pre-R0C Godot process was identified by its baseline runtime
identity, paused, closed, and excluded from evidence before this check.

## Static native evidence

Directory: `docs/m0/evidence/r0c/`

1. `01-idle-build-catalog-1152x648.png`
2. `02-producing-progress-1152x648.png`
3. `03-zero-material-waiting-1152x648.png`
4. `04-material-refill-auto-resume-1152x648.png`
5. `05-ready-to-place-no-world-object-1152x648.png`
6. `06-paid-product-road-invalid-1152x648.png`
7. `07-completed-building-slot-idle-1152x648.png`
8. `08-dense-waiting-panel-1280x720.png`
9. `09-standard-ready-placement-1440x900.png`
10. `10-schema4-legacy-foundation-lock-1152x648.png`

All ten images are native Godot renders from authoritative runtime states. They
were visually inspected after the 1152x648 top-bar and shortage-copy fixes.

## Continuous player journey

- File: `m0-r0c-continuous-player-journey.mp4`
- Container: MPEG-4 (`mov,mp4,m4a,3gp,3g2,mj2`)
- Video: H.264 High profile
- Pixel format: `yuv420p`, TV range
- Frame size: 1152x648
- Frame rate: 30 FPS
- Frames: 494 consecutive frames
- Duration: 16.466 seconds
- Audio: none

The uncut journey uses actual scene-tree input distribution and continuously
shows zero-material registration, proportional payment, mid-build shortage,
refill recovery, one ready token, road-overlap rejection, right-click return,
rotation, legal completed placement, and the idle slot. The contact sheet is
diagnostic only; the delivered MP4 is not a screenshot carousel.

## Remaining acceptance gate

The evidence supports an engineering candidate only. Founder must still play
the one-minute queue-to-placement journey and judge clarity, density, and feel.
No merge, push, deploy, new gameplay, or Founder acceptance is claimed.

## R0C.1 top-bar responsive closure

- `tests/run_m0_r0c1_topbar_responsive_smoke.gd`: 57 assertions across
  1152x648, 1280x720, and 1440x900. It drives one settled day with `今日结算`,
  `下一阶段`, `主线期限`, `压力`, and `治安` present, then asserts all five
  top-bar region rectangles are inside the bar and pairwise disjoint.
- `tests/capture_m0_r0c1_topbar_evidence.gd` renders the same state with the
  native Godot compatibility renderer. Captures are:
  `docs/m0/evidence/r0c1/topbar-longest-state-1152x648.png`,
  `topbar-longest-state-1280x720.png`, and
  `topbar-longest-state-1440x900.png`.
- R0C focused smoke remains `33/33 PASS`; full dynamic discovery is rerun as
  `49/49` runner exits with no failed runner. This is engineering verification,
  not Founder experience acceptance.

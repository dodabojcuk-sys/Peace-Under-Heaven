# TXWZS M0 R0B Direct Click and Failure Feedback Report

## Result

`ENGINEERING_PASS_PENDING_FOUNDER_LIVE_SMOKE`

R0B starts from exact clean R0A commit
`80908263fbf09cbec963ba4c582ff9b22adea894`. The canonical source checkout
remains unchanged. No push, merge, deploy, balance change, save migration, or
new gameplay was performed.

## Founder Failure and Root Cause

The 1152x648 R0A interaction was reproduced before modification: a building map
left click updated the ghost but did not create an order or leave placement.
Source tracing confirmed that this was the explicit old contract, not a
coordinate or legality failure: `MapPanController` sent map clicks only to
`update_preview()`, while a separate rail button owned commit. Commit rejection
also returned a bare boolean with no player feedback.

`ROOT_CAUSE=OTHER:MAP_LEFT_CLICK_WAS_EXPLICITLY_PREVIEW_ONLY`

## Player Result

A legal map left click now reuses its exact pointer to refresh and revalidate,
creates one timed construction order through the existing authority, and exits
placement. `R` rotates. Right click and `Esc` cancel. The building confirmation
node is deleted; only the pre-existing road confirmation flow remains.

Invalid locations stay red and show a concrete persistent reason plus a brief
non-modal message. Timed-building shortages stay amber and orderable, list the
exact delta, and say that the order will wait for materials. Incremental payment,
missing-material pause/resume, pause semantics, and schema 4 persistence are
unchanged.

## Verification

- Focused R0B runner: 26/26 assertions pass through real Godot input dispatch.
- Full dynamic regression: 47/47 runners pass.
- Real native 1152x648 mouse smoke: direct build and explicit road failure pass.
- 1152x648, 1280x720, and 1440x900 layout evidence is inspected.
- Six PNGs and one uncut MP4 are delivered.
- MP4 verification: MPEG-4, H.264 `avc1`, decoded `420v`, 1152x648, 12.267 s.
- Editor import, three formal scene smokes, save roundtrip, and `git diff
  --check` pass.

## Scope and Remaining Gate

Founder must still perform the one-minute direct-click smoke and judge the
interaction feel. Engineering evidence does not grant Founder experience
acceptance, merge permission, or authorization for another gameplay slice.

Founder script:

1. Open `建造目录` and select `伐木场`.
2. Left-click a road and confirm `无法建造：与道路重叠`.
3. Left-click a green position and confirm one foundation appears immediately.
4. Select again, press `R`, then cancel with right click or `Esc`.
5. Under material shortage, confirm the material name, exact delta, and
   `下单后将等待材料`.

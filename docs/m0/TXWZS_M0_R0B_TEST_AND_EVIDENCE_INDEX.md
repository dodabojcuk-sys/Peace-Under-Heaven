# TXWZS M0 R0B Test and Evidence Index

## Automated Verification

- `tests/run_m0_r0b_direct_click_failure_feedback_smoke.gd`: 26 assertions
  through Godot input distribution (`InputEventMouseMotion`,
  `InputEventMouseButton`, and `InputEventKey`) at 1152x648, plus layout gates at
  1280x720 and 1440x900.
- Full dynamic smoke regression: 47/47 runners pass.
- Editor import and `blank_map`, Blackstone expedition, and C0 battle scene
  headless smokes pass.
- Existing V5 campaign roundtrip and migration runners remain in the full
  regression and pass without a schema change.

## Real Mouse Verification

Computer Use drove the native 1152x648 Godot window with physical pointer
actions. It selected the lumber camp, moved the preview, directly built from a
green map position, observed placement-mode exit, and clicked a road-overlap
position with exact persistent feedback. This verification did not invoke an
internal placement method.

## Static Evidence

Directory: `docs/m0/evidence/r0b/`

1. `01-legal-green-preview-1152x648.png`
2. `02-direct-click-success-1152x648.png`
3. `03-road-overlap-feedback-1152x648.png`
4. `04-material-shortage-1152x648.png`
5. `05-dense-shortage-1280x720.png`
6. `06-standard-green-preview-1440x900.png`

Every image is a native Godot render and was visually inspected. No text,
position, or state was added through image editing.

## Continuous Video

- File: `m0-r0b-continuous-player-journey.mp4`
- Duration: 12.267 seconds, 368 consecutive frames at 30 FPS
- Container: MPEG-4 (`public.mpeg-4`)
- Codec: H.264 (`avc1`)
- Decoded pixel format: 4:2:0 video range (`420v`, yuv420p family)
- Audio: none

The uncut journey uses actual Godot scene-tree input distribution to open the
catalog, select the lumber camp, reject a road click with an exact reason, move
to a legal position, rotate, direct-click one order, exit placement, cancel by
right click and `Esc`, and show the exact seven-wood shortage. AVFoundation
decoded the delivered MP4 and an extracted frame was visually inspected upright.

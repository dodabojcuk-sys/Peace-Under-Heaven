# Encounter correctness follow-up

## Scope

This is a narrow correctness follow-up to `a00b3d3`'s readable patrol
encounter sample. Baseline dispatch remains closed. The previously reported
stall remains **NOT REPRODUCED / NOT DIAGNOSED**.

`MacroMarchR0` still consumes settled Field facts only. This checkpoint does
not change dispatch, casualty authority, world-time ownership or durable event
ownership.

## Corrections

- A historical encounter that lacks remaining-strength fields now shows
  `未记录`. The view derives a value only from same-event before/loss facts; it
  never borrows a current army or patrol strength as historical evidence.
- A multi-army encounter stores and presents aggregate casualties plus each
  participant's result. A single closed army cannot label surviving participants
  as all destroyed.
- `contact_milliseconds` remains the offset inside its simulation step, while
  the authority summary now also stores `contact_world_milliseconds`. This is
  the comparable world-clock instant across frame partitions. The existing
  `contact_world_position` continues to drive nearby engineered-road damage.

## Evidence and limits

All artifacts here are Godot GUI-event / engine-viewport evidence, not normal
macOS system-mouse footage or player hand-feel acceptance.

| Artifact | What it shows |
| --- | --- |
| `01-encounter-impact-engine-gui.png` | Formal map hold/strip/release dispatch, natural contact and settled authority report. |
| `02-encounter-result-engine-gui.png` | Feedback has ended; the army remains in its authority-owned later state with the settled result retained in the side panel. |
| `03-encounter-offscreen-notice-engine-gui.png` | Off-screen report stays non-forcing until the explicit locate click. |
| `encounter-continuous-engine-gui.avi` | 453 frames at 60 FPS: formal dispatch, Controller-owned continuous march and patrol time, contact feedback, feedback end and later state. SHA-256 `c007afef6d35f51d64740c7150b6766dc0d55e4d52babb4a5a94deddb43e4998`. |

## Verification

Godot:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| editor import / script parse | PASS |
| `tests/run_macro_march_encounter_feedback_graphical_smoke.gd` | PASS, 11 assertions |
| `tests/run_macro_march_encounter_persistence_smoke.gd` | PASS, two independent processes with complete child output |
| `tests/run_field_tactics_r2_smoke.gd` | PASS, 72 assertions |
| `tests/run_field_tactics_r2_playthrough_smoke.gd`, Route A | PASS (`39400 ms`, `food_spent=12`, `army_casualties=4`) |
| `tests/run_field_tactics_r2_playthrough_smoke.gd`, Route B | FAIL: an existing stationed-army continuation precondition leaves `point=` empty before the Silverford order; the route still reaches `ambushes=1`. |

The graphical smoke uses a real map press/hold/strip/release event sequence,
then lets the production `ConstructionController._process` advance army and
patrol together at an allowed 4x game speed. It checks feedback end, refresh,
pause, speed change and same-process snapshot restore.

The new independent-process worker persists a settled result, exits, opens the
same isolated V5 directory in a second process, verifies real army and patrol
strengths against the durable summary, and confirms the map primes it as
history (`replay=false`). This is the cross-process result proof. The existing
same-process snapshot assertion is intentionally labelled only as a
same-process snapshot restore.

The Field R2 contact fixture compares one large Controller step with 30 FPS,
60 FPS and irregular partitions. Integer-millisecond remainder and `Vector2i`
serialization produce at most three milliseconds and one logical world unit of
quantization at the shared continuous contact; casualties, participant IDs and
the engineered road selected for damage are identical. It does not claim
bit-identical floating-point contact offsets across different valid partitions.

Route B was rerun in an imported, clean detached worktree at the exact
`a00b3d3` baseline with an independent V5 directory. It fails at the same
`R2_STATION_ISSUE_FAIL` precondition and emits the same Route B metrics as this
candidate. The only runtime change in this checkpoint is settled encounter
summary data, so this continuation failure is not attributed to the contact
coordinate change and remains outside this narrow correction scope.

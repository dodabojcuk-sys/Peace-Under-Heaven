# Encounter readability verification

## Scope and ownership

This checkpoint closes the user-confirmed baseline dispatch phase and adds a
minimal readable patrol encounter. `ConstructionController` computes the first
time-aware army/patrol contact and stores it in the already-settled encounter
summary. `ArmyRegistry` remains the sole owner of army composition, casualties
and macro orders; `FieldTacticsState` remains the owner of patrol facts and the
summary. `MacroMarchR0` consumes that read-only fact once for a local visual and
audio feedback window. It does not pause world time, calculate combat, mutate a
save, or create a durable combat phase.

## Engine GUI-event result

`tests/run_macro_march_encounter_feedback_graphical_smoke.gd` starts with the
formal map hold/strip/release dispatch path, advances the ordinary Controller
world clock into the authored patrol, then checks:

- contact feedback uses the authority contact timestamp and contact coordinate,
  not the end-of-frame patrol position;
- the selected army's side panel shows that encounter's actual own/enemy losses
  and remaining strengths;
- the effect and generated clash sting fire once only;
- refresh, pause, speed change and subsequent world time do not replay the
  effect or alter the settled army/food facts;
- an off-screen encounter remains non-disruptive until its explicit map notice
  is clicked; and
- same-process V5 snapshot restore preserves the authority result but primes it as history, so
  it cannot replay the effect or sound.

The graphical command completed with **7 assertions**.

## Evidence

All artifacts are engine GUI-event evidence, not normal macOS system-mouse
footage and not player hand-feel acceptance.

| File | State |
| --- | --- |
| `01-encounter-impact-engine-gui.png` | New authority encounter: approach/impact feedback and live result card. |
| `02-encounter-result-engine-gui.png` | Settled result card and selected-army detailed battle report. |
| `03-encounter-offscreen-notice-engine-gui.png` | Non-forcing, clickable off-screen locate notice. |
| `encounter-feedback-engine-gui-events.avi` | 110-frame / 60 FPS Godot Movie Maker sequence: direct dispatch, natural contact, feedback, result and locate path. SHA-256 `9a61579051b162f324e8665fc7c6a1eca27236dbd578c9776f0ec9d566b4bbf5`. |

## Commands and result

Godot executable:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| editor import / script parse | PASS |
| `tests/run_field_tactics_r2_smoke.gd` isolated V5 store | PASS, 71 assertions |
| `tests/run_macro_march_encounter_feedback_graphical_smoke.gd` isolated V5 store | Historical result: PASS, 7 assertions; superseded by the 11-assertion continuous Controller-process follow-up. |
| Movie Maker encounter capture | PASS, 110 frames at 60 FPS |

The wider multi-army/shared-patrol and siege-parallel settlement contracts stay
in the Field R2 smoke suite. This visual checkpoint adds presentation-specific
idempotence and same-process snapshot-restore coverage; actual exit/reopen
recovery is covered separately by the 2026-09-11 independent-process follow-up.
It does not claim desktop-system-input or player-experience acceptance. Player
acceptance remains **OPEN**.

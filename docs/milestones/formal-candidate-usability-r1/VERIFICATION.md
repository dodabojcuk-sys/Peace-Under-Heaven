# Formal candidate usability R1 verification

Status: implementation and engineering verification candidate. Human play
acceptance remains OPEN.

## Provenance and scope

- Baseline: `0da50abe317a9941f661c827c5b511917a081f2e`.
- Implementation branch: `codex/formal-candidate-usability-r1`.
- Engine: Godot 4.5.1 stable official on macOS Metal.
- All test and candidate sessions used explicit isolated save directories.
  The three pre-existing candidate windows and their saves were not closed or
  modified.
- Scope is launcher identity/admission, title usability, local interaction
  fixes and result explanation. No campaign, building, population, enemy,
  reward or art content was added.

## Launcher admission checks

The launcher canonicalizes the project and save paths, derives stable keys,
and records the full commit, branch and dirty state in the process arguments
and runtime state file. A per-save atomic launch lock closes the race between
two simultaneous launch attempts.

Observed probes:

1. Reopening the same clean candidate and save reports the existing PID and
   asks macOS to focus it instead of starting another process.
2. A second runtime with the same save key but a different commit is rejected
   with exit code 3 and both identities shown.
3. Existing older candidates with separate `/tmp` stores do not block the new
   isolated candidate.
4. A dirty checkout is never claimed to be reproducibly identical merely
   because commit and `DIRTY` agree; same-store admission conservatively blocks.
5. No launcher path terminates an existing runtime. The default player store is
   never selected by `RUN_ISOLATED_TXWZS.command`.

## Native macOS interaction inspection

The current-run accessibility session used operating-system pointer and
keyboard input against a separate Godot application instance. Godot exposes a
window-level accessibility tree rather than semantic child controls, so
actions were coordinate-driven after live screenshots.

1. **Title / healthy:** empty isolated store showed actual candidate identity,
   enabled New Game and disabled Continue. Development details were moved to a
   modal after the first layout exposed clipped inline paths.
2. **New game / healthy:** native click opened confirmation; confirmation
   entered the canonical city and created V5 generations through the existing
   owner.
3. **City operations / healthy:** pause/resume, 4x speed, build catalogue,
   logging-camp selection, cancellation and production-worker `+1` all changed
   the visible state as expected. Cancel left no placement draft.
4. **War map / mixed evidence:** native navigation and return worked and found
   an overlapping Blackstone detail/specialist hint at 1152x648; the local font
   adjustment removes it in all three graphical sizes. The available native
   drag primitive could not hold for the game's long-press threshold, so it did
   not prove command acceptance.
5. **Quit and continue / healthy:** the candidate quit through the normal macOS
   command, reopened with the exact same `--save-dir`, enabled Continue, and
   restored day/time, paused 4x state and the `19 available / 13 production`
   worker allocation. The window identity changed from `TITLE` to `CITY`.

The native session did not directly exercise every spatial battle command.
Engine GUI and domain coverage below are retained as executable evidence, not
relabeled as native mouse evidence.

## Engine GUI and domain verification

Final logs are under `evidence/logs/`; representative images are under
`evidence/screenshots/`.

| Area | Runner | Result |
| --- | --- | --- |
| Runtime identity | `run_runtime_identity_smoke.gd` | actual full commit retained, 12-character display, unknown fallback |
| Title and responsive layout | `run_m1b_playable_shell_smoke.gd` | New/Continue/Exit, modal details and 1152x648, 1280x720, 1440x900 |
| Macro map GUI | `run_macro_march_low_poly_graphical_smoke.gd` | 22/22; 1152x648, 1280x720, 1920x1080; selection, long-hold draw, scroll, cancel, focus loss, blocked targets and engineering |
| Construction | `run_construction_placement_smoke.gd` | placement, UI occlusion, cancel, camera drag and zoom |
| Population | `run_city_population_pressure_r0_smoke.gd` | 42/42 conservation and shared medical-capacity checks |
| V5 persistence | `run_v5_campaign_persistence_smoke.gd` | save/load, rollback, writer lock, bad-generation fallback and cold processes |
| Causal campaign | `run_blackstone_causal_playtest_r1_smoke.gd` | 10/10 departure cancellation, same-update order, recovery and victory continuation |
| Early route | `run_blackstone_early_counterattack_r1_journey.gd` | 15/15 normal resource route; 272.356 seconds |
| Spatial battle | `run_wartime_spatial_r1_smoke.gd` | 73/73 deployment, move, attack, hold, retreat, work, blockers, recovery and settlement |
| Macro siege GUI | `run_macro_siege_wartime_graphical_smoke.gd` | 12/12; facilities, three sizes, battle progression, result and return |

The graphical macro-siege fixture previously assumed that four timer signals
could complete a ram. Spatial battles advance from fixed 0.25-second frames and
crews must first travel; the fixture now advances that real spatial lifecycle
and accepts the truthful exposed-ram outcome. A separate spatial regression
still proves that a supported ram which reaches its work point damages the
actual gate.

## Personnel reconciliation

The result presentation separates two equations:

- This battle: `committed = surviving + newly wounded + newly fallen`.
- Campaign roster: `initial + additions = garrison + field army + wounded + fallen`.

The normal early-counterattack observation is:

`20 + 0 = 0 + 5 + 2 + 13`.

The five survivors are still one field army, the two wounded exist only in the
recovery owner, and the thirteen fallen exist only in the casualty ledger.
None are added twice. This closes the interpretation gap but does not judge
whether the route is well balanced; no enemy or resource value was changed.

## Remaining risks

- Native long-hold drag feel and all native spatial battle actions still need a
  human continuous play pass. Engine GUI coverage cannot close that gate.
- Normal early counterattack is executable at formal 4x world speed and 1x C0
  speed; there is no claim that it succeeds before departure at unaccelerated
  world speed.
- Engine screenshots and deterministic journeys are not Founder or player
  acceptance. No release package or deployment is included.

## Documentation status

- `AGENTS.md`: unchanged.
- `MEMORY.md`: unchanged.
- Created this verification report and the matching design note; updated the
  README, current state, changelog and earlier causal verification accounting.

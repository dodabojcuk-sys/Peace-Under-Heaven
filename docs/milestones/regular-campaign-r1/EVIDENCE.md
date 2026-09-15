# Regular Campaign R1 — evidence index

## Version and authority

- BASE_COMMIT: `f1ad13ec62ed57ceb71b089b4fa83b5d9607129b`
- Branch: `codex/txwzs-regular-campaign-r1`
- Worktree: `/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1`
- CODE_HEAD: `b4ebe2271e3a20e93d95f3bea07f9051f55df364`
- CODE_TREE: `d9ae9fdaa3fb3358f45eefbf23bf3e3f19d92fe4`
- RUNTIME_SHA256: `0ef58ea2ab2c3c170931795f4ffa36e83b80d15a351f45a0e5f74da95b563c03`
- Godot: `4.5.1.stable.official.f62fdbde1` from the verified local Godot 4.5.1 bundle.
- [Verified input manifest and old source identity](evidence/source-verification.json): all eight packaged source files match their expected bytes, lines and SHA-256. The loose task equals the archive entry; the full execution document and Appendix A were read before implementation.
- [Final test source inventory](evidence/verification-20260913-193144/provenance.json) and [final media source inventory](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-media/source-provenance.json) contain every hashed runtime file and the Godot binary digest.
- [Final delivery manifest](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-delivery.json) records FINAL_HEAD, final tree/status, exact live candidate PID/save directory and title capture. This is written after the verification-only commit; it does not pretend that media was recorded at a later HEAD.

The runtime digest hashes `project.godot` plus files in scripts/resources/scenes,
excluding generated `.uid`/`.import` metadata. Verification-only changes after
CODE_HEAD add tests, documents and evidence; runtime equality is checked again
at delivery. The graphical source was CODE_HEAD with pending report/generated
metadata changes, so its title truthfully includes DIRTY. The final prepared
candidate uses the final clean HEAD.

## Acceptance gates

| Gate | Meaning and result |
| --- | --- |
| ENGINEERING | PASS: source/import/diff checks and the bounded owner/transaction regression suite |
| FORMAL_PLAY_FLOW | PASS at Engine-GUI/API level: real fresh title path, legal fast and slow victories, one confirmed handover, continued home economy |
| COLD_RESTORE | PASS: isolated A–J processes plus a separate cold Continue over a completed normal victory |
| ADAPTIVE_PRESSURE_SCENARIOS | PASS for the deterministic candidate cases: actual losses, finite credit, ineffective farms, forecast/shortage, strong-force long delay, retry and finite enemy growth |
| REAL_INPUT_MEDIA | PASS for inspected Engine-GUI mouse/signal/API media and native title-window capture; a full OS-native mouse journey was not performed |
| HUMAN_ACCEPTANCE | OPEN: no human/Founder playtest, final art, final balance or broad device/performance acceptance |

## Reproducible engineering records

Run from the worktree:

```sh
/usr/bin/python3 tools/verify_regular_campaign_r1.py
```

[Final suite results](evidence/verification-20260913-193144/results.json) contain
all 22 actual command arrays, exit codes, markers and log digests. Each persistent
new runner has a unique temporary save directory. Existing cold runners manage
their own directories; old in-memory tests receive no shared persistence override.
The project uses Godot, so no unrelated npm/typecheck pipeline was invented.
[Final Godot import/parse log](evidence/godot-final-import.log) and
[unmarked-save launcher rejection](evidence/launcher-negative.json) cover the
editor import and safe launch boundary.

| Coverage | Inspectable record |
| --- | --- |
| 11 legacy regressions: Nation/resources, V5, army/training, building growth, population/governance, macro war, Blackstone causality and time consistency | `verification-20260913-193144/run_*` logs referenced in results.json |
| Pure rules, synthetic history/extreme inputs and bounded hysteresis | [rules](evidence/verification-20260913-193144/run_regular_campaign_rules_r1_smoke.log) |
| Normal transfer, productive construction, commands, retry and handover | [smoke](evidence/verification-20260913-193144/run_regular_campaign_r1_smoke.log) |
| Malformed entry, cost, pressure and scouting records | [validation](evidence/verification-20260913-193144/run_regular_campaign_r1_validation.log) |
| 30/60/irregular FPS, 1/2/4 speed equality over 180 game seconds, pause, real famine and long delay | [time](evidence/verification-20260913-193144/run_regular_campaign_r1_time.log) |
| Logging/farm/clinic/warehouse, finite food/person sources, command reservation and actual treatment | [services](evidence/verification-20260913-193144/run_regular_campaign_r1_services.log) |
| Explicit synthetic future-population boundary; six paid training batches and 50-person legal final garrison | [capacity](evidence/verification-20260913-193144/run_regular_campaign_r1_training_capacity.log) |
| Same-army local training, mixed-origin injury/retreat, actual military strength and stranded wounded after real food exhaustion | [wounded supply](evidence/verification-20260913-193144/run_regular_campaign_r1_wounded_supply.log) |
| Full authority rollback at paid completion, real pressure transition and actual combat loss; intentional pause is excluded from equality | [faults](evidence/verification-20260913-193144/run_regular_campaign_r1_faults.log) |
| Separate A–J cold processes, synthetic schema17 migration, consumed events/credit and repeated-confirm rejection | [cold recovery](evidence/verification-20260913-193144/run_regular_campaign_r1_recovery.log) |
| Same initial configuration, two deterministic confirmed victories with JSON metrics | [fast](evidence/verification-20260913-193144/run_regular_campaign_r1_journey.log), [slow](evidence/verification-20260913-193144/run_regular_campaign_r1_journey-slow.log) |
| Cold Continue after a real normal victory; no second confirmation, home clock continues with pressure zero | [completed victory restore](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-media/completed-restore.json) |

The 15-second checkpoint-fault tests use a test-only in-memory hook before disk
publication; independent recovery tests verify saved success receipts in fresh
processes. This is not a claim of simulated disk-controller/power-loss failure.

Development directories `verification-20260913-185009`, `185201` and `190817`
are explicitly earlier attempts, not final acceptance. They preserve a transient
parse failure, genuine capacity/mixed-wound bugs, and a test with too short a
ration horizon. The 190817 final-results receipt fixes only that last test horizon
on identical runtime source. Older `regression/` and loose logs are preliminary
or focused repair checks. The final 193144 suite above supersedes them.

## Images and continuous recording

[Final media commands/results](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-media/results.json)
record four fresh isolated runs: 8-food warning/recovery, 91-minute strong-force
pressure, normal fast completion, and continuous movie. No resource/HP/army
fixture is used. [Image manifest](evidence/image-manifest.json) records actual PNG
pixel sizes and hashes. Images were viewed directly; dimensions are not inferred
from a requested logical window size.

- [Preparation](evidence/02-preparation.png)
- [Productive farm at 1152×648](evidence/03-productive-base-1152x648.png)
- [Early food warning](evidence/07-food-warning.png) and [repaired forecast](evidence/08-forecast-repaired.png)
- [Local command interface](evidence/11-local-command.png)
- [Strong-force pressure 4 and enemy growth](evidence/10-high-pressure.png)
- [Pending victory](evidence/05-victory-preview.png), [confirmed handover](evidence/06-settled.png), [continued home city](evidence/09-home-after-settlement.png)
- [Actual large window](evidence/03-productive-base-1920x947.png)
- [Final continuous MP4](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-media/regular-campaign-r1-playable.mp4)
- [Original AVI with its original audio stream](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-media/regular-campaign-r1-continuous.avi)
- [Native final title window](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-candidate-title.png)

Graphical windows and captured viewports are 1152×648, 1280×720 and 1920×947.
The OS clamps the requested 1920×1080 window; no 1080-high capture is claimed.
The movie is a continuous 20-FPS recording with the regular clock at 4× after
preparation. Its duration/frame count and seven decoded review frames are in
[media inspection metadata](/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1-Delivery-20260913-185216/final-media/inspection.json).
The MP4 is a silent H.264 conversion; no game frame or action is cut out.

The title button and stacked-army selection use viewport mouse events. The native
confirmation dialog is invoked at its engine signal boundary; subsequent gameplay
uses the normal command API. This distinction is intentional and not labelled a
full OS-mouse playthrough. A native screenshot verifies the final prepared window
without moving, clicking or changing any old candidate.

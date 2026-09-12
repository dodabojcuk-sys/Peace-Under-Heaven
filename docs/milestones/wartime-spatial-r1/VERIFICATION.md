# Wartime spatial battle R1 verification

## Provenance and boundaries

- Date: 2026-09-12; Godot 4.5.1 stable, macOS Metal GUI and headless processes.
- Checkout: `/Users/m4-zhi/Documents/codex-workspace/txwzs-field-tactics-r2`.
- Development branch: `codex/txwzs-field-tactics-r2`.
- Inspected clean starting commit: `45018750a6bc7e2aa2c3c351dad7c4276e7f45e2`.
- Remote: `dodabojcuk-sys/Peace-Under-Heaven`; inspected default:
  `codex/txwzs-review-20260906`. Git/PR history records actual delivery.
- Existing candidate windows and player save directories were preserved.
  Graphics used unique `/tmp/txwzs-spatial-graphical-*` stores. Disk runners
  allocate their own process-isolated stores. Plain headless domain fixtures
  deliberately disable the player's V5 store.
- [Design and player operation contract](../../design/WARTIME_SPATIAL_BATTLE_R1.md).

## Coverage

| Requirement | Evidence / outcome |
| --- | --- |
| Formal macro assault | Normal city opens theatre; visible siege entry transfers original army; deployment, physical crew approach, prepared ram, attacks, victory, same-army station and formal theatre return pass |
| Formal sourced defense | Same configured Redcliff invasion arrives at Blackstone; formal defense, exterior trap crew, two approaches, barricade repair, protection support, victory and normal-city return pass |
| Map input | Engine mouse events select a visible formation, create deployment, clear an invalid draft and attack gates; active commands use existing order receipts |
| Geometry | Closed gates disconnect graph; outside cross-connection works; off-corridor/unreachable input rejected; moved units keep frozen source identity |
| Range / work | Distant crews do not build or damage gates; crews reach separate tower/ram sites; enemy approach triggers trap and completed lookout reveals corridor; repair requires crew arrival |
| Interruptions | Movement/retreat and death interrupt work; interrupted and destroyed repair envelopes restore correctly |
| Support | Haste affects distance; medical radius and living-member HP ceiling; domain entry/exit/expiry; map-selected domain route differs from frozen origin; formal shared-energy transactions |
| Retreat / defeat / wipe | In-range retreat damage and physical edge arrival; macro handoff suite covers original-army retreat, defeat and wipe without duplicate losses/food/capture |
| Schema migration | Schema 8 active snapshot projects deterministically and preserves HP/tick/gates/work; malformed current positions rejected; legacy terminal record restores without replay |
| Independent assault recovery | Six processes: moving crew -> construction progress -> active repair plus domain -> victory pending -> repeated confirm -> same stationed army |
| Independent defense recovery | Four processes: sourced active defense -> exact restore and real victory -> pending terminal confirm -> normal city and same resolved invasion |
| Frame consistency | 30/60/120 FPS and irregular frame partition match 8 ticks in 2 seconds; complete battles match terminal authority, HP, losses, gates, positions and tick at all three fixed frame rates |
| Regression | 33 relevant runners pass; full list and outputs in evidence/logs and observation.json |

Cold workers compare serialized actual positions, targets, HP, work/effect
remaining ticks, food, wood and energy against a sidecar expectation before
advancing. Sidecars are test audit data, never game save owners. Terminal
checks compare the existing terminal authority because active snapshots are
intentionally empty after completion.

## Graphical evidence

Screenshots and animated WebP recordings are actual Godot render output at
1280x800. The test submits engine input/formal signals and advances existing
world/battle time under controlled acceleration. One 250 ms battle tick per
recorded 30 FPS frame is approximately 7.5x battle speed; pauses and setup vary.
WebP samples every second recorded MJPEG frame while retaining duration.
No synthetic reconstruction of the battle is used.

- [Assault recording](evidence/assault.webp)
- [Defense recording](evidence/defense.webp)
- [Deployment](evidence/assault-01-deployment.png)
- [Crew approach](evidence/assault-02-crew-approach.png)
- [Full corridor domain](evidence/assault-02-domain-coverage.png)
- [Ram and tower](evidence/assault-03-ram-and-tower.png)
- [Defense repair and support](evidence/defense-03-repair-support.png)
- [Assault result](evidence/assault-04-result-pending.png)
- [Return to city](evidence/defense-04-return.png)

These prove automated engine behavior, not native-pointer usability, final
balance or human normal-speed acceptance. Those gates remain OPEN. The map
is a finite-corridor functional graybox with aggregate enemy groups.

## Reproduction

```sh
GODOT=/absolute/path/to/Godot
"$GODOT" --headless --path . --script res://tests/run_wartime_spatial_r1_smoke.gd
"$GODOT" --headless --path . --script res://tests/run_wartime_defense_r0_smoke.gd
"$GODOT" --headless --path . --script res://tests/run_macro_siege_wartime_persistence_smoke.gd
"$GODOT" --headless --path . --script res://tests/run_wartime_defense_persistence_smoke.gd
"$GODOT" --path . --fixed-fps 30 --write-movie /tmp/spatial-assault.avi \
  --script res://tests/run_wartime_spatial_r1_smoke.gd -- \
  --txwzs-v5-save-dir=/tmp/UNIQUE-spatial-save --evidence=/tmp/spatial-evidence
```

Use `--defense` after `--` for the defense recording. Always use a fresh
isolated store for graphical fixtures. Use ordinary domain fixtures without
forcing an old fixture into V5 disk publication.

## Review notes

Superseded two-route defense assertions are preserved under
`tests/historical/two_route_c0/`; the current entry runs the spatial formal
journey instead of claiming historical remote-work timing still applies.
The C0 exit fixture now accounts for its artificial infantry change in the
existing population total; no production population expansion was added.
Two field runners report ObjectDB instances leaked at exit; their assertions
pass, with no script errors. This known runtime-exit warning remains visible
in the archived logs and is not presented as a clean shutdown claim.

AGENTS.md and MEMORY.md were not changed. Design, current status, decisions,
changelog, historical markers, coverage and evidence were updated.

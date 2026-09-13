# Campaign time consistency and strategy comparison R1 verification

Date: 2026-09-13

## Provenance

- Remote default baseline: `4d3d3b61e024ab3cea6772df518615fc321d1991`.
- Local formal candidate: `0119addb49a9ff6d0af2f5e5136ce97732067b86`.
- Both resolve to tree `15f0260d785085016eb11dd0ebb65468b7fd10eb`;
  the difference is commit ancestry, not candidate content.
- All new runtime and journey checks used independent `/tmp` V5 stores. The
  player store and the already-running candidate window were not touched.

## Observed time contract

`ConstructionController` owns one ordered world frame: city calendar and day
settlement, player-army movement, then field work/patrol/invasion/siege. Player
pause stops every domain. Speed multiplies real delta exactly once for city,
army and field work. A city/field presentation switch does not pause it, and V5
restore resumes saved day, sub-day milliseconds, pause and speed without
offline catch-up.

Formal C0 disables the city root and advances `BattleSession` in 0.25-second
fixed ticks. While C0 is open, city, army and field time are all frozen. Result
confirmation keeps the existing source distinction:

- sourced defense and durable legacy expedition add canonical battle duration
  to city time only;
- macro siege adds no city catch-up;
- neither source catches up army or field time.

This is an existing player-visible product rule, now stated precisely. It was
not silently replaced with a different campaign cadence.

## Root causes and changes

### Runtime boundary

Before R1, crossing the configured day-5 departure boundary in one frame set
the invasion to moving before the complete field delta was consumed. A larger
2x/4x frame therefore granted a few milliseconds of pre-departure movement.
The departure now stores the canonical world instant and preserves the
pre-boundary portion as waiting time. No second clock or save field was added.

### Journey runners

Two test-only defects were separate from runtime behavior:

1. The accelerated closeout helper called the city `_process` method directly
   while C0 had disabled the city root, manufacturing city and field progress
   that a formal run cannot receive.
2. The early-counterattack helper waited for day 5 with one fixed wall-time
   timeout. That incorrectly failed slower speeds even after they had legally
   occupied both cities on day 1.

The helper now skips world stepping while C0 exists, and the date-gated timeout
is derived from equal game-time budget. Formal commands and battle input paths
remain unchanged.

## Speed comparison

The focused runner advances the complete controller frame in 100 ms real-time
steps to the same 740,000 ms game instant and issues all commands from initial
state gates. The strategic snapshot is byte-equivalent after removing only
diagnostic fields that name the containing engine frame.

| Speed | Simulated real time | Date / field clock | Shared outcome |
| --- | ---: | --- | --- |
| 1x | 740.000 s | Day 5 + 20.000 s / 740.000 s | Same |
| 2x | 370.000 s | Day 5 + 20.000 s / 740.000 s | Same |
| 4x | 185.000 s | Day 5 + 20.000 s / 740.000 s | Same |

Shared facts include food 33, wood 55, farm ready at 180,000 ms, day-2
training completion, completed engineer road/camp, player army stationed at
Northwatch with 9 members, and the invasion activated at exactly 720,000 ms
with strength 10 and move progress 6,704 ms. Pause produces zero delta, restore
is exact, and two seconds of C0 always produce eight fixed ticks with zero
world delta.

## Strategy comparison

Both paths start from the normal 20 military, 80 food, 100 wood and city
defense 10. Resource expenditure is reported from committed transactions;
final stock also includes normal production and upkeep.

| Path | Completion / measured wall time | Committed preparation and orders | Final ledger | Final stock / defense |
| --- | --- | --- | --- | --- |
| Early counterattack | Both cities day 1; day-5 cancellation at 804.746 s / 1x, 444.615 s / 2x, 263.241 s / 4x | 9 food in three march orders; 12 food in four daily upkeep settlements; no build, training or treatment spend | `20 + 0 = 0 garrison + 5 field + 2 wounded + 13 fallen` | food 59, wood 100, defense 10 |
| Prepare, defend, recover, counterattack | Day 5 + 145.348 s; 947.570 s at 1x | wood 80 for farm/housing; food 13 for road/camp/tower, 15 training, 4 treatment and 14 in three march orders | `20 + 5 = 0 garrison + 17 field + 1 wounded + 7 fallen` | food 63, wood 20, defense 10 |

The prepared route also retains its completed road, camp and arrow tower. Its
food stock reflects farm production, so final food must not be read as gross
spend. The early route is much faster in game date but accepts greater military
loss; the prepared route spends infrastructure/resources and takes longer but
retains twelve more active soldiers. One deterministic comparison is evidence
of a trade-off, not a balance mandate.

## Regression matrix

| Runner / check | Result | Scope |
| --- | --- | --- |
| `run_campaign_time_consistency_r1_smoke.gd` | PASS, 34 assertions | 1x/2x/4x, pause, restore, construction, training, march, field project, invasion boundary and fixed-step C0 |
| `run_blackstone_causal_playtest_r1_smoke.gd` | PASS, 10 assertions | cancellation, rollback/retry and post-victory legality |
| `run_blackstone_invasion_r0_smoke.gd` | PASS, 17 assertions / 29 steps | invasion lifecycle and movement |
| `run_blackstone_closeout_r1_clock_smoke.gd` | PASS | calendar, pressure and food projection |
| `run_m0_time_build_pressure_smoke.gd` | PASS | construction and schema recovery |
| `run_v5_training_queue_smoke.gd` | PASS | training day boundaries and atomic failure |
| `run_blackstone_recovery_r0_smoke.gd` | PASS, 9 assertions | treatment and population conservation |
| `run_war_loop_r1_smoke.gd` | PASS, 16 assertions | field/macro lifecycle and two-city victory |
| `run_macro_siege_wartime_victory_smoke.gd` | PASS, 9 assertions | C0 result writeback and idempotence |
| `run_v5_campaign_persistence_smoke.gd` | PASS, three cold processes | exact V5 save/restore progression |
| `run_wartime_spatial_r1_smoke.gd` | PASS, 73 assertions | formal battle input, result and return |
| Godot editor import and city headless boot | PASS | parse/import and canonical city entry |

The strategy journeys are engine-GUI/formal-command evidence, not native OS
mouse evidence. Focused smoke runners prove logic and persistence boundaries.
Neither category replaces human long-hold, battle-feel or player acceptance.

Machine-readable summary:
[strategy-comparison.json](evidence/strategy-comparison.json).

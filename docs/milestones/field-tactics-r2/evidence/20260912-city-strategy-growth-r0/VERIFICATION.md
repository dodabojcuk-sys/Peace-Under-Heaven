# City Strategy Growth R0 Verification

## Identity and scope

- Baseline: `156087c6310c8aa197c5bb227bbd0b5d7fa8331d`
- Branch: `codex/txwzs-field-tactics-r2`
- Engine: Godot `4.5.1.stable.official.f62fdbde1`
- Save boundary: fresh directories under `/tmp`; retained player saves and
  candidate windows were not modified.

This slice completes the first six-slot general equipment set, deterministic
training, rank-up and same-slot experience inheritance. It also resolves the
three known Macro March location-detail assertions. It does not claim native
pointer or human full-campaign acceptance.

## Root cause of the Macro March failures

The location-detail fixture still dispatched only its first two formations.
The current playable theatre contains a real six-member patrol before the
Redcliff siege, so that old force closed before occupation. The continuation
and restored-control checks then failed as consequences. Dispatching every
available formation, as the formal direct-route playthrough already does,
allows the legal occupation and makes all three intended location checks pass.
No location capability, defender, casualty or occupation rule was weakened.

## Evidence

- `run_city_strategy_growth_r0_smoke.gd`: 28 assertions for six slots, real
  combat effects, training/rank/inheritance rollback, equipped and active-order
  source refusal, retained over-cap experience, frozen march/combat parameters
  and V5 restore.
- `run_city_strategy_r0_persistence_smoke.gd`: three independent processes
  preserve FINE quality, inherited experience, consumed source identity,
  support energy/expiry, receipt and one in-flight army.
- `run_city_strategy_r0_graphical_smoke.gd`: 18 assertions at 1152x648,
  1280x720 and 1920x1080. Visible controls manufacture/equip all six slots,
  train, rank and perform inheritance after showing source destruction.
- `run_macro_march_r0_smoke.gd`: 35 assertions; the previously failing occupied
  city detail, continuation order and engineering-camp restore checks pass.
- `run_field_tactics_r2_playthrough_smoke.gd`: 7 assertions; the direct and
  engineering routes still complete with their authored encounters and city
  continuation.
- `run_macro_siege_wartime_victory_smoke.gd`: 7 assertions; the siege takeover
  and one-time result writeback remain valid with the frozen order strategy.
- `run_v5_campaign_persistence_smoke.gd`: PASS, including the existing three
  independent-process campaign chain.

Graphical captures are Godot GUI-event/render evidence:

- `city-strategy-overview-1152x648.png`
- `city-strategy-overview-1280x720.png`
- `city-strategy-overview-1920x1080.png`
- `city-strategy-support-active-1280x720.png`
- `city-strategy-equipment-trade-1280x720.png`
- `city-strategy-six-slot-growth-1280x720.png`

## Acceptance boundary

The underlying city, V5, field, siege and campaign regressions are rerun for
the final candidate. Native-pointer feel and an unaccelerated human campaign
remain **OPEN**. The earlier stall remains **NOT REPRODUCED / NOT DIAGNOSED**.

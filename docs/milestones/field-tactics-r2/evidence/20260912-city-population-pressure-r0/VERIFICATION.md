# City Population Development and Social Pressure R0 Verification

## Provenance

- Date: 2026-09-12, Asia/Shanghai.
- Repository: `txwzs-field-tactics-r2`.
- Verified baseline/default/development commit before work:
  `de9e98a5b794dd46de1a5d06089970288c48a991`.
- Actual remote default: `codex/txwzs-review-20260906`.
- Development branch to synchronize after merge:
  `codex/txwzs-field-tactics-r2`.
- Candidate branch: `codex/txwzs-city-population-pressure-r0`.
- Godot: 4.5.1 stable; headless and macOS Metal GUI.
- GUI and persistence runs used isolated temporary V5 save directories. Existing
  player saves and already-open candidate windows were not reused or closed.

## Observed population examples

| Point | Observed authoritative population state |
| --- | --- |
| Fresh campaign | total 72; unknown sex 72; child 0; elderly 0; available 20; military 20; all allocations accounted once |
| Housing completed and placed | housing 88; total remains 72 |
| Healthy city at day 6 | total 73; child 1; available remains 20 |
| Nine-person refugee group accepted after birth | total 82; unsettled 9; available remains 20 |
| Housing-backed settlement | unsettled 0; available 27; resident sick 2 |
| Same group accepted without new housing | total 81; unsettled 9; available 20; settlement blocked with nine-person housing shortfall |

The accelerated age checks use explicit configured boundaries rather than
pretending that a short first-level journey spans generations. Maturation moves
one child to available population. Adult ageing moves only an available city
adult and leaves the same military count. Warned winter exposure records one
elderly death only after its configured threshold.

## Social pressure and recovery observations

- Low security first accumulates visible warning pressure. Continued exposure
  creates one stable petty-theft event and removes a bounded two food from the
  real inventory once; reopening or reapplying does not charge it twice.
- Continued shortage upgrades the same event to targeted production disruption
  and then local production/construction stoppage. It does not change Blackstone
  control or create a battle.
- A staffed governance action spends two food and resolves only the current
  event. Restoring food and housing, then advancing stable days and handling
  concrete events, returns pressure to zero and restores production.
- With four shared medical slots and two reserved by an active wounded batch,
  only two resident sick recover that day. Refugee illness uses the same
  remaining-capacity flow and transfers to resident sickness on settlement.

## Verification results

The following 19 headless runners passed after the final implementation change:

- city population/pressure logic and three-process persistence;
- city governance logic and three-process persistence;
- Blackstone recovery and V5 training;
- sourced Blackstone invasion;
- city strategy, equipment growth and strategy persistence;
- field stationed reinforcement and persistence;
- formal war-loop scene;
- Field Tactics R2 logic, playthrough and persistence;
- Macro March logic and persistence;
- V5 campaign persistence.

The focused population runner passed 41 assertions. The Metal graphical runner
passed eight assertions at 1152x648, 1280x720 and 1920x1080, including visible
accept/defer/reject controls and a disabled settlement action during a real
housing shortfall. Godot editor parsing and the regular-city, field-theatre and
C0 scene launch smokes all exited successfully. `git diff --check` passed.

## Evidence inventory

- `city-governance-default-1152x648.png`
- `city-governance-default-1280x720.png`
- `city-governance-default-1920x1080.png`
- `city-governance-pressure-action-1280x720.png`
- `city-governance-resolved-1280x720.png`
- `city-population-refugee-pending-1280x720.png`
- `city-population-refugee-waiting-1280x720.png`

## Acceptance boundary

These are deterministic/domain, process-recovery, scene-launch and engine-GUI
results. They are not a human normal-speed journey. Manual player experience,
usability and final balance acceptance remain **OPEN**.

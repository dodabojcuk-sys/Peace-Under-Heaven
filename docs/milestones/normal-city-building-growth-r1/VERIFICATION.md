# Normal City Building Growth R1 Verification

Date: 2026-09-13

## Coverage

| Building | L1 capability | L2 capability | Upgrade cost | Duration | Runtime consumer |
| --- | ---: | ---: | ---: | ---: | --- |
| Farm | 22 food/day | 36 food/day | 65 wood, 6 food | 2 days | Daily production with road, workforce, pressure and storage limits |
| Logging camp | 18 wood/day | 30 wood/day | 60 wood, 4 food | 2 days | Daily production with road, workforce, pressure and storage limits |
| Warehouse | +120 each | +200 each | 80 wood, 4 food | 2 days | NationState admission capacity; no inventory grant |
| Housing | +16 | +28 | 55 wood, 4 food | 2 days | City housing capacity; no resident grant |
| Clinic | +6 | +10 | 70 wood, 8 food | 2 days | Shared wounded/disease capacity with staff and food limits |

All upgrades retain placement identity and location. The old capability stays
active until the completion checkpoint succeeds. R1 cancellation refunds the
entire paid cost and keeps the original building. A building with an active
upgrade cannot be resubmitted or removed.

## Automated evidence

| Layer | Command / runner | Result |
| --- | --- | --- |
| Logic and transactions | `run_normal_city_building_growth_r1_smoke.gd` | PASS, 41 assertions |
| Cold process recovery | `run_normal_city_building_growth_r1_persistence_smoke.gd` | PASS, active -> complete -> reopened complete across 3 processes |
| Existing building lifecycle | `run_building_lifecycle_smoke.gd` | PASS |
| Existing selection/input | `run_building_selection_smoke.gd` | PASS |
| Existing unified building flow | `run_unified_building_interaction_smoke.gd` | PASS |
| Population/governance | `run_city_governance_r0_smoke.gd`, `run_city_population_pressure_r0_smoke.gd` | PASS |
| Campaign persistence | `run_v5_campaign_persistence_smoke.gd` | PASS |
| Engine-GUI | `run_normal_city_building_growth_r1_graphical_smoke.gd` | PASS at 1152x648, 1280x720, 1920x1080 |

The focused logic runner verifies insufficient state through the authoritative
preview, duplicate submission, full cancellation refund, start-save rollback,
completion-save retry, V16 migration, active restoration, exact L2 capability
projection, daily logging income spent through formal training, and real
wounded treatment without fallen revival.

## Graphical evidence

The original six `building-growth-confirm-*` and `building-growth-progress-*`
captures are retained as pre-fix evidence. In particular, the original
1152x648 progress capture shows the overlap closed by the phase-closeout fix;
those files are no longer the final passing visual set.

The final six `building-growth-final-confirm-*` and
`building-growth-final-progress-*` captures show the corrected formal states
at 1152x648, 1280x720 and 1920x1080. The confirmation names the building and
level transition and exposes capability, cost, duration and limiting
conditions. Active project facts occupy a bounded scroll region above the
minimum-height action group, so paid amount, remainder, ETA, feedback and
buttons remain accessible without smaller text or hidden facts.

The old `木材 200/160` value came from the graphical runner's direct
`city.wood = 200` layout fixture. It did not prove that formal gameplay created
an overflow and must not be used as economy evidence. The final fixture uses
150 wood within the existing 160 capacity and spends the normal 65-wood
upgrade cost. No storage/admission rule was changed. The separate 41-assertion
logic runner proves the normal fresh-new-game formal build, placement, upgrade,
daily yield and training chain; the graphical runner proves presentation and
state transitions, not resource acquisition.

The final graphical runner additionally checks active cancellation/refund
wording, zero construction-worker waiting, completion-save retry and completed
L2 capability projection at every supported resolution.

This is Engine-GUI and logical evidence, not native mouse evidence or human
acceptance. Final building art, perceived pacing, click/drag feel and balance
judgment remain for human playtesting.

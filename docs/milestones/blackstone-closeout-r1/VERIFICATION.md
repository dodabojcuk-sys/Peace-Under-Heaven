# Blackstone first campaign closeout R1 verification

Status: both normal-speed engine journeys and 18 independent recovery nodes pass.
Human play acceptance remains OPEN. Remote merge is reported only after readback.

## Provenance

Baseline/default/development remote refs were fetched at
`136fe568fffd3e83b4ba5b46016d24b7900457bf` on 2026-09-13.
Implementation branch: `codex/blackstone-first-campaign-closeout-r1`.
Engine: Godot 4.5.1 stable official, native Metal GUI and headless workers.
All game stores use explicit `/tmp/blackstone-r1-*` directories. Existing
player stores and pre-existing candidate windows were not used or closed.

## Evidence gates

- Normal-start accelerated diagnosis: A and B pass. Explicitly separate from
  1x recordings; no resource/date/army/build/gate/result mutation.
- Eight-node independent recovery diagnosis passes using V5 generations.
- Focused current war, population, strategy, construction/calendar and save
  regressions are collected under `evidence/`.
- Five historical runners had failures at the unmodified baseline. Fixture
  corrections align upkeep, schema roots, theatre identity and military
  population with their actual contracts. Legacy repeated settlement exposed
  and now tests a real missing casualty-accounting path.
- Human play and native-pointer feel remain OPEN. Unspecified historical stall
  remains NOT REPRODUCED; do not conflate it with the reproduced clock drift.

## Normal-start continuous journeys

| Journey | Strategy and outcome | Real duration | End state |
| --- | --- | --- | --- |
| A | Paid farm/housing/training; optional road, camp and arrow tower; sourced spatial defense; paid treatment; original formations counterattack and occupy both cities | 947.570 s (15m 47.570s) | Day 5; food 63, wood 20; living 65, military 17, wounded 1, fallen 7; camp/tower retained |
| B | Retain engineering resources; paid city preparation and sourced defense; treatment; counterattack, retreat to Northwatch, reissue the same army, then occupy both cities | 973.964 s (16m 13.964s) | Day 5; food 80, wood 20; living 65, military 17, wounded 1, fallen 7 |

Each farm and housing project takes about 180 real seconds. Waiting for warning
and departure accounts for most preparation time; players can instead use the
existing 2x/4x controls, optional operations or early direct attack. These runs
remain at 1x. No resource, date, army, gate, casualty or construction-completion
fixture is mixed into these records. No refugee acceptance was forced: these
1x routes finish on day 5, before the authored day-6 refugee case.

Each route has nine saved nodes. A includes an external-defense-line node;
B includes the original army returned after retreat. Both include preparation,
warning, marching, active defense, pending result, recovery, occupation and
victory. `cold-a-*` / `cold-b-*` logs restore separate copies in independent
processes. They continue clocks or battle ticks, confirm terminal results twice,
retain invasion/reward identities, check population, and prove post-victory
city return, Silverford supply inspection and exact-army reissue. The late-day
pressure/training probe is explicitly an isolated fixture after the normal
restore checks; it is not normal journey evidence.

The complete 1x timed logs, per-node PNGs, original V5 generations and JSON
reports are in `evidence/normal-a*` and `evidence/normal-b*`. Latest presentation
and treatment-preflight changes are additionally checked by `ui.log` and the
focused recovery regressions. No video or native-pointer recording is claimed.

## Relevant regressions

The final passing logs cover sourced invasion and recovery, field route A/B,
city population/governance/strategy, Macro March, macro handoff/victory and
independent siege restoration, defense restoration, population restoration,
formal-scene timing, V5 training/save, city viewport and pressure migration,
legacy noticeboard/repeated time settlement, clock precision, spatial battle
and exit/return. Baseline-comparison logs are historical failures, not final
passing evidence. No package lint tool is configured; Godot script loading,
scene execution, runtime assertions and `git diff --check` are the applicable
checks.

## Remaining boundaries

- Human experience acceptance and native-pointer feel remain open.
- The historical unspecified stall was not reproduced. F8 now exposes effective
  ancestor processing, clock, task/path and save state for diagnosis.
- Early occupation does not cancel an unlaunched configured invader under the
  existing rule. The separate rule decision is described in the design note.
- Source-specific clock behavior remains: a battle disables city and field
  processing; defense settlement catches up city time, macro assault does not;
  field time does not catch up either. The tooltip and diagnostics disclose it.
- Economic coefficients, food costs, authored force, dates and victory condition
  are unchanged. New legacy harassment is retired from the formal campaign,
  while economic deadline and social-pressure costs remain real.
- AGENTS.md and global/project MEMORY.md were not changed. Current state,
  coverage, README, changelog, contract and this evidence report were updated.

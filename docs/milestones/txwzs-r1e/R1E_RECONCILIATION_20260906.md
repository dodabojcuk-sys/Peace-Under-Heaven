# R1E reconciliation — 2026-09-06

## Purpose and identity

This is an engineering reconciliation record for the current R1E expedition
branch. It separates confirmed product decisions, existing implementation, and
unimplemented work. It is neither a replacement full-game design nor a Founder
acceptance record.

| Item | Current value |
| --- | --- |
| Branch | `codex/txwzs-expedition-visual-r1e` |
| Baseline commit | `147430ed1d4fe584abcb423755da4455e5d5f95c` |
| Engine | Godot 4.5.1 |
| Remote | No Git remote configured locally |

## Confirmed product rules, not newly implemented here

- Enemy inner cities have no separate attack scene. Enemy inner-city state is
  not directly visible; spy actions should return a parameter report.
- A breached gate is not itself victory. The defending force must be defeated
  or surrender and occupation must occur. If no other eligible enemy city
  remains, the later product rule is to end the match in victory.
- A captured foreign story city is a garrison point, not an automatically
  buildable sub-city.
- Generals may die, but persistence, revival, and campaign consequences remain
  open. Do not infer an implementation contract from that decision.
- All generals share one energy pool and all strategists share another. Energy
  is not per-character; no save migration is authorized in this reconciliation.
- `匿迹奔袭` is an active energy ability for one army to traverse non-road
  terrain. It is not passive stealth and not an army-wide movement rule.
- Main roads are indestructible. Engineers receive a drawn route and the
  system decides road versus bridge and performs construction; they are not a
  tile-by-tile road-placement system. Basic roads should not be excessively
  slow.
- Engineers can discover and clear mines and can be killed; scouts can detect
  disguises.
- Battlefield and main-city building advancement are level/era gated. Do not
  assume complete inner-city persistence.

## Current implementation boundary

The current C0/R1E battle code implements a route-level victory condition: the
route gate must be destroyed and that route's defending force must be reduced
to zero while the player survives. This is useful engineering scope, but it is
not the complete product rule for occupation, remaining enemy cities, captured
city garrisons, spies, or invisible inner cities.

The following are intentionally still open and were not introduced by this
reconciliation:

- shared-energy capacity, recovery, UI, and migration;
- active ability timing, cost, interruption, and non-road expiry;
- replenishment economy and recovery;
- permanent general death semantics;
- main-road traversal effects;
- fog, disguises, mines, mine clearing, weather, and the full supporting UI;
- formal occupation and multi-city match-end rules.

## Local repair

Expedition preparation roster cards previously rendered values such as
`formation.blackstone.1`, which are internal data identifiers rather than
player-facing content. The cards now render formation name, headcount, capacity,
and availability only. The focused R1E smoke asserts that `formation.` cannot
appear in this surface.

The mainline title and objective wording were intentionally not renamed. Their
relationship needs a product and code-source decision, not a cosmetic patch.

## Verification evidence

### Automated baseline

- `tests/run_r1e_expedition_causality_smoke.gd` covers responsive preparation
  layout, selection validation, payment and persistence ownership, reload and
  duplicate-write idempotence, retreat, victory, defeat, and presentation
  contracts.
- `tests/run_c0_battle_presentation_smoke.gd` covers C0 objective projection,
  selection commands, and responsive presentation.
- Headless startup checks cover `blank_map.tscn` and `c0_battle_graybox.tscn`.

### Native single-city run

An isolated temporary Day 1 save was used to protect the user's existing
campaign data. The real native path was:

1. city screen;
2. select the first two formations (14 people; food cost 3);
3. enter the current mainline battle;
4. issue `ADVANCE` to both formations on the front route;
5. receive defeat at battle tick 532, with 0 survivors;
6. confirm the result and return to the city, where the paid food and pending
   mainline result were visible.

This is valid evidence for the current failure/return/writeback path. It does
not demonstrate a normal-input victory, gate breach, occupation, or Founder
acceptance. A future real victory must be established through the intended
player conditions rather than a static image or a test-only win fixture.

## Handoff boundary

The next engineering task is to reconcile the intended ordinary siege entry
conditions with an actual winnable player path, then validate breach and
occupation semantics. It must preserve the existing single settlement and
expedition ownership boundaries. This reconciliation makes no remote change and
does not authorize a GitHub push.

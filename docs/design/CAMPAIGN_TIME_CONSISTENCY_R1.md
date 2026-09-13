# Campaign time consistency and strategy comparison R1

Baseline: remote default merge `4d3d3b61e024ab3cea6772df518615fc321d1991`.
The local candidate `0119addb49a9ff6d0af2f5e5136ce97732067b86`
has the same Git tree `15f0260d785085016eb11dd0ebb65468b7fd10eb`;
their commit graphs differ because the former is the PR merge.

## Product question

Speed is a real-time control, not a strategic modifier. The same commands
issued at the same world dates or authoritative state gates must produce the
same dates, resources, construction, treatment, army identities, casualties
and control. Real elapsed time is expected to scale with 1x, 2x and 4x during
world simulation. C0 battle time is intentionally independent of world speed.

This work reuses `ConstructionController` as the only world-time authority and
`BattleSession`'s existing 0.25-second fixed step. It does not add another
clock, alter save schema, rebalance armies or change campaign victory.

## Existing time contract

| Activity | Authority and step | Pause / speed behavior |
| --- | --- | --- |
| City date and daily food/production | `ConstructionController.advance_city_time` and ordered day boundaries | Stops on player pause and C0 scene transfer; 1x/2x/4x multiplies real delta once |
| City construction and treatment | Substeps of the city-time advance; training completes at a day boundary | Same city pause and speed |
| Army march / retreat | `ConstructionController._advance_all_macro_marches_seconds` into `ArmyRegistry` | Same player pause and speed |
| Field construction, specialist work, patrols and configured invasion | `ConstructionController.advance_war_loop_time_seconds` into `FieldTacticsState.advance_world` | Same player pause and speed |
| Macro siege | War-loop substep, except the one siege transferred to C0 | Same player pause and speed before handoff; transferred siege is frozen |
| C0 | `BattleSession`, advanced in 0.25-second fixed ticks | City root is disabled; world speed does not alter battle ticks |
| Scene switch city / field | Presentation only | World continues unless the player pauses |
| Save restore | Persisted day, elapsed milliseconds, pause and speed; no offline catch-up | Resumes the exact saved state |

### C0 settlement boundary

Entering any formal C0 disables the canonical city scene, so no city, field,
march, specialist, patrol or invasion process advances while the battle is
open. On confirmation, the established source contract applies exactly once:

- sourced city defense and legacy expedition results advance city-only time by
  the canonical battle duration;
- macro-siege results do not advance city time;
- neither source catches up field time or marching.

This source-specific settlement behavior is already documented and player
visible in the city time tooltip. R1 preserves it. Changing it would alter the
campaign economy and invasion timing and requires a separate product decision.

## Deterministic ordering

One normal world frame executes city/calendar state first, all player army
movement second, then field work, patrol contact, configured invasion departure
and macro siege. The existing causal rule therefore lets an occupation settled
by the army step cancel a dormant source invasion in the later field step. UI
refresh order is not authoritative.

Comparisons must call the same complete controller world-frame entry and issue
commands from world dates or state predicates. Directly advancing only a city,
army, field or siege clock is allowed in focused unit fixtures, but cannot be
used as evidence of whole-campaign speed consistency.

## Acceptance criteria

1. Identical 1x, 2x and 4x scenarios reach matching strategic snapshots at
   equal world elapsed time while simulated real duration scales inversely.
2. Pause changes neither city nor field state and creates no catch-up on resume.
3. C0 advances only its fixed-step session while open; source-specific result
   settlement remains unchanged.
4. The normal early counterattack remains possible at 1x when commands use the
   same state gates, and a dormant Redcliff vanguard still cancels on day 5.
5. Existing accelerated journey helpers never call the disabled city process
   during C0 and therefore cannot manufacture field or calendar progress.
6. Strategy comparison reports costs and the disjoint military ledger without
   treating a single outcome as a balance mandate.

Human long-hold input and battle feel remain separate acceptance gates.

# Blackstone first campaign closeout R1

Baseline: `136fe568fffd3e83b4ba5b46016d24b7900457bf`; remote default
`codex/txwzs-review-20260906`, development `codex/txwzs-field-tactics-r2`.
Both remote refs were fetched and verified at that baseline on 2026-09-13.

## Contract and acceptance

Reuse the confirmed Blackstone campaign and spatial battle contracts. Day 4
warns, day 5 launches the same invader; day 7 is the existing economic pressure
deadline, not a second invasion or an instant loss. Control of both Redcliff
and Silverford clears the campaign. Defense and interception are optional
consequences of the chosen timing, not additional victory flags. A surviving
invader retains its identity after interception; a destroyed invader cannot
spawn defense. Main-city defeat retains the city with actual losses.

Existing economic pressure parameters remain unchanged pending continuous
normal-start evidence. The completed campaign must stop deadline pressure;
ordinary upkeep, housing, health and finite recruitment remain applicable.
No date ceiling may permanently prevent training in this campaign. Old
first-war and noticeboard transactions keep their identities and settlement;
new noticeboard missions leave the normal Blackstone campaign entry flow.

City and field share the controller speed and player pause. In-battle city
and field processing are blocked by the battle scene. Battle time uses its
own session. Sourced defense/legacy settlement catches up city time by the
canonical result duration; macro siege currently does not catch up city time.
The field clock does not catch up either source. This source-specific existing
behavior is documented, not silently replaced by a new global clock rule. Diagnose these clocks separately.
Do not introduce a second save owner or rewrite existing player stores.

## Implementation and verification plan

1. Project live campaign control and invasion phase into the city header;
   make its action open the field source/location using existing navigation.
2. Restore post-deadline training and stop post-victory pressure by querying
   WarLoopState, without rewriting the historical first-war ledger.
3. Retire new legacy noticeboard starts while retaining restore/result paths.
4. Expose read-only clock, training, path/project and checkpoint diagnostics.
5. Verify focused regressions and two independent normal-start journeys with
   formal inputs; isolate extreme fixtures from playable evidence. Record
   normal-speed duration, waits, restart nodes and any missing coverage.

Early occupation currently does not cancel a configured departed/dormant
invader. Changing that authored force based on control is an unconfirmed rule;
retain existing behavior and describe the still-live threat truthfully.
Engine GUI evidence does not close human play acceptance. Art stays deferred.

## Implemented corrections

- The city header now reads the two-city objective and invasion lifecycle. Its
  button and threat text navigate to the known source; completed campaigns
  retain the city/field action surface.
- Economic pressure queries use live city control for the configured campaign.
  The legacy first-war ledger is not repurposed or rewritten. Day-7 pressure
  remains before victory; legacy scheduled harassment no longer stacks a
  second unsourced war event on the authored invasion/social-pressure loop.
- Regular recruitment retains its existing costs, population, capacity and
  daily limits beyond the old first-map date cap. The historical readiness
  restore button is hidden in the live campaign; it cannot roll back selected
  city facts while retaining newer armies and field facts. Emergency levy
  availability now matches its existing single-day rule and personnel cost.
- City frames carry fractional milliseconds, fixing 30/60/120 FPS calendar
  drift (two-second before: 1980/2040/1920 ms; after: 2000 ms each). The
  sub-millisecond remainder is transient and resets on restoration; no schema
  change is needed. Pressure-stage countdown includes time before the deadline.
- City food information shows actual operational production, upkeep and net
  balance. It excludes future construction, disconnected buildings, trade and
  military orders; daily settlement still pays upkeep before accepting output.
- Population-summary clicks locate existing treatment. Interrupted-project
  selection locates its actual work site. Recruitment, workforce, emergency
  levy and engineering controls explain their concrete blockers.
- F8 in debug builds prints `BLACKSTONE_PROGRESS_DIAGNOSTICS`: user pause,
  reservation block, controller processing, clock values, training wait,
  treatment, build slot, blocked army routes, field projects and real save
  status. The previously reported unspecified stall remains NOT REPRODUCED;
  the independently reproduced frame drift is fixed.
- Historical non-durable battle settlement now records casualties through
  PopulationRecoveryState in the same resource transaction. Previously its
  first loss left military/population totals inconsistent and a subsequent
  cross-day result was rejected. Mission identity and first-clear receipts
  remain unchanged.

## Normal resource budget and choices

The initial city has 80 food, 100 wood, 72 living people and 20 soldiers.
Baseline upkeep is 7 food/day; no free production is assumed. A connected farm
costs 45 wood and one 180-second city day of real construction, then supplies
22 food/day at full staffing. Housing costs 35 wood and one day and adds
capacity only. A five-person training order costs 15 food and reserves five
existing available people until the next day. Optional field engineering
spends additional food and occupies one real person; it does not replace the
city construction workforce. These parameters were not increased for R1.

The validation paths build a farm and housing, train, then either establish
an optional road/camp/arrow-tower line or retain those resources for direct
military action. Both face the same sourced invasion, pay treatment for real
wounded, and reuse the surviving formations to counterattack. The alternate
route retreats to Northwatch and reissues from that legal return station.
Silverford's finite supply/reinforcement and its lack of normal-city building
rights remain unchanged. A combat win is not an equipment or population grant.

## Evidence classification

`run_blackstone_closeout_r1_journey.gd` defaults to actual engine frames at 1x.
Its explicit `--fast` mode drives the same controller process for diagnosis and
is separately marked in JSON; neither mode changes resources, dates, force
counts, construction completion, gates or outcomes. Inputs are formal
controller commands, connected GUI signals and spatial map events. Snapshots
are written by the existing V5 store into isolated node directories; separate
processes restore copies and continue. The existing player save directory and
candidate windows are not test inputs.

Historical fixture repair is separate from normal-start evidence: old viewport
upkeep expected four food and now reads actual upkeep; fabricated V3 input
removes post-V3 roots; synthetic battle counts initialise a matching population
fixture; legacy noticeboard tests explicitly select the historical theatre.
Baseline comparison logs preserve the failures observed at `136fe56`.

The first 1x trace distinguishes controller `is_processing()` from effective
`can_process()`: the battle scene disables the city ancestor. F8 is available
in both the city and battle and records that ancestor mode and battle tick.
The governance panel has a bounded 390-pixel readable width at the 1152-pixel
viewport; its scroll region retains all workforce/treatment controls.

## Unconfirmed early-occupation rule

The existing control-only victory rule can complete before the configured
invasion departs. The live invader remains independent and is not cancelled by
that early occupation. Recommended next rule decision: retain already-departed
forces; explicitly decide whether an unlaunched force can still muster after
its source changes controller. R1 does not invent suppression or an additional
victory prerequisite. The header continues to show any outstanding threat even
when the two-city objective is complete.

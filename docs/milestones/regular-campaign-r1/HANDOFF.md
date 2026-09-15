# Regular Campaign R1 — local candidate handoff

This is a local engineering candidate for the verified Regular Campaign R1 task,
not another repository audit or a release. Final machine provenance and test/media
manifests are linked in [EVIDENCE.md](EVIDENCE.md). The authority is the task and
Appendix A U1/U2/U3, not older relief-loop or macro-lock recommendations.

## Scope and player flow

Run `RUN_REGULAR_CAMPAIGN_R1.command` from this isolated worktree. Choose
**常规关卡候选 · 新局**. The launcher creates a unique save directory; the final
prepared candidate is left at its title without starting a player generation.

A reproducible first route selects the three real formations (20 people), takes
30 food and 55 wood, builds one farm at the home-front site, connects its road
and assigns four stationed people. Send one seven-person formation to 溪渡,
then send it and the six-person formation to 赤岭. Retain the farm's workers at
base. Confirm the pending result explicitly, then continue managing the home
city. Local command changes consume the existing same-army path/war interfaces;
they do not trigger another home dispatch or home food payment.

The slower route starts with logging, waits for two actual harvests, adds and
staffs the farm, and leaves more preparation time before the same objectives.
Ordinary road nodes reject construction. Optional local clinic, warehouse,
finite locally sourced training and food claims are implemented; outside
reinforcements or convoys are not required.

## Observed normal routes

Both deterministic routes start from the same authored home assets and enemy
configuration. No soldier, resource, damage or enemy-HP fixture is used. These
are controller/API journeys from the production scene. Graphical runs additionally
use viewport mouse events for the title button and visible army marker, an engine
confirmation signal for the native dialog, and normal runtime command calls.

| Result | Fast | Slow |
| --- | ---: | ---: |
| Confirmed mainline elapsed | 9m31s | 22m31s |
| Successful attempt elapsed | 6m21.25s | 20m27s |
| Local buildings | farm | logging + farm |
| Paid local wood including roads | 47 | 89 |
| Local food produced / consumed | 44 / 8 | 66 / 24 |
| Local wood produced | 0 | 108 |
| Local food / wood before handover | 66 / 8 | 72 / 74 |
| Food actually returned / retained in local scope | 66 / 0 | 65 / 7 |
| Enemy growth events / remaining reserve | 0 / 120 | 2 / 116 |
| Home-origin survivors / wounded / fallen | 17 / 1 / 2 | 13 / 3 / 4 |

Each route also builds one ordinary home farm with actual home wood. Local and
home ledgers are separate. The slow route has more actual production but faces
stronger defenders and suffers larger losses: it is allowed, not made universally
superior. All survivors, wounded, fallen, local recruits and retained overflow
remain source-accounted. The mainline elapsed above includes the short pending
review interval; the successful attempt timer stops at the battle outcome.
Movie capture adds brief real simulation intervals for visual holds, so its
elapsed values are separately recorded rather than called identical to the
headless benchmark.

## Dynamic rules and boundaries

- There is one persisted 250ms game step. Real delta is multiplied by 1/2/4 speed
  once. Pause/exit/offline do not advance it. Home economics continue during
  local operations. A pending outcome stops local combat while home/mainline
  time continues; the player cannot continue that battle without retrying.
- Food is paid before same-cycle harvest every 180 game seconds. One ration per
  five deployed/wounded/reserved people is rounded up. Forecast simulates up to
  12 events using actual staffing, road, production, stock and capacity. A
  warning itself kills nobody; repeated unpaid rations do cause real casualties,
  including stranded wounded after their force has no living members.
- The default preparation window is 30 minutes. Confirmed mainline history is
  normalized to its content baseline and clamped to 75–125%. Actual ready home
  plus deployed troops, wound recovery and effective supply can grant finite
  monotonic tolerance. Pending deaths do not count as ready force; actual local
  recruits do. Preparedness is capped at 10 minutes within the public 15-minute
  envelope. Genuine combat loss awards at most 10 lifetime minutes of recovery
  credit; retry cannot replenish consumed credit or reset mainline elapsed.
- Pressure rises gradually in ten-minute effective-lateness stages. The final
  stage stops nonessential construction, keeps only bounded need-based paid
  recovery, and slows basic training and population growth. A stocked 20-person
  force with a productive farm still reaches pressure 4 after about 91 minutes;
  it cannot buy unlimited delay by building or remaining economically strong.
- Enemy growth starts at ten minutes, then every six minutes adds one defender
  per uncaptured, currently unengaged source from a shared finite reserve of
  120. Every third event increases attack, capped at 18. Capture stops that
  source; gates do not heal and cleared cities do not revive. The 90-minute
  no-advance probe consumes 14 growth events and leaves 92 reserve people.
- Six plots and one paid project bound local building. The 90-second base
  construction, local training and treatment durations are candidate values.
  At extreme pressure, eligibility for additional farm/clinic/logging recovery
  depends on actual shortage and bounded existing counts, not a universal
  exemption for every agricultural building.

## Persistence, safety and source ownership

NationState owns the shared and disjoint local stock. ArmyRegistry owns active
people and orders. PopulationRecovery owns permanent people. Regular metadata
holds only attempt, origins, projects, timing and pending outcome facts under
the existing V5 owner. Schema 18 adds `regular_campaign` and `scoped_resources`;
a synthetic schema17 input migrates to empty regular fields and remains legacy.
Unsupported/invalid nested state is rejected instead of being silently repriced.

Departure transfers selected formations and supplies once. Retry restores only
the entry attempt facts, preserving permanent construction, training, mainline
time and consumed tolerance. Confirm applies permanent losses and home-origin
return once; local recruits remain local. Home training reserves the future
return capacity within existing recruitment/command/formation limits. Full home
storage leaves excess in the same local scope for explicit later claim.
Settlement is an explicit handover, not simulated return transport.

The old source worktree stayed at
`f1ad13ec62ed57ceb71b089b4fa83b5d9607129b` and was not modified. All task saves
are isolated temporary or launcher-created directories. Existing player saves
and old candidate windows were not used. Rollback is to close this candidate
and keep using the old source; no history reset, branch deletion or player-save
migration is required. There was no push, PR, merge or deployment.

## M0–M5 coverage

| Stage | Delivered boundary |
| --- | --- |
| M0 | Manifest/source/Appendix A verification and design before implementation |
| M1 | Regular identity, real departure, one clock, scoped retry metadata |
| M2 | Paid finite projects, roads/staff, actual local yield and ration forecast |
| M3 | Bounded adaptive pressure, actual military/supply inputs, finite enemy growth |
| M4 | Continuous command/combat/settlement/home flow and readable controls |
| M5 | Full diff review, focused regressions, cold processes, faults and inspected media |

## Verification and repaired findings

The evidence index contains actual command arrays, exit codes, source hashes,
result markers, cold-process traces and media metadata. The bounded suite covers
11 legacy owner/regression runners, the new rule/transaction/validation tests,
normal fast/slow completion, food/time/pressure cases, services, return capacity,
wounded supply, independent cold recovery and checkpoint failures.

Cold processes cover construction, warning, genuine combat casualties before a
second force fights, pending and confirmed outcomes, high pressure, consumed
enemy growth and consumed recovery credit. Fault tests inject failures at
payment/confirmation and at real construction-completion, pressure-transition
and combat-loss checkpoints. They compare the full authority before/after,
excluding the intentional paused flag, then resume and verify the legitimate
transition. Synthetic history/malformed saves and the explicitly labelled
future-population capacity fixture are not normal-play evidence.

Review repairs included timed construction's empty paid-cost keys, duplicated
local-source metadata, unsafe draft refresh, worker/order movement reservations,
closed-force treatment, overflow handover, return capacity, fractional milliseconds,
pressure cache/window consistency, real military-strength projection, mixed-origin
wounds, malformed scouting values and visible marker hit testing. Initial failures
and final reruns are distinguished in the evidence index; a stale failure log is
never used as a success receipt.

## Acceptance limits

Continuous combat uses the existing WarLoop on the campaign map. No new C0
battle scene was built; old C0 takeover is guarded in this mode to avoid duplicate
simulation. No next campaign, global war, trade system or Foreign Relief Loop was
added. Enemy scaling, food prices, time tolerance, difficulty, map art, long-session
performance and mouse feel remain candidate-level choices.

After handover the campaign map retains zero-member closed-force markers; the
actual returned people are visible in the home garrison. This is a remaining
presentation limitation, not a claim that all soldiers died.

The video is automated Engine-GUI/API evidence, not an OS-native full journey or
human playtest. Its MP4 copy omits audio; the original AVI is retained. Three
image sizes are actual pixels: 1152×648, 1280×720 and the macOS-clamped large
window 1920×947. No 1920×1080 capture or human/Founder acceptance is claimed.

AGENTS.md and MEMORY.md were not changed. CURRENT_STATE, DECISIONS, CHANGELOG
and these three milestone documents record this bounded implementation. Stop
here after local delivery; no subsequent feature work is included.

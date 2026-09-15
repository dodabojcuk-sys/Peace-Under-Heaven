# Regular Campaign R1: implementation contract

Status: M0 contract implemented; final verification is recorded in HANDOFF.md. Base f1ad13ec62ed57ceb71b089b4fa83b5d9607129b. Inputs verified against SOURCE_MANIFEST.json (8 files, bytes/lines/SHA-256, loose task identical). Source package stored outside repository at /Users/m4-zhi/Documents/txwzs-regular-campaign-r1-input-20260913. No original worktree, existing candidate or player save is used.

## Product and acceptance

U2/U3 override the old audit's mandatory rescue, additional supply convoys, macro command locking and fixed-day sanctions. One compulsory regular campaign allows preparation, local command changes, finite productive wartime construction, sustainable but costly food, gradual sourced enemy preparation, finite adaptive mainline tolerance, retry and atomic settlement. Legacy Blackstone remains available with its original content/time policy. No subsequent map, global war, diplomacy/trade expansion or equipment/energy redesign.

Candidate fast route target: 5–12 simulation minutes. Deliberately slower construction/recovery route target: 15–25 simulation minutes. Both must be reachable with identical authored forces/resources through normal commands, without gifts/HP changes. Initial mainline preparation window 30 simulation minutes, bounded history correction and at most 15 extra minutes; subsequent lateness stages are gradual. These are testable candidate parameters, not final balance. Tune against production consumers, retaining failed experiments and reasons.

## State owners and implementation map

- ConstructionController remains canonical world and commit owner. A small regular-campaign helper may organize its operations; it owns no separate resource/army/save model.
- NationState gains a narrow scoped-inventory transaction seam. Local food/wood are disjoint from shared permanent stock. Departure is a transfer, not a fee plus a second cargo credit. Refund/settlement uses the same owner.
- ArmyRegistry remains the only active soldier/formation and movement owner. Dispatched existing formations can form stationed work details. Assigned workers are part of those same soldiers and cannot simultaneously march/fight; release assignments before issuing their march. No invented workers or duplicated permanent population.
- Regular attempt metadata owns entry snapshots, local buildings/project/work assignments, finite local recruiting provenance, pending casualty origin and objective/settlement facts. Local recruits remain local at settlement. Home casualties remain occupied population until one confirmation applies final losses. This metadata is part of the canonical V5 payload, not a second population/save service.
- WarLoopState/FieldTacticsState remain theater, road and siege owners. Prefer their continuous-map combat for this slice; no new combat engine and no requirement to transfer to a separate C0 scene. Existing legacy C0 remains unchanged. Only one simulator advances each siege. Enemy growth modifies real unoccupied source garrisons, never restores prior damage or revives cleared targets.
- UI is a projection of these records, using existing visual language and continuous road/world coordinates. Temporary buildings have stable identity/position in a bounded build site; ordinary points reject construction at submission.

## One time policy

Regular mode routes the controller frame through persisted integer 250ms simulation steps. Speed multiplies real delta exactly once; pause stops all simulation. Fixed order per step: permanent construction/calendar/production -> local construction and periodic production/rations/medical -> army movement and siege combat/results -> authored enemy growth -> pressure/forecast assessment. Use event boundaries and persisted remainders. Men already simulated in a siege are excluded from duplicate field resolution. No later catch-up after scene/view transitions. Legacy controller frame and C0 contracts are untouched.

## Economy and construction

Local food/wood only; reuse authored BuildingDefinition costs/capabilities with explicit candidate duration/capacity overrides where needed. One paid project, finite plots and allocated stationed workforce; actual operational/road/staff/health/capacity conditions feed both production and forecast. One finite local reserve provides a paid, timed replenishment option; provenance stays local. No permanent reinforcements or grain after first departure.

Forecast is read-only, bounded periodic-event simulation. It checks consumption before next harvest, not just average net income. High stock with negative net gives runway, not immediate starvation. Warning slows new consumption (training and permanent births), never applies a new universal farm-output penalty. Actual sustained unpaid rations cause recorded casualties; restored food cannot revive dead. Existing disease/health effects remain separate.

## Adaptive pressure

Persist rule version, mainline elapsed, last assessment, promised window, finite recovery credit consumed, pressure stage/hysteresis and settlement history. Read actual total home+occupied forces (not only home garrison), wounded/casualty origins, effective agricultural yield and projected ration risk. History uses only confirmed mainline completion elapsed, normalized to content baseline and clamped; no history has an honest default. A promised window never shrinks when a farm finishes. Weakness or rebuilding cannot replenish recovery credit. Enemy growth is authored time/source based, not a same-ratio player tracker.

Late pressure first reduces nonessential growth/construction, ultimately stops it. Essential food/recovery permission is bounded by actual deficit and finite construction capacity; not unlimited exempt farms. Preserve paid progress/ready products and normal refunds. Always retain a finite paid recovery/reattempt path; no free soldiers, money or automatic outside supply.

## Retry and settlement

Capture only this attempt's input/war/army/local inventory initial state. Retry restores those facts, removes all attempt gains and losses, retains permanent city changes, mainline elapsed, consumed tolerance and independent trades. One pending outcome shows survivors/wounded/dead, local people, consumed/returned goods. Confirm through controller transaction+V5 checkpoint once; on failure restore all relevant owners and leave pending state. Return uses explicit settlement handover (not claimed route transport). Success closes this campaign; continuing permanent city does not create a next map.

## Counterexamples and checks

- Dispatch emptying home garrison must not trigger defeat recovery.
- Actual combat loss can earn only finite recovery tolerance; repeated retries grant no fresh pool.
- Unfinished/disconnected/unworked farm never counts as current yield; harvest-gap risk remains visible even with positive average.
- Scope transfer, training, death, work and settlement each conserve persons and food; no twice-paid rations.
- Same game time and timed commands at 30/60/irregular FPS and 1/2/4 speed agree to integer-step state; pause/view changes cannot dodge upkeep/growth.
- Cold processes cover initial transfer, construction/warning, casualty/second combat, high pressure, consumed enemy growth, pending/confirmed settlement. Synthetic schema17 migration only.
- Fault injection at payments/completion/pressure/loss/result must roll back full state, not just UI.
- Fast, slow, real recovery and unbounded-delay scenarios use runtime helpers and production paths. Synthetic history tests are labelled.
- Review all diff, run affected legacy regression, inspect three-resolution images and continuous formal-flow recording; keep engine-input and OS-input evidence distinct from human acceptance.


## Implemented candidate parameters and observed choices

- First deployment: actual selected home formations, 8–80 food and 0–80 wood. Default 20 people / 30 food / 55 wood; existing home starts at 80 food / 100 wood. No later home supply.
- Six local plots, one construction job, two stationed military workers for construction; one project takes 90 simulation seconds. Costs reuse authored building definitions. Road connection costs 2 local wood. Up to four military workers per building; leaving assigned work requires release.
- A staffed farm produces 22 food per 180-second cycle; logging produces 18 wood. Base capacity is 80 per resource; each connected warehouse adds 120. Unfinished, disconnected or unstaffed buildings produce zero. Clinical recovery is a paid 90-second job; local training is a paid 90-second job and food risk slows its real progress.
- Upkeep is one food per five deployed/wounded/reserved people, rounded up, paid before same-cycle harvest. Two consecutive actually unpaid cycles cause casualties. A forecast alone never kills anyone.
- Enemy reserve is 120 shared finite people. First growth at 10 minutes; each later six-minute event adds one actual defender to each still-enemy source. Every third event also raises its attack, capped at 18. Capture stops that source's future growth; no gate repair or dead army recreation. Initial exploration used two defenders per three minutes; normal slow-route losses showed that rate exceeded the M0 window, so both routes now use the same gentler configuration.
- Pressure starts with a 30-minute default, clamped confirmed-history normalization (75–125%), a monotonic preparedness extension capped within 15 minutes, and a separate 10-minute lifetime combat-recovery credit. Stages advance per ten minutes of effective lateness; stage four stops nonessential construction. Essential recovery permission is bounded by real need and finite building counts. High stock with negative net production retains its forecast runway before warning penalties apply.
- Permanent casualty confirmation is separate from battle loss display. Local troops remain local. Full home storage retains the excess in the same NationState scope; an explicit claim action transfers it when space is available. No overflow gift, disappearance or second inventory owner.
- Regular campaign parameter version is 1, root V5 schema is 18. A synthetic schema17 save migrates to empty regular/scoped fields and preserves legacy behavior. Unsupported regular versions are rejected rather than silently repriced.
- Continuous-map WarLoop combat is used for this candidate. The existing separate C0 entry is guarded while regular mode owns the theater, preventing two simulators. This is not a claim of a newly implemented C0 tactical scene.

## Review findings repaired during integration

The review found duplicated local source metadata, stale sidebar input, hidden top controls, a timed placement with an empty paid-cost key set, partial pressure/entry validation, order reservations that could leave with an army, full storage blocking final confirmation, and a floating-point millisecond boundary. These were repaired at the existing owners and tested with normal commands or explicitly labelled fault/malformed inputs. A 90-minute headless test yields between batches so queued UI cleanup is not incorrectly measured as game simulation cost.

Final self-review also separated population occupancy from actual pressure strength,
counted local and home wounded consistently in runtime and strict restore checks,
reserved home recruitment/command capacity for returning people, and applied real
unpaid-ration consequences to stranded wounded. The normal mixed-origin training
and retreat path is covered, while the future-population capacity boundary is an
explicit synthetic fixture. UI now shares drawn marker positions with hit testing
and displays actual nonessential-construction/basic-training modifiers, finite
window and recovery balance. No deadline, clock or source-conservation rule was
relaxed to make a test pass.

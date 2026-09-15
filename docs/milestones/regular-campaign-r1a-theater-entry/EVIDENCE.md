# Regular Campaign R1A main-city restoration evidence

## 2026-09-14 army and engagement presentation continuation

Provenance:

- baseline: `06869cd4339d72f5924f39a0aa3c766b7f07cbd6`;
- branch: `codex/txwzs-regular-campaign-r1a-theater-entry`;
- worktree: `/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a-theater-entry`;
- engine: Godot `4.5.1.stable.official.f62fdbde1`;
- execution: GPT-5.6 Terra, medium reasoning, standard speed, one agent.

### Reuse and authority boundary

The implementation reuses `MacroMarchLowPolyPresentation` for terrain, route,
city, primitive soldiers and flags. `RegularCampaignRuntime` adds presentation
hints only to copied read models; `RegularCampaignPresentationBridge` forwards
those copies; `RegularCampaignView` draws the selection rings, the actual
army-to-city attack relation and a viewport-bounded card. The current attacker
count comes from aggregate WarLoop attacker HP only while its real siege is
active. The formation's original count is retained only as “入战人数”.

WarLoop remains the only damage, target, gate, defender and terminal-result
authority. ArmyRegistry remains the formation authority and is reconciled only
by the existing terminal path. The visual groups have no independent soldier
AI, pathfinding, collision damage, occupation, clock or persistence. Contact
motion is derived from the authoritative siege tick, so pause freezes it and a
cold restore projects current facts without replaying old damage.

The current initial facts are seven attackers against four Silverford
defenders. The existing 3:1 surrender threshold therefore rejects this attempt
(`7 < 12`) and falls through to a short real combat. Earlier wording that calls
this specific current route a successful surrender is stale; no values or
combat outcomes were changed to preserve that wording. A genuine surrender
result is displayed without an attack animation, while refusal displays the
real ensuing target relation.

### Normal-time evidence

The focused setup before `R1A_REALTIME_SEGMENT_START` is compressed separately.
After that marker the runner never calls `runtime.advance`; it enables the
normal controller process and uses only the visible 1x, pause and continue
controls. The Redcliff battle lasts 4.25 seconds of WarLoop time. The recording
contains 120 frames at 20 FPS (6.0 seconds) at 1280x720, including 24 frozen
pause frames. Gate breach is recorded while defenders remain, then the stale
engagement card and contact motion clear at the real terminal state.

- [1280x720 normal-1x MovieWriter recording](evidence/army-engagement-continuation-20260914/qingyuan-engagement-realtime-1x.avi)
- [1280x720 runtime log](evidence/army-engagement-continuation-20260914/qingyuan-engagement-realtime-1x.log)
- [1280x720 siege start](evidence/army-engagement-continuation-20260914/00-realtime-siege-start.png)
- [1280x720 paused](evidence/army-engagement-continuation-20260914/01-realtime-paused.png)
- [1280x720 gate breached with defenders remaining](evidence/army-engagement-continuation-20260914/02-realtime-gate-breached.png)
- [1280x720 engagement cleared](evidence/army-engagement-continuation-20260914/03-realtime-engagement-finished.png)
- [1152x648 gate breached with defenders remaining](evidence/army-engagement-continuation-20260914/1152x648/02-realtime-gate-breached.png)
- [1152x648 runtime log](evidence/army-engagement-continuation-20260914/1152x648/qingyuan-engagement-1152x648.log)

At both target resolutions the selected formation, target, attack relation and
card remain inside the viewport. The card does not cover either endpoint. The
map label and engagement card agree on current combat-ready count; the card
separately labels entry count. Stacked formations' low-poly anchors and
clickable markers remain within two pixels and select the same `army_id`.

### Outcome and regression verification

The full normal title route passes at 1280x720 and 1152x648: split movement,
Silverford surrender attempt/fallback combat, Redcliff refusal/siege, gate
breach with defenders remaining, objective completion, settlement and original
city return. Its authoritative result remains exactly 17 survivors, 1 wounded,
2 fallen, 66 food and 8 wood returned. The focused clip intentionally omits the
earlier farm flow, so its resource totals are not used as a full-route outcome
comparison.

- editor import/script parse: pass;
- `run_regular_campaign_r1a_input_journey.gd`: pass at both target resolutions
  with the exact baseline outcome;
- `run_regular_campaign_engagement_realtime_journey.gd`: pass at both target
  resolutions, including 1x, pause/continue, breach-with-defenders and cleanup;
- `run_regular_campaign_engagement_cold_restore.gd`: separate stage A/B
  processes pass with siege id, tick, gate and counts unchanged and one current
  engagement projection;
- `run_macro_march_low_poly_graphical_smoke.gd`: isolated rerun passes 22/22,
  including army selection and 1152/1280 projections;
- `run_regular_campaign_r1a_theater_entry.gd`: 16/16 pass;
- `run_regular_campaign_r1_services.gd`: 11/11 pass;
- `run_regular_campaign_r1_time.gd`: 23/23 pass;
- `run_regular_campaign_rules_r1_smoke.gd`: 17/17 pass;
- `run_regular_campaign_r1a_city_smoke.gd`: pass;
- `run_regular_campaign_r1_recovery.gd`: A-J cold-process recovery pass.

The historical `run_war_loop_r1_smoke.gd` still reaches 14 passing assertions,
then its old controller route fails to return an `army` receipt at line 68; the
remaining four assertions are unreachable. It is not reported as 18/18, and no
gameplay was modified to satisfy the obsolete route.

SHA-256:

- MovieWriter AVI: `6bd8460992859cd5dd76d3f42a209e2dbcdaf7b5cb33442fecf1fa457f30b70f`
- 1280 siege start: `f5e3388f5a14911d7c9bfa0ab7486b7fc6b7b0a13ef44bdb10479f5285e3aa11`
- 1280 paused: `3bd36bce9015266d08842c51a36a5410c4a5e5fb7c526ff24c7edeb65f7b3b10`
- 1280 gate breached: `98cdeff5a04ea88abb65e320ad4556dc399f2da53e7f5ab0353768471eb9e8ae`
- 1280 finished: `39875fb06cec88d11f0e00c97edf24bf8e1a2227bfdfdc5971aa5007f3e3ad69`
- 1280 runtime log: `40558937aa19e1e71cdde8bedda1a0a51a8fe04c52b0931dcbdb926277e4e02f`

### Open gates

The 4.25-second real battle leaves a narrow player response window. This batch
records the fact but does not extend combat or change values. The presentation
is aggregate because WarLoop exposes aggregate battle data; it is not per-
soldier spatial combat. Human mouse-feel, unfamiliar-player/Founder acceptance,
balance, real-device behavior, push, merge and deploy remain unverified or out
of scope. No next stage, unit type, skill, trade or city-art work was started.

## Context and asset closeout evidence

Continuation baseline: `9ee281bf07aff56a7da7be1ade7f0eeb2127040b`.
The same working version produced all media below through the normal title
confirmation and existing city/theater inputs, with a new isolated test-save
directory for every run.

Causes and outcomes:

1. The wartime-city `无法出征：没有可派编队` message came from
   `_refresh_current_mainline_entry_ui()` falling through to permanent-city
   first-war eligibility. The regular phase now owns that action first and the
   wartime city returns to its current theater.
2. The Qingyuan/Blackstone copy mixture was an incorrect legacy-mode gate after
   returning to the permanent main screen. The home-entry path now refreshes
   the regular authoritative projection; legacy Redcliff/Silverford and day
   4/5/7 text remains available only when that legacy mode is the active owner.
3. The four art resources were connected to the formal city host, but the old
   four-type test still inspected the retired campaign presentation bridge.
   It now traces each real id through host record, texture, authored world
   coordinate, camera round trip, hit projection and shared detail selection.

Normal-path media:

- [1280x720 preparation main city](evidence/context-assets-closeout/1280x720/00-normal-entry-main-city.png)
- [1280x720 wartime main city](evidence/context-assets-closeout/1280x720/02-wartime-main-city.png)
- [1280x720 connected, staffed, producing farm](evidence/context-assets-closeout/1280x720/03-connected-staffed-farm.png)
- [1280x720 pan/zoom selection](evidence/context-assets-closeout/1280x720/04-pan-zoom-selection.png)
- [1280x720 same-city restoration](evidence/context-assets-closeout/1280x720/05-round-trip-restored.png)
- [1152x648 preparation main city](evidence/context-assets-closeout/1152x648/00-normal-entry-main-city.png)
- [1152x648 connected, staffed, producing farm](evidence/context-assets-closeout/1152x648/03-connected-staffed-farm.png)
- [1152x648 pan/zoom selection](evidence/context-assets-closeout/1152x648/04-pan-zoom-selection.png)
- [continuous 1280x720 input journey](evidence/context-assets-closeout/1280x720/context-assets-closeout-journey-1280x720.mp4)

The movie contains 385 frames at 30 FPS (12.83 seconds). It includes the normal
title route, Qingyuan preparation/theater, a clearly visible real farm,
construction, connection, four worker inputs, real production, pan/zoom hit,
one theater movement command, same-city return and temporary leave/continue.
Construction and production waits use compressed authoritative runtime advance;
this is an evidence edit, not real-time pacing or human mouse-feel acceptance.
The uncompressed source input sequence remains the test runner itself.

Four-type presentation fixtures (not claimed as normal acquisition):

- [farm](evidence/context-assets-closeout/1280x720/asset-farm-formal-mapworld-1280x720.png)
- [logging camp](evidence/context-assets-closeout/1280x720/asset-logging-formal-mapworld-1280x720.png)
- [warehouse](evidence/context-assets-closeout/1280x720/asset-warehouse-formal-mapworld-1280x720.png)
- [clinic](evidence/context-assets-closeout/1280x720/asset-clinic-formal-mapworld-1280x720.png)

Focused verification:

- editor import/script parse: pass;
- normal input journey: pass at 1280x720 and 1152x648;
- main-city HUD/input/camera/resource isolation smoke: pass;
- four formal-MapWorld asset chains: pass;
- theater route and cold-context restore: 16/16 pass, including repeated-restore
  idempotence for records, timers, totals and departure ledger;
- regular campaign services: 11/11 pass;
- construction placement, building selection and city viewport/input-owner
  regressions: pass;
- legacy Blackstone UI smoke: pass;
- `git diff --check`: pass.

Movie SHA-256:
`75c2b5d04332e822597d4caf0bb6c559600e21ea76fd58dda08865168239b6e7`.

Automated engine evidence is not human mouse-feel, Founder acceptance,
long-term balance, push, merge or deployment.

## Provenance

- Continuation baseline: `404c87fcec014d8cec4ae0c6198dbae5c55b99b6`
- Original city-screen reference: `f1ad13ec62ed57ceb71b089b4fa83b5d9607129b`
- Branch: `codex/txwzs-regular-campaign-r1a-theater-entry`
- Worktree: `/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a-theater-entry`
- Engine: Godot `4.5.1.stable.official.f62fdbde1`
- Execution: GPT-5.6 Terra, medium reasoning, standard speed, one agent

The evidence was recorded through the normal title confirmation and the existing
city/theater controls. Each run used a fresh isolated save directory. Existing
candidate windows and player saves were left untouched.

## Same-resolution comparison

| Resolution | Original normal city at `f1ad13ec` | Restored regular-campaign city |
| --- | --- | --- |
| 1280x720 | [original](../field-tactics-r2/evidence/20260912-city-governance-r0/city-governance-default-1280x720.png) | [wartime main city](evidence/main-city-restoration/1280x720/02-wartime-main-city.png) |
| 1152x648 | [original](../field-tactics-r2/evidence/20260912-city-governance-r0/city-governance-default-1152x648.png) | [wartime main city](evidence/main-city-restoration/1152x648/02-wartime-main-city.png) |

The comparison is about the complete screen contract: MapWorld remains the
primary viewport, the established camera scale remains 1:1, and the original
top bar, minimap, selection panel and construction catalog remain the operating
surface. The campaign city is not fitted into a left preview panel.

## Final media

- [1280x720 normal entry](evidence/main-city-restoration/1280x720/00-normal-entry-main-city.png)
- [1280x720 wartime main city](evidence/main-city-restoration/1280x720/02-wartime-main-city.png)
- [1280x720 connected and staffed farm](evidence/main-city-restoration/1280x720/03-connected-staffed-farm.png)
- [1280x720 pan, zoom and transformed selection](evidence/main-city-restoration/1280x720/04-pan-zoom-selection.png)
- [1280x720 same-city round-trip restoration](evidence/main-city-restoration/1280x720/05-round-trip-restored.png)
- [1152x648 normal entry](evidence/main-city-restoration/1152x648/00-normal-entry-main-city.png)
- [1152x648 wartime main city](evidence/main-city-restoration/1152x648/02-wartime-main-city.png)
- [1152x648 connected and staffed farm](evidence/main-city-restoration/1152x648/03-connected-staffed-farm.png)
- [1152x648 pan, zoom and transformed selection](evidence/main-city-restoration/1152x648/04-pan-zoom-selection.png)
- [1152x648 same-city round-trip restoration](evidence/main-city-restoration/1152x648/05-round-trip-restored.png)
- [continuous 1280x720 input journey](evidence/main-city-restoration/1280x720/main-city-restoration-journey-1280x720.mp4)

The MP4 contains 353 frames at 30 FPS (11.77 seconds). It covers title entry,
the original permanent-city screen, theater entry and departure, licensed-city
entry, map construction, road connection, four worker assignments, real
production, pan, zoom, transformed hit testing, theater return and restoration
of the same city camera/building/jobs. Twelve distributed frames were decoded
and inspected after recording; all 353 frames were readable.

Title, route, plot, build, connect, worker, pan, zoom and return actions use
engine mouse/keyboard input. The 90-second construction and 180-second
production waits are compressed by advancing the same authoritative campaign
runtime between visible actions; the recording is not a claim of normal-speed
human waiting. Resource, clock and persistence effects are covered separately
by the focused service, time and recovery runners below.

SHA-256:

- MP4: `4eed9da20736b572d269f09e2e11f1f951b4eb9bcc0d4f0740f3bbb6814ab793`
- 1280 wartime city: `6e9998dec20b329af1f23e96f75dbb9f71a5d81201c7e34e88a00b0c0337d501`
- 1280 pan/zoom: `b8b78717744411a548343132c15842a578709216368a359ea0c3a790508ab076`
- 1152 wartime city: `0cc52eee6a07a59931af239e8e04dc320c917f9d32e85ca8192d9c108ad16b29`
- 1152 pan/zoom: `8dacc9e1f4441219f47b330d647a0c3818677a727ecdd226b2fa6365dc5ebb75`

## Focused verification

- Godot editor import and script parse: pass.
- `run_regular_campaign_r1a_city_smoke.gd`: pass. Normal city host, 1:1
  scale, plot selection, construction, road, workers, production, pan/zoom/hit,
  resize, theater round trip, ledger isolation and no route-time duplication.
- `run_regular_campaign_r1a_input_journey.gd`: pass at 1280x720 and
  1152x648 through the normal title route.
- `run_regular_campaign_r1a_theater_entry.gd`: 14/14 pass.
- `run_regular_campaign_r1a_building_types_smoke.gd`: pass with all four
  authored building kinds and their road/worker/visual bindings at both target
  resolutions.
- `run_regular_campaign_art_r1_visual_smoke.gd`: pass with 18 graphical
  outputs covering the four preserved art types and their activity states.
- `run_regular_campaign_r1_services.gd`: 11/11 pass.
- `run_regular_campaign_r1_recovery.gd`: A-J cold-process recovery pass.
- `run_regular_campaign_r1_time.gd`: 23/23 pass when run with its intended
  independent in-memory sub-scenarios.
- `run_regular_campaign_rules_r1_smoke.gd`: 17/17 pass.
- Existing `run_construction_placement_smoke.gd`,
  `run_building_selection_smoke.gd`, and `run_city_time_viewport_smoke.gd`:
  pass.
- `git diff --check`: pass.

One excluded time-suite invocation incorrectly forced its intentionally
independent in-process cases into one shared persistent store. Later cases then
restored earlier state. The same runner passed 23/23 with its intended
in-memory isolation; this was a harness invocation error, not a product change.

## Open gates

Automated input and MovieWriter evidence are not human mouse-feel or Founder
acceptance. Long-term balance, real-device acceptance, push, merge and deploy
remain unverified or intentionally out of scope. No art extension or new asset
was made in this batch.

## 2026-09-14 full Qingyuan battle closure

The normal title entry was replayed with a new isolated save through the current
permanent-city control, departure control, licensed wartime city, original map
construction controls, theater army markers, result tab, settlement confirmation
and return-to-city control. No victory, occupation, damage, free-force or direct
confirmation command was called by the input journey.

Observed authoritative route:

- three existing formations and 30 food / 55 wood entered once;
- one real farm was built, road-connected and staffed by four people, producing
  44 local food while total wartime food use was 8;
- stacked markers separately selected the second and third formation;
- Silverford used its existing surrender-first rule and did not complete the
  campaign while Redcliff remained hostile;
- Redcliff rejected surrender, reached a visible `gate 0 / defender 1` state
  while the phase was still `ACTIVE`, then completed after defender resolution;
- the siege retained its identity through pause and wartime-city return;
- settlement recorded 17 home survivors, 1 wounded and 2 fallen, and actually
  returned 66 food and 8 wood. The completed settlement remained stable.

The only product change is a read-only siege projection plus a theater overlay
showing the attacking formation, live gate state, and authoritative attacker and
defender counts. Combat, pressure, food, damage, occupation, save schema and
settlement rules are unchanged.

Media:

- [original 1280x720 MovieWriter recording](evidence/full-battle-20260914/qingyuan-full-input-original.avi)
- [raw input and settlement log](evidence/full-battle-20260914/qingyuan-full-input.log)
- [siege begins](evidence/full-battle-20260914/07-redcliff-siege-start.png)
- [gate breached while one defender remains](evidence/full-battle-20260914/08-redcliff-gate-breached-defenders-remain.png)
- [full objective pending confirmation](evidence/full-battle-20260914/09-victory-pending-settlement.png)
- [permanent city after settlement](evidence/full-battle-20260914/10-permanent-city-after-settlement.png)

The original AVI is 930 frames at 20 FPS (46.5 seconds). Construction,
production and march waits are compressed through the same authoritative clock,
with the ordinary process disabled to prevent MovieWriter holds from advancing
time twice. State-changing actions remain native button/map input. This is
input/state evidence, not a normal-speed pacing claim.

Focused results: full formal input journey passes at 1280x720 and 1152x648;
regular campaign services pass 11/11; A-J cold recovery passes; theater entry
and cold view-context recovery pass 16/16.

The historical `run_war_loop_r1_smoke.gd` reaches 14 passing assertions, then
fails at line 68 because its old Redcliff-to-Silverford controller route returns
no `army` receipt. Its remaining four controller assertions therefore do not
run. It does not use the current title / regular-campaign runtime entry. The
obsolete expectation was preserved, not deleted or used to change current
route rules.

SHA-256:

- AVI: `43694486bb961f7d3c83c60560e9219442ca2d3e7d48690e7685a24e542d592e`
- siege start: `7cb8ba8fb4cd6189a2eb7aaee277c6b78ec8903b81fd88609ef5e6c38532d2f9`
- breached gate: `246e1a05659b13b97b6eaf0ffbcc1828f4d6868d1369b34b69ada8dd27db1b7b`
- pending result: `49904925f5e33713d6f6532fa55c792c562ec9f205a849244043b46879c2530d`
- returned city: `bb189e2fe2af0dd81f3e9578807fcd5bbd5470f2e75a8c57c0981163ea1728f4`

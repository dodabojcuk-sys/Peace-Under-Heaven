# Regular Campaign R1A main-city restoration handoff

## Context and asset closeout

Continuation baseline: `9ee281bf07aff56a7da7be1ade7f0eeb2127040b`.

- The regular-campaign phase now gates the top-bar objective and current action
  before the legacy Blackstone campaign. This fixes incorrect mode activation,
  not merely the displayed strings.
- Preparation uses the permanent main city while explicitly labeling its
  calendar and Qingyuan objective. Wartime city labels mainline and current
  attempt time and routes both existing return actions to the same theater.
- Shortage and stopped-construction states remain in the alert area even when
  the compact settlement line is ellipsized.
- Empty plots are normally hidden and appear through the existing construction
  entry. Each of the four existing textures is proven on the formal MapWorld
  host with the same runtime id, world coordinate, camera transform, hit record
  and detail selection.
- Leaving a wartime city clears only its shared presentation selection, so a
  hidden campaign visual cannot leave a detail card or outline in the permanent
  city. Campaign records, jobs and camera persistence are unchanged.

The normal input journey now also issues one existing theater movement order
and temporarily leaves/continues the same campaign without redispatch, extra
cost or route-time advance. See the closeout section in [evidence](EVIDENCE.md).

## Outcome

The regular campaign now continues through the established city game screen
instead of treating an isolated campaign canvas as the wartime city. A new
campaign starts on the permanent-city main screen, enters the existing theater
from the original top bar, opens a licensed wartime city in the same MapWorld,
and returns to the same theater.

The theater overlay remains the campaign route surface. The prior city preview
inside that overlay is no longer the active city operating surface.

## Preserved systems

- `scenes/blank_map.tscn` remains the only city scene and owns the existing
  `MapWorld`, `Camera2D`, UI shell and input controllers.
- `scripts/map_pan_controller.gd` remains the only pan/zoom owner.
- `scripts/building_selection_controller.gd` remains the only selection and
  detail-input owner.
- `scripts/regular_campaign/regular_campaign_runtime.gd` remains the only
  campaign resource, building, job, clock, pressure, combat and settlement
  authority.
- The existing low-poly theater, four current art textures, shared graybox
  fallback, duplicate-draw suppression, stopped-construction gate and real
  production feedback remain unchanged in ownership.
- The authored six plots, construction costs, road fees, worker limits and
  campaign transactions are unchanged.

## Adapter boundary

`scripts/regular_campaign/regular_campaign_city_host.gd` is a presentation and
hit-test adapter attached to the existing MapWorld. It projects the current
campaign project/building records onto the already-authored city coordinates
and reuses `GrayboxBuildingVisual`. It owns no inventory, population, clock,
production, save or settlement state.

The permanent-city placement controller is not copied. While a campaign city
is active, the existing construction catalog and detail panel translate only
the necessary actions into the campaign runtime's `build`, `cancel`, `connect`
and `workers` commands. Permanent placement records and resources remain hidden
from those commands and are restored unchanged on exit.

The existing city foundation and minimap consume the same local road projection
as the host. Rendering, hit testing, selection outlines and minimap viewport
therefore follow the same camera transform after pan and zoom.

## Camera and route contract

- First wartime-city entry uses the established operational zoom of 1.0 and a
  city focus, not whole-city fit.
- Detail open/close and viewport resize do not reset camera state.
- Theater exit/re-entry restores the same camera position and zoom.
- Route transitions do not redispatch units, transfer food/wood again, reset
  time, settle the campaign or change pause/speed.
- Location identity, not display name, selects the campaign ledger.

The full route is:

`permanent main city -> current campaign theater -> licensed wartime city in the original main screen -> same campaign theater`

## Rollback boundary

A rollback should remove only the city host projection and the four input/UI
adaptations. It must not revert the current campaign runtime, save schema,
construction transactions, roads, art fixes, theater renderer or player save.

## Scope and status

Baseline: `404c87fcec014d8cec4ae0c6198dbae5c55b99b6`

Original screen reference: `f1ad13ec62ed57ceb71b089b4fa83b5d9607129b`

Branch: `codex/txwzs-regular-campaign-r1a-theater-entry`

Engine: Godot `4.5.1.stable.official.f62fdbde1`

No project, clone, worktree, launcher, title candidate, art asset, save migration,
push, merge or deployment was added. Existing candidate processes were not
closed. See [evidence](EVIDENCE.md) for the two-resolution normal-entry proof,
recording, checksums and open acceptance gates.

## Full-battle closeout

The formal journey now continues through the Silverford surrender attempt and
fallback combat, Redcliff siege, gate breach, defender resolution, pending loss
review, settlement confirmation and return to permanent-city operation. The
theater consumes a read-only live
siege projection so the attacking formation, gate, attacker count and defender
count remain visible. No combat or settlement rule changed. See the dated
full-battle section and original MovieWriter evidence in `EVIDENCE.md`.

## Army and engagement presentation continuation contract

Continuation baseline: `06869cd4339d72f5924f39a0aa3c766b7f07cbd6`.

This continuation is limited to the existing regular-campaign theater. The
established `MacroMarchLowPolyPresentation` remains the reusable army, flag,
terrain, road and city renderer. `RegularCampaignPresentationBridge` may add
read-only layout hints so stacked formations, their hit targets and their
selection feedback refer to the same `army_id`. Those hints are never written
to `ArmyRegistry`, `WarLoopState` or the save.

`WarLoopState` remains the only combat simulator. An active siege may be
projected as an aggregate relation between its real `army_id` and `city_id`,
including current attacker HP-derived headcount, entry headcount, defender
headcount, gate HP and tick. It does not create soldier AI, pathfinding,
collision damage, another clock or another battle result. A successful
surrender produces a result message and ownership change without an attack
animation. A rejected surrender exposes the real siege relation; a breached
gate remains an active engagement while defender HP remains above zero.

The map, army tab and engagement card use the same current-combat headcount
during a siege. The original formation count is retained only under the
explicit `entry_count`/“入战人数” label. Army composition is still reconciled
through the existing terminal `_finish_siege()` path, not continuously changed
to satisfy the presentation.

All motion is derived from persisted march progress or the authoritative siege
tick. Pause therefore freezes it, and cold restore resumes from current facts
without replaying historical hits or gate breach. Removing the read-only
projection removes the presentation without rolling back gameplay state or a
player save.

## Army and engagement presentation continuation result

The continuation implements that boundary by enriching copied army and siege
read models in `RegularCampaignRuntime`, forwarding them through
`RegularCampaignPresentationBridge`, and rendering them in the existing
`MacroMarchLowPolyPresentation`. The regular-campaign view adds only selection
rings, the real army-to-city attack relation and a viewport-bounded aggregate
engagement card. No new asset, scene, ledger, clock, save field or combat owner
was added.

The current Qingyuan initial facts contain seven attackers against four
Silverford defenders. The existing surrender threshold requires a 3:1 force
ratio, so this route truthfully attempts surrender and then resolves a short
combat; it must not be described as a successful surrender. The successful
surrender presentation path is still handled generically and produces no fake
attack relation.

The full normal input route retains its baseline settlement result: 17 home
survivors, 1 wounded, 2 fallen, 66 food and 8 wood returned. The focused
normal-1x Redcliff segment lasts 4.25 seconds of WarLoop time and proves pause,
continue, gate breach with defenders remaining, terminal cleanup and two-
resolution viewport containment. Automated evidence does not close the human
response-window, mouse-feel or Founder acceptance gates. Exact artifacts,
checksums and regression scope are in [EVIDENCE.md](EVIDENCE.md).

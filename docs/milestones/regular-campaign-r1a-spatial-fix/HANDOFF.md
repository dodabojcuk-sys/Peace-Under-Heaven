# Regular Campaign R1A spatial correction handoff

## Scope and source

- R1A base: `d50682b189fac3174b3c869094fe6443bb67844f`
- Branch: `codex/txwzs-regular-campaign-r1a-spatial-fix`
- Worktree: `/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a-spatial-fix`
- Old visual reference: `f1ad13ec62ed57ceb71b089b4fa83b5d9607129b`

The correction changes only `RegularCampaignView`, its focused graphical tests
and the isolated launcher. No R1 runtime, rule, resource, army, battle, clock or
persistence implementation changed.

## Reuse boundary

The correction retains `CampaignMapSurface` as the R1 read projection and uses
the old city's layered ground, broad-road proportions, roof/body/shadow language
and selection outline conventions. `GrayboxBuildingVisual` was inspected as the
shared source for farm, logging and warehouse silhouette rules. It could not be
embedded directly because it assumes the permanent city's 40-pixel Node2D grid,
footprints and lifecycle nodes. The bounded draw adapter uses those shapes with
R1 plot hit regions and records; it does not copy the permanent controller.

Eight small unlabeled dwellings and one well establish inhabited scale outside
all six hit regions. They have no selection, status or gameplay claim. Walls,
gate and command hall likewise remain presentation only.

## Result

All six legal sites fit the initial viewport and the lower-right site is directly
clickable at 1280x720 and 1152x648. Empty sites do not show permanent borders or
numbers. Selection and construction reveal one bounded site. Completed buildings
show distinct city-scale forms. A disconnected entrance stops short of the main
road; the existing connect command turns the same gap into a solid spur.

The normal panel shows facility name, `已建成`, road state, staffing and an
explicit three-minute output cycle. Internal IDs remain in runtime/debug evidence
only. Theater/city switching preserves selection and record identity.

## Limits

This remains a six-site R1 candidate and does not define the final construction
contract. It does not restore drag-to-lay roads, expand C0 battlefield visuals,
or close human mouse-feel, final-art, balance or real-device acceptance.

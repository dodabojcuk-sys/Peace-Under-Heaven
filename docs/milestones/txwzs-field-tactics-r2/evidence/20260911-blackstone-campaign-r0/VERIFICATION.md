# Blackstone First Campaign R0 verification

Run date: 2026-09-11
Godot: `4.5.1.stable.official.f62fdbde1`
Candidate: Blackstone Campaign R0 worktree changes after `f226238`

## Player-flow coverage

The formal Route A regression starts from the normal Blackstone entry, survives
the authored patrol, and captures both required cities. It also asserts that
the victory card and return action read the existing city-control/clear facts.

The formal Route B regression uses the same starting food and drives the
existing Macro March controls to create a runtime camp, construct the
three-segment water crossing to Forest Watch, plan and complete a tower, capture
Silverford, restore a V5 snapshot in a new scene, reinforce the actual stationed
army, send Silverford's one finite transport, continue to Redcliff, and restore
the final result. The regression checks that extra world advancement does not
credit the same transport again.

The graphical companion separately records the visible engineering portion:
road-to-camp plan, work in progress, completed camp, bridge plan/work/completion,
and tower placement from legal A through invalid water B back to legal A. It
uses a fresh explicit V5 save directory. Construction is advanced through the
normal `ConstructionController` process entry at an explicitly documented test
pacing of 100 ms per rendered frame.

## Commands and results

```text
Godot --headless --path . --script res://tests/run_field_tactics_r2_playthrough_smoke.gd \
  -- --txwzs-v5-save-dir=/tmp/txwzs-blackstone-playthrough-final-v5
FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE PASS assertions=7
R2_PLAYTHROUGH_ROUTE_A elapsed_ms=39400 food_remaining=68 food_spent=12 army_casualties=4 specialist_losses=0
R2_PLAYTHROUGH_ROUTE_B elapsed_ms=79400 food_remaining=44 food_spent=36 army_casualties=3 specialist_losses=0 lost_roles=[] ambushes=1
BLACKSTONE_CAMPAIGN_R0_ROUTE_B food=80->48 camp=camp.site.000001 tower_count=1 reinforcements=4 transport=supply.000001

Godot --path . --user-data-dir=/tmp/txwzs-blackstone-campaign-r0-movie/user2 \
  --write-movie /tmp/txwzs-blackstone-campaign-r0-movie/blackstone-campaign-r0-engine-gui-fixed.avi \
  --fixed-fps 30 --script res://tests/run_blackstone_campaign_r0_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=/tmp/txwzs-blackstone-campaign-r0-movie/v5-save \
  --txwzs-blackstone-campaign-evidence-dir=/tmp/txwzs-blackstone-campaign-r0-movie/evidence-fixed
BLACKSTONE_CAMPAIGN_R0_GRAPHICAL_SMOKE PASS assertions=3
405 frames at 30 FPS (00:00:13:15)

Godot --headless --path . --script res://tests/run_field_watchtower_r0_smoke.gd
FIELD_WATCHTOWER_R0_SMOKE PASS assertions=5

Godot --headless --path . --script res://tests/run_field_watchtower_r0_persistence_smoke.gd
FIELD_WATCHTOWER_R0_PERSISTENCE_SMOKE PASS

Godot --path . --user-data-dir=/tmp/txwzs-campaign-direct-graphical-user \
  --script res://tests/run_macro_march_direct_dispatch_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=/tmp/txwzs-campaign-direct-graphical-v5
MACRO_MARCH_DIRECT_DISPATCH_GRAPHICAL_SMOKE PASS assertions=18

Godot --path . --user-data-dir=/tmp/txwzs-campaign-lowpoly-graphical-user \
  --script res://tests/run_macro_march_low_poly_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=/tmp/txwzs-campaign-lowpoly-graphical-v5
MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=19
```

The dedicated supply A/B/C/D workers remain the cross-process proof for cargo
departure, transit, completion and one-time deposit. The Route B V5 assertion
is deliberately described as restoration into a new scene in the same Godot
process; it is not mislabelled as the cross-process proof for the whole battle.

## Evidence scope

- `blackstone-campaign-r0-engine-gui-events.avi` is a 13.5-second Godot Movie
  Maker record from the successful isolated graphical run.
- The PNGs in `screenshots/` are actual root-viewport captures from that same
  campaign runner: they include overview, plan, construction, completion,
  invalid placement and legal re-plan states.
- Map planning uses synthesized Godot GUI pointer press/hold/motion/release.
  Confirmation uses an in-tree, visible, enabled button's connected action
  signal because SceneTree cannot deliver a native macOS click to that control.
  This is engine GUI evidence, not native system-mouse/player-feel evidence.

## Remaining limits

- The automated route demonstrates correctness, not a balance conclusion.
  Its timing and food totals include test pacing and authored encounters.
- Native mouse/video usability and player acceptance remain open.
- The earlier reported stall remains not reproduced and not diagnosed.

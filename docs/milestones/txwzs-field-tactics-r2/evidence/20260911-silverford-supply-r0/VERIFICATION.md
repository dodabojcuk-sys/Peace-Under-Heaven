# Silverford supply R0 verification

## Scope and authority

This checkpoint implements one finite supply use only: a player-controlled
Silverford can send its authored 20 food to Blackstone. It does not add city
production, replenishment, trade, escort combat, transport encounters, camp
construction, or a second order/food/save owner.

`FieldTacticsState` owns remaining point inventory and physical transport
facts: identity, payload, stored directed route segments, actual world
position, elapsed time, blocked road and completion marker.
`ConstructionController` advances those facts with the existing world clock.
Only its existing `NationState` resource transaction adds food at Blackstone,
after the whole payload has arrived and capacity is available. This leaves the
three balances disjoint: Silverford stock, cargo in transit, and shared food.

## Player path and failure behavior

1. Occupy Silverford, then open its existing location detail through a map
   press/release pair.
2. Read `银渡城余粮：20 粮`, the authoritative shortest open route and estimate.
3. Use the visible `运回黑石城（20 粮）` action once. No food is added at
   departure and a second action cannot make a second transport.
4. The map projects a crate/status at the stored route position. A damaged
   future road changes the transport to `WAITING_ROUTE`; repair resumes the
   same stored directed segments. A full Blackstone warehouse changes it to
   `WAITING_CAPACITY` without discarding cargo.
5. Arrival makes one `NationState` add and marks that exact ID completed.
   The Silverford detail remains readable as `本批 20 粮已入库` after refresh
   and restore; this is durable completed-transport state, not a replayed
   notification. Reloading or advancing the completed state does not make
   another add.

The transport is not an army, specialist, soldier, or garrison entry. The
panel's unrelated view-navigation button is labelled `退出战区`, preventing it
from being read as a second logistics action.

## Commands and results

Godot binary:

```text
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

| Check | Result |
| --- | --- |
| Editor import / parse | PASS: Godot 4.5.1 editor run completed without script parse errors. |
| `tests/run_field_supply_r0_smoke.gd` | PASS, 10 assertions: departure/delivery idempotence, no-route atomicity, warehouse-full waiting without repeated checkpoints, damage/resume, strict Field restore, legacy no-seed behavior, real-repair same-step timing at large/30/60/irregular steps, and two post-credit rollback injections. |
| `tests/run_field_supply_r0_persistence_smoke.gd` | PASS: isolated A/B/C Godot processes print and assert `SUPPLY_PRE=20`, `SUPPLY_RESTORED_MID`, one `SUPPLY_DELIVERED deposited=true food=100`, then `SUPPLY_RESTORED_DONE ... duplicate_credit=false`. |
| `tests/run_field_supply_r0_graphical_smoke.gd` | PASS, 3 assertions in a Metal graphical process: map GUI press/release opens Silverford's factual detail; the visible enabled button's connected action creates exactly one moving transport with no early NationState credit; completed durable state reads `本批 20 粮已入库`. |
| `tests/run_macro_march_r0_smoke.gd` | PASS, 35 assertions. |
| `tests/run_field_tactics_r2_smoke.gd` | PASS, 72 assertions. |
| `tests/run_field_tactics_r2_persistence_smoke.gd` | PASS: existing independent construction, repair, marching and blocked-transfer recovery chains. |
| `tests/run_macro_march_low_poly_graphical_smoke.gd` | PASS, 19 assertions at 1152×648, 1280×720 and 1920×1080. |
| `git diff --check` | PASS before staging. |

The graphical runner saved engine-view screenshots named
`field-supply-01-location-detail-engine-gui.png` and
`field-supply-02-moving-engine-gui.png` in its isolated temporary evidence
directory. The map inspection is engine GUI input evidence. Godot's SceneTree
runner does not dispatch a synthetic OS click to a native `Button`; the test
therefore first asserts the actual button is in-tree, visible and enabled, then
fires its already-connected action signal separately. This is not desktop
system-mouse or player-feel evidence.

## Correctness follow-up (2026-09-11)

`mark_supply_transport_waiting_capacity()` now requests a critical checkpoint
only when the convoy first enters the durable capacity-wait phase; unchanged
render/world frames do not publish new save generations. It still retries once
capacity changes. Repairs completed inside one world step carry their actual
completion offset into convoy advancement, so cargo uses only the post-repair
remainder. The R0 timing fixture uses a genuine `REPAIR` project (not a direct
road-state mutation) and compares a large step with 30 FPS, 60 FPS and
irregular splits.

Transport snapshot validation now checks field types before conversion,
sequence identity/range, directed-road continuity and endpoints, phase versus
elapsed/deposited consistency, and the R0 Silverford inventory-plus-cargo
conservation bound. Invalid data is rejected before Field state changes.
Two test-only controller fault seams verify that an injected failure after a
successful NationState credit, and an injected critical-checkpoint failure,
both restore the complete pre-step authority snapshot; retrying the former
credits exactly 20 once. These seams are non-persistent and have no production
caller.

The completed-state graphical capture is
`../20260911-silverford-supply-r0-correctness/field-supply-03-completed-engine-gui.png`.
Its sibling captures are engine-view GUI evidence from an isolated runtime
store. A bright-image observation has not been attributed to lighting or
materials because this run did not perform a fixed-settings parent comparison.

## Candidate boundary

No new long-running candidate window was opened. Existing candidate windows
and isolated user saves were retained. The normal launcher remains the only
supported route for a later player trial. Player acceptance is **OPEN**.

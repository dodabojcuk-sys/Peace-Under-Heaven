# TXWZS M0 R0C State and Resource Map

## Purpose

This pre-implementation audit maps the R0B authorities to the authorized R0C
single-city build slot. It is the design boundary for the code change: R0C
replaces the new-building order flow without creating a second clock, resource
ledger, placement rule set, or save owner.

## Authority map

| Capability | Current authority | R0C disposition | Implementation boundary |
| --- | --- | --- | --- |
| Strategic time, pause, 1x/2x/4x | `ConstructionController.advance_city_time` | `REUSE_AS_AUTHORITY` | The build slot advances only from the existing deterministic construction tick. |
| Construction speed and pressure modifier | `ConstructionController.get_pressure_modifier_permille` | `REUSE_AS_AUTHORITY` | The slot uses the existing `construction` channel; no second speed source. |
| Shared resources | `NationState.commit_resource_transaction` | `REUSE_AS_AUTHORITY` | Every incremental payment and refund is one atomic national transaction. |
| Incremental payment algorithm | `_advance_construction_tick` cumulative target payment | `ADAPT_FOR_R0C` | Move the new-flow project from a placed record to the current-city build slot; keep legacy placed records on the old loop. |
| Building and road legality | `CityGridRules.evaluate_placement_legality`, exposed through `ConstructionController.evaluate_origin_cell_for_definition` | `REUSE_AS_AUTHORITY` | Preview and final ready-placement commit revalidate through this same path. |
| R0B catalog building selection | `_on_definition_button_pressed -> begin_placing_definition` | `ADAPT_FOR_R0C` | Non-road catalog entries call `start_build_project`; road still enters map drag mode. |
| R0B map click timed foundation | `commit_building_from_map_click -> place_definition_at_cell(... timed ...)` | `REMOVE_FROM_NEW_FLOW` | A building map click is reachable only while consuming one paid ready token and creates a completed building without payment. |
| Road drag construction | `begin_road_mode`, road draft validation, `place_player_road_path` | `REUSE_AS_AUTHORITY` | Road remains map-local, continuous, and independent of the building slot. |
| Existing schema 4 constructing placements | placement construction fields in `V5CampaignSnapshot` | `LEGACY_COMPATIBILITY_ONLY` | Preserve position, progress, paid costs, priority, and normal completion. Any legacy construction locks the R0C slot. |
| Construction priority | legacy placement field and detail UI | `REMOVE_FROM_NEW_FLOW` | Schema 4 values remain readable for legacy foundations; the R0C slot has no priority field or player control. |
| Campaign persistence | `V5CampaignSnapshot` plus `ConstructionController` export/restore | `ADAPT_FOR_R0C` | Minimal schema 5 adds one `build_slot`; schema 4 migrates non-destructively with an empty slot. Placement-active saves normalize to ready-to-place. |
| Completed building production | existing runtime placement and road-connectivity derivation | `REUSE_AS_AUTHORITY` | Ready placement creates the normal completed placement record, so connected/disconnected production remains derived. |
| Actual input routing | `MapPanController._handle_construction_input` | `ADAPT_FOR_R0C` | `R`, right click, `Esc`, UI hit protection, and map left click remain real input; the building click now consumes a ready token only. |

## R0C state ownership

`ConstructionController` owns exactly one persistent `build_slot` for the
active current city. Its business states are:

```text
IDLE -> PRODUCING <-> WAITING_MATERIAL -> READY_TO_PLACE
READY_TO_PLACE -> PLACEMENT_ACTIVE -> READY_TO_PLACE
PLACEMENT_ACTIVE -> IDLE only after one legal completed-building placement
```

`PLACEMENT_ACTIVE` is runtime interaction state. Persistence normalizes it to
`READY_TO_PLACE`; mouse coordinates, ghost nodes, hover state, and current
legality are never serialized.

The build slot owns only definition identity, progress, required duration,
total and paid costs, missing-resource IDs, ready-token state, orientation, and
completion-notification state. Map occupancy and production are absent until
the ready token is legally consumed.

## Resource invariants

For every resource in the active build slot:

```text
0 <= paid <= total
remaining = total - paid
0 <= progress <= required
READY_TO_PLACE implies progress == required and paid == total
```

Each deterministic tick calculates one cumulative target payment using the
same pressure-adjusted progress delta. The slot advances only inside the local
commit of the matching `NationState` spend transaction. Cancellation returns
all actually paid resources in one `ADD` transaction; the ledger permits the
lossless administrative refund even when the visible storage capacity is
temporarily exceeded.

## Legacy compatibility boundary

Schema 4 map construction records remain ordinary placement records. They are
not moved, completed, refunded, or converted into ready tokens. The legacy
tick path continues to advance them with their saved priority. While any such
record is constructing, `start_build_project` fails with
`LEGACY_CONSTRUCTION_LOCK`; roads remain usable. A schema 4 snapshot migrates
to schema 5 by adding an empty build slot only.

## Verification targets

- Zero resources: registered slot, 0 progress, 0 paid, no world placement.
- Partial resources: paid progress stops atomically and resumes after refill.
- Pause: no progress and no payment.
- Completion: exact total payment, exactly one ready token, no world object.
- Invalid placement: explicit reason, unchanged resources and token.
- Valid placement: one completed building, no foundation and no second charge.
- Right click or `Esc`: return to ready state with the same token.
- Road drag: independent from every build-slot state.
- Save/load: every persistent slot state plus schema 4 legacy placements.

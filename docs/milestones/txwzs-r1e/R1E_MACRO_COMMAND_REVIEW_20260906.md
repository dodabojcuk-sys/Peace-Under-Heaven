# R1E Macro Command Review — 2026-09-06

## Scope and evidence boundary

This document is a bounded code review and delivery-synchronization record for
the source branch `codex/txwzs-expedition-visual-r1e` at
`4c3e501c16d1a882b996a6a96b2473128312d12c`. It records the latest ordinary
army command contract, maps it to the checked code, and proposes the smallest
next implementation seam. It does **not** implement a macro command system,
modify gameplay source, migrate saves, change siege balance, or certify a
player victory, occupation, visual acceptance, or release.

The R1E source baseline is
`147430ed1d4fe584abcb423755da4455e5d5f95c`. The later source commit repairs
player-visible formation labels and adds the focused assertion; this review
keeps that result and treats the actual checked source SHA above as the only
current identity.

## Effective product contract

Ordinary forces are macro tasks: a player chooses a source strongpoint, draws a
continuous route to a legal strongpoint target, assigns force, and issues the
order. The task may be previewed or cancelled before issue. Once issued, its
target and route are not arbitrarily changed or withdrawn; emergency escape is
a separate, loss-bearing future action. Ordinary targets are cities or garrison
points, not arbitrary wilderness clicks. A blocked route normally produces a
nearby temporary station while an engineer restores the connection.

The current slice also records, without implementing them, separate general and
strategist shared energy pools, a separate skill-use-count constraint, and a
single-army one-use off-road permission (`匿迹奔袭`). No timed `non-road expiry`,
automatic teleport, universal stealth, per-character pool, or automatic skill
count recovery follows from this contract.

## Checked responsibility map

| Concern | Checked implementation | Current behavior and reusable boundary | Difference from macro contract |
| --- | --- | --- | --- |
| Expedition preparation and force identity | `scripts/construction_controller.gd`: `get_expedition_preparation_model`, `open_expedition_preparation`, `commit_expedition_attempt`; `scripts/ui/expedition_preparation_panel.gd` | Selects one to three persistent `GarrisonState` formations, shows readable names, validates supply and creates a detached attempt. This is reusable for force selection and pre-issue validation. | It has no source/target strongpoint selector or drawn strategic route; it is an entry to one fixed mainline battle. |
| Occupied assets and immutable departure | `commit_expedition_attempt`, `_install_expedition_attempt`, `_persist_expedition_departure`; `NationState.commit_resource_transaction` | One food transaction, reservation and V6 attempt are installed together, then persisted; failure rolls the state back or blocks duplicate action. This is the required pattern for an issued command. | The attempt stores a battle snapshot, not a reusable strategic mission order or blocked/stationed outcome. |
| Existing strategic army record | `scripts/army/army_registry.gd`: `create_reserved`, `transition`, `advance_progress`, `apply_settlement`; `scripts/construction_controller.gd`: `reserve_army_dispatch`, `confirm_army_dispatch`, `advance_army_strategic_time` | Already owns stable army ID, source, target, route ID, duration, progress and phase. The registry is persistable and uses guarded transitions. This is the closest reuse seam for issued macro orders. | It currently permits only one active army, has no legal-target registry or drawn-route geometry, no blockage/station phase, and no player-facing macro command UI. Its reservation can be cancelled before confirmation, which is appropriate only for a draft. |
| Legacy point-to-point prototype | `scripts/mvp/blackstone_expedition_mvp.gd`: `begin_command_interaction`, `_open_pending_order`, `confirm_pending_dispatch_percent`, `advance_marching_time`, `handle_escape` | Has a pointer drag, source/target preview, percentage force selection and visible marching interpolation across a small fixed node graph. It is useful interaction evidence only. | Its `_marching_armies` and garrisons are scene-local dictionaries, it permits a legacy tactical command model, has no durable strategic owner, and must not become the new source of truth. |
| Battle command and movement | `scripts/combat/c0_battle_graybox.gd`: `_issue_selected_order`; `scripts/combat/combat_transaction_coordinator.gd`: `issue_order`; `scripts/combat/battle_session.gd`: `issue_order`, `_apply_orders_for_current_tick`, `_update_positions` | C0 accepts repeated per-squad `ADVANCE`, `HOLD`, and `RETREAT` orders and continuously advances or retreats squad positions. It is reusable as a battle-local executor. | These are mutable formation micro-orders, not issued strategic missions. `BattleOrder` must not be repurposed as `MarchOrder`. |
| Route assignment and outcome | `commit_expedition_attempt` fixes all selected formations to `CommittedForceSnapshot.FRONT_ROUTE`; `BattleSession._check_outcome` | The R1E entry already freezes the selected formation route before the C0 session. A C0 victory occurs when one route has gate HP zero, that route's enemy HP zero and a living player squad remains there. | No player-drawn strategic path, no arrival/blocked station, and no formal breach → remaining defenders → occupation → multi-city outcome chain. |
| Result writeback and return | `scripts/combat/combat_transaction_coordinator.gd`: `confirm_result`, `request_return_to_city`; `scripts/construction_controller.gd`: `apply_battle_result_atomic`, `get_expedition_attempt`; `scripts/army/garrison_state.gd` formation-survivor application | The coordinator authorizes one terminal snapshot, and city settlement writes selected formation survivors once before guarded city return. This is the existing single settlement authority to preserve. | A strategic task needs an arrival/blocked disposition before any battle and must not add another settlement ledger. |
| Save and cold recovery | `scripts/construction_controller.gd`: `export_v5_campaign_snapshot`, `restore_v5_campaign_snapshot`, `_restore_first_war_runtime_from_persistence`; `scripts/state/runtime_campaign_persistence_coordinator.gd` | The durable expedition attempt is serialized and rebuilds its runtime projection after restore; active non-durable reservations are rejected. This shows where any future command must be validated and restored atomically. | No migration or new fields are authorized in this review. A future slice must define the snapshot boundary before adding strategic command state. |

## Source-backed conclusions

1. **The existing R1E path is a durable battle departure, not a macro command.**
   Its strongest reusable pieces are formation identity, transactional supply,
   immutable attempt snapshots, settlement idempotence, and recovery guards.
2. **Two incompatible command surfaces already exist.** The legacy expedition
   MVP has a scene-local drag-and-dispatch loop, while C0 provides repeatable
   squad orders. Neither is a legal-target, issued-and-locked strategic task.
   A future slice should compose the persistent `ArmyRegistry`/city authority,
   not promote either presentation model to an owner.
3. **The siege result is only route-level.** The checked `BattleSession` code
   confirms the reported condition: destroyed gate plus cleared defending force
   on one route plus a surviving squad. It does not implement occupation,
   remaining enemy cities, captured-city construction permissions, or a match
   victory rule.

The historical 20-person normal-input victory note and current 14-person
failure record belong to different evidence points. The code review does not
infer that the six-person difference is the only cause, and this task neither
replays the 14-person run nor changes enemy values or victory conditions.

## Smallest next implementation seam (not implemented here)

Keep the current city, resource, roster, attempt, settlement and save owners.
Add one explicit strategic `MarchOrder` domain record adjacent to the existing
`ArmyRegistry` lifecycle rather than to C0 UI code:

1. Build a read-only legal-strongpoint graph and route-preview model. A draft
   carries source, legal target, selected force and drawn continuous path; it is
   disposable and has no resource/roster side effect.
2. At issue, validate the draft again and atomically create the command/army
   lifecycle record through the current city authority. Lock route and target;
   move resource or force reservations only at this existing transaction
   boundary.
3. Advance the issued route through the strategic owner. Arrival invokes the
   already-owned battle/settlement bridge when relevant; a blockage creates the
   defined nearby-station result and does not expose a free wilderness target.
4. Add focused tests for draft cancellation versus issued-order immutability,
   legal-target rejection, reload idempotence, continuous progress and blocked
   station. Keep battle micro-orders isolated and defer energy/skill-count,
   off-road use, escape, occupation and multi-city rules.

Only two product inputs truly block this narrow slice:

- the initial canonical list of strongpoint IDs and which relationships are
  legal ordinary targets; and
- the persisted semantics of a route blockage/nearby station (especially
  whether the force remains an `ArmyRegistry` active record and what resumes it).

Energy pools, skill-count restoration, off-road interruption and escape-loss
formula are important, but are deliberately outside this first command slice
and should not be guessed here.

## Acceptance boundary

This review records product rules and a code seam only.

- Macro command implementation: **NO**
- Shared energy / skill counts / off-road implementation: **NO**
- Siege victory, breach, occupation or multi-city acceptance: **NO**
- Founder, visual or player acceptance: **NO**
- Gameplay source changes in this delivery: **NO**

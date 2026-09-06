# TXWZS M0 Time, Construction, and Mainline Pressure Tech Spec

## Status

- Scope: conditional M0 only
- Source baseline: `0b1c3b5b5e15c564105c0c745efab274110c9240`
- Candidate branch: `codex/txwzs-m0-time-build-pressure-r0`
- Product authority: the supplied M0 instruction and game-bible decisions D-067 through D-070
- Overall MVP and full-game design: not frozen

## Problem

The accepted R3B baseline already has one city time owner, one construction
owner, one national resource ledger, and a versioned V5 save path. Construction
currently pays its full cost when an order is placed and completes on a day
boundary. The legacy first-war deadline also freezes city time when it becomes
pending. Those behaviors cannot express the authorized M0 chain:

`game time -> incremental construction payment -> material pause/resume -> mainline deadline -> permanent city pressure`

## Acceptance Criteria

1. Paused city time still permits a legal construction order, while city time,
   production, construction progress, resource payment, and mainline pressure do
   not advance.
2. Non-immediate construction pays through `NationState` as deterministic
   progress crosses fixed simulation ticks. Final paid totals exactly match the
   configured cost and no balance becomes negative.
3. A task that cannot pay its next required cumulative amount becomes
   `BLOCKED_RESOURCES`, names each missing resource, preserves progress and paid
   totals, and resumes automatically after a legal resource transaction.
4. Construction exposes `HIGH`, `NORMAL`, and `LOW` priority. Tasks are processed
   by priority and then stable placement ID, so scarce resources have a stable
   winner without introducing workers or a second queue authority.
5. A single current-mainline state owns level ID, activation time, deadline,
   monotonic pressure stage, clear state, committed pressure events, and
   permanent losses. A battle attempt never owns or restores those fields.
6. Security mitigates configured pressure loss but cannot lower the pressure
   stage or clear an uncleared level.
7. Production and construction consume one pressure-modifier interface.
   Essential recovery channels always clamp above zero at maximum pressure.
8. Clearing the current level stops future core pressure while preserving losses
   already committed to the permanent city.
9. V5 save schema v4 round-trips time, construction payment/progress/blocking,
   security, mainline pressure, and permanent losses. Schema v2/v3 and V1 import
   receive safe defaults without offline catch-up or destructive migration.
10. The existing road, placement, rotation, movement/removal boundary, dual-city
    runtime isolation, combat, resource, and persistence regressions remain
    green except where an old assertion directly encodes the superseded
    full-prepayment or pending-time-freeze rule.
11. The HUD shows game time and controls, current mainline deadline, pressure
    stage, next-stage consequence, security mitigation, and explicit missing
    material feedback without a new permanent sidebar.

## Ownership and Data Flow

| Concern | Existing authority | M0 change |
| --- | --- | --- |
| Game time | `ConstructionController` | Reuse; fixed construction ticks derive only from its elapsed simulation time. |
| Resources | `NationState.commit_resource_transaction()` | Reuse for every incremental payment and pressure loss. |
| Construction | `ConstructionController` placement records | Extend records; do not add a parallel task store. |
| Pressure config | New typed `MainlinePressureProfile` resource | Centralize prototype thresholds, modifiers, floors, and event loss values. |
| Current mainline | New `CurrentMainlineLevel` value object owned by `ConstructionController` | Own deadline, stage, clear state, event IDs, and permanent losses. |
| Battle attempt | Existing combat objects; pure M0 boundary fixture where no retry API exists | Never restore current-mainline or permanent-city fields. |
| Save | `V5CampaignSnapshot` and `V5CampaignSaveStore` | Bump domain schema to v4 and migrate older accepted shapes in memory. |
| HUD | Existing top status bar and building detail panel | Reuse lightweight surfaces; no shell redesign. |

## Deterministic Construction Algorithm

- Simulation quantum: one game second (`1000` milliseconds), aligned to the
  existing day clock. Rendering frame partitioning cannot change the number of
  crossed quanta.
- Construction progress is integer milliseconds.
- Each active task computes its target cumulative paid amount as
  `floor(total_cost * target_progress / required_progress)`, with exact total
  cost forced at completion.
- A tick first prepares all spend entries, then commits them and the record
  progress in one `NationState` transaction callback. If the spend is invalid,
  neither resource nor progress changes.
- Tasks are ordered by `HIGH`, `NORMAL`, `LOW`, then placement ID.
- Immediate definitions such as current roads retain their accepted atomic
  placement and payment contract; non-immediate buildings use M0 incremental
  payment. This avoids turning existing road connectivity into a second major
  migration in this restricted slice.
- Cancellation/removal retains the accepted no-refund rule. M0 does not invent a
  refund economy.

## Mainline Pressure State

Prototype stages are `NORMAL`, `ALERT`, `UNREST`, `CRISIS`, and `EXTREME`.
Thresholds and all numeric effects live in the pressure profile resource.

The current first-war level becomes the current mainline target at the start of
day 1. Its deadline is the existing day-7 first-war boundary. Becoming pending
does not freeze permanent-city time or construction. Only an actual battle
transaction/instance blocks city authority as before.

Each day boundary:

1. settle construction completion and existing city economy;
2. derive the monotonic pressure stage from current-mainline elapsed time;
3. commit at most one deterministic pressure event per day and record its stable
   event ID;
4. publish read models and HUD state.

Clearing the level prevents later pressure events and modifiers, but does not
refund committed losses. Ordinary save/load restores exact state and performs no
real-time catch-up.

## Compatibility and Rollback

- V5 schema v4 is an additive domain evolution with in-memory migration from
  accepted v2/v3 snapshots and the existing V1 import path.
- Older saves receive a current-mainline default anchored to day 1, but no
  retroactive event losses are applied during load.
- No real `user://` save is modified by tests; all persistence tests use explicit
  temporary directories.
- Rollback is deleting or abandoning the isolated worktree/branch. The source
  worktree remains at the verified clean R3B head.

## Verification

- One dedicated M0 runner covers the eight mandatory scenarios.
- Existing 44-runner regression is rerun in full.
- Godot editor import, `blank_map`, Blackstone, and C0 headless smokes are rerun.
- UI evidence is captured at 1440x900 and 1280x720, plus the specified paused,
  blocked-material, and overdue-pressure states.
- `git diff --check`, final status, and manual diff review are required before a
  local commit.

## Explicit Non-Goals

No battle redesign, population agents, security AI, equipment, trade, technology
expansion, final art, overall UI rewrite, Godot/dependency upgrade, deployment,
push, merge, or later-phase implementation is authorized.

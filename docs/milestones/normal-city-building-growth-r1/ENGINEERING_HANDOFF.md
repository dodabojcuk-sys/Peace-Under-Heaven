# Pre-Migration Engineering Handoff

Prepared: 2026-09-13 14:50 CST

## Repository and baseline

| Fact | Value |
| --- | --- |
| Repository | `/Users/m4-zhi/Documents/codex-workspace/txwzs-field-tactics-r2` |
| GitHub | `dodabojcuk-sys/Peace-Under-Heaven` |
| Default branch | `codex/txwzs-review-20260906` |
| Development branch | `codex/txwzs-field-tactics-r2` |
| Input baseline | `9d285d1e93d5115f35824b67e05de9cac6f94e1a` |
| Closeout implementation | `a415b7ca3c79ede303f10e0b631a2b3cd78b1f65` |
| Closeout implementation tree | `8a73cac3ac2bf56a55eebb36152d42bf8600706c` |
| Godot | `4.5.1.stable.official.f62fdbde1`; project feature set `4.5` |

The final default/development merge SHA is an external ref fact and cannot
self-reference from inside its own commit. Record it from the post-merge
readback in the delivery accompanying this handoff; both branch refs and the
local checkout must resolve to that same full SHA and tree.

## Supported startup and saves

- Formal candidate: double-click `RUN_CURRENT_TXWZS.command`.
- Isolated candidate: double-click `RUN_ISOLATED_TXWZS.command` or run
  `./RUN_CURRENT_TXWZS.command --isolated`.
- Resume one isolated store with
  `./RUN_CURRENT_TXWZS.command --save-dir /exact/reported/path`.
- The launcher identifies project, Git commit and save directory, refuses a
  second writer for the same store, and does not close an existing candidate.
- Campaign snapshot schema is 17. V16 migration adds an empty building-upgrade
  target only; it does not upgrade buildings, add population or grant
  resources. Older migrations remain conservative through the existing chain.
- `user://` and explicit candidate save directories are not Git assets. Do not
  copy, truncate, overwrite or manually edit player saves during migration.

## Runtime ownership

| Layer | Responsibility and authority |
| --- | --- |
| Normal inner city | `ConstructionController` owns world/calendar ordering and building placement/project records; `NationState` owns shared resources; `PopulationRecoveryState`, `CityGovernanceState`, `GarrisonState` and `TrainingQueue` own their existing population, governance, soldiers and training facts. |
| Field theatre | `WarLoopState`, `FieldTacticsState` and `ArmyRegistry` own roads, camps, specialists, patrols, armies, marches and macro sieges. Normal-city UI reads their projection and does not duplicate it. |
| Wartime C0 instance | `BattleSession` and the existing combat transaction/result path own fixed-step deployment, actions, temporary works and one settlement. C0 does not turn temporary works into city buildings. |
| Persistence | The existing runtime campaign persistence coordinator writes the V5 envelope. UI, scene nodes and test read models are not save owners. |

## Confirmed product rules

- Blackstone victory is settled once from actual player control of Redcliff
  and Silverford; no mandatory defense-battle prerequisite exists.
- A dormant sourced Redcliff vanguard becomes terminal `CANCELLED` if the
  player controls Redcliff at departure. A departed/arrived/engaged army
  persists. Occupation commits before a same-update configured departure.
- World speed changes real duration, not strategic results. City, field and
  army systems use the existing world clock. Opening C0 freezes that world;
  C0 uses 0.25-second fixed steps. Only established source-specific settlement
  catch-up is applied.
- Farm, logging camp, warehouse, housing and clinic support formal L1-to-L2
  in-place upgrades. Cost is paid once, old capability remains during work,
  completion changes capability only after save success, duplicate submission
  is rejected, and R1 cancellation refunds the full paid cost. Storage grants
  no inventory, housing grants no residents and medical capacity cannot revive
  fallen soldiers.

## Completed capability and evidence

- Normal city: roads, five-building growth, pressure/workforce-aware daily
  production, storage/housing/medical capacity, training, treatment and
  persistent recovery.
- Field: marching, locations, supply, construction, specialists, patrols,
  macro siege and sourced defense handoff.
- C0: fixed-step spatial battle, deployment/actions/temporary works and atomic
  outcome settlement.
- Candidate: New/Continue/Exit, pause/speed guidance, commit identity and
  isolated save entry.

Representative entry points:

- `tests/run_normal_city_building_growth_r1_smoke.gd` — 41 assertions,
  including a normal-resource formal build-to-training route.
- `tests/run_normal_city_building_growth_r1_persistence_smoke.gd` — three
  independent processes covering active and completed upgrade restoration.
- `tests/run_normal_city_building_growth_r1_graphical_smoke.gd` — final
  confirmation/progress and exceptional states at all three resolutions.
- `tests/run_v5_campaign_persistence_smoke.gd` — campaign cold persistence.
- `docs/evidence/normal-city-building-growth-r1/` — both pre-fix and final
  screenshot sets; only `building-growth-final-*` is final visual evidence.

## Evidence boundaries and remaining work

- Complete engineering evidence does not equal native mouse feel or human
  player acceptance.
- Final building art, numerical balance, long-hold/drag feel, combat feel and
  unfamiliar-player comprehension remain OPEN.
- This closeout does not start a new campaign, building, population or art
  phase and does not claim release readiness.
- The original screenshot's `木材 200/160` was direct graphical-fixture state,
  not formal acquisition. Final layout evidence uses `150/160`; normal-resource
  economy proof is separate.

## Git and worktree audit at preparation time

- GitHub had no open PR before this closeout repair.
- All named historical remote branches except
  `codex/normal-city-building-growth-r1` were ancestors or tree-contained by
  the input default. The divergent growth branch has tree
  `eaeaaf608e7e831da3b23a907dcb93592327ac7f`, identical to delivered commit
  `192daa0fe083d9ff747d7f308f4ad4dae4843553`; its unique history must not be
  merged by name.
- Other worktrees were not switched or cleaned. At 14:50 CST, the detached
  Blackstone baseline contained 12 generated untracked `.uid` files; the
  M0 time/build worktree had 12 deleted historical evidence files; the war-loop
  worktree had one untracked `delivery/` directory. These are not part of this
  closeout and require their owners to resolve them.

## Candidate processes observed at preparation time

This is a time-bounded process snapshot, not durable configuration:

- PID 18904: formal candidate `0119addb49a9ff6d0af2f5e5136ce97732067b86`,
  isolated save `/private/tmp/txwzs-formal-candidate-0119addb49a9.wt9n83bb/saves`.
- PID 27048: city-strategy candidate `156087c`, isolated save
  `/tmp/txwzs-city-strategy-candidate.tT7e92`.
- PID 35530: city-strategy growth candidate `3a4ac84`, isolated save
  `/tmp/txwzs-city-strategy-growth-3a4ac84-save.2aPPNI`.
- PID 44874: war-specialists candidate `4501875`, isolated save
  `/tmp/txwzs-war-specialists-4501875.236SZr/saves`.

They were preserved. Recheck PIDs, commands and directories at actual migration
time; do not assume any process or temporary directory still exists.

## Rollback and migration cautions

- Building growth functional commits: `8428bb63f3f43a19df2d97f9f8342e5426dc4edc`,
  `192daa0fe083d9ff747d7f308f4ad4dae4843553`, and normal-resource proof
  `b124602f67e8382da8f9926a3c16be99148521f6`.
- Layout closeout checkpoint: `a415b7ca3c79ede303f10e0b631a2b3cd78b1f65`.
- Revert by complete feature commit after verifying save compatibility; do not
  manually reverse player saves or force-push shared branches.
- Do not migrate `.godot/`, logs, temporary runner stores or process IDs.
- Fresh-clone validation must restore tracked assets, run Godot import and use
  an isolated V5 save directory before any real-save operation.

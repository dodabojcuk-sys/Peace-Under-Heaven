# TXWZS City Governance Interaction 001 — Blocker Report

## Result

```text
RESULT=BLOCKED_BASELINE_CONTRACT_MISMATCH
BASE_HEAD=2e39ac78f3c9d93585edee6e43a1b736e0ba05bf
WORKTREE=txwzs-city-governance-interaction-001
BRANCH=codex/txwzs-city-governance-interaction-001
PRODUCT_SOURCE_CHANGED=NO
V5_SCHEMA_CHANGED=NO
SECOND_STATE_OWNER=NO
SECOND_ROAD_NETWORK=NO
SECOND_QUEUE=NO
ROAD_GAMEPLAY_CHANGED=NO
PORTABLE_MACOS_EXPORT_PRESET=PASS
EXPORT_TEMPLATE_DOWNLOAD=IN_PROGRESS
GOVERNANCE_VISUAL_CANDIDATE=NOT_CLAIMED
PUSH=NO
MERGE=NO
DEPLOY=NO
```

## Stop condition

The requested road-connection interaction cannot be implemented truthfully from
this exact base without adding the very authority and queue mechanisms that the
task prohibits.

The audit brief describes these pre-existing contracts:

```text
RoadConnectivitySystem query
immutable preview/confirm intent
reservation
ScheduledJob
```

They are not present in `2e39ac78f3c9d93585edee6e43a1b736e0ba05bf`:

| Required contract | Exact base observation | Consequence |
| --- | --- | --- |
| `RoadConnectivitySystem` | No class or reference exists. Connectivity is derived by `ConstructionController.get_connected_road_cells()` through `CityGridRules` and `RegularCitySpatialFoundation`. | Creating a class with this name would be a second/renamed authority, not reuse. |
| Immutable road intent with stale rejection | `ConstructionController.evaluate_road_path()` only returns a mutable validation dictionary for the current drag draft. | Adding persistence or a new intent identity would introduce a new transaction model. |
| Reservation and `ScheduledJob` for a road | No `ScheduledJob` class/reference exists. `confirm_road_preview()` calls `place_player_road_path()`; it immediately calls `NationState.commit_resource_transaction()` and registers road placements. | Converting this to a queued job changes existing road timing and requires a queue/owner that the task explicitly forbids. |
| Existing recommendation rejection matrix | The base does not model defense-zone or strategic-route recommendation policy. It only rejects illegal walls, gates, reserves, occupancy, bounds, and non-orthogonal drags. | Inventing a strategic-path classifier would exceed the requested governance-only change. |

The audit evidence also confirms the player-facing starting point: the native
city shell exposes only `建造目录` in its right rail, while the existing
controller owns the direct road drag and immediate commit. It therefore
supports the UX problem, but it does not supply the required transaction
boundary.

No partial governance UI was added. A cosmetic `查看接通方案` button that
ultimately commits the current immediate road write would incorrectly claim the
requested preview/reservation/job behavior, so it was intentionally not made.

## Read-only audit record

The following project inputs were read before the stop decision:

- `AGENTS.md`
- `CURRENT_STATE.md`
- `docs/m1b/TXWZS_M1B_PLAYABLE_SHELL_R0_REPORT.md`
- `docs/m1a/TXWZS_M1A1_R2_V5_RUNTIME_PERSISTENCE_REPORT.md`
- the byte-identical audit copies at
  `../txwzs-m1-live-restore-acb5ed59/docs/audit/TXWZS_PLAYER_EFFORT_REDUCTION_AUDIT_001.md`
  and `../txwzs-restored-normalized-m1/docs/audit/TXWZS_PLAYER_EFFORT_REDUCTION_AUDIT_001.md`
  (SHA-256 `a752306891a9a6f7224a721b02eb9cd4dd597fdccc0d12ba3ce2e9e8c5df9bc9`).

The Product Design audit workflow was used to establish the player-visible
baseline. Its current native capture was manually inspected at:

```text
/tmp/txwzs-city-governance-audit-001/baseline-city-1440x900.png
```

It is a temporary audit artifact, not a final governance evidence attachment;
no final UI state exists because source changes were stopped.

## Skills and external intelligence

| Requested item | Status | Actual use / decision |
| --- | --- | --- |
| `product-design:audit` | Used | Captured and manually inspected the baseline city rail, then limited the proposed surface to an existing workflow. |
| `using-godot-prompter`, `godot-ui`, `responsive-ui`, `input-handling`, `godot-testing`, `godot-code-review`, `save-load`, `game-ui-ux` | Unavailable locally | Not claimed as used. Their required behavior was not fabricated; project tests and Godot 4.5.1 documentation remain the implementation authority. |
| Godot 4.5.1 UI documentation | Used | Containers, anchors, size flags, focus, and GUI input would govern a later implementation. No 4.7 API or example was copied. |
| `godotengine/godot` | Targeted read-only reference | Commit `f62fdbde15035c5576dad93e586201f4d41ef0cb` (`4.5.1-stable`), MIT license. Used only to verify the engine/version and UI documentation authority. |
| Godogen | Not used | Its C# generation system was neither downloaded nor introduced; the baseline mismatch was found before an engineering-method reference was needed. |

The official documentation's advice to use nested Containers and size flags for
complex responsive UIs was accepted as a future implementation constraint. It
was not used as a reason to replace the project’s GDScript architecture.

## M1B portable export follow-up

The local ignored M1B preset was inspected for certificates, accounts, secrets,
and absolute user paths. It contained no secret values; blank code-signing
identity fields are retained as blank. This branch now tracks one minimal,
portable macOS debug preset through a narrow `!export_presets.cfg` exception.
`export_credentials.cfg` remains explicitly ignored.

The exact official template archive is downloading in the background with
resume enabled:

```text
https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz
```

The existing 13 MiB partial was preserved and resumed at the same file. At the
last observation it had reached 42 MiB; the required target directory still
lacked `export_templates/4.5.1.stable/macos.zip`. No focus probe, engine
upgrade, standalone export, or standalone evidence was attempted. A completed
download must still pass archive validation before installation and export.

## Verification performed

```text
BASE_HEAD_EXACT=PASS
SOURCE_WORKTREE_CLEAN=PASS
TARGET_WORKTREE_CLEAN_BEFORE_CHANGES=PASS
GODOT_VERSION=4.5.1.stable.official.f62fdbde1
GODOT_EDITOR_IMPORT=PASS
EXPORT_PRESET_SECRET_AND_ABSOLUTE_PATH_SCAN=PASS
EXPORT_CREDENTIALS_IGNORED=PASS
EXPORT_PRESET_DIFF_CHECK=PASS
ROAD_CONTRACT_INVENTORY=PASS_BLOCKER_CONFIRMED
NATIVE_BASELINE_AUDIT_CAPTURE=PASS_MANUALLY_INSPECTED
FOCUSED_GOVERNANCE_TEST=NOT_CREATED_STOPPED_BEFORE_PRODUCT_CHANGE
FULL_53_OF_53_REGRESSION=NOT_RERUN_NO_PRODUCT_CHANGE
FINAL_SCREENSHOT_COUNT=0
FINAL_CONTACT_SHEET=NOT_CREATED
```

## Required next decision

Choose one of the following before resuming governance implementation:

1. Rebase this task onto the audited product lineage that already contains
   `RoadConnectivitySystem`, immutable construction intents, and a scheduled
   road-job contract; or
2. Explicitly authorize a separate, scoped road-transaction foundation task
   that defines one authoritative road intent/job lifecycle before this UI task.

Neither choice is made here. This branch must remain unmerged while the
baseline contract is unresolved.

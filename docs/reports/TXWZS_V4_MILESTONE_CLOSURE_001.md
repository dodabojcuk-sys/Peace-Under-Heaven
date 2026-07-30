# TXWZS V4 Milestone Closure 001

## Verdict

`TXWZS_V4_MILESTONE_CLOSURE_001_ACCEPTED`

- `Blackstone visual slice: INDEPENDENTLY_VERIFIED`
- `V4 UI visual slice: ACCEPTED`
- `T-V4-003: PASS`
- `V4: VERIFIED / FROZEN`
- `V5: READY`

本报告是 V4 整体里程碑 Gate，不是新的路线单点复审。既有
`V4_UI_VISUAL_SLICE_INDEPENDENT_REVIEW_002_ACCEPTED` 直接复用，没有创建
Review 003。

## Candidate identity

- Branch: `codex/v4-milestone-closure`
- Parent HEAD: `64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Formal launcher: `./RUN_CURRENT_TXWZS.command`
- Formal window identity:
  `天下无战事 · CITY · codex/v4-milestone-closure@64f37bd · DEBUG · DIRTY`
- Final evidence directory:
  `/tmp/txwzs-v4-milestone-closure.fD2A6P`
- Staged state before closure: empty
- Protected scope: the eight S1A.2 files stayed untracked and were not modified,
  staged, or treated as an accepted disk-save baseline.

Review 002 candidate hashes still match the final candidate:

| File | SHA-256 |
| --- | --- |
| `scenes/blackstone_expedition_mvp.tscn` | `1100bf7cd58bfe482a3adbdbedd761eaeb490ea6e86848335d83dc1497446c2b` |
| `scripts/mvp/blackstone_expedition_mvp.gd` | `5b651e0381fd7c315ef388498aa46ce7b837b10f91ddfb5963edb8b7411ed65f` |
| `tests/run_blackstone_playable_mvp_smoke.gd` | `737d8c9384900bc62993e459d4e68d809e0ed262bf1c89ea534ab2a733062806` |

## Final 1152 × 648 visual path

The formal Blackstone scene was instantiated from the current candidate and
captured afresh at 1152 × 648. The temporary capture harness was moved out of
the repository after use.

| State | Evidence | Result |
| --- | --- | --- |
| Default | `01-default.png` | PASS; route does not intersect or crowd 山路援军 title/description |
| Dispatch | `02-dispatch.png` | PASS; selected route remains outside both text rectangles |
| Marching | `03-marching.png` | PASS; progress and command presentation do not clip |
| Retreat | `04-retreat-confirm.png` | PASS; 72% blocking mask and confirmation modal are singular and readable |
| Failure | `05-failure.png` | PASS; one failure result layer, no stale mask |
| Victory | `06-victory.png` | PASS; one victory result layer, no stale failure content |
| Return | `07-return-city.png` | PASS; city returns without residual overlay |
| Re-entry | `08-reenter.png` | PASS; Blackstone state resets without duplicate result layer |

The Blackstone smoke assertions independently enforce that both the title
rectangle and description rectangle do not intersect the route. Human visual
inspection confirms the route does not touch the text, seize hierarchy, or
impair reading. Route meaning, node relationships, and the established color
semantics are unchanged.

## Final automated and runtime Gate

| Check | Result |
| --- | --- |
| Blackstone focused runner | exit 0; 150 explicit assertions + 1 runner summary |
| C0 city-time / BattleSession / coordinator runner | exit 0; 59 explicit assertions + 1 runner summary |
| Git-tracked runners | 27/27 exit 0; 1515 PASS lines |
| All-present runners | 29/29 exit 0; 1686 PASS lines |
| Formal main scene headless | exit 0 |
| Formal Blackstone scene headless | exit 0 |
| Final Godot headless editor scan | exit 0 |
| `git diff --check` | exit 0; empty output |
| `FAIL / ERROR / WARNING / Parse Error / SCRIPT ERROR` scan | 0 matches in final logs |

The final all-present suite includes the untracked S1A.2 runner only as a
read-only regression observation. Passing it does not accept, freeze, stage, or
commit S1A.2.

## Ordinary closeout repair

The first editor scan found one import warning because Godot treated planning
CSV mirrors as translation resources. `docs/planning/.gdignore` now declares
the planning directory to be documentation rather than Godot runtime resources.
The final editor scan is warning-free. No runtime, data, save, or player-facing
behavior changed.

## Regression conclusion

The final candidate preserves:

- original route meaning and node relationships;
- established Figma-derived color semantics;
- Result Modal projection;
- 72% blocking mask;
- dispatch, march, retreat, failure, victory, return, and re-entry behavior;
- C0 city-time settlement authority;
- `BattleSession` terminal authority and copy isolation;
- coordinator ownership, replay idempotency, and conflict rejection.

The V4 freeze checkpoint must include only the explained V4/C0/planning/report
scope and must continue to exclude the protected S1A.2 files. No push or deploy
is authorized.

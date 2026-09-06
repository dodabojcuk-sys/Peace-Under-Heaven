# R1E Delivery Verification — 2026-09-06

## Snapshot identity

| Field | Actual value |
| --- | --- |
| Source path | `/Users/m4-zhi/Documents/codex-workspace/txwzs-city-governance-interaction-001` |
| Source branch | `codex/txwzs-expedition-visual-r1e` |
| Source head | `4c3e501c16d1a882b996a6a96b2473128312d12c` |
| Source worktree before capture | clean; source was not modified by this delivery operation |
| Independent review branch | `codex/txwzs-review-20260906` |
| Review snapshot root commit | `1b3400f898ed6af0d9702bb5e6e94e0dbe903209` |
| Remote URL | `https://github.com/dodabojcuk-sys/Peace-Under-Heaven` |
| Remote snapshot head after first upload | `1b3400f898ed6af0d9702bb5e6e94e0dbe903209` |
| Development history carried into review branch | none; the review snapshot is an intentional new root commit |

The root snapshot retains the captured tracked project tree plus the R1E review
documents. The only content differences from the source tree are documentation
and delivery records: `README.md`, `CURRENT_STATE.md`, `CHANGELOG.md`,
`DECISIONS.md`, the updated R1E reconciliation report, and the new R1E macro
review/source-inventory/verification/manifest files. No gameplay script, scene,
resource, test semantic, balance, save schema or victory condition was changed.

## Delivery checks

| Check | Result | Evidence |
| --- | --- | --- |
| Remote branch preflight | PASS | Remote had no existing `codex/txwzs-review-20260906` ref before upload. |
| Content review | PASS | Candidate contains the full tracked project set; ignored cache/export/credential carriers were not copied. Credential-carrier filename hits: 0; common secret-pattern filename hits: 0. |
| Upload | PASS | Normal existing GitHub authentication pushed the independent review branch without force, merge, tag, release or deploy. |
| Remote SHA verification | PASS | `git ls-remote --heads origin refs/heads/codex/txwzs-review-20260906` returned the root snapshot SHA above. |
| Fresh clone | FAIL — transport | Three new empty clone directories were tried (full clone twice, partial clone once). Each failed before checkout with GitHub HTTPS `curl 28` connection timeout after about 75 seconds. This is a current network transport failure, not a project-resource or Godot failure; it prevents claiming a clean-clone PASS. |
| Exact independent delivery-root import | PASS | Godot 4.5.1 editor import/parse exited 0 from the independent review root. |
| Formal scene startup | PASS | `blank_map.tscn` and `c0_battle_graybox.tscn` each exited 0 headlessly. |
| R1E causality smoke | PASS | `tests/run_r1e_expedition_causality_smoke.gd`: 50 assertions. |
| C0 presentation smoke | PASS | `tests/run_c0_battle_presentation_smoke.gd`: PASS. |
| Diff and tracked state | PASS | `git diff --check` passed before the root snapshot; the delivery root has no tracked runtime changes after import. |

## Commands actually run

```sh
TASK_GODOT=/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
"$TASK_GODOT" --version
"$TASK_GODOT" --headless --path . --editor --quit
"$TASK_GODOT" --headless --path . --scene res://scenes/blank_map.tscn --quit-after 5
"$TASK_GODOT" --headless --path . --scene res://scenes/c0_battle_graybox.tscn --quit-after 5
"$TASK_GODOT" --headless --path . --script res://tests/run_r1e_expedition_causality_smoke.gd
"$TASK_GODOT" --headless --path . --script res://tests/run_c0_battle_presentation_smoke.gd
```

Observed engine: `4.5.1.stable.official.f62fdbde1`. The first test confirms the
existing R1E departure/persistence/settlement contracts; it does not prove a
normal-input siege victory. The second confirms battle presentation behavior;
it does not implement macro orders.

## Explicit stopping point

This delivery stops after documentation alignment, source review, independent
snapshot upload and the reproducibility checks possible in the current network
state. It does not start macro command development, shared-energy migration,
skill counts, off-road movement, escape, breach/occupation, multi-city victory,
UI redesign, merge or deployment.

`CLEAN_CLONE=FAIL_NETWORK_TRANSPORT`

`SIEGE_VICTORY_ACCEPTED=NO`

`DEPLOYMENT=NO`

# R1E Source Inventory — 2026-09-06

## Provenance

| Field | Value |
| --- | --- |
| Source path | `/Users/m4-zhi/Documents/codex-workspace/txwzs-city-governance-interaction-001` |
| Source branch | `codex/txwzs-expedition-visual-r1e` |
| Source head | `4c3e501c16d1a882b996a6a96b2473128312d12c` |
| R1E baseline | `147430ed1d4fe584abcb423755da4455e5d5f95c` |
| Source state at capture | clean tracked worktree; no configured remote |
| Capture method | exact copy of the source `git ls-files` set into an independent delivery root |
| Candidate branch | `codex/txwzs-review-20260906` |
| Candidate history | new root commit; it does not claim to preserve or rewrite source development history |

The source-to-R1E diff is limited to `CHANGELOG.md`, `CURRENT_STATE.md`, the
R1E reconciliation report, `scripts/ui/expedition_preparation_panel.gd`, and
`tests/run_r1e_expedition_causality_smoke.gd`. The source baseline is an
ancestor of the captured source head. This delivery retains the entire tracked
project set rather than filtering the project down to selected source files.

## Included project material

The independent snapshot retains `project.godot`, `export_presets.cfg`, all
tracked scenes, scripts, `.uid` files, resources, tests, source documentation,
run command and tracked R1E evidence. It intentionally excludes untracked
personal data and ignored/generated material: `.godot/`, `.import/`, export
credentials, build/app artifacts, import caches, OS noise and files ignored by
the source `.gitignore`.

`docs/engineering/EXTERNAL_INTELLIGENCE_REGISTRY.md` records the read-only
public reference sources, pins and licenses used for the current project. The
R1E implementation report states that no third-party code, installer, plugin,
framework or generated project material was introduced. The snapshot contains
no separately imported art dependency requiring a new public-source record.

## Content review

Before upload, the candidate is reviewed for credential-carrier filenames and
common secret-assignment patterns without printing secret values. A detected
ignored carrier or any untracked personal save is excluded rather than copied.
The final SHA-256 manifest is generated from the candidate's tracked files and
excludes only the manifest itself to avoid a self-referential checksum.

Capture review result: `0` credential-carrier filename hits and `0` common
secret-pattern filename hits in the candidate's tracked source set. This is an
exclusion/safety check, not a claim that arbitrary application code is secure.

The delivery verification document records the root snapshot commit, remote
branch, fresh-clone result and commands after upload. It is evidence of project
reproducibility only; it is not a siege-victory, Founder, visual, release or
deployment acceptance.

# TXWZS Master Plan Review 002

## Review scope

- Task: `PLAN-REPAIR-001`
- Repository: `/Users/m1-meng/Documents/Codex_workspace/godot-天下无战事2`
- Baseline: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Baseline relation: `origin/main..main = ahead 29, behind 0`
- Review target: planning workbook, Markdown mirror, five CSV mirrors, and the CSV ZIP package
- Runtime boundary: planning repair only; `V4-P5-T001` was not executed, V5 was not started, and no game implementation file was changed by this task

## Pre-repair findings

The pre-repair audit reproduced all twelve reported defects:

1. Only seven generic gates existed and gate IDs were not phase-specific.
2. All gates were `NOT_STARTED` while `V4-P5-T001` was marked `READY`.
3. P0 requirement `REQ-ARCH-001` had no registered test.
4. Usage metric `B22` cached `0` even though one P0 requirement lacked a test.
5. Eighteen test rows were orphan placeholders.
6. Requirement-to-test and test-to-requirement mappings were not consistently bidirectional.
7. None of the thirteen worksheets had frozen panes.
8. Roadmap CSV phase progress was blank.
9. Test CSV headers drifted from the workbook schema.
10. Review 001 did not bind the workbook SHA-256.
11. `V4-P5-T001` was ambiguously named as a review-and-freeze operation.
12. Workbook styles did not provide a reliable Chinese font.

Evidence: `/tmp/txwzs-plan-repair-001.302d9z/pre-repair-audit.json`.

## Round 1 independent review

- Reviewer: independent Codex task `/root/master_plan_review_final`
- Reviewed baseline: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Verdict: `BLOCKED`

### Findings and disposition

| Finding | Severity | Round 1 evidence | Disposition |
| --- | --- | --- | --- |
| `PLAN-FORM-001` | Critical, blocking | A cancelled task could be removed from the phase denominator by placing any `DEC-*` text in a review-record field; the formula did not bind a real accepted Decision. | Added dedicated `Decision Record ID` and `Progress Denominator Flag` columns. The flag now performs an exact lookup against `09_风险与决策`, requiring matching ID, `Type=Decision`, and `Status=ACCEPTED`. Negative tests cover empty ID, fake ID, Risk ID, and proposed Decision; only accepted `DEC-003` excludes a cancelled task. |
| `PLAN-MAP-001` | High, blocking | `REQ-ARCH-001` linked `V8-P2-T003`, but that task did not link back to `T-ARCH-OWNERSHIP-001`; other future tasks with no test IDs were not explicitly deferred. | Added `T-ARCH-OWNERSHIP-001` to both related tasks. Added `Test Mapping Status`; tasks without a current test are explicitly `DEFERRED_UNTIL_PRIOR_PHASE_VERIFIED`. Re-ran duplicate, dangling, orphan, and bidirectional mapping checks. |
| `PLAN-VIS-001` | Low, non-blocking | Wide sheets were structurally valid but full-sheet renders made body text small. | Retained all thirteen full-sheet renders and added eight 100% key-column crops in `/tmp/txwzs-plan-repair-001.302d9z/final-focused-100-r2`. |
| `PLAN-PKG-001` | Low, non-blocking | `.DS_Store` and generated inspect NDJSON were residual files in the planning directory. | Moved both residual files to the recoverable task backup under `/tmp/txwzs-plan-repair-001.302d9z/residue`; neither is part of the final package. |

## Round 2 initial independent review

- Reviewer: independent Codex task `/root/master_plan_review_001`
- Verdict: `REQUEST_CHANGES / PLAN-REPAIR-001_REVIEW_BLOCKED`

| Finding | Severity | Independent evidence | Disposition |
| --- | --- | --- | --- |
| `PLAN-PKG-002` | Critical, blocking | ZIP `tasks.csv` and `tests.csv` were older than their external CSV counterparts. | Rebuilt the ZIP from the five final external CSV files. The final audit performs byte-for-byte comparison for every ZIP member. |
| `PLAN-MIRROR-002` | High, blocking | XLSX had 87 cached denominator flags, but external `tasks.csv` left those values blank. | The CSV exporter now emits the calculated `0/1` denominator flag for every task. The final audit compares every cell of all five CSV tables against the corresponding XLSX cached values. |

The formula contract was also extended to cover the original bypass explicitly: an accepted Decision ID placed only in `Review Record ID`, with an empty `Decision Record ID`, must not remove a cancelled task from the denominator.

## Final planning contract

- Phase gates: 63 unique IDs, `V4-G0` through `V12-G6`.
- Gate status: `V4-G0=VERIFIED`; the remaining 62 gates are `NOT_STARTED`.
- Tasks: 87 total; V5 contains 44 tasks.
- Unique next task: `V4-P5-T001=READY`.
- `V4-P5-T001` is an independent V4 implementation review only. It does not submit or freeze V4, does not start V5, and does not modify S1A.2.
- Requirements: 23.
- Tests: 67, with no orphan, dangling, or duplicate IDs.
- Formulas: 136, including 87 task denominator flags; no formula errors.
- Phase progress: V4 through V12 all evaluate to `0%`.
- Frozen panes: 13 of 13 worksheets; task table freezes the first five columns and first four rows.
- Chinese font: `Hiragino Sans GB`.
- XLSX, Markdown, CSV, and ZIP are generated from one planning revision; five CSV schemas match the corresponding workbook tables.

## Final artifact hashes

These hashes bind the exact files presented to the final independent reviewer:

| Artifact | SHA-256 |
| --- | --- |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.xlsx` | `845fbd32da88d22a7e7a0a9d3cf64f3a3bdd65fccf5ca18588d8d14d8f2c437c` |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL.md` | `ebb5ddb22b93b7500f909358aaf9601ab9d6fc284c0ef7bbc2722a63086e03f8` |
| `docs/planning/csv/roadmap.csv` | `135a6127306ffefd240e662e0b36849ed97c5186d29c5c99d91c59a5acf16c9f` |
| `docs/planning/csv/tasks.csv` | `308a988f70f55649c4a714672a8c9496b951acfcb92379e1f10ecaf0640630e9` |
| `docs/planning/csv/acceptance_matrix.csv` | `d45e8b45f5bc402aa2a0ae93af81ea431aaa919f3ec1a1e21ddcd0c0134d0875` |
| `docs/planning/csv/tests.csv` | `88e7865c08be8949c30011e40d0131d350216b7468544693ac7f9cea0814b2a0` |
| `docs/planning/csv/risks_and_decisions.csv` | `0b54f738b61ec22abb0d9fbc44ab4c5735a7635b5ee311bcf1501d62c223a650` |
| `docs/planning/TXWZS_MASTER_DEVELOPMENT_CONTROL_CSV.zip` | `ad3440676ee10326e74e128ade99c22a9eb8618abbfc223a389322da8e9a5921` |

Manifest: `/tmp/txwzs-plan-repair-001.302d9z/final-sha256-r2.txt`.

## Verification evidence

- Structural and cross-file audit: `/tmp/txwzs-plan-repair-001.302d9z/final-audit-r2.json`
- Formula contract test: `/tmp/txwzs-plan-repair-001.302d9z/formula-contract-final-r2.json`
- Full-sheet renders: `/tmp/txwzs-plan-repair-001.302d9z/final-render-r2`
- Focused visual crops: `/tmp/txwzs-plan-repair-001.302d9z/final-focused-100-r2`
- Recoverable pre-repair backup: `/tmp/txwzs-plan-repair-001.302d9z`

## Round 2 independent review

- Reviewer identity: `/root/master_plan_review_fast`
- Mode: independent, read-only
- Reviewed baseline: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Reviewed manifest: `/tmp/txwzs-plan-repair-001.302d9z/final-sha256-r2.txt`

### Final findings disposition

| Finding | Severity | Blocking | Result |
| --- | --- | --- | --- |
| `PLAN-FORM-001` | Critical | Yes | Closed |
| `PLAN-MAP-001` | High | Yes | Closed |
| `PLAN-VIS-001` | Low | No | Closed |
| `PLAN-PKG-001` | Low | No | Closed |
| `PLAN-PKG-002` | Critical | Yes | Closed |
| `PLAN-MIRROR-002` | High | Yes | Closed |

The reviewer independently confirmed:

- all eight R2 artifact hashes;
- byte-for-byte identity between each ZIP member and its external CSV;
- cell-by-cell identity between all five CSV mirrors and their XLSX tables;
- all denominator formula negative cases, including an accepted Decision placed only in `Review Record ID`;
- zero orphan, dangling, duplicate, or bidirectional mapping defects;
- 63 gates, 87 tasks, 23 requirements, 67 tests, 136 formulas, and 13 of 13 frozen panes;
- one unique READY task, `V4-P5-T001`, while every V5 task remains `NOT_STARTED`;
- unchanged original V4 dirty patch and unchanged eight protected S1A.2 files.

### Re-review result

`ACCEPTED / ALL_PLAN_REPAIR_FINDINGS_CLOSED`

This accepts only the immutable R2 planning package. It does not execute `V4-P5-T001`, start V5, freeze or submit V4, or authorize changes to S1A.2.

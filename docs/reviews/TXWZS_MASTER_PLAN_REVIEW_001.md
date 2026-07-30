# TXWZS Master Plan Review 001

## Review Identity

- Review ID: `RVW-PLAN-001`
- Reviewer task: `/root/master_plan_review_fast`
- Reviewed baseline: `main@64f37bda130397f08cdd012609dc2d3a5f5c6b99`
- Reviewed plan revision: `0.1.0-draft`
- Reviewed assets: workbook, Markdown mirror, CSV mirrors, repository baseline evidence
- Review mode: independent planning and architecture review

## Review Limitations

The reviewer confirmed the Git baseline and inspected the planning assets, but did not independently rerun the complete Godot runner suite or perform a new line-by-line runtime-code audit. Existing runtime results therefore remain labeled `PASS_MAIN_AGENT`, not independently verified.

## Checks That Passed

- Repository identity, branch, HEAD, upstream, ahead/behind, dirty scope, and protected S1A.2 scope matched the planning baseline.
- The plan correctly recognized the existing `BattleSession`, current `UnitRole`, and read-only `WorldMapPresentationModel`.
- V5 contained the intended training, garrison, dispatch, result-writeback, save/reload, and migration work packages.
- The plan avoided introducing a second writable `CityState`.
- The second persistent city remained deferred to V9.
- Atomicity, idempotency, migration, and protected S1A.2 isolation were represented as gates.

## Findings

| ID | Severity | Blocking | Finding | Required correction |
| --- | --- | --- | --- | --- |
| PLAN-001 | HIGH | Yes | V5 required saved in-transit state while V6 appeared to introduce the persistent `ArmyState` collection, creating a model and migration contradiction. | V5 must establish the collection container, stable route/node IDs, and progress while allowing at most one active army; V6 only enables multiple active armies and complete theater restoration. |
| PLAN-002 | HIGH | Yes | The V4 rollback wording treated `64f37bd` and a `/tmp` patch as sufficient even though the dirty V4 implementation is not in that commit and `/tmp` is ephemeral. | Record the exact file manifest, patch/archive hashes, checked forward/reverse apply procedures, and use the later V4 freeze commit plus parent as the durable rollback point. |
| PLAN-003 | HIGH | Yes | Test references contained malformed or dangling IDs, and current PASS evidence did not always name a locatable command and evidence source. | Add a test registry CSV, normalize references, remove dangling future IDs, and bind current results to actual commands, evidence paths, and evidence identity. |
| PLAN-004 | MEDIUM | No | V7–V12 used task/test precision that exceeds available evidence. | Keep V7–V12 at work-package goal, gate, risk, and rollback level; create exact tests only when the prior phase is VERIFIED. |
| PLAN-005 | MEDIUM | No | Main-agent test evidence was presented as plain PASS despite no independent rerun in this review. | Label it `PASS_MAIN_AGENT` or equivalent and keep independent verification status separate. |
| PLAN-006 | MEDIUM | No | Role labels alone did not prove independence or bind a review to an exact patch/hash. | Record reviewer task identity, reviewed baseline/patch/hash, findings disposition, and re-review; prohibit implementer self-approval. |

## Main Agent Disposition

All six findings were accepted.

- `PLAN-001`: V5 now owns the persistent `ArmyState` collection container and stable route/node/progress fields; V6 only enables multiple active armies and full theater restoration.
- `PLAN-002`: V4 rollback now distinguishes the session backup from a durable rollback point and records checked restore/reverse procedures.
- `PLAN-003`: a `tests.csv` registry was added, references were normalized, current commands/evidence were made explicit, and planned far-future test IDs were removed.
- `PLAN-004`: V7–V12 retain work-package tasks but no longer manufacture exact test IDs before stage start.
- `PLAN-005`: current runtime and workbook results are labeled `PASS_MAIN_AGENT`.
- `PLAN-006`: review identity, reviewed baseline, findings, response, and re-review are bound in the workbook and this report.

## Re-review

- Reviewed revision: `0.1.0-review1`
- Mirror manifest: `/tmp/txwzs-plan-review1-mirror-manifest.sha256`
- Mirror manifest SHA-256: `c21c3b4e95d9026d48b26c8b799ffd8afc7ba48958ddb31ef43098d07a5e8503`
- Round 1 result: `REQUEST_CHANGES / V5_EXECUTION_BLOCKED`
- Round 1 residuals:
  - `PLAN-002`: one V4 implementation task retained obsolete “return to 64f37bd” rollback text.
  - `PLAN-004`: one far-future V8 test ID was still predeclared.
  - `PLAN-006`: the re-review identity had not yet been written back or bound to a revision manifest.
- Round 1 residual disposition:
  - The V4 rollback row now uses the checked three-file patch procedure and future freeze commit/parent.
  - The predeclared V8 test ID was removed; the requirement keeps only a future review gate description.
  - This report and workbook record now bind the reviewer task, baseline, mirror manifest, findings, responses, and re-review rounds.
- Round 2 result: `PLAN-001～PLAN-006 CLOSED`
- Manifest verification: all six mirror entries returned `OK`
- Independent Godot rerun: not performed; runtime evidence remains `PASS_MAIN_AGENT`
- Final verdict: `ACCEPTED / ALL_PLAN_FINDINGS_CLOSED`

This planning review no longer blocks V5 at the plan level. V5 still cannot start until V4 passes its independent code review, physical mouse gate, and atomic freeze.

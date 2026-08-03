# TXWZS V5-G3 Refreshed Full Regression And Traceability

## Verdict

`TXWZS2_V5_G3_REFRESHED_FULL_REGRESSION_AND_TRACEABILITY_ACCEPTED`

Validated source head:
`712dcbd8e092ff844c4274a2f3a3c260d29998e7`

This is a V5-G3 automated regression and traceability record. It is not a
real-window acceptance, independent review, user playtest, release, or V5
freeze.

## Isolated verification result

All commands ran from an exact `git archive` of the validated source head in a
repository-external temporary directory. Godot 4.5.1 used a sandboxed temporary
home, cache, log, and `user://`; Canonical source and real user data were not
written.

| Check | Result |
| --- | --- |
| P0-01 national read model | 10/10 pass |
| R2C-01 national resource convergence | pass |
| R2C-02 First War lifecycle | 20/20 structural checks pass |
| Dynamic runner discovery | 37/37 pass; 1819 emitted `PASS:` assertions |
| V5 persistence | 51/51 pass |
| Editor parse/import | exit 0; no parser or script error |
| blank_map / Blackstone / C0 / configured main | exit 0; no error signature |
| Canonical and isolated source fingerprints | unchanged |

`run_runtime_identity_smoke.gd` has no emitted per-assertion `PASS:` lines;
its exit code is zero and its own terminal success marker is
`RUNTIME_IDENTITY_SMOKE PASS`. The 1819 assertion-line total intentionally
remains the raw count emitted by runners.

## Authority and persistence conclusions

- `NationState` remains the single shared national-resource authority.
- `GarrisonState` remains the local garrison owner, and `ArmyRegistry` remains
  the sole Army collection owner within `ConstructionController`.
- `CombatTransactionCoordinator` is the terminal settlement authority;
  `BattleSession` produces facts only.
- R2C-02 First War survivors return only to `blackstone_city`; `riverbend_city`
  garrison, owner, faction, and local state remain unchanged.
- V5 schema version, storage version, codec/store/snapshot blobs, and snapshot
  topology are unchanged between `a0406ede` and `712dcbd8`.
- Persistent external theater, mid-operation restart, and full Riverbend local
  persistence are not implemented and are not claimed.

## Gate boundary

V5-P4-T005 and V5-P7-T001–T003 are `VERIFIED`. V5-P6, V5-P7-T004–T007,
V5-G4, V5-G5, V5-G6, R2C-03, and V6 remain `NOT_STARTED`.

The complete command logs, source fingerprint comparison, authority inventory,
and task-to-test matrices are in the external G3 evidence package created for
this acceptance. A later G4 authorization must perform a genuine real-window
check; this report cannot substitute for it.

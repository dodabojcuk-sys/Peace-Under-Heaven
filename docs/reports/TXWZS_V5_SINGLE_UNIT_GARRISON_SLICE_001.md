# TXWZS V5 Single-Unit Garrison Slice 001

## Status

`V5_P0_P1_SINGLE_UNIT_GARRISON_IMPLEMENTED_PENDING_PACKAGE_REVIEW`

This is the first substantive V5 slice after the frozen V4 checkpoint
`5357c28`. It completes the planned V5 P0 baseline/contracts and P1
single-unit/garrison implementation as one runnable, player-visible package.

It is not marked `VERIFIED`: the V5 P0/P1 package review remains a separate
gate. Only G0 can receive a full verdict from this slice; G1/G2 remain partial
until their later-phase requirements are implemented. No Review 003 or
additional V4 review was created.

## Player-visible result

The expanded city sidebar now displays:

```text
驻军 20 · 可派 20/50
科技 0
```

“驻军” is the authoritative city total. “可派” simultaneously reflects active
battle reservation, recruitment capacity, and the selected general's command
limit. A fresh 1152×648 formal-scene capture is stored at:

`/tmp/txwzs-v5-single-unit-garrison.20260730/v5-garrison-city-bar.png`

The visual inspection found no overlap, clipping, or loss of existing recruit,
general, tech, threat, and construction controls.

## P0 contract result

`docs/architecture/V5_SINGLE_UNIT_WAR_FOUNDATION_CONTRACT_V0.md` records:

- V4 checkpoint and protected S1A.2 baseline;
- the city—garrison—training—reservation—battle—result ownership table;
- stable single-unit ID and query boundary;
- garrison conservation and failure paths;
- the temporary food/capacity manpower rule without fabricating population;
- rollback and stop conditions.

The current city runtime authority remains `ConstructionController`.
`BattleSession` still owns only a battle instance, and result writeback still
uses the bound coordinator/city path.

## P1 implementation result

- Added private `GarrisonState` as the Blackstone city garrison count source.
- Preserved `infantry_count` as a compatibility property rather than a second
  storage field, so existing C0, P1, S1A.1, checkpoint, training, mobilization,
  and result paths all reach the same source.
- Reused the existing `UnitRole` resource and stable ID
  `unit_role.infantry_basic`; no second unit or duplicate battle values.
- Added unit-definition and garrison read APIs.
- Added a dispatchable count that applies total, reservation, recruitment
  capacity, and command limit together.
- Added the garrison read model to `get_city_state()`.
- Added a deterministic V5 runner covering definition identity, deep-copy
  isolation, negative/over-cap/over-removal failure atomicity, reservation,
  release, command cap, UI projection, training completion, and compatibility.

## Verification

| Check | Result |
| --- | --- |
| V5 single-unit garrison runner | exit 0; 25 explicit assertions + 1 summary |
| All-present runners | 30/30 exit 0; 1740 PASS lines |
| Formal main scene headless | exit 0 |
| Formal Blackstone scene headless | exit 0 |
| Final Godot headless editor scan | exit 0 |
| `git diff --check` | exit 0; empty output |
| Error signature scan over all runner logs | 0 matches |
| Fresh 1152×648 city-sidebar capture | PASS |

Final evidence:
`/tmp/txwzs-v5-single-unit-garrison.20260730/final`.

## Protected boundary

The eight S1A.2 files remain untracked, unstaged, and unmodified. The all-present
runner observation does not accept them or authorize a V5 save schema. V5 P5
must independently decide whether S1A.2 can be reused.

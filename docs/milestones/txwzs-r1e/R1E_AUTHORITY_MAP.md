# R1E Authority Map

## Purpose

R1E connects one city decision to one battle attempt without introducing a
parallel resource ledger, roster, battle result writer, or save owner.

## Existing authorities

| Domain | Authority | R1E rule |
| --- | --- | --- |
| Wood, food, tech points | `NationState` | Expedition food is spent only through `commit_resource_transaction()`. |
| Permanent city force | `GarrisonState` | Upgrade the aggregate infantry state into the sole three-formation roster; aggregate counts remain derived compatibility views. |
| Current mainline | `CurrentMainlineLevel` | Reuse its deadline, pressure, and clear state. |
| Active battle transaction | `ConstructionController` reservation lifecycle | Replace the transient reservation payload with one durable expedition-attempt snapshot; do not add a second attempt registry. |
| Runtime battle facts | `BattleSession` | Preserve deterministic movement, damage, and outcome rules; add formation identity only to result facts. |
| Settlement authorization | `CombatTransactionCoordinator` | Continue authorizing the one terminal result produced by its bound session. |
| Applied settlement ledger | `ConstructionController` committed-result and closed-transaction maps | Keep the existing result/transaction IDs as the cold-start idempotency authority. |
| Campaign persistence | `V5CampaignSnapshot`, save codec/store, and runtime persistence coordinator | Advance the domain schema from V5 to V6; keep the storage envelope version unchanged. |
| City/battle presentation transition | `ConstructionController` and `C0BattleGraybox` return contract | Battle consumes the exact saved attempt and returns through the existing guarded contract. |

## R1E transaction boundary

1. Validate the mainline and a selection of one to three stable formations.
2. Re-read each selected formation count and calculate the existing
   `ceil(committed soldiers / maintenance_units_per_food)` cost.
3. Build a detached attempt snapshot and matching committed-force snapshot.
4. Atomically install the attempt and spend food through `NationState`.
5. Synchronously publish and re-read the campaign generation.
6. On save failure, restore food, attempt, reservation, and sequence before
   allowing another action; never enter battle.
7. Give the battle scene the exact saved request. Scene reloads rebuild from
   that same attempt and do not charge food again.
8. The terminal result reports survivors per stable formation.
9. The existing settlement ledger applies one authorized result, updates only
   selected formations, and then clears the active reservation.

## Migration boundary

V5 aggregate infantry deterministically seeds three stable formations using
the same split previously used by `CommittedForceSnapshot` (20 becomes
7/7/6). V2-V4 migrations still preserve their existing fields and then pass
through the V5-to-V6 step. Zero-member formations remain present so saved
references never disappear.

## Explicit non-authorities

- `ArmyRegistry` remains the lifecycle owner for dispatched strategic armies;
  it is not the permanent formation roster.
- `BattlePresentationModel`, UI panels, and screenshots are read models only.
- The legacy Blackstone MVP dictionaries are not used by the R1E path.
- The expedition preparation panel owns only temporary selection state.

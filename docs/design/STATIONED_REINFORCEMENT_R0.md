# Stationed Reinforcement R0

## Scope

Silverford has one authored pool of four local infantry after the player
occupies it. The pool is not production, a training queue, an enemy defender,
or a second garrison roster. It is consumed only by a player army that has
actually arrived and is `STATIONED` at Silverford.

## Ownership and transaction boundary

- `FieldTacticsState` owns the persisted remaining local pool.
- `ArmyRegistry` owns formation member counts and the army aggregate.
- `ConstructionController` previews, revalidates, applies both changes, and
  publishes the normal V5 checkpoint. A checkpoint failure restores the Field
  and ArmyRegistry snapshots together.
- Macro March only reads the authority projection. Its location panel never
  maintains another soldier ledger.

The allocation order is ascending `formation_id`. The same preview is checked
again at commit, so stock or capacity changes cannot alter the destination of a
recruit between display and submission. Replenishment has no food price and
does not create an order, move an army, or change its order history.

## Compatibility and limits

Fresh theatres seed `initial_stationed_reinforcements = 4` from the playable
theatre Resource. The authored amount is deliberately a small, adjustable
playtest configuration; persisted state accepts only the R0 Silverford identity
and a finite non-negative integer. Older Field snapshots without the new
inventory restore an empty pool and do not receive four recruits on load.

R0 deliberately excludes automatic production, population, recruitment
buildings, remote transfers, transport escorts, new unit types, training time,
and food cost.

## Known follow-up

The supply R0 repair rollback keeps a compatibility fallback for older repair
projects that lack `repair_initial_durability`. New repair projects preserve
the original durability explicitly; old interrupted projects can only restore
their recorded current durability. This remains a compatibility TODO and is
not changed by local reinforcement.

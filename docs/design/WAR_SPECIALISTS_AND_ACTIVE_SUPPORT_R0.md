# War Specialists and Active Official Support R0

## Purpose

This R0 gives the player meaningful commands after a war begins without adding
a second army, combat, resource, clock, or save owner. It extends the existing
field-specialist records and `BattleSession` command stream.

## Field specialist coverage

| Role | Formal acquisition and target | Authoritative result | R0 limits |
| --- | --- | --- | --- |
| Engineer | Existing map engineering and repair entries | Existing road/facility projects | Unchanged in this slice |
| Scout | Existing direct dispatch and point targeting | Existing fog/intel facts | Unchanged in this slice |
| Medic | War-specialist menu, then a wounded living siege army | Repairs partial HP only below the current survivor ceiling | Does not restore fallen members or replace city treatment |
| Saboteur | War-specialist menu, then a discovered hostile facility | Reduces that facility's persisted durability | Cannot target fog-hidden, friendly, destroyed, or handed-off battle facts |
| Thief | War-specialist menu, then a scouted enemy city with finite supply | Debits real enemy stock, carries it home, then credits national food | No intel/capacity/stock means no task; returned cargo waits if capacity changed in transit; there is no generated loot |
| Sniper | War-specialist menu, then a visible live patrol | Reduces that patrol's real strength and records exposure | Cannot target fog-hidden or battle-handed-off enemies |

Dispatch costs, action costs, work durations and effect amounts are centralized
in `ConstructionController`. The action plan uses the existing specialist land
path, world clock and V5 checkpoint. Dispatch allocates one person through the
aggregate population authority. Action publication spends food through
`NationState`; a failed checkpoint restores the field action and resource
transaction together.

An enemy lookout authored by the playable Blackstone theatre provides one real
sabotage target. It remains hidden until an existing player observer discovers
it and is a durable field facility, not a presentation-only prop.

## Active official support

The appointed physician can issue one immediate heal to a selected surviving
squad. The strategist can issue temporary movement, attack, protection, or
route-domain support. Each command costs one point from the existing shared
campaign-energy balance. Scene entry, battle entry and restore never replenish
that balance.

The immutable battle request remains unchanged. Accepted commands, receipts,
effect scope and expiry tick live in `BattleSession`; the city strategy state
continues to own the account-wide energy. `ConstructionController` checkpoints
both in one transaction and restores both snapshots if persistence fails.

Effects expire on battle ticks and are consumed by the existing authoritative
movement and damage calculations. Healing cannot cross the current survivor
count, and the presentation does not invent a continuous health-drain model.

## Cross-layer handoff rules

- A field target already handed to a wartime instance is not a valid specialist
  damage target.
- Completed field effects are already part of the source facts; battle entry
  does not replay them.
- A specialist with an active action cannot simultaneously receive an ordinary
  movement order or engineering project.
- UI menus and markers only project these states; they do not own or advance
  specialist actions or support effects.

## Verification boundary

Focused domain checks cover all four new specialist results, scout-gated theft,
returned cargo waiting for capacity, no-resurrection medical behavior, all five
active-support mechanisms, expiry, shared-energy debit and checkpoint-failure
rollback. A three-process V5 chain covers a specialist in transit, completed
sabotage without replay, and an active battle support command with its energy
balance. The graphical smoke uses visible menu actions and map GUI input; it is
engine-GUI evidence, not native-pointer player acceptance.

Human balance, usability and player-feel acceptance remain `OPEN`.

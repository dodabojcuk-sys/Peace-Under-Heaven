# Blackstone City Strategy R0

This document records rules newly selected for the first implementation on
2026-09-12. They are adjustable development parameters, not claims about older
confirmed design history.

## Officials and campaign energy

Blackstone begins a fresh campaign with three deterministic retainers: a
steward, physician and strategist. One may be appointed at a time. Their active
support costs one of three campaign-energy points and cannot stack. Production
and medical support last one city day; defense support is frozen into a battle
request created while it is active. Energy resets only when the whole campaign
is restarted, never on scene entry, C0 entry or restore.

## Equipment

Troop equipment is shared by the infantry role rather than instantiated for
every soldier. The first three pieces provide attack, protection and mobility
choices. General equipment uses six stable slots: weapon, helmet, armor,
gloves, boots and accessory. R0 authors one weapon, armor and boots choice and
leaves the other slots empty instead of filling them with duplicate items.
Items are deterministically crafted from existing resources, have a single
identity, and cannot be equipped before ownership. Equip and unequip operations
share the same checkpoint boundary and never consume the owned item. The loadout
is read when a formal order or battle request freezes its force facts; an active
field army cannot be retroactively changed by the city screen.

## Player entry

The existing city-governance surface has one `Strategic Support` entry. It
opens a separate scrollable detail workspace rather than adding permanent
controls to the crowded city summary. Visible controls cover appointment,
support activation, deterministic crafting, troop/general loadout and authored
trade. The workspace is a city-management surface and is never reused as a
wartime-inner-city authority.

## Trade

The city exposes two authored, once-per-day exchanges: 10 wood for 5 food and
5 food for 8 wood. Both use the national resource transaction, capacity checks
and a unique receipt. The reverse prices deliberately prevent a zero-cost
cycle. Trade does not create caravans, production or a world market.

## Persistence boundary

`CityStrategyState` owns only unlock/appointment, campaign energy, timed support,
equipment ownership/loadout and trade receipts. `NationState` remains the only
resource writer; combat and field movement continue to consume frozen facts.
Legacy saves receive an empty strategy record rather than unearned officials,
items, energy or receipts. A fresh campaign receives the authored starting set.

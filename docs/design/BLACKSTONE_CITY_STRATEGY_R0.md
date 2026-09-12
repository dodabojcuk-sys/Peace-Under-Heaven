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

## Equipment and growth

Troop equipment is shared by the infantry role rather than instantiated for
every soldier. The first three pieces provide attack, protection and mobility
choices. General equipment uses six stable slots: weapon, helmet, armor,
gloves, boots and accessory. The first complete set is an iron sword, scout
helmet, lamellar, leather gloves, riding boots and command talisman. A bronze
sword remains as a second weapon for a real same-slot inheritance path.
Items are deterministically crafted from existing resources, have a single
identity, and cannot be equipped before ownership. Equip and unequip operations
share the same checkpoint boundary and never consume the owned item. The loadout
is read when a formal order or battle request freezes its force facts; an active
field army cannot be retroactively changed by the city screen.

The following are adjustable R0 development rules selected on 2026-09-12:

- general equipment stores a stable item id, quality and cumulative experience;
  level is derived as `1 + experience / 100`, capped by quality;
- `COMMON`, `FINE` and `ELITE` cap displayed/effective level at 3, 5 and 8;
- training costs 4 wood and grants 100 experience without random failure;
- rank-up is available at the current cap, costs 10 then 18 wood, raises the
  cap and retains all cumulative experience;
- inheritance is same-slot only, consumes an unassigned source, and transfers
  its cumulative experience plus its base-level value in one transaction;
  experience above the target's current cap is retained;
- troop-standard equipment remains a shared formation kit; only uniquely
  owned general equipment uses this growth model.
- each new macro order freezes its equipment identities and effective combat
  values. Active orders retain those item references for inheritance, and a
  later siege takeover uses the frozen values instead of the current city
  loadout.

Each effective level contributes five percentage points to an authored attack,
defense or mobility effect. The command talisman contributes to attack and
defense. Published march and battle facts remain frozen after later training.

## Player entry

The existing city-governance surface has one `Strategic Support` entry. It
opens a separate scrollable detail workspace rather than adding permanent
controls to the crowded city summary. Visible controls cover appointment,
support activation, deterministic crafting, troop/general loadout and authored
trade. The workspace is a city-management surface and is never reused as a
wartime-inner-city authority.

Manufacturing and equipping are separate visible states. The workspace names
the selected general, lists all six slots, and shows quality, effective level,
cap, cumulative experience, current effect and deterministic costs. Inheritance
copy explicitly says the source will disappear. Support copy distinguishes an
action result from a currently active effect and its remaining day boundary.

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

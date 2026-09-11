# Blackstone First Campaign R0

## Player goal

Blackstone clears only when the player holds both required eastern cities:
Redcliff and Silverford. The battle map presents their live controllers and a
`held / required` counter directly from `WarLoopState`; it has no separate
campaign-progress record.

## Optional preparation

The northern road remains a valid direct attack route. Scouting, engineering a
road and field camp, building a watchtower, reinforcing a stationed army at
occupied Silverford, and returning Silverford's finite food are tactical
options. None is an additional victory flag or a mandatory tutorial step.

The authored engineering demonstration is:

1. Dispatch an engineer and construct a road to a new field camp.
2. Connect that camp to Forest Watch, then build one watchtower from the camp.
3. Use the tower's normal observer range to see a real patrol, station an army,
   and capture Silverford.
4. Use the existing Silverford detail actions to reinforce that exact stationed
   army and send the finite 20 food through the live road network.
5. Continue the same army to Redcliff and clear the two-city objective.

## Authority and settlement

- `WarLoopState` owns city control and the two-required-city clear rule.
- `FieldTacticsState` owns roads, camps, towers, visibility, finite local
  reinforcement, and supply transports.
- `ArmyRegistry` owns armies, formations, casualties, and orders.
- `ConstructionController` owns world time, resource transactions, V5
  checkpoint publication, and rollback.

The map consumes those read models. It may display objective progress and the
two-city result, but it does not settle victory, credit food, add troops, or
persist a new campaign state.

## Verification boundary

The campaign smoke drives formal Macro March map input and visible connected
actions. Its graphical counterpart advances the normal Controller process over
engine frames; it records any fixture acceleration separately. Synthetic Godot
GUI events and connected Button signals are engine evidence, not native macOS
mouse evidence. Cross-process transport and tower persistence remain covered by
their dedicated A/B/C worker suites.

# Blackstone First Campaign R0

## Milestone contract

The first playable campaign is a normal-game sequence, not a collection of
independent battle launchers:

1. Blackstone receives a source-aware warning while the hostile force still
   exists at Redcliff.
2. The same hostile record departs, follows the authored Redcliff -> Northwatch
   -> Blackstone road, and may be observed or intercepted under existing field
   fog and encounter rules.
3. If it reaches Blackstone, its actual surviving strength is frozen into the
   existing wartime-defense transaction. The field record becomes handed off
   and stops simulating, so no participant can be damaged twice.
4. The defense result returns to Blackstone's existing campaign state. The
   main city may take the already-authored damage and loss consequences, but is
   not permanently transferred to an enemy controller.
5. Surviving armies and persistent field works remain available for recovery
   and the existing Redcliff counterattack, siege, C0 takeover and occupation.

This milestone deliberately adds configured first-level facts instead of a
generic campaign-event framework. `MacroMarchTheaterDefinition` owns the
warning day, departure day, identity, source, target, route and initial force.
`FieldTacticsState` owns the one-shot hostile participant and its movement;
`ConstructionController` owns day activation, defense transaction handoff and
V5 publication.

### Authored first-pass parameters

| Fact | R0 value | Adjustment boundary |
| --- | --- | --- |
| Warning | start of day 4 | Known source, target and broad approach only |
| Departure | start of day 5 | Exactly one persisted activation |
| Force | Redcliff Vanguard, 16 members | Exact count requires live observation |
| Route | Redcliff -> Northwatch -> Blackstone | Existing reversible road graph |
| Arrival | Blackstone city point | Creates one pending defense handoff |

The warning-to-departure window is one full city day; travel adds a visible
field interval. These are development parameters, not final balance.

## Acceptance criteria

- Closing or reopening the map does not duplicate the invasion or restart its
  warning/departure clock.
- A destroyed invasion never creates a defense. A damaged invasion creates a
  defense with that exact remaining member count.
- Hidden enemies expose no exact strength. A campaign warning may identify the
  known threat, source, target and expected route without bypassing fog.
- Entering C0 transfers simulation ownership once. The field force is no
  longer mobile or encounterable until the defense result is applied.
- Saving before departure, during movement, at pending handoff, in battle and
  at result-pending restores the same IDs and quantities without another
  resource grant or preparation window.
- Persistent field facilities and roads remain field facts. C0 facilities
  remain battle-session facts even when their Chinese display names overlap.

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

Automated engine input, isolated saves and screenshots are implementation
evidence. Player-experience acceptance remains OPEN until a person completes
the unaccelerated normal-game journey.

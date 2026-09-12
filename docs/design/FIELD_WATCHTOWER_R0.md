# Field Watchtower R0

## Purpose

Watchtower R0 turns a completed, connected engineering camp into a limited preparation decision: spend food and engineer time to reveal actual patrols earlier. It is deliberately not a city construction, production, combat, or upgrade system.

## Authorship and configuration

`MacroMarchTheaterDefinition.watchtower_config` owns the reversible theatre defaults: a 150-unit build radius, 360-unit completed visibility range, 6 food, 6000 milliseconds of construction, and a connected-camp requirement. The playable Blackstone Resource authors the same values.

A Field watchtower requires a player engineering camp whose referenced physical road is open. It must occupy in-bounds, non-water land, cannot overlap its camp, a completed tower, or another non-complete tower reservation, and requires an actual land path for its selected engineer. Each camp owns at most one completed or non-complete tower project. An interrupted project remains the camp's project and must be resumed or otherwise resolved; starting a replacement cannot silently duplicate it.

## Runtime contract

`FieldTacticsState` owns camps, watchtower projects and completed towers. `ConstructionController` owns the food transaction, world-time advance and V5 checkpoint/rollback boundary. `MacroMarchR0` only asks for read-only previews and renders returned state. The low-poly layer consumes the same projection; it does not create strategic objects or visibility.

Selecting an idle engineer exposes `工程师建瞭望塔`. The player picks a completed engineering camp, then an eligible nearby land point. The preview shows travel, construction time, food and the new observation radius. `开工建瞭望塔` is the single commit action. Preview, invalid clicks and cancellation write neither food nor Field state.

The engineer first follows its actual land route, then builds at the saved world point. A lost engineer interrupts both `TRAVELING` and `BUILDING` work; an unfinished project supplies no observer. Completion creates the persisted tower and refreshes existing fog facts. Completion remains provisional until time-aware patrol contact for the same world step resolves: a pre-completion contact removes the tower, observer and completion event, whereas a post-completion contact preserves the completed tower. The observer reveals only patrols in range; when they leave, the normal Field intel transition keeps prior knowledge as historical (`OBSERVED`) rather than exposing their current position.

## Persistence and rollback

New Field snapshots contain `watchtowers_by_id` and `next_watchtower_sequence`. The previously supported 11-field base, 14-field supply and 15-field stationed-reinforcement Field formats all restore through the formal V5 path with no new towers. New snapshots strictly validate canonical tower IDs, sequence high-water marks, known camps, concrete `Vector2i` anchors, positive integer ranges and complete state; a completed tower must match its completed project reservation's camp, anchor and range. Malformed data is rejected before current Field state changes.

Starting a project spends food through the existing NationState transaction, creates the Field project, and publishes the existing V5 checkpoint. A failed checkpoint restores both the Field snapshot and food. Project completion uses the existing Field completion checkpoint, so a save failure never leaves a durable tower visible without corresponding project state.

## Verification boundaries

Focused smoke coverage proves a formally completed road project's runtime camp is an eligible anchor, legal travel/build/visibility, duplicate and land/range/road rejection, interruption, pre/post-completion contact order, completion checkpoint rollback/retry, all earlier Field layouts through formal V5 restore, and strict malformed snapshot rejection. Independent Godot processes cover travel, completion and completed-tower reopen without duplication. The graphical contract uses map press/release to select the engineer, camp and placement; it records invalid re-placement, a re-enabled legal plan and completion as a continuous Godot Movie Maker sequence. The visible side-panel button remains explicitly labelled as a connected-action signal because the SceneTree runner cannot provide a macOS native button click. Its completed camp is a Field fixture; the separate focused smoke proves the road-project-to-camp boundary.

## Deferred

No attacks, tower upgrades, automatic production, new city build menu, tower garrison, or visibility beyond the existing patrol-intel rules is included.

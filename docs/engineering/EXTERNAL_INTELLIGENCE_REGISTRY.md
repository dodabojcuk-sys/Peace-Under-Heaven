# External Intelligence Registry

## Scope and precedence

This registry records read-only references used by `TXWZS M1A.1 LIVE CLOSURE +
DEVELOPMENT INTELLIGENCE R0`. It does not import source, dependencies, scripts,
or generated output. The project is pinned to Godot `4.5.1`; its code, tests,
and the official Godot 4.5 documentation take precedence over every external
example.

| Source | Pin and license | Files actually read | Adopted for this task | Rejected or constrained |
| --- | --- | --- | --- | --- |
| [GodotPrompter](https://github.com/jame581/GodotPrompter) | `eae755a1f3719076d52f50ab76f21993ebb9682b`, MIT | `skills/godot-testing/SKILL.md`; `skills/input-handling/SKILL.md`; `skills/responsive-ui/SKILL.md` | Keep focused assertions separate from live input evidence; verify input is consumed by native controls before map handling; use the existing 1152x648, 1280x720, and 1440x900 geometry checks. | No GUT/gdUnit4 dependency, synthetic `InputEvent`, fixture, debug shortcut, or 4.7-only API is introduced. |
| [Awesome Gamedev Agent Skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) | `7110607ab816ece9669274bc84937857a8819796`, Apache-2.0 | `skills/disciplines/game-ui-ux/SKILL.md`; `skills/disciplines/game-feel/SKILL.md` | Treat layout as anchors plus containers, retain readable text and event-driven feedback, and inspect interaction feedback during the live flow. | No absolute-coordinate patch, UI rewrite, new feedback mechanic, or 4.7 snippet is copied into product code. |
| [gstack-game](https://github.com/fagemx/gstack-game) | `7259ab9782fa9c17e45c16f1fb8347823ddb4379`, MIT | `skills/game-visual-qa/SKILL.md`; `skills/playtest/SKILL.md` | Use the visual-QA checklist for every captured image and the playtest framework only to order the observable player journey and record its first blocker. | Its generated preamble, telemetry, build scripts, player-data protocol, and any scripts are not run. It does not authorize a simulated playtest or replace a real player-flow capture. |
| [Godot Engine official 4.5 documentation](https://docs.godotengine.org/en/4.5/) | Godot Docs 4.5, CC BY 3.0 | `tutorials/ui/gui_containers.html`; `tutorials/rendering/multiple_resolutions.html`; `classes/class_control.html`; `getting_started/step_by_step/signals.html` | Use `VBoxContainer`/size flags/minimums for recovered panel layout; check `Control` input capture and size bounds; retain signal-based UI updates and resize-safe controls. | This is the technical authority. External 4.7 examples that conflict with it are not adopted. |

## Applied evidence policy

- L1 logic is the existing headless focused and full regression runners.
- L2 visual is the three target resolutions, geometric rectangle assertions, and
  manual image review for clipping, overlap, containment, click-through, and
  obvious world interpenetration.
- L3 milestone is one uninterrupted OS-level input recording of the player flow.
  It is required for gameplay milestones and merge candidates, not by default for
  an ordinary local repair.

The live recording must be labelled with its actual input provenance. Test
helpers, fixtures, state injection, signal injection, and frame-sequence video
are L1/L2 tools only and cannot satisfy L3.

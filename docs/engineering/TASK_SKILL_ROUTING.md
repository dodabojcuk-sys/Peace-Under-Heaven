# Task Skill Routing

## Rule

Before a game task starts, select at most four relevant skills or reference
frameworks. Select by the failure surface, not by a generic tool list. The
project Godot version and official Godot documentation override external
examples.

| Task signal | Select first | Required verification |
| --- | --- | --- |
| Native mouse, keyboard, input routing, click-through | Godot input handling | Native control receives the event; the map/game route does not receive an accepted UI click. |
| Responsive HUD, panel overflow, recovered Control state | Godot responsive UI plus official 4.5 Containers/Control docs | Target-resolution geometry assertions and manual native-image review. |
| State ownership, idempotency, save/cold restart | Godot testing plus project save contract | Focused behavior test, regression, and separate cold-process proof. |
| Visual milestone closure | gstack-game visual QA plus game UI/UX | Every image inspected for clipping, overlap, containment, contrast, state feedback, and world interpenetration. |
| Player-journey milestone | gstack-game playtest framework | One ordered, continuous, OS-level input recording. Record the first blocker; do not turn a test simulation into player proof. |
| Feedback readability only | game-feel | Inspect feedback visibility and return-to-rest only. Do not alter mechanics unless the task authorizes it. |

## Evidence gates

| Gate | Purpose | Default requirement |
| --- | --- | --- |
| L1 logic | Deterministic behavior and ownership | Every code/state task. |
| L2 visual | Responsive geometry and visual defects | UI or visual tasks. |
| L3 milestone | Actual player journey over native OS input | Gameplay milestone and merge candidate only. Ordinary local fixes do not automatically require L3. |

## Guardrails

- Never use more than four skills for one task unless the task is split.
- Record the source, commit, license, read files, and adoption/rejection in
  `EXTERNAL_INTELLIGENCE_REGISTRY.md` whenever external material is used.
- Do not run installer, build, postinstall, or telemetry scripts from an
  external skill repository.
- Do not replace a project-supported Godot 4.5.1 API with a newer example.
- L1 and L2 evidence never substitutes for L3 when L3 is explicitly required.

# Blackstone specialist-selection overlay verification

## Scope

This evidence covers only the 2026-09-09 low-poly specialist-selection overlay:
authoritative specialist position, map/side-panel agreement, same-gate input
cycling, cancellation, and graphical evidence. It does not certify normal
desktop-system-input recording or player acceptance.

## GUI-event and viewport proof

All PNGs were produced by a non-headless Godot 4.5.1 Metal process at 1152x648
from an isolated temporary V5 save directory. The capture script dispatched an
idle scout and engineer as fixture setup, then used `InputEventMouseButton`
through `MacroMarchR0._on_gui_input` at the Blackstone gate:

1. first left click selected the engineer;
2. second left click selected the scout;
3. right click cleared the specialist selection.

The role order is a stable ID ordering detail. The interaction contract is that
both living specialists and the army beneath them are reachable by successive
normal map clicks; it does not promise a role-specific first click.

| State | Full candidate viewport | Low-poly viewport | Expected visible result |
| --- | --- | --- | --- |
| Engineer selected | `01-engineer-selected-full-engine-viewport.png` | `01-engineer-selected-low-poly-engine-viewport.png` | Orange hollow ring and `已选·工程师·待命`; side panel names engineer and real status. |
| Scout selected | `02-scout-selected-full-engine-viewport.png` | `02-scout-selected-low-poly-engine-viewport.png` | Blue hollow ring and `已选·侦察兵·待命`; side panel names scout and real status. |
| Selection cleared | `03-specialist-selection-cleared-full-engine-viewport.png` | — | Prior specialist ring/role label is absent and no command was issued. |

These are engine-viewport captures driven by GUI event objects. They are not
claimed as human desktop input or video proof.

## Automated check

```text
Godot 4.5.1 Metal
tests/run_macro_march_low_poly_graphical_smoke.gd
MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=14
```

The added assertion uses GUI mouse events to select a moving army plus both
same-gate specialist roles. It checks side-panel role/status text, selection
cleanup, compact 3D markers, and whole-viewport image deltas: army 529,
scout 2222, engineer 983, cancellation 2624 changed pixels in the fixed
selection regions. No `SelectionRing` mesh is only a supplementary regression
check; it is not treated as selection proof.

## Remaining boundary

The current desktop accessibility surface does not expose this custom map
canvas as normal OS-accessible controls. Normal system-input video therefore
remains an explicit media gap. Player acceptance is **OPEN**.

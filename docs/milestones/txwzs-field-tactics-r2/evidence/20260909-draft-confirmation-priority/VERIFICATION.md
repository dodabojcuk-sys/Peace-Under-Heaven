# Draft-confirmation priority verification

## Scope

This checkpoint fixes a view-priority regression only.  It keeps the current
specialist selection overlays, truthful field task state, ArmyRegistry order
ownership, ConstructionController world clock, and runtime persistence model.

An active engineering action or accepted engineering draft now owns the side
panel.  An explicit city-formation click clears only the conflicting view
selection and starts city-command drafting; it does not cancel or mutate the
specialist's authoritative task or location.

## GUI-event contracts

The non-headless graphical runner validates two complete input chains:

1. Select an engineer through the map GUI event, enter engineering mode,
   choose the source, draw and release a route.  The construction plan's
   `确认施工` control is in the scene tree, visible and enabled.  One mouse
   press/release on the actual control creates exactly one project and deducts
   exactly the authoritative preview cost.
2. Select a scout through the map GUI event, use an enabled city formation
   button, then draw and release a march route.  Specialist view selection is
   cleared, `确认并锁定军令` is visible and enabled, and one actual control
   click creates exactly one army and one food transaction.

The graphical runner clears only `campaign_*` generations in the supplied
temporary save directory between independent contracts.  This makes the UI
fixtures deterministic without touching a player save or campaign authority.

## Candidate viewport evidence

These are Godot engine-viewport screenshots driven by GUI events, not normal
desktop-system-input recordings.

- `01-engineering-draft-confirm-visible-engine-viewport.png` — selected
  engineer remains visibly marked while the construction plan and enabled
  confirmation control retain the side panel.
- `02-march-draft-confirm-visible-engine-viewport.png` — selecting a city
  formation removes the conflicting specialist selection and shows the route
  plan plus enabled march confirmation control.

## Commands and results

Godot: `/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`

```text
Godot --path . --script res://tests/run_macro_march_low_poly_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=<temporary directory>
MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=15

Godot --headless --path . --script res://tests/run_macro_march_r0_smoke.gd \
  -- --txwzs-v5-save-dir=<temporary directory>
MACRO_MARCH_R0_SMOKE PASS assertions=30

Godot --headless --path . --script res://tests/run_field_tactics_r2_smoke.gd \
  -- --txwzs-v5-save-dir=<temporary directory>
FIELD_TACTICS_R2_SMOKE PASS assertions=69
```

Player acceptance remains **OPEN**.  Normal desktop-system-input recording is
outside this checkpoint and remains a separately labelled media gap.

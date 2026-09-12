# Low-poly projection and interaction evidence

Candidate source commit: `ba7016b35a83c90f3e3ffaa2c180c1f31ef65286`.

## Reproducible graphical check

The graphical check deliberately runs without `--headless`:

```sh
/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot \
  --path /Users/m4-zhi/Documents/codex-workspace/txwzs-field-tactics-r2 \
  --user-data-dir <isolated-user-data-dir> \
  --script res://tests/run_macro_march_low_poly_graphical_smoke.gd \
  -- --txwzs-v5-save-dir=<isolated-save-dir>
```

It passed eight assertions: at 1152x648, 1280x720, and 1920x1080 the largest
2D-anchor/`Camera3D.unproject_position()` difference was 0.22 logical pixels,
and road/bridge midpoint and facing error was 0. The same process used Macro
March GUI input handlers to draft and confirm a route, create a cross-river
engineering project, update a visible army node, and switch 2D/3D without
mutating the V5 campaign snapshot.

## Media boundary

This candidate's custom canvas exposes no accessible child controls to the
available desktop automation surface. An attempted window capture could not be
reliably tied to the short-lived candidate process, so no screenshot or video
is included here. The graphical UI-event check above is reproducible render and
interaction evidence, but it is not normal operating-system mouse input or
recorded player media.

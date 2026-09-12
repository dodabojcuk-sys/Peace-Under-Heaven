# Low-poly sample runtime evidence

`00-low-poly-runtime.png` is a crop from an isolated macOS Godot process using
the committed workspace at `92baf1cb88b48a4eb48ea9229f17ee672626fae8`.

- SHA-256: `6fe9513bed382679ca7ddef70702b699d635394a978a8ef98051eefe453d1ab2`
- Engine: `/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`
  (`4.5.1.stable.official.f62fdbde1`)
- Launch id: `lowpoly-final-92baf1c`
- Isolated V5 save: `/tmp/txwzs-lowpoly-final-92baf1c/save`

The screenshot was opened by a small external visual runner that calls the
normal scene's `open_macro_march_r0()` method after startup. It demonstrates
the committed render layer in a real Godot window, including its visible 2D
fallback control. It is not normal-system-input evidence and does not record a
route, construction, battle, or save action. The custom drawing canvas did not
expose accessible child controls to the available desktop automation surface,
so a truthful input video for this candidate remains open.

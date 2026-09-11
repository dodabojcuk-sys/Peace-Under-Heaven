# Macro Siege Effectful Facility Planning

## Scope

This checkpoint prevents a new macro-siege C0 plan from charging wood for
defense-only facilities that do not take part in the macro assault simulation.
It does not redefine historical saved plan records or the authored FIRST_WAR
facility set.

## Commands and results

Executed from the repository root with Godot 4.5.1:

```text
Godot --headless --path . --script tests/run_macro_siege_wartime_handoff_smoke.gd
MACRO_SIEGE_WARTIME_HANDOFF_SMOKE PASS assertions=31

for mode in A B C D E; do
  Godot --headless --path . --script tests/macro_siege_wartime_persistence_worker.gd \
    -- --mode=$mode --txwzs-v5-save-dir=<isolated-dir>
done
MACRO_SIEGE_WARTIME_DISK_WORKER_A PASS
MACRO_SIEGE_WARTIME_DISK_WORKER_B PASS
MACRO_SIEGE_WARTIME_DISK_WORKER_C PASS
MACRO_SIEGE_WARTIME_DISK_WORKER_D PASS
MACRO_SIEGE_WARTIME_DISK_WORKER_E PASS

Godot --headless --path . --script tests/run_wartime_inner_city_r0_smoke.gd
WARTIME_INNER_CITY_R0_SMOKE PASS

Godot --headless --path . --script tests/run_wartime_defense_r0_smoke.gd
WARTIME_DEFENSE_R0_SMOKE PASS
```

The macro smoke enters C0 through the real macro siege controller path and
asserts that the formal panel exposes only the ram and arrow tower, rejects a
direct barricade submission before wood changes, and that the two completed
works change real gate and defender state. The A-to-E workers are independent
processes against one isolated V5 directory: they save construction, restore
it, complete the ram, restore the active battle, publish a result, and apply
it once.

## Evidence boundary

These are engine GUI/button and controller integration checks, not native
macOS mouse-play evidence. The non-headless defense graphical smoke remains a
separate rendering check; this macro checkpoint does not claim a new visual
capture or player acceptance.

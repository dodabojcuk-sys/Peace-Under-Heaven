# Inner City Golden Path UI-R0 Acceptance

## Identity

- Active product successor: `codex/product-successor-inner-city-r0`
- UI implementation commit: `38f9e7de0cb310a463c83c76a497b7fafc7094f9`
- Forensic Canonical is read-only and was not modified.
- RG-O1 v1 remains `INVALID_QUARANTINED`; no preservation retry or G4 work was started.

## Runtime evidence

The isolated Godot 4.5.1 runtime was cold-imported before GUI launch. The
runtime title identified `codex/product-successor-inner-city-r0@38f9e7d`.
Real mouse/keyboard evidence covered build-catalog opening, blueprint
selection, Escape cancellation, confirmed road placement (shared wood
`100 -> 98` in the isolated runtime), building selection, and the upgrade-gate
confirmation/return flow.

## Visual evidence

All captures are native Godot window captures. Their image dimensions include
macOS window chrome; the named runtime launch sizes are retained in filenames.

| Evidence | Purpose |
| --- | --- |
| `screenshots/inner_city_ui_r0/baseline-legacy-shell-1440x900.png` | Baseline visual debt reference |
| `screenshots/inner_city_ui_r0/pass1-overview-1440x900.png` | Visual pass 1: hierarchy baseline |
| `screenshots/inner_city_ui_r0/pass2-overview-1440x900.png` | Visual pass 2: rail/readability correction |
| `screenshots/inner_city_ui_r0/final-overview-1280x720.png` | Final responsive overview |
| `screenshots/inner_city_ui_r0/final-overview-1440x900.png` | Final responsive overview |
| `screenshots/inner_city_ui_r0/final-overview-1920x1080.png` | Final responsive overview |
| `screenshots/inner_city_ui_r0/final-building-detail-1440x900.png` | Building detail and real data projection |
| `screenshots/inner_city_ui_r0/final-build-catalog-1440x900.png` | Build catalog and existing definitions |
| `screenshots/inner_city_ui_r0/final-upgrade-confirmation-1440x900.png` | No-writer upgrade gate and return action |

## Automated coverage

- Final dynamic discovery: `38/38` runners, `0` failed, `1832` explicit
  `PASS:` assertions under Godot 4.5.1.
- `run_inner_city_ui_r0_smoke.gd`: single-authority overview, responsive safe
  partition, build menu/cancel, and upgrade-gate zero mutation.
- `run_building_selection_smoke.gd`: responsive detail bounds plus upgrade-gate
  cancel and aliasing guard.
- `run_city_time_viewport_smoke.gd`: visible-by-default rail, collapse safety,
  camera safe area, and UI input occlusion.
- `run_unified_building_interaction_smoke.gd`: every fixed building remains
  reachable after safe-area camera focus.

## Result

`INNER_CITY_UI_R0=ACCEPTED_FOR_PRODUCT_SUCCESSOR`

The accepted slice is presentation and interaction integration only. It does
not certify G4, a real upgrade command, legacy migration closure, or deletion.

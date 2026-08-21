# Organic Garden City R3B Acceptance

## Scope

R3B adds the deterministic `REGULAR_IMPERIAL` and `ORGANIC_GARDEN` layout
profiles, formal Riverbend navigation, and in-memory dual-city runtime layout
isolation. It does not add final building art, curved roads, traffic,
full-map rotation, a new save schema, or G4.

## Identity and protection

| Check | Result |
| --- | --- |
| Successor branch | `codex/product-successor-inner-city-r0` |
| Start head | `90f46de7d2cc6db9eac0f69ca9b642699b3d0c7e` |
| Formal main scene | `res://scenes/blank_map.tscn` |
| Formal city node | `MapWorld/RegularCitySpatialFoundation` |
| Final head | `90f46de7d2cc6db9eac0f69ca9b642699b3d0c7e` before R3B commits |
| Canonical | unchanged, `4292ade22bbd3b4b14e48d98475ac50c1da265f6` |
| RG-O1 v1 | unchanged, `INVALID_QUARANTINED` |

## Acceptance matrix

| Area | Evidence | Result |
| --- | --- | --- |
| Stable IDs and profile resolver | `run_r3b_city_layout_profiles_smoke.gd` | PASS |
| Determinism and profile difference | focused runner | PASS |
| Organic road connectivity and reserve separation | focused runner | PASS |
| Fixed building non-overlap | focused runner and runtime sync | PASS |
| Same gate component | existing R1 component plus profile gate layout | PASS |
| Formal Riverbend world-map entry | `run_r3b_dual_city_navigation_smoke.gd` | PASS |
| Runtime building and player-road isolation | focused runner | PASS |
| V5 single-city save boundary | focused runner, fail-closed on Riverbend | PASS |
| Existing R2A/R2B/R3A behavior | 44-runner full smoke regression | PASS |
| Editor parse/import and formal scenes | Godot 4.5.1 headless | PASS |
| Native 1440x900 dual-city flow | external runtime evidence and continuous MOV | PASS |
| 1280x720 layout | native window bounds `1280x748` | PASS |
| Requested 1920x1080 | native window bounds `1920x960` | LAYOUT PASS; STRICT 1080 HEIGHT NO |

## Product truth

The organic city is a graybox spatial profile. It is not final art and does not
claim a persistent multi-city save. Shared resources and the existing
construction authority remain unchanged. A Riverbend snapshot cannot be
exported through the Blackstone-scoped V5 schema.

## Final evidence fields

The external evidence directory is kept outside Git and contains the native
window sequence, window identity, screenshots at 1280x720 and 1440x900, the
requested 1920x1080 with actual 1920x960 bounds, a continuous QuickTime
recording, and a SHA-256 manifest. The native sequence used only the temporary
R3B process (PID 54049, Window ID 2129); existing Godot processes were not
focused, attached to, or terminated by this slice.

## Final disposition

`VERDICT=PASS_ORGANIC_GARDEN_CITY_R3B`

The profile resolver, formal stable-ID entry, single construction authority,
in-memory city isolation, native Riverbend build/rotate/confirm/completion
flow, 44/44 regression, three-scene smoke, and 1280/1440 responsive evidence
are accepted for this slice. The requested 1920x1080 launch was capped by
macOS to a `1920x960` visible window; the layout passed at that actual size,
but this is not claimed as a strict 1080-pixel-height window pass. Persistent
multi-city V5 save remains deliberately fail-closed and is outside R3B.

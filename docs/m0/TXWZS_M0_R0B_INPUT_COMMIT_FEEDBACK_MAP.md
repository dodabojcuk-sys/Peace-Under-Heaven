# TXWZS M0 R0B Input, Commit, and Feedback Map

## Authority

- Base: `80908263fbf09cbec963ba4c582ff9b22adea894`
- Scope: direct building placement and explicit failure feedback only
- Spatial authority: `CityGridRules.evaluate_placement_legality()`
- Placement, construction, resource, and save-facing writer: `ConstructionController`
- Save schema: unchanged at schema 4

## Root Cause

`ROOT_CAUSE=OTHER:MAP_LEFT_CLICK_WAS_EXPLICITLY_PREVIEW_ONLY`

R0A deliberately routed a building-mode map left click to `update_preview()`
only. The right rail owned the separate confirmation signal. Therefore the
physical map event could never reach the placement writer, and a rejected
confirmation returned only `false`, leaving no player-facing failure result.

## Input to Commit Map

| Input | Boundary | Result |
| --- | --- | --- |
| Map left press | Outside construction UI; building placement active | Recompute the preview at that exact pointer, revalidate, then create at most one order |
| Map left press on invalid cell | Same boundary | No write; persistent reason and a replacing 2.5-second non-modal message |
| UI left press | Construction rail, catalog, top bar, minimap, or detail UI | UI action only; never leaks to map placement |
| `R` press | Building placement active | Rotate once and refresh footprint, entrance, connection, and legality |
| Right press | Building placement active | Cancel without order, allocation, resource, or save mutation |
| `Esc` press | Building placement active | Cancel without order, allocation, resource, or save mutation |
| Second click after success | Placement state already cleared | Cannot create another building |

Road construction retains its existing drag and `ConfirmRoadButton` flow. The
removed `ConfirmPlacementButton` no longer exists in the scene tree.

## Structured Result and Copy

| Reason code | Player copy |
| --- | --- |
| `ROAD_OVERLAP` | `无法建造：与道路重叠` |
| `BUILDING_OVERLAP` | `无法建造：与其他建筑重叠` |
| `IMMOVABLE_OBJECT_OVERLAP` | `无法建造：此处有不可移动建筑` |
| `OUT_OF_BOUNDS` | `无法建造：超出可建区域` |
| `INVALID_MAP_TARGET` / `UI_OCCLUDED` | `无法建造：请选择城内空地` |
| `INSUFFICIENT_RESOURCE` | `无法建造：缺少<材料与差额>` |
| `STATE_CHANGED` | `建造失败：状态已变化，请重新选择位置` |
| `UNKNOWN_COMMIT_FAILURE` | `建造失败，请重试（R0B-UNKNOWN）` plus an internal error log |

Shortages preserve resource order and list every positive `required -
available` delta. Timed construction remains orderable when total stock is
insufficient and instead shows `材料不足：缺木材 7；下单后将等待材料`.

## Atomicity

An invalid result creates no placement ID, order, resource transaction, or save
mutation. A successful result creates exactly one placement, uses the existing
incremental construction-payment path, and clears placement presentation state.

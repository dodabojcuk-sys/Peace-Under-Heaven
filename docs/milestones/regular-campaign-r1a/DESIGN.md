# Regular Campaign R1A — wartime inner-city spatial slice

## Goal

Restore one operable frontline city view inside the normal Regular Campaign
entry. The city must expose the real R1 local building records and commands
without changing R1 economy, pressure, combat, settlement, storage ownership,
or time authority.

## Reuse and adaptation boundary

- `RegularCampaignRuntime` remains the only owner of local projects, buildings,
  scoped food/wood, workers, production and road connection facts.
- The existing R1 campaign projection remains one `CanvasLayer`. It adds a
  city/theater view mode and keeps only transient selection state.
- The six authored plots remain the candidate's fixed inputs. R1A makes them
  spatially selectable but does not expand capacity or define a future city
  construction contract.
- The old city camera proportions, selection outline language, road preview
  language and distinct building silhouettes are reused as presentation
  references. The permanent-city controller is not embedded or copied because
  it owns different inventory, records and time.
- Every displayed building is projected from `local.buildings`; the active
  scaffold is projected from `local.project`. Selection resolves to the same
  stable building ID and plot stored in the V5 regular campaign payload.
- Build, connect and worker actions call the existing `command()` boundary.
  The scene cannot pay, complete, staff or produce by itself.

## Player-visible contract

The R1A candidate opens on a city-sized enclosed space with a gate, wall,
cross-road, command building and six readable plots. The enclosure and command
building are presentation only and explicitly claim no defense, collision or
production effect. Farm, logging camp, warehouse and clinic have distinct low
cost silhouettes.

Clicking an empty plot opens the existing building choice and enables the build
command for that plot. Clicking a completed building highlights its plot and
shows its real ID, completion, road, workers and effect. Road and worker buttons
submit the existing authoritative commands. Switching to the theater overview
and back reconstructs no state and grants no resources.

The top bar keeps local food, local wood, supply risk and current objective.
The supply forecast remains visible. Detailed pressure multipliers are collapsed
behind an explicit button while the current pressure stage remains visible.

## Acceptance and exclusions

Focused validation covers engine import, plot/building hit testing, authoritative
build/connect/workers commands, local production, city/theater round trip,
1152×648 and 1280×720 layouts, and cold restoration in a new isolated store.
The continuous input journey must use title/UI mouse and keyboard events; it may
observe runtime state to decide when to continue, but cannot call build, connect,
staff or production methods directly.

R1A does not change dynamic pressure, enemy growth, rations, training, battle,
settlement, save owners, clocks, C0 takeover, trade, the next campaign or the
global map. Full battlefield presentation and human mouse-feel acceptance remain
open.

## Main-city host correction (2026-09-14)

The earlier integration reused the established city foundation, building visual
and minimap inside a new full-screen campaign surface. That is component reuse,
but it is not restoration of the established game screen or its camera and input
relationship. The accepted host is therefore the existing `blank_map` city:
`MapWorld`, `Camera2D`, `MapPanController`, `BuildingSelectionController` and
`UI/Shell` remain the visible and interactive city hierarchy.

Retained without rule changes:

- `RegularCampaignRuntime` remains the only owner of campaign-local resources,
  projects, buildings, workers, production, pressure, time and view context.
- The six authored plot indices, build/connect/workers commands, four existing
  building textures, graybox fallback, duplicate-draw suppression, construction
  gates and authoritative production feedback remain unchanged.
- The established low-poly theater presentation and the route permanent city ->
  campaign theater -> licensed wartime city -> same theater remain unchanged.

Changed presentation and input boundary:

- The campaign overlay remains the theater/preparation surface only. Entering a
  licensed wartime city reveals the normal city world and shell instead of a
  left map preview plus permanent right management page.
- Campaign buildings are transient projections in the existing `MapWorld` and
  are selected through the existing map input and building-detail surface. The
  existing construction catalog is parameterized to submit the campaign's
  fixed-plot build command; it never starts the permanent-city build writer.
- The initial wartime-city camera uses the established 1:1 city zoom and layout
  focus. Panning, cursor-anchored zoom, hit testing and minimap share the normal
  world/canvas transform. Resize, detail open/close and theater round trips keep
  the saved city camera; whole-city fit is an optional observation state only.
- The normal top bar shows campaign-local stock, current campaign time/pressure
  and concise supply or construction warnings while this host is active. Long
  rules remain in the theater surface and do not occupy the unselected city.

The host adapter is presentation and command routing only. It does not copy the
permanent-city controller, expose permanent inventory to the campaign, change
world size or footprints, tick time, settle results, or add persistence fields.

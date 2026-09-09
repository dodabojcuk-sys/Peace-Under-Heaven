# Blackstone Sample Theater R2 — Playable 2.5D Slice

## Problem

The R2 war loop is mechanically integrated, but the existing playable resource
still inherits the regression fixture's geometry. Its engineering playthrough
also mixes natural player choices with fault-injection coverage, so the current
route metrics cannot answer whether the battlefield is understandable or fun.

## Player outcome

From the normal city entry, a player can read the battlefield, scout a threat,
choose either a direct northern advance or an engineered central crossing, and
capture the two required enemy cities. The two routes share one initial economy
but trade preparation and construction cost against exposure and casualties.

## Scope

- Keep the existing regression theater available to focused tests.
- Define a separate playable theater resource with its own points, roads, water,
  forests, and patrol setup.
- Present the same authoritative geometry through an invertible fixed-oblique
  projection used by rendering, hit testing, and route drawing.
- Add only the map feedback and controls needed for scouting, construction,
  repair, march orders, encounters, and occupation.
- Preserve `ArmyRegistry`, `ConstructionController`, `FieldTacticsState`, and V5
  persistence as the existing authorities.

Out of scope: commanders, generations, new resources, Meshy, paid assets, a full
3D navigation rewrite, and main-city art replacement.

## Battlefield layout

- Blackstone is the western player city.
- Redcliff and Silverford are separated enemy objectives in the east.
- The northern road is immediately available and passes through the patrol's
  operating area.
- A central river and wooded bank block the shorter approach.
- A player-built road–bridge–road connection reaches Forest Watch; the existing
  eastern network then provides a concealed staging route toward both objectives.
- Forest Watch is a real authored friendly garrison. Junctions remain connection
  nodes only and never become arbitrary march destinations.

## Route trade-off

| Route | Cost | Benefit | Risk |
| --- | --- | --- | --- |
| Northern road | No construction delay | Immediate access to Redcliff | Patrol contact and higher casualties |
| Central works | Engineer, food, and build time | Forest staging, ambush opportunity, shorter second-army access | Specialist exposure before guards arrive |

The formal playthrough never injects road damage or engineer death. Those cases
remain in the separate recovery regression suite.

## Presentation contract

- World facts stay in the theater resource; presentation never invents walkable
  land, water, roads, or visibility.
- `world_to_screen` and `screen_to_world` are inverse operations around the same
  fixed-oblique projection.
- The map canvas clips every world primitive before the side panel.
- Far zoom emphasizes flags, city silhouettes, bridge openings, and counts;
  closer zoom adds small formation dots and construction detail.
- Player copy uses names and readable phases, not internal IDs or enum values.

## Timed encounter contract

An engineer moving along an active construction segment contributes a timed
movement trace for the exact work interval. Arrival, construction, bridge opening,
patrol movement, guard position, and specialist contact are compared on one world
time axis. A large step and equivalent split steps must produce the same survivor,
project-progress, and guard-participation results.

## Acceptance and verification

1. Playable and regression theater resources can be selected independently.
2. The playable resource owns materially different geometry and patrol setup.
3. Main-road and engineering routes both start with the same normal resources,
   use formal UI events for core commands, and end with both required cities held.
4. Natural route metrics include world elapsed time, all army casualties,
   specialist losses, and food transactions; no fixed remainder is required.
5. Construction timed-contact partition tests pass.
6. Macro, Field R2, playthrough, persistence, import, and scene smoke checks pass.
7. Design QA compares the supplied concept direction with final candidate frames.

Passing these checks produces a review candidate. It does not constitute player
acceptance or a release decision.

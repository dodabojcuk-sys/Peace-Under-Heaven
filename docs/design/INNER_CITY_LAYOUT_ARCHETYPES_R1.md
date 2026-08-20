# Inner City Layout Archetypes R1

## Product decision

The product can support three long-lived city layout archetypes:

- `REGULAR_AXIAL_CITY`: a formal axis, courtyards, and a strong civic order.
- `REGULAR_WARD_CITY`: legible orthogonal wards and streets without compulsory symmetry.
- `ORGANIC_GARDEN_CITY`: later work for water, garden structure, and more organic circulation.

R1 implements only the first regular-city spatial foundation. It combines a
main axial road, cross street, walls, wards, and a compact civic court. The
default view intentionally has no permanent gameplay grid. This keeps the city
readable as space rather than a background of cards while retaining room for
player-built roads and buildings.

## Responsibility boundary

`RegularCitySpatialFoundation` owns only graybox spatial presentation. It does
not own City, Building, resource, placement, or save state. `NationState` and
the existing `ConstructionController` remain the unique resource and building
placement authorities. A future layout profile may change roads, walls, ward
geometry, colors, and fixed ambience without cloning the construction model or
creating a second city UI.

The right build rail is the single construction and selected-building surface.
It contains the minimap, real construction catalog, placement controls, and
building detail in one responsive region. The prior always-open bottom catalog
is not the formal product direction. Upgrade is still presented as an explicit
read-only gate because no authoritative upgrade writer exists.

## Rotation

Building instances record `NORTH=0`, `EAST=1`, `SOUTH=2`, or `WEST=3` through
the existing authority. The V5 compatibility snapshot defaults missing legacy
orientation to north. A single `CityGateComponentR1` is instantiated four
times with rotation; there are not four gate logic implementations.

R1 deliberately does not rotate the entire camera/map view. Current
screen-to-map conversion, selection, placement snapping, minimap viewport
projection, and scene-safe UI regions all assume an unrotated world. Adding a
90-degree view transform needs a dedicated coordinate-contract change, not
four copied maps or an unsafe save rewrite.

## Deferred scope

- `ORGANIC_GARDEN_CITY` and its garden/water layout are not implemented.
- Final building art is not started; R1 is a graybox spatial foundation.
- Road routing, traffic simulation, and automatic road generation are not
  implemented. Existing road and connection authority remains intact.

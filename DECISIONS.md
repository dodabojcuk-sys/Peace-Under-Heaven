# Product Successor Decisions

## R3B dual-city layout profiles

- `blackstone_city` remains the default `REGULAR_IMPERIAL` profile. The formal
  world-map `riverbend_city` entry resolves to `ORGANIC_GARDEN` by stable ID;
  no name-based matching or debug-only city is used.
- `RegularCitySpatialFoundation` projects both authored profiles into the
  existing 55x35 orthogonal grid. Garden roads, reserves, gates, and fixed
  anchors are static data; `ConstructionController` remains the sole runtime
  writer.
- Switching cities snapshots and restores only in-memory runtime placement
  records and player-road cells. Nation resources remain shared. V5 and early
  single-city saves fail closed on Riverbend instead of changing schema or
  writing Riverbend under the Blackstone ID.
- Both cities reuse one `CityGateComponentR1`, one building visual path, one
  placement path, one road path, and one right-rail UI. Final art, traffic,
  curved roads, full-map rotation, and persistent multi-city V5 storage remain
  separate scopes.

## R2B player road construction

- Formal roads remain the spatial authority of
  `RegularCitySpatialFoundation`; player roads are runtime placement records
  owned by `ConstructionController`.
- The player-road set is a delta over the formal 55×35 layout. Rendering,
  connectivity, entrance checks, production activation, and save/load all read
  the same union and do not persist derived connectivity flags.
- The right rail is the only road entry point. A drag creates one orthogonal
  segment; diagonal input is rejected and turns require another segment.
- Confirmation uses the existing national resource transaction and writes one
  record per new road cell. Existing roads are traversable without duplicate
  cost; invalid paths fail atomically.
- Player roads reuse the existing V5 placement array without a schema bump.
  Legacy snapshots with no road placements restore an empty delta.
- R2B excludes road deletion/upgrades, traffic/pathfinding, bridges/slopes,
  curved roads, full-map rotation, organic city generation, final art, and G4.

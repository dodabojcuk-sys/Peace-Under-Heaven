# Product Successor Decisions

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

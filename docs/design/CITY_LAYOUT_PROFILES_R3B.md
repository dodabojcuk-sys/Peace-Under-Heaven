# City Layout Profiles R3B

## Purpose

R3B introduces deterministic spatial profiles for the two formally reachable
inner cities without creating a second construction state owner. The profile
is a read-only layout input to the existing `RegularCitySpatialFoundation` and
`ConstructionController`.

## Stable identity

| City ID | Profile | Product role |
| --- | --- | --- |
| `blackstone_city` | `REGULAR_IMPERIAL` | Existing regular axial/ward city and default entry |
| `riverbend_city` | `ORGANIC_GARDEN` | Formal world-map entry with an orthogonal garden graybox |

`CityLayoutProfileResolver` is the single deterministic mapping from stable
city ID to profile. It owns no runtime state and does not persist a city.

## Spatial contracts

Both profiles use the existing 55x35, 40-unit orthogonal grid and the same map
extent. The regular profile keeps the accepted axial roads, civic court,
wards, fixed building anchors, and four `CityGateComponentR1` instances.

The garden profile uses offset and bent/T-shaped orthogonal roads, unequal
blocks, one large garden reserve, two smaller courtyards/reserves, an
off-centre civic court, and deliberately open building space. Its roads and
reserves are projected into the same construction queries as the regular
profile. No curved roads, procedural city generator, or alternate coordinate
system is introduced.

Both profiles use the same four gate component class. Gate orientation is a
profile datum; it is not four copied scenes or four state owners.

## Runtime ownership

`ConstructionController` remains the only writer for buildings, player roads,
resource transactions, construction lifecycle, and derived road connection.
When the world-map entry requests a known city, the controller snapshots only
the current city's runtime placement records, switches the foundation profile,
rebuilds fixed occupancy, and restores that city's runtime placement records.
The nation resource ledger remains shared. City layout snapshots are in-memory
only for this slice.

The existing `V5` and early single-city snapshot schemas remain Blackstone
scoped. Export and restore fail closed while `riverbend_city` is active rather
than serializing Riverbend data under `blackstone_city`. No save schema,
autoload, resource definition, or migration format changes are made.

## UI and navigation boundary

The existing campaign world map is the formal navigation entry. It exposes
Riverbend only through its stable ID and emits `city_entry_requested`; the
map controller then switches the same construction authority. The right rail,
placement, road tool, minimap, selection, Escape handling, and input routing
are reused. The minimap receives the active profile's projected road and
reserve cells so the two layouts remain visibly distinct.

## Future extension

An organic profile is intentionally a static authored arrangement, not a
general city generator. A later profile can add another stable ID and profile
dictionary while reusing the existing building instance model, construction
controller, road projection, save boundary, and right rail. Final art,
curved roads, traffic, full-map rotation, and multi-city persistent V5 storage
remain separate authorizations.

# TXWZS M0 R0C Legacy Save Migration Map

## Schema decision

R0C upgrades the campaign snapshot from schema 4 to schema 5 because the
current-city build slot and its paid ready token must survive a process restart.
The storage envelope and save owner are unchanged. `V5CampaignSnapshot` remains
the structure validator and `ConstructionController` remains the only runtime
export and restore boundary.

Schema 5 adds one required root field, `build_slot`, with these persistence-only
values:

- business state;
- building definition ID;
- integer progress and required milliseconds;
- integer total and paid costs by resource ID;
- missing resource IDs;
- four-way orientation;
- completion-notification flag.

Mouse position, preview legality, UI nodes, selection, and map ghosts are never
saved. Runtime `PLACEMENT_ACTIVE` is exported as `READY_TO_PLACE`.

## Migration chain

```text
schema 2
  -> schema 3: existing orientation defaults
  -> schema 4: existing M0 construction and pressure defaults
  -> schema 5: add an empty R0C build slot

schema 3
  -> schema 4
  -> schema 5

schema 4
  -> schema 5: add an empty R0C build slot only
```

No migration moves, completes, refunds, repays, or converts a placed legacy
foundation. Its cell, orientation, progress, required duration, paid costs,
missing resources, and legacy priority remain in the placement record.

## Legacy bridge

If any restored schema 4 placement is still constructing:

- the R0C build slot remains `IDLE`;
- starting a new building project fails with `LEGACY_CONSTRUCTION_LOCK`;
- the catalog explains `旧存档施工完成后启用新建造队列`;
- the legacy foundation continues through the existing placed-construction
  tick path;
- roads remain independent and usable;
- the new slot becomes available after all legacy construction completes.

Snapshots containing both an active R0C slot and a constructing legacy
placement fail structural validation as `LEGACY_BUILD_SLOT_CONFLICT`. This
prevents two construction authorities from being restored together.

## Verified compatibility cases

- `IDLE`, `PRODUCING`, zero-progress `WAITING_MATERIAL`, mid-progress
  `WAITING_MATERIAL`, and `READY_TO_PLACE` roundtrip exactly.
- `PLACEMENT_ACTIVE` reloads as `READY_TO_PLACE` with no ghost.
- One and multiple schema 4 legacy foundations retain their state and lock only
  the new building slot.
- Existing V2/V3 chained migration remains green in the full regression.
- Three independent Godot processes preserve exactly one fully paid ready token
  alongside the existing army state without offline progress or duplicate
  payment.


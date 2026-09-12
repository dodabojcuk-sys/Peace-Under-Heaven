# Blackstone Formal Art Integration R2 Plan

## Scope and boundary

This plan replaces the previous built-in-geometry-only constraint for the
Blackstone miniature **presentation layer**.  It does not change battlefield
coordinates, routes, fog, field projects, ArmyRegistry, resource transactions,
world time, or V5 persistence.  The existing 2D map stays available as a
rendering fallback.

## First batch

| Area | Runtime treatment | Source / reason |
| --- | --- | --- |
| Trees, rocks, grass | Selected importable GLB scenes, instanced from the static theatre renderer | Kenney Nature Kit 2.1, CC0; three tree variants, three rock variants and one grass clump keep the environment coherent without importing the full pack. |
| City gate, wall, camp, watchtower | Small authored low-poly assemblies built from Godot meshes | These must read as Chinese frontier architecture; the generated gatehouse image is a design reference only, not a game texture or a claimed runtime asset. |
| Roads, bridge, damage and work | Existing data-driven mesh path, refined per authoritative road/project segment | These objects must remain geometrically tied to actual passability and construction state. |
| Armies and specialists | Existing runtime read-model silhouettes, improved flags, selection ring, and role marker | Counts, casualties, and visibility remain read-only views of the existing authorities. |

## Asset record

- `assets/blackstone_art/kenney_nature/`: selected original GLBs plus the
  upstream `License.txt`.  Source: <https://kenney.nl/assets/nature-kit>;
  archive: `kenney_nature-kit.zip`, Nature Kit 2.1, retrieved 2026-09-09;
  archive SHA-256
  `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d`;
  license: CC0 1.0 Universal.  No attribution is required; the source is
  retained here for traceability.
- `docs/design/references/blackstone_chinese_gatehouse_reference_20260909.png`:
  generated with the available image-generation tool on 2026-09-09.  It is a
  non-runtime design reference for proportions, palette, and roof silhouette.
  It is not presented as a gameplay screenshot or as a third-party model.

## Execution and rollback

1. Import and validate the selected CC0 GLBs, then instantiate only them in
   static forest/rock/riverbank patches.
2. Refine the existing render-only city, camp, watchtower, bridge, road and
   unit assemblies around their current world anchors; validate at all three
   review resolutions.
3. Independently reproduce and repair the blocked-transfer segment and natural
   ambush regressions.  Their commits must remain separable from presentation
   changes.
4. Run graphical, Macro March, Field R2, playthrough and persistence checks;
   capture candidate viewport evidence from the final revision.

Presentation changes can be reverted independently by removing the asset
mapping/renderer checkpoint; the legacy 2D mode remains a usable fallback.
Gameplay regression repairs are kept in a separate checkpoint.

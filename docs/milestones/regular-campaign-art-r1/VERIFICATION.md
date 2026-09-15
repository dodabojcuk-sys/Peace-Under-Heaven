# Regular Campaign Art Assets R1 verification

## Result

Four generated building textures are integrated into the established wartime inner-city scene through `RegularCampaignPresentationBridge` and `GrayboxBuildingVisual`. The original city foundation, roads, walls, camera, minimap and low-poly theater remain active. The graybox geometry remains the default fallback for every other caller.

The bridge reads the existing building kind, ID, project progress, road state and workers. It adds no owner, command, clock or resource mutation. Construction dust runs only while the authoritative project can actually advance; pause, insufficient materials and other existing stalls stop it. Farm work runs only for a completed, connected, staffed and unpaused farm. Deposit feedback compares successive authoritative production totals, displays only a positive real delta and establishes an initial baseline on a new bridge, preventing replay after load or re-entry.

The closeout suppresses the replaced graybox subject only for an art-enabled building, hides the outline during ordinary connected browsing, and keeps both behaviors intact for graybox fallback callers. Early construction shows the existing foundation instead of mature crops. The city foundation skips only ambient decorative volumes that overlap current R1 project/building footprints, so no building, resource or hit target is removed. The road entrance marker now follows the actual selected/disconnected state.

The theater overlay clamps right-edge labels and separates colliding city/army labels without changing world positions, hit targets, routes or font size.

## Evidence

- Same-scale before/after: `evidence/comparison/before-after-same-scale.jpg`
- Four-building fixture, explicitly fixture evidence: `evidence/fixture-four-buildings-1280x720.png` and `evidence/fixture-four-buildings-1152x648.png`
- Normal farm construction/production: `evidence/normal-flow/`
- Final GUI-input journey with theater point click: `evidence/normal-flow/r1-art-normal-input-final.avi` (1280×720, 321 frames, 30 fps, 10.7 seconds)
- Engine-frame previews: `evidence/previews/construction.gif`, `evidence/previews/farm-work.gif`
- Closeout before/after and paused-construction proof: `evidence/closeout/`
- Normal-time closeout journey: `evidence/normal-flow/r1-art-closeout-realtime-input.avi` (1280×720, 897 frames, 15 fps, 59.8 seconds)
- Generation provenance: `IMAGE_CALL_LOG.md`, `ASSET_MANIFEST.json`, `ASSET_SHA256.txt`

The final journey uses GUI mouse events for the eligible city, plot, build, road and worker controls. Runtime time advancement is accelerated by the validation runner; it is not presented as a real-time balance recording.

The closeout journey is separate from that accelerated runner. It uses the visible pause and 4× controls and the regular controller `_process` path, with no direct `runtime.advance()` calls. It pauses construction for two seconds, resumes, completes the real project, waits for the real three-minute production cycle at the selected game speed, returns to the theater and enters the same city again.

## Verification run

Passed:

- Godot 4.5.1 editor import and script registration.
- `run_regular_campaign_art_r1_visual_smoke.gd`: four RGBA textures, 1280×720 and 1152×648 captures, pause gating, actual-delta popup and no same-total replay.
- `run_regular_campaign_r1a_city_smoke.gd`: normal farm build, connection, staffing, real local food output, theater round trip and both target resolutions.
- `run_regular_campaign_r1a_building_types_smoke.gd`: four authoritative records and visuals, roads and workers.
- `run_regular_campaign_r1a_theater_entry.gd`: permission, view identity, pause/speed, one clock, cold-restored view context.
- `run_regular_campaign_r1_smoke.gd`: 14 assertions.
- `run_regular_campaign_rules_r1_smoke.gd`: 17 assertions.
- `run_regular_campaign_art_r1_realtime_journey.gd`: normal GUI controls, stalled construction, resume, road, workers, actual production and theater re-entry.

Shared permanent-city regression now passes all 41 assertions. The two prior failures were stale fixture assumptions: the active snapshot expectation now uses the current schema constant, while the V16 fixture explicitly omits V18-only roots before exercising the real V16→V17→V18 migration. Upgrade state, resource conservation and no-free-grant assertions remain active. Runtime schema and permanent-city state code are unchanged.

The closeout used zero additional image-generation requests. The Art R1 total remains six of eight requests, including one of the two permitted revision requests.

## Open gates

Human/player visual acceptance, mouse feel and final art direction remain open. The optional generated icon/effect atlas was rejected from runtime use because it lacked transparency. Existing full battlefield presentation remains outside this task.

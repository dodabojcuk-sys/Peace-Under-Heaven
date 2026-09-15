# Image generation call log

Code model reported by the active Codex task: `gpt-6-astra`. The user explicitly directed the active task to execute after the earlier model preference. No subagent or external paid API was used.

Image tool: built-in `image_gen`. The tool did not expose a backend model/version identifier, so none is inferred. Six of the allowed eight requests were used: five initial generations and one targeted farm correction. One of the two allowed revision requests was used.

1. Farm initial — requested a transparent, high-angle ancient frontier farm with furrows, crops, tools, baskets and a bottom entrance. Source: `assets/regular_campaign/art_r1/source/farm-initial.png`. Result was RGB with a baked checkerboard.
2. Farm alpha correction — preserved the farm and requested removal of the baked checkerboard with true alpha. Source: `assets/regular_campaign/art_r1/source/farm-alpha-revision.png`. Result was still RGB; deterministic foreground extraction produced the runtime alpha texture.
3. Logging yard — requested a timber shed, cut-log piles, work area, stump and tools. Source: `assets/regular_campaign/art_r1/source/logging.png`. True RGBA.
4. Warehouse — requested a closed broad storehouse, reinforced wide entrance, loading awning, crates and sacks. Source: `assets/regular_campaign/art_r1/source/warehouse.png`. True RGBA.
5. Clinic — requested a period healer lodge with curtain, drying herbs, jars and baskets, without a modern medical symbol. Source: `assets/regular_campaign/art_r1/source/clinic.png`. True RGBA.
6. Icon/effect atlas — requested six isolated grain, wood, construction, leaf, dust and basket elements. Source: `assets/regular_campaign/art_r1/source/icon-effects-atlas-unused.png`. Its background was opaque and visually unsuitable, so it is retained as source evidence but not shipped at runtime.

Runtime images are 256×192 RGBA. The four 64×64 icons are deterministic crops of the accepted building textures. Exact hashes are in `ASSET_SHA256.txt`.

Closeout at baseline `74166de60cf30894729a55698cf2c83ee54810ad` used existing source/runtime images and deterministic presentation changes. It made zero additional image-generation or edit requests, so the cumulative total remains six of eight.

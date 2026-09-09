# 2026-09-09 low-poly readability fix evidence

Candidate source state: local worktree following `8a8fd97ad0cf4d7a5572269a6203bfbb7ec169fe`.

These PNGs are captured from Godot's rendered root viewport after Macro March
GUI-event handlers create the shown state. They are engine-viewport evidence:
they prove the current renderer and authoritative UI event chain, but are not
normal desktop mouse-input evidence and are not player acceptance.

| File | Rendered state |
| --- | --- |
| `00-overview-full-engine-viewport.png` | Full Blackstone overview with horizontal presentation ground and map clipping. |
| `01-route-draft-full-engine-viewport.png` | Confirmable route draft. |
| `02-auto-march-full-engine-viewport.png` | Selected formation on the focused automatic-march view. |
| `03-engineering-preview-full-engine-viewport.png` | Mouse release has already cleared transient draw points; the persisted authoritative engineering plan remains visible, including normal-road and bridge portions. |
| `04-land-construction-full-engine-viewport.png` | Active normal-road segment: road surface only, no bridge rails. |
| `05-bridge-construction-full-engine-viewport.png` | Active bridge segment: deck and rails only on the authoritative bridge portion. |
| `06-complete-crossing-full-engine-viewport.png` | Completed construction state after the same project advances through its segment plan. |

Companion `low-poly-*` files are the bare SubViewport render. The `*-full-*`
files include the actual Macro March rail and overlays, and are the preferred
review images.

The graphical smoke is deliberately run in a graphical Metal process at
1152x648, 1280x720, and 1920x1080. Its output confirms 0--0.22 pixel anchor
alignment, horizontal ground and matching normals, actual road endpoint/facing
geometry, persistent engineering drafts, and authoritative `NORMAL → BRIDGE →
NORMAL` construction rendering. The normal-system-input recording gap remains
open because the candidate's custom canvas cannot safely be addressed by the
available desktop automation session.

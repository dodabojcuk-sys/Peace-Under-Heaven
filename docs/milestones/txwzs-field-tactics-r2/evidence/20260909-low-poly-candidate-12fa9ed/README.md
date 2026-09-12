# Low-poly candidate handoff evidence

## Candidate identity and remote delivery

- Source implementation commit: `ba7016b35a83c90f3e3ffaa2c180c1f31ef65286`
- Candidate runtime commit: `12fa9edbc6c9ca03c172fc9cecc09d3b7a186773`
- Branch: `codex/txwzs-field-tactics-r2`
- Remote branch before this evidence-publication commit:
  `12fa9edbc6c9ca03c172fc9cecc09d3b7a186773`
- Runtime: Godot `4.5.1.stable.official.f62fdbde1`, Metal 3.2 / Apple M4
- Formal-window PID: `87293`; Window ID: `13347`
- Runtime title: `天下无战事 · CITY · codex/txwzs-field-tactics-r2@12fa9ed · DEBUG`
- Save store: `/tmp/txwzs-lowpoly-12fa9ed-window-1788934751-87288/saves`

The standard launcher was first used with the documented Godot path. It safely
refused to start because older unregistered project processes (PID 3332 and
68275) were present. They were neither focused nor stopped. The recorded
candidate therefore used the same formal scene, runtime identity arguments,
and an isolated save directory through a separate `open -na` Godot instance.

## Current screenshots

| File | Source and observed state |
| --- | --- |
| `00-city-entry-window.png` | Window-only macOS capture of the identified current candidate before entering the city. |
| `00-overview-full-engine-viewport.png` | Actual Godot root viewport after the formal city entry opened the Blackstone Macro March screen. |
| `01-route-draft-full-engine-viewport.png` | Engine GUI-event route draft: the selected seven-member Northern Vanguard snaps from Blackstone to Northwatch; the rail reports 15.0 seconds and 2 food. |
| `02-auto-march-full-engine-viewport.png` | Engine GUI-event confirmation plus one authoritative march advance: seven members are travelling at 7 percent, with the same route and a single 2-food payment. |
| `03-engineering-preview-full-engine-viewport.png` | Engine GUI-event cross-river road-and-bridge preview: four points, 21.0 seconds, and 12 food before confirmation. |
| `04-construction-progress-full-engine-viewport.png` | Engine GUI-event confirmation and authoritative world-time advance: the road/bridge work is visibly marked `施工中`. |

All map screenshots were inspected after capture. The displayed road endpoints
meet at their named points; the Northwatch bridge reaches both river banks; the
army marker remains on its authored northern road; and the action rail remains
visible. The miniature presentation is still intentionally primitive-based and
does not claim final building, vegetation, or combat art.

## Evidence boundary

The four battle-state screenshots are engine viewport captures from the formal
scene and its real GUI handlers, not OS-pointer captures. The available desktop
automation API exposed only the older `UNKNOWN` Godot window and provides no
PID/window-target selector; sending coordinate clicks could therefore affect an
unrelated process and was refused. Consequently there is no normal-system-input
video for `12fa9ed`. The existing graphical smoke remains a reproducible
render/input-handler check, while the normal mouse/video requirement remains an
explicit media gap rather than a claim of player acceptance.

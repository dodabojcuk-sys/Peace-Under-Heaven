# Regular Campaign R1A handoff

## Candidate

- Worktree: `/Users/m4-zhi/Documents/codex-workspace/txwzs-regular-campaign-r1a`
- Branch: `codex/txwzs-regular-campaign-r1a`
- Source report commit: `6796cbd00dd0deb95a2787cca9c784f9d9ae4865`
- Implementation commit: `9bc44f50f25ac40da63f9241c454346ea4260b69`
- Entry: `RUN_REGULAR_CAMPAIGN_R1A.command`

The launcher requires a clean R1A branch derived from the source report commit
and creates a new marked save store under
`/Users/m4-zhi/Documents/TXWZS-Regular-Campaign-R1A-Runs`. It does not reuse the
running R1 store.

## Result

Normal Regular Campaign entry now opens the frontline city. The scene shows a
readable enclosure, gate, roads, command hall and six current R1 plots. Clicking
a plot chooses the authoritative build target. Clicking a finished facility
selects the matching R1 building ID and reports progress, road, workers and
production. Connect and staffing controls submit existing R1 commands. Theater
overview and city return preserve the same state.

All permanent-city and R1 authorities remain unchanged. Walls and command hall
are presentation only. No trade, next campaign, global war, new capacity,
second clock, second save owner or second battle simulator was added.

## Verification

- Godot 4.5.1 import and script parsing: pass.
- Existing focused R1 smoke/services/validation: 14/14, 11/11, 15/15 pass.
- Runtime identity smoke including R1A: pass.
- New city GUI smoke: build, completion, real ID selection, road, four workers,
  food production and theater round trip pass at 1280x720 and 1152x648.
- Four-building GUI smoke: real farm, logging, warehouse and clinic records,
  roads and staffing pass; both target resolutions were captured and inspected.
- New isolated multi-process cold recovery A-J: pass.
- Continuous 47.55-second, 951-frame, 20 FPS input journey: title entry, build,
  connect, staff, production, theater return and city re-entry pass. Business
  mutations were performed by visible mouse/keyboard input; runtime reads only
  controlled observation timing.

## Open gates

Full battlefield presentation was not restored in R1A. Human mouse feel,
unfamiliar-player acceptance, final art, long-term balance and real-device
coverage remain open. Push, merge and deployment were not performed.

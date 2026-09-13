# Blackstone causal boundary and playtest candidate R1 verification

Status: implementation and engineering verification candidate. Human play
acceptance remains OPEN.

## Provenance

- Baseline: `5bb22dc533dae749c2648ffc9ce18ea67f6240b1`.
- Baseline branch, development remote and actual default remote were fetched
  before implementation and resolved to the same commit; no later relevant
  work existed at that point.
- Implementation branch: `codex/blackstone-causal-playtest-r1`.
- Engine: Godot 4.5.1 stable official.
- Every save-writing runner used an explicit `/tmp/txwzs-*` save directory.
  Player saves and pre-existing native windows were not used or closed.

## Rule result

The day-5 gate now rechecks Redcliff control. A player-controlled source makes
the same dormant vanguard record terminal `CANCELLED`, with reason
`SOURCE_CONTROLLED_BEFORE_DEPARTURE` and cancellation day. The exact player
message is `赤崖已被控制，本次先遣军出兵取消。` A departed force keeps its
identity, strength, position, route and damage; arrival and defense handoff keep
their existing transaction. Restored terminal states do not regenerate.

Macro army movement and occupation continue to settle before configured field
departures within the existing authoritative update. Whole, split and
irregular frame partitions produce the same tie result. A failed campaign
checkpoint restores the prior war, army and population snapshots, so a
cancellation retries rather than leaking as an unsaved terminal state.

## Normal fresh-campaign early route

`run_blackstone_early_counterattack_r1_journey.gd` uses the playable theatre,
fresh day-1 resources, formal 4x/1x speed controls, paid macro orders, natural
field contacts, the visible macro-siege C0 handoff and authorized battle
confirmation. It does not mutate date, resources, force strength, gate HP,
control or results.

- 20 soldiers leave Blackstone and suffer the authored Northwatch and Redcliff
  contacts; 9 reach the Redcliff siege in two surviving original formations.
- The normal spatial assault wins and occupies Redcliff on day 1, then the same
  surviving army proceeds to Silverford and completes the control-only victory.
- At day 5 the still-dormant vanguard becomes `CANCELLED`; victory and the
  existing player army remain valid.
- Final observed real duration: 272.493 seconds at formal 4x travel/world speed and
  1x C0 battle speed. All 14 journey assertions pass.

This journey exposed and fixed a real continuity issue: a field-exhausted
zero-count formation remains in ArmyRegistry for provenance but cannot become
a C0 squad. Handoff and result settlement now compare only the non-empty
formations that actually enter battle; no formation is merged, replaced or
refilled.

## Candidate entry

`RUN_CURRENT_TXWZS.command` now opens the formal title scene. The title shows
candidate branch/commit/dirty identity, explicit Continue and New Game actions,
pause/speed help, and concise current input guidance. Continue is disabled when
the selected V5 directory has no generation. New Game confirms intent, enters
the same canonical city and asks the existing persistence coordinator to write
one fresh generation. The title never becomes a second snapshot owner and no
regression deletes player generations.

The launcher no longer terminates its previously registered candidate. It
keeps that process open and refuses a duplicate until the player closes the
existing window explicitly. Short graphical regressions exit themselves and
do not leave additional long-running windows.

Responsive title checks cover 1152x648, 1280x720 and 1440x900. Engine-rendered
PNG evidence is stored beside this report under `evidence/`.

## Verification matrix

Final logs are stored under `evidence/logs/`.

Final focused totals include causal boundary 10/10, candidate save entry 6/6,
responsive title 101/101, normal early route 14/14, sourced invasion 17/17,
recovery 9/9, War Loop 16/16 plus formal timing 10/10, macro handoff 31/31,
macro victory 9/9, city governance 26/26, population pressure 42/42 and
wartime spatial battle 73/73. The associated multi-process V5, arrival,
war-loop, governance, pressure and macro-handoff persistence runners all exit
successfully. Existing accelerated normal-invasion routes A and B also finish
with empty failure lists; they remain diagnostic regressions, not substitutes
for the prior 1x evidence or human play.

| Area | Runner | Expected proof |
| --- | --- | --- |
| Causal boundary | `run_blackstone_causal_playtest_r1_smoke.gd` | pre-warning and post-warning cancellation, departed/handoff retention, same-update ordering, restore, save-failure retry, early victory continuation |
| Candidate save entry | `run_blackstone_candidate_entry_r1_smoke.gd` | empty-store state, fresh generation through the existing owner, saved Continue restore |
| Candidate layout | `run_m1b_playable_shell_smoke.gd` | labels, focus, bounds, no overlap and one canonical city at three sizes |
| Normal early route | `run_blackstone_early_counterattack_r1_journey.gd` | actual fresh resources, formal orders/battle/result, day-1 Redcliff, two-city victory and day-5 cancellation |
| Existing invasion | `run_blackstone_invasion_r0_smoke.gd` | warning, departure, arrival and handed-off behavior retained |
| Affected systems | focused war, macro siege, V5 persistence, population and spatial runners | no regression in ownership, settlement, recovery or conservation |

## Remaining boundaries

- Automated journeys and engine-rendered images are engineering evidence, not
  native-pointer feel, Founder review or human player acceptance.
- Balance is not declared final. The early route succeeds with five soldiers
  remaining and thirteen fallen in this deterministic run, so it is playable
  but deliberately costly.
- No release build, distribution package or production deployment is part of
  this candidate.
- `AGENTS.md` and project/global `MEMORY.md` are unchanged.

# R1E Implementation Report

## Candidate scope

R1E links the existing city decision, battle, settlement, and V5 persistence
owners into one durable expedition lifecycle.  It also establishes a shared
northern command-board presentation baseline for the city and C0 battle.  It
does not add a troop class, equipment, queue, road authority, strategic AI,
or a second save/resource owner.

Baseline: `f778dab3b7d044bd883a6cc578debbd42b02d18b`
Branch: `codex/txwzs-expedition-visual-r1e`
Engine: Godot `4.5.1.stable.official.f62fdbde1`

## Delivered behavior

- `GarrisonState` is now the single durable three-formation roster.  Its
  aggregate infantry view remains a compatibility projection; formation IDs
  persist even when a formation reaches zero members.
- Opening the current mainline opens a preparation panel.  It shows three
  stable formations, selection, current food, the existing formula
  `ceil(committed / maintenance_units_per_food)`, cost, remainder, and an
  explicit invalid reason.
- Confirming 1–3 formations atomically validates the current roster/mainline,
  writes one immutable V6 attempt, charges food once through `NationState`,
  persists it, and only then changes to C0.  Re-clicks cannot create another
  attempt or another food debit.
- C0 consumes only the attempt snapshot.  Reloading an active attempt restores
  the same selected formations and frozen battle facts without another debit.
- Victory, defeat, and withdrawal write survivors back per stable formation
  through the existing coordinator/ledger exactly once.  The settlement
  transaction stages city-day effects and rolls them back on failure.
- V5 saves migrate deterministically to V6 (legacy 20 infantry becomes
  7/7/6) while keeping resources, time, building, road, and mainline data.
- The visual baseline adds a shared palette/theme, city ground/road/building
  silhouettes and state cues, battle lanes/gates/faction banners, a responsive
  preparation panel, and a content-safe battle result modal.  These are
  presentation/read-model changes; spatial, battle, and save authorities are
  unchanged.

## External guidance actually applied

The registry at `docs/engineering/EXTERNAL_INTELLIGENCE_REGISTRY.md` records
the fixed source, commit, license, files read, adopted rules, and rejected
material.  This work applied its GodotPrompter test/input/responsive guidance,
Awesome Gamedev UI/feel guidance, gstack-game visual-QA/playtest checklists,
and Godot 4.5 UI/container/input documentation.  No third-party code,
installer, plugin, framework, Godot 4.7 API, or generated project material was
introduced.  Final code review used the `godot-code-review` checklist.

## Verification

| Gate | Result |
| --- | --- |
| R1E expedition causality runner | PASS, 50 assertions |
| Full dynamic regression | PASS, 55/55 runners |
| City governance regression | PASS (included in full run) |
| Topbar responsive smoke | PASS, 57 assertions |
| Editor import/parse | PASS |
| Title, city, and C0 headless smoke | PASS |
| `git diff --check` | PASS |
| Runtime console error signatures | 0 |
| Godot review | PASS; existing large-controller and legacy absolute-layout debt remain non-blocking follow-up items |

The focused runner covers selection/cost, zero-write failure, insufficient
food, duplicate confirm, selected-only battle loading, per-formation V/D/R
writeback once, scene reload/cold restore, V5 migration, rejection of tampered
V6 facts, cross-day training conservation, 44px/modal geometry/focus, and
governance-road regression.

## Native evidence

The final capture is one unedited system `screencapture` recording made after
the native Godot window was positioned at `0,30`:

```text
screencapture -v -V112 -R0,30,1152,648 -C -k -x r1e-real-input-final4.mov
```

It uses OS-level pointer input with visible cursor/click feedback; it does not
call tests, fixtures, debug shortcuts, signals, or internal battle methods.
It records city → preparation → two selected formations and visible food cost
→ battle commands → withdrawal confirmation → returned-city settlement
confirmation → normal process close → same-directory cold start.  The 112 s
duration is longer than the requested approximate 60–90 s because host UI
automation latency made a full uncut settlement/cold-restart proof take longer;
there is no cut, speed change, remux, or frame reordering.

| Artifact | Verification |
| --- | --- |
| `r1e-real-input-final4.mov` | SHA-256 `0ed752c0a69d9c6057fd8d149a32272bef747ae864bd470782c481087a518243`; H.264 (`avc1`); 1152×648; 111.980 s; 6,418 decoded frames; monotonic timestamps; full AVFoundation decode PASS |
| `01-city-default-clean.png` | Native Godot city state, 1152×648, SHA-256 `b30b5178633bd6154633c55b1e54ba659ec7fd36b91ea60e306e70c0a6ec1193` |
| `02-expedition-preparation-clean.png` | Native preparation state with selected formations/cost, 1152×648, SHA-256 `f734c55763b975a32088a5f83b03091f6ff7a4f1d7b5a1cf0f07591dd14b5d30` |
| `03-selected-formations-battle-clean.png` | Native selected-formation battle state, 1152×648, SHA-256 `7e2eddb23eb2b5a86c0297d35d7b724f9f938d72ac049affadae2b62f055b1f2` |
| `04-returned-city-summary-clean.png` | Native returned-city settlement summary, 1152×648, SHA-256 `9d4c4b37be792e7caac0a59955d727163afbd986d1c9dd99b334efcd12e01cbf` |
| `contact-sheet.png` | Native three-resolution city contact sheet, 960×1710, SHA-256 `cd159204fabafe97c712fcde239e4dc7534e0ef6c1c95c1c14f2a9ed7060bc00` |

Each retained PNG and the contact sheet was visually inspected.  The video was
inspected through ordered source frames spanning entry, preparation, live
battle/withdrawal modal, returned city, confirmed `RESOLVED_RETREAT`, and cold
restart.  No critical clipping, UI overlap, input-through-modal event, or
obvious city/battle interpenetration was observed.  These are engineering
evidence checks only: Founder visual acceptance remains pending.

## Candidate status

`PASS_R1E_ENGINEERING_CANDIDATE_FOUNDER_REVIEW_REQUIRED`.

The visual baseline is now coherent enough for a Founder review, but it is not
a declaration that the product or its art is complete.  No push, merge, or
deployment occurred.  `AGENTS.md` and `MEMORY.md` were not changed.

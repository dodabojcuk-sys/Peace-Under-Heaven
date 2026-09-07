# FIELD_TACTICS_R2 Engineering Checkpoint

## Scope and authority

This checkpoint starts from R1 source `3fbc5b9`. It adds a persistent outer-city
field record without replacing city resource authority, army ownership, or V5
publication. `FieldTacticsState` is nested in `WarLoopState`; it holds runtime
road identities, camps, specialist positions, construction projects, patrol
facts, and player knowledge. `ConstructionController` is still the sole food
transaction and persistence-checkpoint caller.

## Delivered engineering evidence

### Formal-input and repair follow-up

- Confirming a camp-building project reserves its `camp_id` and its generated
  runtime camp point immediately.  A second engineer confirmed before the
  first completion receives a distinct persisted identity.
- Repeated automatic mouse input at an overlapping army marker cycles the
  selected `army_id`; dead specialist history does not hide a replacement
  dispatch control.
- A damaged field road now remains closed while its selected engineer travels
  to the endpoint and completes a timed repair project.  The same road ID is
  restored only at completion.  A completed road can be validated in either
  direction when the submitted polyline is directionally exact.

Verification after this follow-up: `run_field_tactics_r2_smoke.gd` passes 27
assertions, `run_macro_march_r0_smoke.gd` passes 17, and
`run_field_tactics_r2_persistence_smoke.gd` passes its independent three-process
construction/restore chain.  The repair path has focused state coverage, but
not yet map-operable damaged-road selection or a dedicated repair disk chain.

- Two macro armies can be issued from distinct garrison formations. The
  registry rejects a persisted formation identity in two non-closed macro
  armies, and closed history no longer blocks a new departure.
- Existing roads are represented in a runtime graph. A field road is not open
  until its project completes; normal, reinforced, and bridge defaults are
  separate configurable record kinds. Damage affects field-road passage, while
  main roads cannot be damaged; repair preserves the road identifier.
- Scouts and engineers are dispatched via food transactions. Patrol facts are
  private to the authoritative record; the public field projection returns no
  unobserved location or strength, and observed intel becomes last-known after
  visibility is lost.
- V5 validation normalizes a real R1 nested war snapshot to the R2 field-state
  shape before exact restore verification. This preserves old city, gate,
  army, and order facts without granting map knowledge.

## Verification

Godot `4.5.1.stable.official.f62fdbde1` imported and parsed the project.

- `tests/run_field_tactics_r2_smoke.gd`: 20 assertions passed, including timed
  scout arrival and patrol contact, plus two
  independent city-keyed siege records advancing and restoring together.
- `tests/run_field_tactics_r2_persistence_smoke.gd`: three independent Godot
  processes persisted construction-in-progress, completed it after restore,
  and then cold-restored the completed road/camp.
- `tests/run_macro_march_r0_smoke.gd`: 14 assertions passed.
- `tests/run_war_loop_r1_smoke.gd`: 15 assertions passed.
- `tests/run_v5_campaign_persistence_smoke.gd`: passed, including its isolated
  three-process disk chain.

## Remaining work and evidence boundary

Follow-up engineering made the city-keyed siege records the controller's
settlement boundary and moved macro progression to the shared controller
clock. It also removed the normal-map static route-break demonstration controls
and prevents the macro read model from disclosing the authoritative field
snapshot. These changes close timing and cross-siege ownership defects, not
the remaining player-operated tactics work.

The current R2 continuation also connects a completed field road to the
controller's actual macro-order validator and duration calculation. An
engineer-selected drawn route can terminate at a newly created runtime camp;
its persisted endpoint coordinate is returned to the safe map projection. The
focused field runner now has 22 assertions. This confirms the state/command
connection, not a completed normal-input journey or road encounter loop.

The map now resolves a selected army from its visible marker. Subsequent
drafting and retreat use its identity, instead of silently targeting the first
army returned by the compatibility read model. This still needs normal-input
evidence alongside the remaining specialist and encounter work.

Field project completion and specialist encounter records now trigger the
controller's V5 checkpoint even when no siege ticks during that frame. The
controller snapshots field state before advancing and restores it if the
checkpoint fails. The existing three-process engineering chain remains green;
an immediate encounter-specific disk chain is still part of the unfinished
encounter delivery.

Specialists now carry persisted current/start/target coordinates and advance
between positions under the same shared clock. Scout visibility is a finite
coordinate radius, and an unobserved patrol remains unobserved through repeated
projection refreshes. The focused R2 runner has 23 assertions. Patrol movement,
army encounters and normal-input verification remain open.

The formal map now normalizes runtime-road records before using them as UI
drafts, eliminating the old `road_id/route_world_points` versus
`route_id/points` mismatch. Engineering drag release creates a cancellable
draft; only confirmation writes its resource transaction. The macro runner has
16 assertions including automated map-to-controller checks. This is not a
replacement for system-input evidence.

This is not a complete R2 play-flow delivery. The formal map does not yet offer
a full player-operated specialist drag-line workflow, nor does the formal
controller yet settle patrol/ambush damage against armies or apply
parallel-siege losses back to separate armies. No
safe candidate game window was locked for normal system input during this
checkpoint, so no real screenshots or recording are claimed. These gaps must
be completed before describing the R2 tactical loop as playable or accepted.

Suggested next engineering entry: make the existing city-keyed siege records
the controller's settlement loop, then bind `MacroMarchR0` selection/drawing
to the already-persisted field-road and specialist APIs. Keep
`ConstructionController` as resource/save authority.

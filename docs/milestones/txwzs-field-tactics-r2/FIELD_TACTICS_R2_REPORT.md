# FIELD_TACTICS_R2 Engineering Checkpoint

## Scope and authority

This checkpoint starts from R1 source `3fbc5b9`. It adds a persistent outer-city
field record without replacing city resource authority, army ownership, or V5
publication. `FieldTacticsState` is nested in `WarLoopState`; it holds runtime
road identities, camps, specialist positions, construction projects, patrol
facts, and player knowledge. `ConstructionController` is still the sole food
transaction and persistence-checkpoint caller.

## Delivered engineering evidence

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

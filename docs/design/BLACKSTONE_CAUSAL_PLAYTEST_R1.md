# Blackstone causal boundary and playtest candidate R1

Baseline: `5bb22dc533dae749c2648ffc9ce18ea67f6240b1`.

## Product rule

The authored Blackstone first invasion remains one record in
`FieldTacticsState.patrols_by_id`.

- At the day-5 departure gate, Redcliff control is read again from
  `WarLoopState.cities_by_id`.
- If Redcliff is already player-controlled, the dormant invasion becomes
  `CANCELLED`. The same record stores the cancellation reason and authoritative
  campaign day. It is never replaced by another event or patrol.
- Once the record is `INVADING`, `ARRIVED` or `HANDED_OFF`, later control
  changes cannot cancel, recreate or rewind it. Its identity, strength,
  position, route, damage and battle transaction remain authoritative.
- `DEFEATED`, `CANCELLED` and `RESOLVED` are terminal across time advance,
  restoration and later city-control changes.
- A restored old save is interpreted only from its existing phase. Existing
  non-dormant records are retained. A dormant record is decided only when it
  next reaches the departure gate; no historical ordering is invented.

## Same-update ordering

The existing controller order remains the authority: city time advances,
player macro armies and their arrival/occupation transactions advance, then
configured field departures are resolved. Therefore a Redcliff occupation
committed in the same controller update as the day-5 gate wins the tie and
cancels the still-dormant invasion. A departure committed by an earlier update
is retained. UI refresh order is never consulted.

This is a bounded ordering rule for configured departures, not a world-clock
rewrite. The existing source-specific battle clock behavior remains unchanged.

## Victory and continuation

Victory remains derived only from current military control of Redcliff and
Silverford. It is not gated by defending Blackstone. Completing the objective
does not delete a departed patrol, an arrived force, a handed-off battle,
recovery work or an existing player army. The normal field and city action
surfaces remain available after the one-time victory fact is true.

## Acceptance and verification

- Occupy Redcliff before warning and after warning but before departure.
- Occupy it after departure and after defense handoff.
- Cover the same-update tie at multiple frame partitions.
- Restore cancelled, marching and active-defense facts without regeneration.
- Inject checkpoint failure and prove cancellation rollback and retry.
- Complete both required cities early and continue legal outstanding work.
- Run an early-counterattack journey through formal commands and regress the
  existing normal-invasion journey. If normal resources and timings cannot
  reach Redcliff before departure, report that limit rather than relabeling a
  fixture as a player journey.

Automated engine journeys, screenshots and recordings remain engineering
evidence. Human play acceptance is a separate open gate.

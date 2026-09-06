# WAR_LOOP_BATCH_R1 Engineering Candidate Report

## Scope

This local candidate starts from `a5fda3dd` and implements only the requested
outer-city war loop: macro attack arrival, surrender-or-siege resolution,
gate/guard occupation, retreat, durable state, and focused regression. It does
not add fog, roads strategy, generals, specialist units, art production, 3D,
remote changes, or deployment.

## Authority and model

`ConstructionController` remains the sole writer for food, the exact selected
formation extraction, `ArmyRegistry`, and the existing runtime save checkpoint.
The narrow `V5ArmyDispatchAdapter` is still the only macro screen command path.
`WarLoopState` is a serializable domain record rather than a new scene-local
battle owner: it stores enemy military control, gate and guard totals, active
siege tick, attacker facts, and completed resolution identifiers.

The battle order is deterministic: arrival checks configured surrender ratios;
on refusal, attacker damage targets the gate until breached and then guards,
while living guards retaliate. `UnitRole` HP/attack/armor and the committed
army count are the attacker inputs. Occupation changes military control only;
story ownership is intentionally retained. Retreat applies the configured
minimum/proportional loss, returns the same army over its reversed recorded
route, and does not create a second food transaction.

## Persistence

`V5CampaignSnapshot` schema 7 includes `war_loop`; schema 6 is migrated to an
empty schema-7 war record. `ArmyRegistry` schema 3 preserves SIEGING and
RETREATING macro phases. Restore cross-validates any active siege against the
stored army/order before applying it. This is a cold-recovery engineering
claim, not a player acceptance claim.

## Verification

- Godot `4.5.1.stable.official.f62fdbde1` editor import/parse completed.
- `tests/run_war_loop_r1_smoke.gd`: 9 assertions passed.
- `tests/run_macro_march_r0_smoke.gd`: 14 assertions passed.
- `tests/run_macro_march_r0_persistence_smoke.gd`: passed.
- `git diff --check`: passed.

## Evidence boundary

The focused scripts verify authority, deterministic state transitions, and
cold restore. They do not demonstrate normal mouse-drawn play, a continuous
player recording, Founder review, Founder acceptance, or a released siege
victory. `REAL_INPUT_MEDIA=NOT_PROVIDED` for this candidate.

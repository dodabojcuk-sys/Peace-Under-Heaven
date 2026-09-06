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
minimum/proportional loss, records the immutable outgoing order, creates a new
return order over its reversed route, and does not create a second food
transaction. A zero-survivor retreat/defeat closes the army explicitly rather
than leaving a zero-count active formation.

## Persistence

`V5CampaignSnapshot` schema 7 includes `war_loop`; schema 6 is migrated to an
empty schema-7 war record. `ArmyRegistry` schema 4 preserves siege/retreat/
closed macro phases and normalizes prior registry snapshots with an empty order
history. Restore rejects malformed nested city/siege facts and cross-validates
any active siege against the stored army/order before applying it. This is a
cold-recovery engineering claim, not a player acceptance claim.

## Verification

- Godot `4.5.1.stable.official.f62fdbde1` editor import/parse completed.
- `tests/run_war_loop_r1_smoke.gd`: 15 assertions passed.
- `tests/run_war_loop_disk_recovery_smoke.gd`: 3 assertions passed; its A/B/C
  processes persisted tick 1, restored and advanced exactly one tick, then
  restored tick 2 from the same isolated V5 directory.
- `tests/run_war_loop_formal_scene_smoke.gd`: 10 assertions passed through the
  formal city entry, including outer-city ticking, CLOSED reissue, and frame
  split/pause/speed equivalence.
- `tests/run_war_loop_arrival_persistence_smoke.gd`: 3 assertions passed;
  separate processes immediately loaded Redcliff siege creation, first-city
  completion/Silverford surrender, then the completed two-city state.
- `tests/run_macro_march_r0_smoke.gd`: 14 assertions passed.
- `tests/run_macro_march_r0_persistence_smoke.gd`: passed.
- `tests/run_v5_campaign_persistence_smoke.gd`: passed.
- `tests/run_r1e_expedition_causality_smoke.gd`: 50 assertions passed.
- `tests/run_m1b_playable_shell_smoke.gd`: 44 assertions passed.
- `git diff --check`: passed.

## Evidence boundary

The focused scripts verify authority, deterministic state transitions, and
cold restore. They do not demonstrate normal mouse-drawn play, a continuous
player recording, Founder review, Founder acceptance, or a released siege
victory. `REAL_INPUT_MEDIA=NOT_PROVIDED` for this candidate.

The candidate may be parsed/run from the isolated worktree with:

```sh
GODOT_BIN="/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --path /Users/m4-zhi/Documents/codex-workspace/txwzs-war-loop-r1
```

The production runtime accepts `--txwzs-v5-save-dir=<absolute path>` after
`--`. Do not use an existing player save for review; the focused persistence
runners create their own runner-specific temporary directories.
The only available desktop Godot window belonged to another branch, and the
new candidate `e0eec91` window was launched with its own `--txwzs-v5-save-dir`
and exact runtime identity, but the desktop automation still exposed only that
pre-existing R1E window. No input was sent to either window; the identified
candidate process was terminated normally, and no startup capture is
represented as player-operation evidence.

## Source synchronization

The authorized ordinary push of `codex/txwzs-war-loop-r1` was attempted once
after the final local engineering checkpoint, using non-interactive HTTPS and
a bounded connect/low-speed timeout. Git reported `Operation too slow` before
any bytes were transferred. No credentials were read or printed; no remote ref,
force push, merge, tag, deployment, or protection change occurred.

`SOURCE_SYNC=BLOCKED_NETWORK`. The local handoff therefore includes the exact
commit and a complete `git archive` source bundle with SHA-256 in the untracked
`delivery/TXWZS_WAR_LOOP_BATCH_R1_<commit>/` directory; this is a review
artifact, not proof of remote upload or acceptance.

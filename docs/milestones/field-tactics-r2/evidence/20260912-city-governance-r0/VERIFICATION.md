# Blackstone City Governance R0 Verification

## Candidate scope

This checkpoint connects aggregate population staffing, daily food, health,
disease, seasons, housing and one basic security intervention to the existing
regular-city authority. It does not implement individual residents, civil
official abilities, equipment or trade, and it is not player acceptance.

## Player-visible flow

- The existing city governance workspace shows the current issue, its cause,
  staffing, health, housing, security and the available action.
- Visible controls reassign production, construction, medical and governance
  staff without creating people.
- `民居` and `医舍` use the normal construction/road/resource path and add
  capacity only after completion.
- Sustained shortage creates recoverable disease and one stable petty-theft
  event. A governance action requires staff and spends two food once.

## Executed checks

Godot: `4.5.1.stable.official.f62fdbde1` at the repository root.

- `run_city_governance_r0_smoke.gd`: PASS, 26 assertions.
- `run_city_governance_r0_persistence_smoke.gd`: PASS; three independent Godot
  processes preserved shortage, disease, event identity and one-time cost.
- `run_city_governance_r0_graphical_smoke.gd`: PASS, 6 assertions; 1152x648,
  1280x720 and 1920x1080. It requires an explicit empty
  `--txwzs-v5-save-dir` and refuses to run against the player's default save.
- `run_blackstone_recovery_r0_smoke.gd`: PASS, 9 assertions.
- `run_field_stationed_reinforcement_r0_smoke.gd`: PASS, 5 assertions; the
  finite Silverford pool, selected formation and population ledger conserve
  the same people, including checkpoint-failure rollback.
- `run_war_loop_formal_scene_smoke.gd`: PASS, 10 assertions.
- `run_field_tactics_r2_smoke.gd`: PASS, 72 assertions.
- `run_field_tactics_r2_playthrough_smoke.gd`: PASS, 7 assertions; both direct
  and engineering routes still finish, including Silverford reinforcement,
  supply and mid-route V5 restore.
- `run_v5_campaign_persistence_smoke.gd`: PASS, including its three cold
  processes.
- `run_blackstone_invasion_r0_smoke.gd`: PASS, 17 assertions and 29 steps.

## Evidence type and limits

The PNG files in this directory are actual Godot root-viewport captures from
the candidate. Staffing and governance actions use visible engine GUI button
signals; shortage days are a controlled accelerated fixture. They are not
native macOS mouse input and do not establish normal-speed player feel.

- `city-governance-default-1152x648.png`
- `city-governance-default-1280x720.png`
- `city-governance-default-1920x1080.png`
- `city-governance-pressure-action-1280x720.png`
- `city-governance-resolved-1280x720.png`

Player acceptance remains **OPEN**. Civil officials, equipment and trade remain
the next functional gaps.

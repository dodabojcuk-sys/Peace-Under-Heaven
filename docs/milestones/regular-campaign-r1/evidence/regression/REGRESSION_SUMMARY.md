# Regular Campaign R1 Focused Regression

Run with Godot 4.5.1 headless from this worktree. Each persistence runner kept
its own test-managed save directory; no shared player-save override was passed.

| Runner | Result marker | Script errors |
| --- | --- | --- |
| `run_p0_01_national_read_model_smoke` | `P0_01_NATIONAL_READ_MODEL_SMOKE PASS` | 0 |
| `run_r2c01_national_resource_convergence_smoke` | `R2C01_NATIONAL_RESOURCE_CONVERGENCE_SMOKE PASS` | 0 |
| `run_v5_campaign_persistence_smoke` | `V5_CAMPAIGN_PERSISTENCE_SMOKE PASS` | 0 |
| `run_v5_army_state_smoke` | `V5_ARMY_STATE_SMOKE PASS` | 0 |
| `run_v5_training_queue_smoke` | `V5_TRAINING_QUEUE_SMOKE PASS` | 0 |
| `run_normal_city_building_growth_r1_persistence_smoke` | `NORMAL_CITY_BUILDING_GROWTH_R1_PERSISTENCE_SMOKE PASS` | 0 |
| `run_city_population_pressure_r0_persistence_smoke` | `CITY_POPULATION_PRESSURE_R0_PERSISTENCE_SMOKE PASS` | 0 |
| `run_city_governance_r0_persistence_smoke` | `CITY_GOVERNANCE_R0_PERSISTENCE_SMOKE PASS` | 0 |
| `run_macro_march_r0_persistence_smoke` | `MACRO_MARCH_R0_PERSISTENCE_SMOKE PASS` | 0 |
| `run_blackstone_causal_playtest_r1_smoke` | `BLACKSTONE_CAUSAL_PLAYTEST_R1_SMOKE PASS assertions=10` | 0 |
| `run_campaign_time_consistency_r1_smoke` | `CAMPAIGN_TIME_CONSISTENCY_R1_SMOKE PASS assertions=34` | 0 |
| `run_regular_campaign_r1_journey` | no script marker; exit 0, `FINAL COMPLETED []`, no V5 validation error | 0 |

The national-resource convergence runner initially exposed only its stale
current-version assertion (`17`). It was updated to the approved schema `18`,
then rerun successfully. Historical migration fixtures were unchanged.

The normal-city building-growth persistence runner was rerun after the
zero-value construction payment-ledger repair and passed again.

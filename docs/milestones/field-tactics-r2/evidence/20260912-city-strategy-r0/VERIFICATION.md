# City Strategy R0 Verification

## Candidate identity

- Starting baseline: `82fbe3248dd91a58e5f28c9bad94cddb80388a0c`
- Branch: `codex/txwzs-field-tactics-r2`
- Engine: Godot `4.5.1.stable.official.f62fdbde1`
- Project: `/Users/m4-zhi/Documents/codex-workspace/txwzs-field-tactics-r2`

All persistence and graphical runners used a fresh `--txwzs-v5-save-dir` under
`/tmp`. They did not load or overwrite a retained player candidate.

## Player-visible entry

The existing city governance surface exposes one `战略支持 · 文官 / 装备 / 贸易`
button. It opens a separate scrollable workspace. Engine GUI button events were
used to appoint the physician, activate support, craft and equip the infantry
spear kit, and execute the wood-for-food trade. The 1280x720 capture shows the
actual equipped item and the trade receipt's resulting inventory.

These captures are Godot GUI-event/render evidence, not native macOS pointer or
human-feel acceptance:

- `city-strategy-overview-1152x648.png`
- `city-strategy-overview-1280x720.png`
- `city-strategy-overview-1920x1080.png`
- `city-strategy-support-active-1280x720.png`
- `city-strategy-equipment-trade-1280x720.png`

## Functional coverage

| Area | Verified R0 behavior | Explicit remaining scope |
| --- | --- | --- |
| Officials | deterministic fresh-campaign roster; appointment; production, medical and defense support; campaign energy; expiry and save-failure retry | more officials, reward progression and in-battle active commands |
| Troop equipment | deterministic manufacture; unique ownership; reversible equip/unequip; attack, protection and mobility effects; published march duration remains frozen | upgrade, rank and experience progression |
| General equipment | six stable slots; weapon, armor and boots have authored R0 items and formal effects | authored helmet, gloves and accessory items; progression rules |
| Trade | two authored exchanges; spend/gain/capacity preview; once-per-day receipt; no-arbitrage prices | caravans, market simulation and automatic trade |
| Persistence | V15 strict state, conservative V14 and earlier migration, independent A/B/C process recovery | human interruption testing at normal speed |

## Commands and observed results

All commands use:

```sh
GODOT=/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot
```

- `--headless --path . --script res://tests/run_city_strategy_r0_smoke.gd`
  - PASS, 18 assertions.
  - Covers actual building production calculation, medical capacity, formal
    march duration, formal attack/defense snapshot, six-slot general loadout,
    transaction rollback and expiry-save retry.
- `--headless --path . --script res://tests/run_city_strategy_r0_persistence_smoke.gd`
  - PASS. Independent A/B/C Godot processes preserve one receipt, two remaining
    energy, equipped mobility gear and the same in-flight army; day two expires
    support without replenishing energy.
- graphical `--path . --script res://tests/run_city_strategy_r0_graphical_smoke.gd`
  - PASS, 14 assertions at 1152x648, 1280x720 and 1920x1080.
  - Visible controls perform appointment, support, manufacture, loadout,
    reversible unequip and trade.
- `run_city_governance_r0_smoke.gd`: PASS, 26 assertions.
- `run_blackstone_recovery_r0_smoke.gd`: PASS, 9 assertions.
- `run_blackstone_invasion_r0_smoke.gd`: PASS, 17 assertions / 29 steps. This
  includes formal defense, battle losses, treatment and a later counterattack.
- `run_field_tactics_r2_smoke.gd`: PASS, 72 assertions.
- `run_v5_campaign_persistence_smoke.gd`: PASS, including three independent
  save/restore processes.
- `run_field_tactics_r2_playthrough_smoke.gd`: PASS, 7 assertions. Route A and
  route B both reach the two-city result; the engineering route also preserves
  reinforcement and supply transactions across V5 restore.
- `run_macro_siege_wartime_victory_smoke.gd`: PASS, 7 assertions. The original
  army reaches one authoritative siege victory and duplicate confirmation is
  idempotent.

## Baseline diagnostic, not a new regression

`run_macro_march_r0_smoke.gd` still reports three failures in its location-detail
subflow: occupied-city garrison detail, continued order from that city, and the
completed engineering-camp restore assertion. The exact three failures were also
reproduced from an archived clean checkout of parent `82fbe324`, so this candidate
does not claim to have fixed or introduced them. The stronger current route A/B
playthrough and focused strategy integration checks above pass.

## Acceptance boundary

This verification proves formal inputs, authoritative calculations, rollback and
cold recovery. It does not prove native-pointer feel or a human, unaccelerated
full campaign. Player acceptance therefore remains **OPEN**. The earlier stall
remains **NOT REPRODUCED / NOT DIAGNOSED**.

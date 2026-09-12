# Blackstone First Defense Loop Verification

## Scope

This checkpoint connects one authored Redcliff invasion to Blackstone's formal
wartime-defense transaction and adds a persistent field defense line composed
of a watchtower, arrow tower and barricade. It preserves the existing
counterattack, siege takeover and occupation flow.

## Commands executed

Godot executable:

`/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot`

- `--headless --editor --path . --quit-after 2`
- `--headless --path . --script res://tests/run_blackstone_invasion_r0_smoke.gd`
- `--headless --path . --script res://tests/run_field_tactics_r2_playthrough_smoke.gd`
- `--headless --path . --script res://tests/run_macro_siege_wartime_handoff_smoke.gd`
- `--path . --script res://tests/run_blackstone_campaign_r0_graphical_smoke.gd -- --txwzs-v5-save-dir=<isolated>/saves --txwzs-blackstone-campaign-evidence-dir=<this-directory>`

## Results and causal evidence

- `BLACKSTONE_INVASION_R0_SMOKE PASS assertions=16 steps=29`: one configured
  force warns, departs once, accepts actual encounter losses, moves on the
  authored road, hands off its surviving count, completes a real
  three-formation C0 defense, confirms the result once and returns with the same
  invasion resolved. A separately eliminated instance cannot open a gate
  defense. The runner also covers restore/migration and real arrow-tower,
  barricade and repair effects, plus rejection of an impossible facility
  durability snapshot without state pollution.
- `FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE PASS assertions=7`: both the direct-army
  route and the optional engineering route still reach the existing campaign
  results with real food, casualty, supply and army identities.
- `MACRO_SIEGE_WARTIME_HANDOFF_SMOKE PASS assertions=31`: the counterattack
  still uses the original army and order through siege, C0 takeover and
  victory/retreat/defeat/full-wipe settlement without a second food charge.
- `BLACKSTONE_CAMPAIGN_R0_GRAPHICAL_SMOKE PASS assertions=4`: isolated engine
  GUI input builds a camp, bridge and all three external defense kinds through
  the visible controls and Controller world frames.

The fourteen PNGs in this directory show the connected field engineering
sequence. `campaign-14-field-defense-line-engine-gui.png` is the final durable
three-facility state. The fixture accelerates Controller frames and seeds an
engineer before visible construction; it does not edit control, troop HP or a
battle result after the flow starts.

## Warning boundary

The long field playthrough still emits `ObjectDB instances leaked at exit`.
Verbose inspection found four `AudioStreamGeneratorPlayback` instances and four
`Master` StringName orphans at test-process shutdown. The same warning exists in
the pre-checkpoint route-B evidence, so this run did not establish a new field
authority or facility leak. It remains a test-exit/audio cleanup issue unless a
continuous runtime accumulation reproduction appears.

## Acceptance boundary

These are deterministic engine tests, synthetic GUI input, isolated saves and
screenshots. They verify implementation continuity, not native macOS pointer
feel, final balance, or a human unaccelerated full-session playthrough. Player
experience acceptance remains **OPEN**.

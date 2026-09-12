extends SceneTree

const CITY := preload("res://scenes/blank_map.tscn")
const THEATER := preload("res://scripts/macro_march/macro_march_theater.gd")
var failures: Array[String] = []
var assertions := 0
var scene: Node
var city: Node
var battle: C0BattleGraybox
var evidence := ""

func _initialize() -> void:
	if use_defense():
		THEATER.use_playable_definition()
	else:
		THEATER.use_regression_definition_for_tests()
	call_deferred("run")

func use_defense() -> bool:
	return "--defense" in OS.get_cmdline_user_args()

func run() -> void:
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			evidence = argument.trim_prefix("--evidence=")
	scene = CITY.instantiate()
	root.add_child(scene)
	await frames(3)
	city = scene.get_node("ConstructionController")
	city.set_process(false)
	if use_defense():
		await defense_flow()
	else:
		await assault_flow()
	scene.queue_free()
	await frames(2)
	for failure in failures:
		push_error("WARTIME_SPATIAL_R1 FAIL: " + failure)
	print("WARTIME_SPATIAL_R1 %s assertions=%d" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)

func assault_flow() -> void:
	check(city.appoint_city_official(&"official.strategist").get("success", false), "existing strategist appointed through city transaction")
	city.food = 120
	var roster: Array = city.get_formation_roster()
	var road: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var sent: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id), StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(road.route_id), Array(road.points))
	check(sent.get("success", false), "original formations depart through normal army transaction")
	var army: Dictionary = sent.get("army", {})
	if army.is_empty(): return
	var army_id := StringName(army.army_id)
	var march: Dictionary = army.macro_march
	city.advance_macro_march_time(army_id, StringName(march.order_id), 0, int(march.total_millis))
	road = THEATER.get_route(&"road.northwatch.redcliff")
	sent = city.commit_macro_march_from_station(army_id, &"redcliff_city", StringName(road.route_id), Array(road.points))
	march = sent.army.macro_march
	city.advance_macro_march_time(army_id, StringName(march.order_id), 0, int(march.total_millis))
	var food_before := int(city.food)
	check(scene.open_macro_march_r0(), "normal city opens external war theatre")
	var theatre := scene.get_node("UI/MacroMarchR0") as MacroMarchR0
	theatre._selected_army_id = army_id
	theatre.refresh()
	await capture("assault-00-field-siege")
	check(theatre._siege_battle_button.visible and not theatre._siege_battle_button.disabled, "formal siege entry is available on the war map")
	theatre._siege_battle_button.pressed.emit()
	await frames(3)
	battle = city.get_formal_battle_scene()
	if battle == null: check(false, "battle exists"); return
	check(battle.spatial_view != null, "formal source uses spatial map")
	battle.select_squad(1)
	battle.spatial_view.selected_route = &"FRONT_GATE"
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_SIEGE_RAM)
	battle.select_squad(2)
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_ARROW_TOWER)
	var wood := int(city.wood)
	battle._confirm_wartime_facility_plan()
	check(int(city.wood) == wood - 18, "ram and tower use one existing resource transaction")
	var selection_click := InputEventMouseButton.new()
	selection_click.button_index = MOUSE_BUTTON_LEFT
	selection_click.pressed = true
	selection_click.position = battle.spatial_view.screen(BattlefieldSpace.point(0, 24))
	battle.spatial_view._gui_input(selection_click)
	check(battle._selected_squad_id == 1, "map input selects the visible formation")
	selection_click.position = battle.spatial_view.screen(BattlefieldSpace.point(20, 24))
	battle.spatial_view._gui_input(selection_click)
	check(battle.spatial_view.draft.get("1") == BattlefieldSpace.point(20, 24), "map input creates legal spatial deployment")
	var invalid_deployment := InputEventMouseButton.new()
	invalid_deployment.button_index = MOUSE_BUTTON_LEFT
	invalid_deployment.pressed = true
	invalid_deployment.position = battle.spatial_view.screen(BattlefieldSpace.point(40, 24))
	battle.spatial_view._gui_input(invalid_deployment)
	check(not battle.spatial_view.draft.has("1"), "invalid deployment clears previous draft")
	await capture("assault-01-deployment")
	check(battle.start_battle(false), "original army activates")
	battle.tick_timer.stop()
	var s := battle.coordinator.active_session
	check(int(city.food) == food_before, "entry does not charge departure food twice")
	var frozen := battle.request.committed_force.get_digest()
	var start := s.get_snapshot()
	check(BattlefieldSpace.deploy(s, 1, BattlefieldSpace.point(20, 24)).is_empty(), "legal staging deployment accepted")
	check(s.request.committed_force.get_digest() == frozen and s.squads == start.squads, "deployment preserves frozen formations and HP")
	check(not BattlefieldSpace.deploy(s, 1, BattlefieldSpace.point(76, 24)).is_empty(), "forward deployment rejected")
	check(s.restore_snapshot(start), "full snapshot restores before path checks")
	if DisplayServer.get_name() == "headless":
		spatial_checks(s)
	check(s.restore_snapshot(start), "isolated checks restore exact starting session")
	await advance_visible(80)
	check(int(s.spatial_state.units["1"][0]) > 0 and int(s.wartime_facility_state.facilities[0].progress_ticks) == 0, "crew travels before ram preparation")
	await capture("assault-02-crew-approach")
	battle.select_squad(1)
	var energy := int(city.get_city_strategy_read_model().campaign_energy)
	battle.spatial_view.selected_route = &"SIDE_GATE"
	battle._on_official_support_selected(4)
	check(int(city.get_city_strategy_read_model().campaign_energy) == energy - 1 and not s.official_support_state.effects.is_empty(), "visible domain command uses shared energy")
	check(s.official_support_state.effects[0].route_id == &"SIDE_GATE", "map-selected domain target overrides frozen source route")
	await capture("assault-02-domain-coverage")
	for i in 260:
		if s.wartime_facility_state.facilities.all(func(r: Dictionary): return r.phase == s.FACILITY_PHASE_ACTIVE): break
		await advance_visible(1)
	if s.wartime_facility_state.facilities[0].phase in [s.FACILITY_PHASE_INTERRUPTED, s.FACILITY_PHASE_DESTROYED, s.FACILITY_PHASE_DAMAGED]:
		battle.select_squad(1)
		battle.spatial_view.selected_route = &"FRONT_GATE"
		battle._selected_repair_facility_id = &"siege_ram-front_gate"
		battle._repair_damaged_wartime_facility()
		battle.step_battle_for_test(8)
	check(s.wartime_facility_state.facilities.all(func(r: Dictionary): return r.phase == s.FACILITY_PHASE_ACTIVE), "crews reach separate work positions and finish paid works")
	check(int(s.routes[&"FRONT_GATE"].gate_hp) <= int(start.routes[&"FRONT_GATE"].gate_hp) - s.SIEGE_RAM_GATE_DAMAGE, "ram damages gate only after physical approach and preparation")
	await capture("assault-03-ram-and-tower")
	for squad in s.squads:
		battle.select_squad(int(squad.squad_id))
		var attack_click := InputEventMouseButton.new()
		attack_click.button_index = MOUSE_BUTTON_LEFT
		attack_click.pressed = true
		attack_click.position = battle.spatial_view.screen(BattlefieldSpace.point(80, 24))
		battle.spatial_view._gui_input(attack_click)
		check(s.spatial_state.tasks[str(squad.squad_id)].kind == "ATTACK", "map gate input submits attack order")
	var outcome := await advance_visible(400)
	check(outcome != null and outcome.outcome == BattleOutcome.Value.VICTORY, "spatial assault reaches victory")
	await capture("assault-04-result-pending")
	if outcome == null: return
	var summary := battle.confirm_pending_result()
	check(not summary.is_empty() and battle.confirm_pending_result() == summary, "result confirmation idempotent")
	check(city.get_army_state(army_id).phase == ArmyRegistry.PHASE_STATIONED, "same army stationed after victory")
	check(battle.request_return_to_city() != null, "formal result returns to theatre")
	await frames(5)
	check(city.get_formal_battle_scene() == null, "temporary battle scene released")
	await capture("assault-05-return")

func spatial_checks(s: BattleSession) -> void:
	var start := s.get_snapshot()
	# No implicit path through the front gate; the open side entrance is a legal flank.
	var closed_side: Dictionary = s.routes[&"SIDE_GATE"].duplicate(true)
	s.routes[&"SIDE_GATE"].gate_hp = 100
	check(BattlefieldSpace.path(s, BattlefieldSpace.point(60, 24), BattlefieldSpace.point(100, 24)).is_empty(), "closed gates disconnect inside from outside")
	s.routes[&"SIDE_GATE"] = closed_side
	check(not BattlefieldSpace.path(s, BattlefieldSpace.point(20, 24), BattlefieldSpace.point(60, 64)).is_empty(), "cross connection supports real lateral movement")
	check(not BattlefieldSpace.command(s, 1, "MOVE", [333, 333], &"FRONT_GATE").is_empty() and s.get_snapshot() == start, "invalid target neither spends nor replays stale draft")
	var order := BattlefieldSpace.command(s, 1, "MOVE", BattlefieldSpace.point(60, 64), &"SIDE_GATE")
	check(order.is_empty(), "cross-route move accepted without changing source")
	s.step_tick()
	var moving := s.get_snapshot()
	var restored := BattleSession.new(s.request)
	restored.apply_macro_siege_start_state(s.request.macro_siege_start_state)
	check(restored.restore_snapshot(moving) and restored.get_snapshot() == moving, "moving position target HP and remaining path restore exactly")
	for i in 12:
		s.step_tick()
		restored.step_tick()
	check(s.get_snapshot() == restored.get_snapshot(), "restore continues identical deterministic movement")
	var malformed := moving.duplicate(true)
	malformed.spatial_state.units["1"] = [333, 333]
	check(not restored.restore_snapshot(malformed), "off-corridor save rejected")
	check(s.restore_snapshot(start), "fresh current schema accepted")
	var legacy := start.duplicate(true)
	legacy.schema_version = 8
	legacy.erase("spatial_state")
	check(s.restore_snapshot(legacy), "schema eight active battle migrates")
	check(s.current_tick == int(start.current_tick) and s.squads == start.squads and s.routes == start.routes and s.wartime_facility_state == start.wartime_facility_state, "migration preserves old HP progress gates and completed work")
	check(s.restore_snapshot(start), "restore current before support tests")
	BattlefieldSpace.command(s, 1, "MOVE", BattlefieldSpace.point(20, 24), &"FRONT_GATE")
	s.step_tick()
	check(s.wartime_facility_state.facilities[0].phase == s.FACILITY_PHASE_INTERRUPTED, "move command interrupts assigned construction")
	var before_move := int(s.spatial_state.units["1"][0])
	check(not s.issue_official_support(s.SUPPORT_MOVE, 1).is_empty(), "movement buff applies to live target")
	s.step_tick()
	check(int(s.spatial_state.units["1"][0]) - before_move > int(s.request.committed_force.move_speed_fixed / 4), "haste affects physical distance per tick")
	check(s.restore_snapshot(start), "support fixture restored")
	# Domain follows the actual corridor, independent of frozen origin.
	s.spatial_state.units["1"] = BattlefieldSpace.point(60, 64)
	check(not s.issue_official_support(s.SUPPORT_DOMAIN, 1, &"SIDE_GATE").is_empty(), "side corridor field created")
	check(s._support_basis_points(s.SUPPORT_ATTACK, 1, &"FRONT_GATE") > s.BASIS_POINTS, "field uses physical position")
	s.spatial_state.units["1"] = BattlefieldSpace.point(60, 44)
	check(s._support_basis_points(s.SUPPORT_ATTACK, 1, &"SIDE_GATE") == s.BASIS_POINTS, "leaving corridor removes domain benefit")
	s.spatial_state.units["1"] = BattlefieldSpace.point(60, 64)
	for i in s.SUPPORT_DURATION_TICKS: s.step_tick()
	check(s.official_support_state.effects.is_empty(), "domain expires on battle ticks")
	check(s.restore_snapshot(start), "medical boundary fixture restored")
	s.squads[0].total_hp -= 7
	var live_before := s._alive_members(int(s.squads[0].total_hp))
	check(not s.issue_official_support(s.SUPPORT_HEAL, 1).is_empty() and s._alive_members(int(s.squads[0].total_hp)) == live_before, "medical station repairs partial living HP without resurrection")
	s.squads[0].total_hp -= 7
	s.spatial_state.units["1"] = BattlefieldSpace.point(60, 24)
	check(s.issue_official_support(s.SUPPORT_HEAL, 1).is_empty(), "medical station rejects out-of-range target")
	check(s.restore_snapshot(start), "retreat exposure fixture restored")
	s.spatial_state.units["1"] = BattlefieldSpace.point(76, 24)
	s.current_tick = 3
	var exposed_hp := int(s.squads[0].total_hp)
	BattlefieldSpace.command(s, 1, "RETREAT", [], &"FRONT_GATE")
	s.step_tick()
	check(int(s.squads[0].total_hp) < exposed_hp and not bool(s.squads[0].exited), "retreating formation remains exposed to in-range enemy fire")
	check(s.restore_snapshot(start), "crew casualty fixture restored")
	s.squads[0].total_hp = 0
	s.step_tick()
	check(s.wartime_facility_state.facilities[0].phase == s.FACILITY_PHASE_INTERRUPTED, "dead crew cannot complete or continue construction")
	var frame_reference := {}
	for fps in [30, 60, 120]:
		check(s.restore_snapshot(start), "frame comparison restores exact baseline")
		battle._spatial_elapsed_seconds = 0.0
		for frame in fps * 2:
			battle.advance_spatial_frame(1.0 / fps)
		if frame_reference.is_empty(): frame_reference = s.get_snapshot()
		else: check(s.get_snapshot() == frame_reference, "display frame rate preserves fixed ticks movement and damage")
	check(s.current_tick == 8, "two real seconds produce exactly eight battle ticks")
	check(s.restore_snapshot(start), "irregular frame comparison restores baseline")
	battle._spatial_elapsed_seconds = 0.0
	for repeat in 8:
		for delta in [0.013, 0.137, 0.09, 0.01]: battle.advance_spatial_frame(delta)
	check(s.get_snapshot() == frame_reference, "irregular render frames preserve exact simulation result")
	var terminal_reference := {}
	for fps in [30, 60, 120]:
		var candidate := BattleSession.new(s.request)
		candidate.apply_macro_siege_start_state(s.request.macro_siege_start_state)
		check(candidate.restore_snapshot(start), "full battle frame comparison restores baseline")
		for squad in candidate.squads:
			BattlefieldSpace.command(candidate, int(squad.squad_id), "ATTACK", [], &"SIDE_GATE")
		var elapsed := 0.0
		for frame in fps * 1800:
			elapsed += 1.0 / fps
			while elapsed + 0.000000001 >= 0.25 and not candidate.completed:
				elapsed -= 0.25
				candidate.step_tick()
			if candidate.completed: break
		check(candidate.completed, "frame comparison reaches actual terminal battle")
		var terminal := {
			"result": candidate.result.get_authority_snapshot() if candidate.result != null else {},
			"tick": candidate.current_tick,
			"squads": candidate.squads.duplicate(true),
			"routes": candidate.routes.duplicate(true),
			"spatial": candidate.spatial_state.duplicate(true),
			"works": candidate.wartime_facility_state.duplicate(true),
			"support": candidate.official_support_state.duplicate(true),
		}
		if terminal_reference.is_empty(): terminal_reference = terminal
		else: check(terminal == terminal_reference, "full terminal HP losses gates and tick match across frame rates")
	check(s.restore_snapshot(start), "retreat fixture restored")
	BattlefieldSpace.deploy(s, 1, BattlefieldSpace.point(20, 24))
	BattlefieldSpace.command(s, 1, "RETREAT", [], &"FRONT_GATE")
	s.step_tick()
	check(not bool(s.get_squad_state(1).exited), "retreat is not instant removal")
	for i in 100:
		if s.get_squad_state(1).exited: break
		s.step_tick()
	check(s.get_squad_state(1).exited and s.spatial_state.units["1"] == BattlefieldSpace.point(0, 24), "retreat must reach evacuation edge")

func defense_flow() -> void:
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	city.current_day = 5
	field.activate_configured_invasions(5)
	for i in 120:
		if field.get_blackstone_invasion().phase == FieldTacticsState.INVASION_ARRIVED: break
		city.advance_war_loop_time(1000)
	check(field.get_blackstone_invasion().phase == FieldTacticsState.INVASION_ARRIVED, "same sourced invasion reaches Blackstone by road")
	check(bool(city.appoint_city_official(&"official.strategist").get("success", false)), "appoint battle support official through city transaction")
	var roster: Array = city.get_formation_roster()
	var ids: Array[StringName] = []
	for r in roster: ids.append(StringName(r.formation_id))
	await capture("defense-00-city-arrival")
	check(city.enter_wartime_defense_battle(ids), "normal city defense entry")
	await frames(3)
	battle = city.get_formal_battle_scene()
	if battle == null: check(false, "defense scene exists"); return
	battle.select_squad(1)
	battle.spatial_view.selected_route = &"FRONT_GATE"
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_ARROW_TOWER)
	battle.select_squad(2)
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_BARRICADE)
	battle.select_squad(1)
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_WATCH_PLATFORM)
	battle.select_squad(3)
	battle.spatial_view.draft["3"] = BattlefieldSpace.point(60, 24)
	battle.spatial_view.selected_route = &"FRONT_GATE"
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_SPIKE_TRAP)
	battle._confirm_wartime_facility_plan()
	await capture("defense-01-deployment")
	check(StringName(city.get_expedition_attempt().get("source_patrol_id", &"")) == &"invasion.blackstone.001", "defense freezes the same arriving enemy")
	check(battle.start_battle(false), "defense activates")
	battle.tick_timer.stop()
	var s := battle.coordinator.active_session
	var gate := int(s.mission_objective_state.protect_target_hp)
	battle.step_battle_for_test(8)
	check(int(s.mission_objective_state.protect_target_hp) == gate and int(s.spatial_state.enemies["FRONT_GATE"][0]) > 0, "enemy approaches physically without remote gate damage")
	check(s.wartime_facility_state.facilities.any(func(r: Dictionary): return r.kind == WartimeFacilityPlan.KIND_SPIKE_TRAP and r.phase == s.FACILITY_PHASE_ACTIVE), "outside crew builds trap at its actual position")
	check(BattlefieldSpace.command(s, 3, "MOVE", BattlefieldSpace.point(60, 64), &"SIDE_GATE").is_empty(), "defense redeploys an existing formation across the outside connection")
	await capture("defense-02-construction")
	await advance_visible(80)
	check(BattlefieldSpace.command(s, 2, "MOVE", BattlefieldSpace.point(100, 64), &"SIDE_GATE").is_empty(), "reserve movement exposes a real defensive work to contact")
	BattlefieldSpace.command(s, 3, "RETREAT", [], &"SIDE_GATE")
	var result: BattleResult
	var repairs := 0
	var repair_completed := false
	var crew_sent := false
	for i in 500:
		var barricade: Dictionary = s.wartime_facility_state.facilities[1]
		if repairs < 2 and barricade.phase in [s.FACILITY_PHASE_DAMAGED, s.FACILITY_PHASE_DESTROYED, s.FACILITY_PHASE_INTERRUPTED]:
			if not crew_sent:
				BattlefieldSpace.command(s, 2, "MOVE", BattlefieldSpace.point(84, 64), &"SIDE_GATE")
				crew_sent = true
			elif BattlefieldSpace.distance(s.spatial_state.units["2"], BattlefieldSpace.point(76, 64)) <= BattlefieldSpace.WORK_RANGE:
				battle.select_squad(2)
				battle._selected_repair_facility_id = barricade.facility_id
				battle._repair_damaged_wartime_facility()
				if s.wartime_facility_state.facilities[1].phase == s.FACILITY_PHASE_REPAIRING: repairs += 1
		elif repairs > 0 and not repair_completed and barricade.phase == s.FACILITY_PHASE_ACTIVE:
			repair_completed = true
			check(bool(battle.coordinator.issue_official_support(s.SUPPORT_PROTECT, 2).get("success", false)), "defense protection uses formal shared energy transaction")
			BattlefieldSpace.command(s, 2, "ATTACK", [], &"SIDE_GATE")
			await capture("defense-03-repair-support")
		result = await advance_visible(1)
		if result != null: break
	check(repairs > 0 and repair_completed, "defense physically repairs a damaged work before redeploying its crew")
	await capture("defense-03-result")
	check(result != null and result.outcome == BattleOutcome.Value.VICTORY, "two approaches can be defended with real deployments")
	check(s.wartime_facility_state.facilities.any(func(r: Dictionary): return r.kind == WartimeFacilityPlan.KIND_SPIKE_TRAP and r.phase == s.FACILITY_PHASE_DESTROYED), "approaching enemies trigger and consume the real trap")
	check(s._get_active_watch_platform_id(&"FRONT_GATE") != &"", "completed observation post reveals its actual corridor")
	if result == null: return
	var summary := battle.confirm_pending_result()
	check(not summary.is_empty() and battle.confirm_pending_result() == summary, "defense writes losses once")
	check(battle.request_return_to_city() != null, "defense returns to regular city")
	await frames(4)
	await capture("defense-04-return")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if ok: print("PASS: " + message)
	else: failures.append(message)

func frames(count: int) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await frames(2)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(evidence)
	root.get_texture().get_image().save_png(evidence.path_join(name + ".png"))

func advance_visible(count: int) -> BattleResult:
	var result: BattleResult
	for i in count:
		result = battle.step_battle_for_test(1)
		if DisplayServer.get_name() != "headless": await process_frame
		if result != null: break
	return result

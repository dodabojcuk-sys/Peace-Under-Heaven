extends SceneTree

const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const THEATER := preload("res://scripts/macro_march/macro_march_theater.gd")
var failures: Array[String] = []
var mode := ""
var save_dir := ""

func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")

func _run() -> void:
	mode = _argument_value("--mode=")
	save_dir = _argument_value("--txwzs-v5-save-dir=")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	if mode == "A":
		await _run_a(scene, city)
	elif mode == "F":
		var armies: Array = city.get_macro_march_read_model().armies
		_require(armies.any(func(a: Dictionary): return a.phase == ArmyRegistry.PHASE_STATIONED and a.army_id == &"army.player.000001"), "F original army remains stationed")
		_require(city._war_loop_state.get_wartime_handoff(&"redcliff_city").is_empty(), "F no duplicated handoff after settlement")
	else:
		await _continue(scene, city)
	scene.queue_free()
	await process_frame
	print("MACRO_SIEGE_WARTIME_DISK_WORKER_%s %s" % [mode, "PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func _run_a(scene: Node, city: Node) -> void:
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var first_leg: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var north: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	_require(bool(north.get("success", false)), "A 建立首段正式军令")
	if north.is_empty():
		return
	var army: Dictionary = north.army
	var macro: Dictionary = army.macro_march
	city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.army_id), &"redcliff_city", StringName(attack_route.route_id), Array(attack_route.points))
	_require(bool(attack.get("success", false)), "A 建立围城军令")
	if attack.is_empty():
		return
	army = attack.army
	macro = army.macro_march
	city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
	_require(city.enter_macro_siege_wartime(StringName(army.army_id), &"redcliff_city"), "A 从真实围城进入战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_require(battle != null and battle.spatial_view != null, "A formal spatial scene exists")
	if battle == null: return
	_require(bool(city.appoint_city_official(&"official.strategist").get("success", false)), "A appoint existing strategist")
	battle.select_squad(1)
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_SIEGE_RAM)
	battle.select_squad(2)
	battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_ARROW_TOWER)
	battle._confirm_wartime_facility_plan()
	_require(battle.start_battle(false), "A activate same army")
	battle.tick_timer.stop()
	battle.step_battle_for_test(80)
	var s := battle.coordinator.active_session
	_require(int(s.spatial_state.units["1"][0]) > 0 and int(s.wartime_facility_state.facilities[0].progress_ticks) == 0, "A workers moving, no remote construction")
	_save_expected(scene, city, battle)

func _continue(scene: Node, city: Node) -> void:
	var siege: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	_require(city.enter_macro_siege_wartime(StringName(siege.get("army_id", &"")), &"redcliff_city"), mode + " reopen same sourced battle")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null or battle.coordinator.active_session == null:
		_require(false, "restored session exists")
		return
	battle.tick_timer.stop()
	var s := battle.coordinator.active_session
	var expected: Dictionary = FileAccess.open(save_dir.path_join("spatial-expectation.bin"), FileAccess.READ).get_var()
	var actual := s.get_terminal_result_snapshot() if s.completed else s.get_snapshot()
	_require(actual == expected.session and int(city.wood) == int(expected.wood) and int(city.food) == int(expected.food) and int(city.get_city_strategy_read_model().campaign_energy) == int(expected.energy), mode + " cold restore exact positions targets HP work effects resources")
	match mode:
		"B":
			for i in 240:
				if int(s.wartime_facility_state.facilities[1].progress_ticks) == 1: break
				battle.step_battle_for_test(1)
			_require(int(s.wartime_facility_state.facilities[1].progress_ticks) == 1, "B save actual in-progress construction after arrival")
			_save_expected(scene, city, battle)
		"C":
			battle.step_battle_for_test(140)
			battle.select_squad(1)
			battle._selected_repair_facility_id = &"siege_ram-front_gate"
			battle._repair_damaged_wartime_facility()
			_require(s.wartime_facility_state.facilities[0].phase == s.FACILITY_PHASE_REPAIRING, "C formal paid repair of interrupted ram")
			_require(bool(battle.coordinator.issue_official_support(s.SUPPORT_DOMAIN, 1, &"FRONT_GATE").get("success", false)), "C energy transaction creates corridor field")
			_save_expected(scene, city, battle)
		"D":
			_require(not s.official_support_state.effects.is_empty() and s.wartime_facility_state.facilities[0].phase == s.FACILITY_PHASE_REPAIRING, "D field and repair survive independent process")
			battle.step_battle_for_test(8)
			for squad in s.squads:
				_require(BattlefieldSpace.command(s, int(squad.squad_id), "ATTACK", [], &"FRONT_GATE").is_empty(), "D attack through formal spatial order")
			var result := battle.step_battle_for_test(300)
			_require(result != null and result.outcome == BattleOutcome.Value.VICTORY, "D actual spatial victory pending settlement")
			_save_expected(scene, city, battle)
		"E":
			_require(s.completed and battle.result_panel.visible, "E restored terminal result without replay")
			var summary := battle.confirm_pending_result()
			_require(not summary.is_empty() and battle.confirm_pending_result() == summary, "E settle once and repeat idempotently")
			_require(scene.flush_runtime_persistence(&"spatial_settled"), "E persist settled generation")

func _save_expected(scene: Node, city: Node, battle: C0BattleGraybox) -> void:
	_require(scene.flush_runtime_persistence(&"spatial_checkpoint"), mode + " persist existing V5 generation")
	var s := battle.coordinator.active_session
	var expected := {"session": s.get_terminal_result_snapshot() if s.completed else s.get_snapshot(), "wood": int(city.wood), "food": int(city.food), "energy": int(city.get_city_strategy_read_model().campaign_energy)}
	FileAccess.open(save_dir.path_join("spatial-expectation.bin"), FileAccess.WRITE).store_var(expected)

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _require(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures.append(message)
		push_error("MACRO_SIEGE_WARTIME_DISK_WORKER_FAIL: " + message)

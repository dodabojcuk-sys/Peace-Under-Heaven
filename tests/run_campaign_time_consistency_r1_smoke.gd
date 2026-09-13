extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const TARGET_GAME_MILLISECONDS := 740000
const REAL_STEP_MILLISECONDS := 100

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	var results: Array[Dictionary] = []
	for speed in [1.0, 2.0, 4.0]:
		results.append(await _run_world_speed_case(speed))
	var strategic := results.map(func(result: Dictionary): return result.strategic)
	_check(
		strategic[0] == strategic[1] and strategic[1] == strategic[2],
		"1x, 2x and 4x reach the same strategic snapshot at equal game time"
	)
	_check(
		int(results[0].simulated_real_milliseconds) == TARGET_GAME_MILLISECONDS
			and int(results[1].simulated_real_milliseconds) == TARGET_GAME_MILLISECONDS / 2
			and int(results[2].simulated_real_milliseconds) == TARGET_GAME_MILLISECONDS / 4,
		"world speed changes required real duration by 1:1, 1:2 and 1:4 only"
	)
	await _check_restore_contract()
	await _check_c0_freeze_contract()
	print("CAMPAIGN_TIME_CONSISTENCY_RESULTS %s" % JSON.stringify(results))
	_finish()


func _run_world_speed_case(speed: float) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	_reset_fresh_campaign(city)
	_check(city.set_city_time_speed(speed), "formal %.0fx speed is accepted" % speed)
	_check(bool(city.start_build_project(&"building.farm.t1").get("success", false)), "farm starts at %.0fx" % speed)
	if city.can_queue_training():
		city.recruit_button.pressed.emit()
	_check(city.get_training_queue_snapshot().active_order_id != &"", "training starts at %.0fx" % speed)
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	_check(bool(engineer.get("success", false)), "engineer dispatch starts at %.0fx" % speed)
	var engineer_id := StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))
	var project: Dictionary = city.begin_field_road_project(
		engineer_id, &"blackstone_city", &"",
		[Vector2i(135, 650), Vector2i(310, 640), Vector2i(500, 620)],
		FieldTacticsState.ROAD_NORMAL, true
	)
	_check(bool(project.get("success", false)), "field construction starts at %.0fx" % speed)

	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var march: Dictionary = city.commit_macro_march_from_city(
		_formation_ids(city), &"northwatch_garrison",
		StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	_check(bool(march.get("success", false)), "army order starts at %.0fx" % speed)

	var before_pause := _complete_world_snapshot(city)
	city.set_city_time_paused(true)
	city._process(5.0)
	_check(_complete_world_snapshot(city) == before_pause, "pause freezes every world domain at %.0fx" % speed)
	_check(city.set_city_time_speed(speed), "speed selection resumes pause at %.0fx" % speed)

	var simulated_real_milliseconds := 0
	var target_real_milliseconds := roundi(float(TARGET_GAME_MILLISECONDS) / speed)
	while simulated_real_milliseconds < target_real_milliseconds:
		var step := mini(REAL_STEP_MILLISECONDS, target_real_milliseconds - simulated_real_milliseconds)
		city._process(float(step) / 1000.0)
		simulated_real_milliseconds += step
	var result := {
		"speed": speed,
		"simulated_real_milliseconds": simulated_real_milliseconds,
		"strategic": _strategic_snapshot(city),
	}
	scene.queue_free()
	await process_frame
	return result


func _strategic_snapshot(city: Node) -> Dictionary:
	var projects: Array[Dictionary] = []
	for project_id in city._war_loop_state.field_tactics.projects_by_id.keys():
		var project: Dictionary = city._war_loop_state.field_tactics.projects_by_id[project_id]
		projects.append({
			"project_kind": StringName(project.get("project_kind", &"")),
			"phase": StringName(project.get("phase", &"")),
			"progress_milliseconds": int(project.get("progress_milliseconds", 0)),
			"required_milliseconds": int(project.get("required_milliseconds", 0)),
		})
	projects.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.project_kind) < String(b.project_kind))
	var armies: Array[Dictionary] = []
	for army_value in city.get_macro_march_armies():
		var army: Dictionary = army_value
		var macro: Dictionary = army.get("macro_march", {})
		armies.append({
			"phase": StringName(army.get("phase", &"")),
			"target_node_id": StringName(army.get("target_node_id", &"")),
			"member_count": _army_total(army),
			"progress_milliseconds": int(macro.get("progress_millis", 0)),
			"total_milliseconds": int(macro.get("total_millis", 0)),
		})
	var invasion: Dictionary = city._war_loop_state.field_tactics.get_blackstone_invasion()
	var engagement: Dictionary = Dictionary(invasion.get("last_engagement", {})).duplicate(true)
	# These fields describe the containing engine step for diagnostics. They do
	# not drive movement, damage, identity or settlement and may differ within
	# one rounded millisecond when real-frame sizes differ.
	engagement.erase("contact_milliseconds")
	engagement.erase("contact_world_milliseconds")
	engagement.erase("world_milliseconds")
	invasion.last_engagement = engagement
	return {
		"day": city.current_day,
		"day_elapsed_milliseconds": city.get_day_elapsed_milliseconds(),
		"field_world_milliseconds": city._war_loop_state.field_tactics.world_milliseconds,
		"food": city.food,
		"wood": city.wood,
		"build_state": city.get_build_slot_state(),
		"build_progress_milliseconds": int(city.get_build_slot_snapshot().get("progress_milliseconds", 0)),
		"training": city.get_training_queue_snapshot(),
		"projects": projects,
		"armies": armies,
		"invasion": invasion,
		"population": city.get_population_recovery_read_model(),
	}


func _complete_world_snapshot(city: Node) -> Dictionary:
	return {
		"strategic": _strategic_snapshot(city),
		"war_loop": city._war_loop_state.get_snapshot(),
		"army_registry": city._army_registry.get_snapshot(),
	}


func _check_restore_contract() -> void:
	var source_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(source_scene)
	await process_frame
	await process_frame
	var source: Node = source_scene.get_node("ConstructionController")
	source.set_process(false)
	_reset_fresh_campaign(source)
	_check(source.set_city_time_speed(2.0), "restore probe selects 2x")
	source._process(6.1725)
	source.set_city_time_paused(true)
	var snapshot: Dictionary = source.export_v5_campaign_snapshot()
	var expected := _strategic_snapshot(source)

	var restored_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restore_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(bool(restore_result.get("success", false)), "V5 restore accepts the authoritative clock snapshot")
	_check(
		_strategic_snapshot(restored) == expected
			and restored.get_city_time_speed() == 2.0
			and restored.is_city_time_paused(),
		"restore keeps date, field clock, pause and speed without implicit catch-up"
	)
	source_scene.queue_free()
	restored_scene.queue_free()
	await process_frame


func _check_c0_freeze_contract() -> void:
	THEATER.use_regression_definition_for_tests()
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	_reset_fresh_campaign(city)
	city.food = 120
	_check(city.set_city_time_speed(4.0), "C0 probe preserves selected world speed")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var first_route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var first: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(first_route.route_id), Array(first_route.points)
	)
	var first_army: Dictionary = first.get("army", {})
	var first_macro: Dictionary = first_army.get("macro_march", {})
	city.advance_macro_march_time(
		StringName(first_army.get("army_id", &"")), StringName(first_macro.get("order_id", &"")),
		0, ceili(float(first_macro.get("total_millis", 0)) / city.get_city_time_speed())
	)
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(
		StringName(first_army.get("army_id", &"")), &"redcliff_city",
		StringName(attack_route.route_id), Array(attack_route.points)
	)
	var attack_army: Dictionary = attack.get("army", {})
	var attack_macro: Dictionary = attack_army.get("macro_march", {})
	city.advance_macro_march_time(
		StringName(attack_army.get("army_id", &"")), StringName(attack_macro.get("order_id", &"")),
		0, ceili(float(attack_macro.get("total_millis", 0)) / city.get_city_time_speed())
	)
	var army_id := StringName(attack_army.get("army_id", &""))
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "existing siege enters formal C0")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(battle != null and battle.start_battle(false), "formal C0 session starts")
	if battle == null or battle.coordinator.active_session == null:
		scene.queue_free()
		await process_frame
		THEATER.use_playable_definition()
		return
	battle.set_process(false)
	battle.tick_timer.stop()
	var world_before := _frozen_world_snapshot(city)
	var tick_before := battle.coordinator.active_session.current_tick
	battle.advance_spatial_frame(2.0)
	_check(
		battle.coordinator.active_session.current_tick == tick_before + 8,
		"C0 advances eight fixed battle ticks for two battle seconds"
	)
	_check(_frozen_world_snapshot(city) == world_before, "C0 ticks do not advance city, march or field time")
	battle.abort_formal_entry()
	scene.queue_free()
	await process_frame
	THEATER.use_playable_definition()


func _formation_ids(city: Node) -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation in city.get_formation_roster():
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _reset_fresh_campaign(city: Node) -> void:
	city.restart_first_map()
	# `restart_first_map` is a player-facing restart, while this runner restores
	# multiple independent initial scenarios in one process. Clear the transient
	# build UI slot left by the preceding scenario before issuing the same order.
	city._build_slot = city._empty_build_slot()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()


func _frozen_world_snapshot(city: Node) -> Dictionary:
	var siege: Dictionary = city._war_loop_state.get_siege(&"redcliff_city")
	return {
		"day": city.current_day,
		"day_elapsed_milliseconds": city.get_day_elapsed_milliseconds(),
		"field_world_milliseconds": city._war_loop_state.field_tactics.world_milliseconds,
		"field_projects": city._war_loop_state.field_tactics.projects_by_id.duplicate(true),
		"field_patrols": city._war_loop_state.field_tactics.patrols_by_id.duplicate(true),
		"army_registry": city._army_registry.get_snapshot(),
		"siege_tick": int(siege.get("tick", 0)),
		"siege_gate_hp": int(siege.get("gate_hp", 0)),
		"siege_attacker_hp": int(siege.get("attacker_total_hp", 0)),
		"siege_defender_hp": int(siege.get("defender_total_hp", 0)),
	}


func _army_total(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("CAMPAIGN_TIME_CONSISTENCY_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("CAMPAIGN_TIME_CONSISTENCY_R1_SMOKE FAIL: %s" % failure)
	quit(1)

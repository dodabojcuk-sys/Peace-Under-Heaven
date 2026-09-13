extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var city: Node
var started_milliseconds := 0
var assertions := 0
var failures: Array[String] = []
var world_speed := 4.0
var evidence_path := ""
var records: Array[Dictionary] = []


func _initialize() -> void:
	THEATER.use_playable_definition()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			world_speed = float(arg.trim_prefix("--speed="))
		if arg.begins_with("--evidence="):
			evidence_path = arg.trim_prefix("--evidence=")
	call_deferred("_run")


func _run() -> void:
	started_milliseconds = Time.get_ticks_msec()
	root.size = Vector2i(1280, 800)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	_check(city.current_day == 1 and city.food == 80 and city.infantry_count == 20, "normal fresh campaign resources and garrison")
	_check(city.set_city_time_speed(world_speed), "formal player speed selected without fixture mutation")
	_record("fresh")
	var army_id := await _march_to_northwatch()
	if army_id == &"":
		_finish()
		return
	await _occupy_redcliff(army_id)
	if StringName(city._war_loop_state.get_city(&"redcliff_city").get("military_controller_faction_id", &"")) != &"player":
		_finish()
		return
	var occupied_day := int(city.current_day)
	var occupied_elapsed := float(city.day_elapsed_seconds)
	_record("redcliff-occupied")
	_check(
		occupied_day < 5
			and StringName(city._war_loop_state.field_tactics.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_DORMANT,
		"Redcliff is occupied before departure while the original invasion is still dormant"
	)
	await _occupy_silverford(army_id)
	_check(city._war_loop_state.is_level_cleared(), "actual Redcliff and Silverford control completes the campaign once")
	_record("two-city-victory")
	# The gate is a world-date condition. Give each formal speed the same game
	# time budget instead of a fixed real-time timeout that rejects 1x/2x only.
	await _wait_until(
		func(): return city.current_day >= 5,
		760.0 / world_speed,
		"day-five departure gate"
	)
	var invasion: Dictionary = city._war_loop_state.field_tactics.get_blackstone_invasion()
	var personnel: Dictionary = city.get_blackstone_personnel_accounting()
	_record("day-five-cancellation")
	_check(
		StringName(invasion.get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED
			and city._war_loop_state.is_level_cleared()
			and not city._army_registry.get_army(army_id).is_empty(),
		"day-five gate cancels the unlaunched vanguard without deleting victory or the player army"
	)
	_check(
		bool(personnel.get("reconciled", false))
			and int(personnel.get("initial_military", 0)) == 20
			and int(personnel.get("added_military", -1)) == 0
			and int(personnel.get("garrison_survivors", -1)) == 0
			and int(personnel.get("field_army_survivors", -1)) == 5
			and int(personnel.get("wounded", -1)) == 2
			and int(personnel.get("fallen", -1)) == 13
			and int(personnel.get("accounted_total", -1)) == 20,
		"personnel accounting explains all 20 initial soldiers without double counting"
	)
	print("BLACKSTONE_EARLY_COUNTERATTACK_TRACE %s" % JSON.stringify({
		"real_duration_milliseconds": Time.get_ticks_msec() - started_milliseconds,
		"speed": world_speed,
		"redcliff_occupied_day": occupied_day,
		"redcliff_occupied_day_elapsed_seconds": occupied_elapsed,
		"final_day": city.current_day,
		"food": city.food,
		"army_id": army_id,
		"invasion_phase": invasion.get("phase", &""),
		"level_cleared": city._war_loop_state.is_level_cleared(),
		"population": city.get_population_recovery_read_model(),
		"personnel_accounting": personnel,
	}))
	_finish()


func _march_to_northwatch() -> StringName:
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var selected_formations := _formation_ids()
	print("EARLY_ROSTER %s" % str(city.get_formation_roster()))
	var issued: Dictionary = city.commit_macro_march_from_city(
		selected_formations, &"northwatch_garrison",
		StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	print("EARLY_MARCH_ISSUE formations=%s route=%s result=%s" % [str(selected_formations), str(route.get("route_id", &"")), str(issued)])
	_check(bool(issued.get("success", false)), "formal paid march sends the original garrison to Northwatch")
	var army_id := StringName(Dictionary(issued.get("army", {})).get("army_id", &""))
	await _wait_until(
		func(): return StringName(city.get_army_state(army_id).get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		60.0, "Northwatch arrival"
	)
	_record("northwatch-arrival")
	return army_id


func _occupy_redcliff(army_id: StringName) -> void:
	var route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var issued: Dictionary = city.commit_macro_march_from_station(
		army_id, &"redcliff_city", StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	_check(bool(issued.get("success", false)), "same army receives the paid Redcliff assault order")
	await _wait_until(
		func(): return StringName(city.get_army_state(army_id).get("phase", &"")) == ArmyRegistry.PHASE_SIEGING,
		60.0, "Redcliff siege arrival"
	)
	_record("redcliff-siege-arrival")
	city.set_city_time_paused(true)
	print("EARLY_SIEGE_HANDOFF army=%s siege=%s persistence=%s" % [str(city.get_army_state(army_id)), str(city._war_loop_state.get_siege(&"redcliff_city")), str(city.get_parent().get_runtime_persistence_status())])
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "existing siege enters the formal spatial battle")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "formal Redcliff battle scene exists")
		return
	_check(battle.start_battle(false), "formal Redcliff battle starts")
	var frozen_world := _world_clock_snapshot()
	_record("c0-enter")
	for squad in battle.coordinator.active_session.squads:
		battle.select_squad(int(squad.squad_id))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = battle.spatial_view.screen(BattlefieldSpace.point(80, 24))
		battle.spatial_view._gui_input(click)
	await _wait_until(func(): return battle.coordinator.active_session.completed, 180.0, "Redcliff battle result")
	if not battle.coordinator.active_session.completed:
		return
	print("EARLY_ASSAULT_OUTCOME outcome=%s request_phase=%s result_error=%s checkpoint=%s" % [
		str(battle.coordinator.active_session.result.outcome),
		str(battle.coordinator.active_request.phase),
		str(battle.coordinator.last_result_error_id),
		str(city._last_campaign_checkpoint_result),
	])
	var result: Dictionary = battle.confirm_pending_result()
	_check(not result.is_empty(), "Redcliff battle result commits once")
	_check(battle.request_return_to_city() != null, "formal battle returns to the live campaign")
	await _wait_until(func(): return city.get_formal_battle_scene() == null, 8.0, "Redcliff return")
	var returned_world := _world_clock_snapshot()
	var city_resume_delta: int = (
		(int(returned_world.day) - int(frozen_world.day)) * city.MILLISECONDS_PER_DAY
		+ int(returned_world.day_elapsed_milliseconds)
		- int(frozen_world.day_elapsed_milliseconds)
	)
	var field_resume_delta: int = int(returned_world.field_world_milliseconds) - int(frozen_world.field_world_milliseconds)
	_check(
		city_resume_delta >= 0
			and city_resume_delta < 1000
			and absi(city_resume_delta - field_resume_delta) <= 2,
		"macro C0 freezes city and field time and applies no catch-up"
	)
	_record("c0-exit")


func _occupy_silverford(army_id: StringName) -> void:
	_check(city.set_city_time_speed(world_speed), "resume selected campaign speed after the spatial battle")
	var route: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
	var issued: Dictionary = city.commit_macro_march_from_station(
		army_id, &"silverford_city", StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	_check(bool(issued.get("success", false)), "same surviving army continues to Silverford")
	await _wait_until(func(): return city._war_loop_state.is_level_cleared(), 60.0, "Silverford occupation")


func _world_clock_snapshot() -> Dictionary:
	return {
		"day": city.current_day,
		"day_elapsed_milliseconds": city.get_day_elapsed_milliseconds(),
		"field_world_milliseconds": city._war_loop_state.field_tactics.world_milliseconds,
	}


func _record(node: String) -> void:
	if city == null:
		return
	var record := {
		"node": node,
		"real_milliseconds": Time.get_ticks_msec() - started_milliseconds,
		"clock": _world_clock_snapshot(),
		"food": city.food,
		"wood": city.wood,
		"city_defense": city.get_city_defense(),
		"invasion_phase": StringName(city._war_loop_state.field_tactics.get_blackstone_invasion().get("phase", &"")),
		"personnel": city.get_blackstone_personnel_accounting(),
	}
	records.append(record)
	print("EARLY_NODE %s" % JSON.stringify(record))


func _formation_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation in city.get_formation_roster():
		if int(formation.get("member_count", formation.get("current_count", formation.get("count", 0)))) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _wait_until(predicate: Callable, timeout_seconds: float, label: String) -> void:
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_seconds:
		if predicate.call():
			print("EARLY_WAIT %s real_ms=%d" % [label, Time.get_ticks_msec() - started])
			return
		await create_timer(0.1).timeout
	_check(false, "timeout: %s" % label)
	print("EARLY_DIAGNOSTICS %s" % JSON.stringify(city.get_campaign_progress_diagnostics()))


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if evidence_path != "":
		DirAccess.make_dir_recursive_absolute(evidence_path.get_base_dir())
		var file := FileAccess.open(evidence_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({
				"world_speed": world_speed,
				"real_duration_milliseconds": Time.get_ticks_msec() - started_milliseconds,
				"failures": failures,
				"records": records,
			}, "\t"))
	if failures.is_empty():
		print("BLACKSTONE_EARLY_COUNTERATTACK_R1_JOURNEY PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("BLACKSTONE_EARLY_COUNTERATTACK_R1_JOURNEY FAIL: %s" % failure)
	quit(1)

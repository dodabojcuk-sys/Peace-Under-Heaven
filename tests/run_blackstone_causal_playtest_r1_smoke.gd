extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	await _check_predeparture_cancellation(3)
	await _check_predeparture_cancellation(4)
	await _check_same_update_partitioning()
	await _check_departed_force_survives_capture()
	await _check_handed_off_force_survives_capture()
	await _check_cancelled_restore_is_terminal()
	await _check_checkpoint_failure_rolls_back_and_retries()
	await _check_early_victory_keeps_existing_army()
	if failures.is_empty():
		print("BLACKSTONE_CAUSAL_PLAYTEST_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("BLACKSTONE_CAUSAL_PLAYTEST_R1_SMOKE FAIL: %s" % failure)
	quit(1)


func _check_predeparture_cancellation(occupation_day: int) -> void:
	var city := await _fresh_city()
	_set_city_controller(city, &"redcliff_city", &"player")
	city.current_day = 5
	var result: Dictionary = city.advance_war_loop_time(1)
	var invasion: Dictionary = city._war_loop_state.field_tactics.get_blackstone_invasion()
	_check(
		StringName(invasion.get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED
			and StringName(invasion.get("cancellation_reason", &"")) == FieldTacticsState.INVASION_CANCELLATION_SOURCE_CONTROLLED
			and int(invasion.get("cancelled_day", 0)) == 5
			and Array(result.get("cancelled_invasion_ids", [])) == [&"invasion.blackstone.001"]
			and city.get_blackstone_campaign_status_text().contains("赤崖已被控制，本次先遣军出兵取消。"),
		"day %d Redcliff occupation cancels the same dormant invasion at departure" % occupation_day
	)
	var terminal_before := invasion.duplicate(true)
	city.current_day = 9
	city.advance_war_loop_time(30000)
	_set_city_controller(city, &"redcliff_city", &"enemy")
	city.advance_war_loop_time(30000)
	_check(
		city._war_loop_state.field_tactics.get_blackstone_invasion() == terminal_before,
		"cancelled invasion stays terminal across later days and source recapture"
	)
	await _dispose(city)


func _check_departed_force_survives_capture() -> void:
	var city := await _fresh_city()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	city.current_day = 5
	city.advance_war_loop_time(1)
	var departed := field.get_blackstone_invasion().duplicate(true)
	_set_city_controller(city, &"redcliff_city", &"player")
	city.advance_war_loop_time(1250)
	var after := field.get_blackstone_invasion()
	_check(
		StringName(departed.get("phase", &"")) == FieldTacticsState.INVASION_MARCHING
			and StringName(after.get("phase", &"")) == FieldTacticsState.INVASION_MARCHING
			and StringName(after.get("patrol_id", &"")) == StringName(departed.get("patrol_id", &""))
			and int(after.get("strength", 0)) == int(departed.get("strength", 0))
			and int(after.get("move_elapsed_milliseconds", 0)) >= int(departed.get("move_elapsed_milliseconds", 0)),
		"departed invasion keeps identity, strength and forward movement after Redcliff occupation"
	)
	await _dispose(city)


func _check_same_update_partitioning() -> void:
	var final_records: Array[Dictionary] = []
	var final_controllers: Array[StringName] = []
	for partitions in [[5.0], [2.5, 2.5], [0.2, 0.4, 0.7, 0.9, 2.8]]:
		var city := await _prepare_same_update_occupation()
		for delta_value in partitions:
			city._process(float(delta_value))
		final_records.append(city._war_loop_state.field_tactics.get_blackstone_invasion())
		final_controllers.append(StringName(
			city._war_loop_state.get_city(&"redcliff_city").get(
				"military_controller_faction_id", &""
			)
		))
		await _dispose(city)
	print("CAUSAL_TIE_TRACE phases=%s strengths=%s controllers=%s" % [
		final_records.map(func(record: Dictionary): return record.get("phase", &"")),
		final_records.map(func(record: Dictionary): return record.get("strength", 0)),
		final_controllers,
	])
	_check(
		final_records.size() == 3
			and final_records[0] == final_records[1]
			and final_records[1] == final_records[2]
			and final_controllers == [&"player", &"player", &"player"]
			and StringName(final_records[0].get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED,
		"same-update macro occupation wins the departure tie for whole, split and irregular frames"
	)


func _prepare_same_update_occupation() -> Node:
	var city := await _fresh_city()
	var north_route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city(
		_available_formation_ids(city), &"northwatch_garrison",
		StringName(north_route.get("route_id", &"")), Array(north_route.get("points", []))
	)
	var army: Dictionary = Dictionary(issued.get("army", {}))
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	city.advance_macro_march_time(
		StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")),
		0, int(macro.get("total_millis", 0))
	)
	var redcliff_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(
		StringName(army.get("army_id", &"")), &"redcliff_city",
		StringName(redcliff_route.get("route_id", &"")), Array(redcliff_route.get("points", []))
	)
	army = Dictionary(attack.get("army", {}))
	macro = Dictionary(army.get("macro_march", {}))
	city.advance_macro_march_time(
		StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")),
		0, int(macro.get("total_millis", 0)) - 4000
	)
	# This fixture changes only the surrender threshold so an actual macro arrival
	# can commit source control in the exact update that crosses the day-5 gate.
	var redcliff: Dictionary = city._war_loop_state.get_city(&"redcliff_city")
	redcliff.surrender_allowed = true
	redcliff.defender_count = 1
	redcliff.defender_hp_per_member = 1
	redcliff.defender_attack_per_member = 0
	redcliff.defender_armor_per_member = 0
	city._war_loop_state.cities_by_id[&"redcliff_city"] = redcliff
	city.current_day = 4
	city.day_elapsed_seconds = float(city.SECONDS_PER_DAY) - 5.0
	return city


func _check_handed_off_force_survives_capture() -> void:
	var city := await _fresh_city()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.activate_configured_invasions(5)
	for _step in 120:
		if StringName(field.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_ARRIVED:
			break
		city.advance_war_loop_time(1000)
	var arrived := field.get_blackstone_invasion()
	var handed_off := field.mark_invasion_handed_off(
		StringName(arrived.get("patrol_id", &"")), &"attempt.causal.001"
	)
	var before := field.get_blackstone_invasion().duplicate(true)
	_set_city_controller(city, &"redcliff_city", &"player")
	city.advance_war_loop_time(30000)
	_check(
		handed_off and field.get_blackstone_invasion() == before,
		"active defense handoff remains the same frozen battle transaction after source capture"
	)
	await _dispose(city)


func _check_cancelled_restore_is_terminal() -> void:
	var city := await _fresh_city()
	_set_city_controller(city, &"redcliff_city", &"player")
	city.current_day = 5
	city.advance_war_loop_time(1)
	var snapshot: Dictionary = city._war_loop_state.field_tactics.get_snapshot()
	var restored := FieldTacticsState.new()
	var restored_ok := restored.restore_snapshot(snapshot)
	var restored_before := restored.get_blackstone_invasion().duplicate(true)
	var repeated := restored.resolve_configured_invasion_departures(
		12, {&"redcliff_city": &"enemy"}
	)
	_check(
		restored_ok
			and StringName(restored_before.get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED
			and Array(repeated.get("activated_invasion_ids", [])).is_empty()
			and Array(repeated.get("cancelled_invasion_ids", [])).is_empty()
			and restored.get_blackstone_invasion() == restored_before,
		"cancelled original record restores without regeneration or a parallel event ledger"
	)
	await _dispose(city)


func _check_checkpoint_failure_rolls_back_and_retries() -> void:
	var city := await _fresh_city()
	_set_city_controller(city, &"redcliff_city", &"player")
	city.current_day = 5
	city.set_field_supply_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var failed: Dictionary = city.advance_war_loop_time(1)
	var after_failure: Dictionary = city._war_loop_state.field_tactics.get_blackstone_invasion()
	var retried: Dictionary = city.advance_war_loop_time(1)
	_check(
		StringName(failed.get("error_id", &"")) == &"SAVE_FAILED"
			and StringName(after_failure.get("phase", &"")) == FieldTacticsState.INVASION_DORMANT
			and Array(retried.get("cancelled_invasion_ids", [])) == [&"invasion.blackstone.001"]
			and StringName(city._war_loop_state.field_tactics.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED,
		"failed cancellation checkpoint rolls back the record and a later retry commits once"
	)
	await _dispose(city)


func _check_early_victory_keeps_existing_army() -> void:
	var city := await _fresh_city()
	var formation_ids := _available_formation_ids(city)
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison")
	var issued: Dictionary = city.commit_macro_march_from_city(
		formation_ids, &"northwatch_garrison",
		StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	var army_id := StringName(Dictionary(issued.get("army", {})).get("army_id", &""))
	_set_city_controller(city, &"redcliff_city", &"player")
	_set_city_controller(city, &"silverford_city", &"player")
	city.current_day = 5
	city.advance_war_loop_time(1)
	_check(
		bool(issued.get("success", false))
			and city._war_loop_state.is_level_cleared()
			and StringName(city._war_loop_state.field_tactics.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED
			and not city._army_registry.get_army(army_id).is_empty()
			and city.get_blackstone_campaign_status_text().contains("双城目标达成"),
		"control-only victory settles once while cancelled threat and existing player army remain legal"
	)
	await _dispose(city)


func _fresh_city() -> Node:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	return city


func _set_city_controller(city: Node, city_id: StringName, faction_id: StringName) -> void:
	var state: Dictionary = city._war_loop_state.get_city(city_id)
	state.military_controller_faction_id = faction_id
	city._war_loop_state.cities_by_id[city_id] = state


func _available_formation_ids(city: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	for formation_value in city._garrison_state.get_formations():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			result.append(StringName(formation.get("formation_id", &"")))
	return result


func _dispose(city: Node) -> void:
	if city != null and is_instance_valid(city.get_parent()):
		city.get_parent().queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)

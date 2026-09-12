extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var passed := false
	match mode:
		"A":
			passed = _settle_and_persist_encounter(city, scene)
		"B":
			passed = await _verify_restored_encounter(city, scene)
		_:
			push_error("未知遭遇持久化 worker 模式：%s" % mode)
	if not passed:
		print("ENCOUNTER_PERSISTENCE_WORKER_%s_STATUS %s" % [mode, JSON.stringify(scene.get_runtime_persistence_status())])
	print("ENCOUNTER_PERSISTENCE_WORKER_%s %s pid=%d" % [mode, "PASS" if passed else "FAIL", OS.get_process_id()])
	_write_result_marker(save_directory, mode, passed)
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _settle_and_persist_encounter(city: Node, scene: Node) -> bool:
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"northwatch_garrison",
		StringName(route.route_id), Array(route.points)
	)
	var army_id := StringName(Dictionary(issued.get("army", {})).get("army_id", &""))
	city.set_city_time_speed(4.0)
	var encountered: Dictionary = {}
	# This intentionally calls the production Controller frame pipeline rather
	# than advancing army and patrol with separate test-only clocks.
	for _frame in 480:
		city._process(1.0 / 60.0)
		for patrol_value in Dictionary(city.get_field_tactics_read_model().get("visible_patrols_by_id", {})).values():
			var encounter: Dictionary = Dictionary(Dictionary(patrol_value).get("last_engagement", {}))
			if army_id in Array(encounter.get("army_ids", [])):
				encountered = encounter
				break
		if not encountered.is_empty():
			break
	var patrol_id := StringName(encountered.get("patrol_id", &""))
	var patrol: Dictionary = Dictionary(city._war_loop_state.field_tactics.patrols_by_id.get(patrol_id, {}))
	var army: Dictionary = city._army_registry.get_army(army_id)
	var persisted: bool = scene.flush_runtime_persistence(&"encounter_persistence_worker_a")
	var result: bool = bool(issued.get("success", false)) \
		and not encountered.is_empty() \
		and int(encountered.get("patrol_strength_after", -1)) == int(patrol.get("strength", -2)) \
		and city._macro_army_member_count(army) == int(Dictionary(encountered.get("army_strength_after_by_army", {})).get(army_id, -1)) \
		and persisted
	print("ENCOUNTER_PERSISTENCE_SETTLED army=%s patrol=%s own_after=%d patrol_after=%d persisted=%s" % [army_id, patrol_id, city._macro_army_member_count(army), int(patrol.get("strength", -1)), str(persisted)])
	return result


func _verify_restored_encounter(city: Node, scene: Node) -> bool:
	var field: Dictionary = city.get_field_tactics_read_model()
	var restored_encounter: Dictionary = {}
	var restored_patrol: Dictionary = {}
	for patrol_value in Dictionary(field.get("visible_patrols_by_id", {})).values():
		var patrol: Dictionary = Dictionary(patrol_value)
		var encounter: Dictionary = Dictionary(patrol.get("last_engagement", {}))
		if not encounter.is_empty():
			restored_encounter = encounter
			restored_patrol = patrol
			break
	if restored_encounter.is_empty():
		return false
	var authority_patrol: Dictionary = Dictionary(city._war_loop_state.field_tactics.patrols_by_id.get(StringName(restored_encounter.get("patrol_id", &"")), {}))
	var army_ids: Array = Array(restored_encounter.get("army_ids", []))
	var army_id := StringName(army_ids.front()) if not army_ids.is_empty() else &""
	var army: Dictionary = city._army_registry.get_army(army_id)
	scene.open_macro_march_r0()
	await process_frame
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro._selected_army_id = army_id
	macro.refresh()
	await process_frame
	var replayed := not macro._encounter_feedback.is_empty() or macro._encounter_audio_play_count != 0
	var result: bool = army_id != &"" \
		and int(restored_encounter.get("patrol_strength_after", -1)) == int(authority_patrol.get("strength", -2)) \
		and city._macro_army_member_count(army) == int(Dictionary(restored_encounter.get("army_strength_after_by_army", {})).get(army_id, -1)) \
		and not replayed
	print("ENCOUNTER_PERSISTENCE_RESTORED army=%s own_after=%d patrol_after=%d replay=%s" % [army_id, city._macro_army_member_count(army), int(authority_patrol.get("strength", -1)), str(replayed)])
	return result


func _write_result_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("encounter_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("ENCOUNTER_PERSISTENCE_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

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
	city._ensure_war_loop_initialized()
	var passed := false
	match mode:
		"A":
			city._war_loop_state.field_tactics.patrols_by_id.clear()
			var silverford := Dictionary(city._war_loop_state.cities_by_id.get(&"silverford_city", {}))
			silverford.military_controller_faction_id = &"player"
			city._war_loop_state.cities_by_id[&"silverford_city"] = silverford
			var stationed := _station_silverford(city)
			var army_id := StringName(stationed.get("army_id", &""))
			var replenished: Dictionary = city.replenish_field_stationed_army(&"silverford_city", army_id)
			var current: Dictionary = city._army_registry.get_army(army_id)
			print("REINFORCEMENT_PRE army=%s phase=%s stock=%d members=%d" % [army_id, current.get("phase", &""), int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1)), _members(current)])
			passed = bool(replenished.get("success", false)) and _members(current) == 11 and scene.flush_runtime_persistence(&"reinforcement_worker_a")
		"B":
			var army := _first_army(city)
			var stock := int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1))
			var route: Dictionary = city.plan_field_path(&"silverford_city", &"redcliff_city")
			var reissued: Dictionary = city.commit_macro_march_from_station(StringName(army.get("army_id", &"")), &"redcliff_city", StringName(route.get("route_id", &"")), Array(route.get("points", [])))
			var active: Dictionary = city._army_registry.get_army(StringName(army.get("army_id", &"")))
			print("REINFORCEMENT_RESTORED army=%s stock=%d members=%d reissued=%s order=%s" % [army.get("army_id", &""), stock, _members(active), reissued.get("success", false), Dictionary(active.get("macro_march", {})).get("order_id", &"")])
			passed = StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and stock == 0 and _members(army) == 11 and bool(reissued.get("success", false)) and scene.flush_runtime_persistence(&"reinforcement_worker_b")
		"C":
			var active := _first_army(city)
			var before_members := _members(active)
			var before_stock := int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1))
			city.set_city_time_paused(false)
			city._process(0.2)
			var advanced := _first_army(city)
			print("REINFORCEMENT_RESTORED_REISSUE phase=%s members=%d stock=%d progress=%d" % [advanced.get("phase", &""), _members(advanced), before_stock, advanced.get("progress_milliseconds", -1)])
			passed = StringName(active.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING and before_members == 11 and before_stock == 0 and _members(advanced) == before_members and int(advanced.get("progress_milliseconds", 0)) > 0
	print("FIELD_STATIONED_REINFORCEMENT_R0_WORKER_%s %s pid=%d" % [mode, "PASS" if passed else "FAIL", OS.get_process_id()])
	_write_result_marker(save_directory, mode, passed)
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _station_silverford(city: Node) -> Dictionary:
	var roster: Array = city.get_formation_roster()
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"silverford_city")
	if roster.is_empty() or not bool(route.get("valid", false)):
		return {}
	var issued: Dictionary = city.commit_macro_march_from_city([StringName(Dictionary(roster.front()).get("formation_id", &""))], &"silverford_city", StringName(route.get("route_id", &"")), Array(route.get("points", [])))
	var army: Dictionary = Dictionary(issued.get("army", {}))
	if army.is_empty():
		return {}
	city.set_city_time_paused(false)
	for _step in range(400):
		city._process(0.1)
		var current: Dictionary = city._army_registry.get_army(StringName(army.get("army_id", &"")))
		if StringName(current.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED:
			return current
	return city._army_registry.get_army(StringName(army.get("army_id", &"")))


func _first_army(city: Node) -> Dictionary:
	var armies: Array = city.get_macro_march_armies()
	return Dictionary(armies.front()) if not armies.is_empty() else {}


func _members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _write_result_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("field_stationed_reinforcement_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("FIELD_STATIONED_REINFORCEMENT_R0_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

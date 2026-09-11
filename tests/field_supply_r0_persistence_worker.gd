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
			var silverford := Dictionary(city._war_loop_state.cities_by_id.get(&"silverford_city", {}))
			silverford.military_controller_faction_id = &"player"
			city._war_loop_state.cities_by_id[&"silverford_city"] = silverford
			var before := int(Dictionary(city.get_field_tactics_read_model().get("supply_inventory_by_point_id", {})).get(&"silverford_city", -1))
			var started: Dictionary = city.begin_field_supply_transport(&"silverford_city")
			var transport := _transport(city)
			city.advance_war_loop_time(1200)
			transport = _transport(city)
			print("SUPPLY_PRE=%d" % before)
			print("SUPPLY_MID phase=%s elapsed=%d food=%d" % [transport.get("phase", &""), transport.get("elapsed_milliseconds", -1), city.food])
			passed = bool(started.get("success", false)) \
				and before == 20 \
				and StringName(transport.get("phase", &"")) == FieldTacticsState.SUPPLY_MOVING \
				and int(transport.get("elapsed_milliseconds", 0)) > 0 \
				and scene.flush_runtime_persistence(&"field_supply_worker_a")
		"B":
			var transport := _transport(city)
			var elapsed := int(transport.get("elapsed_milliseconds", -1))
			var total := int(transport.get("total_milliseconds", 0))
			print("SUPPLY_RESTORED_MID phase=%s elapsed=%d food=%d" % [transport.get("phase", &""), elapsed, city.food])
			if StringName(transport.get("phase", &"")) == FieldTacticsState.SUPPLY_MOVING and elapsed > 0 and total > elapsed:
				city.advance_war_loop_time(total - elapsed)
			transport = _transport(city)
			print("SUPPLY_DELIVERED deposited=%s food=%d" % [transport.get("deposited", false), city.food])
			passed = bool(transport.get("deposited", false)) and city.food == 100 and scene.flush_runtime_persistence(&"field_supply_worker_b")
		"C":
			var transport := _transport(city)
			var food_before: int = int(city.food)
			city.advance_war_loop_time(5000)
			var duplicate_credit: bool = int(city.food) != food_before
			print("SUPPLY_RESTORED_DONE phase=%s deposited=%s food=%d duplicate_credit=%s" % [transport.get("phase", &""), transport.get("deposited", false), city.food, duplicate_credit])
			passed = bool(transport.get("deposited", false)) and city.food == 100 and not duplicate_credit
	print("FIELD_SUPPLY_R0_WORKER_%s %s pid=%d" % [mode, "PASS" if passed else "FAIL", OS.get_process_id()])
	_write_result_marker(save_directory, mode, passed)
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _transport(city: Node) -> Dictionary:
	var transports := Dictionary(city.get_field_tactics_read_model().get("supply_transports_by_id", {}))
	var ids: Array = transports.keys()
	ids.sort()
	return Dictionary(transports.get(ids.front(), {})) if not ids.is_empty() else {}


func _write_result_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("field_supply_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("FIELD_SUPPLY_R0_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

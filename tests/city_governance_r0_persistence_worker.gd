extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")


func _initialize() -> void:
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
			city.restart_first_map()
			city.adjust_city_workforce(&"medical", -4)
			city.food = 0
			for _day in range(3):
				city._advance_day_boundary(true)
			var state: Dictionary = city.get_city_governance_read_model()
			passed = int(state.diseased_count) == 4 and StringName(Dictionary(state.active_event).phase) == &"ACTIVE" and scene.flush_runtime_persistence(&"governance_worker_a")
			print("GOVERNANCE_A day=%d diseased=%d event=%s" % [city.current_day, int(state.diseased_count), String(Dictionary(state.active_event).event_id)])
		"B":
			var state: Dictionary = city.get_city_governance_read_model()
			var event_id := StringName(Dictionary(state.active_event).event_id)
			city.food = 5
			var result: Dictionary = city.resolve_city_governance_event()
			passed = int(city.current_day) == 4 and int(state.diseased_count) == 4 and event_id != &"" and bool(result.success) and city.food == 3 and scene.flush_runtime_persistence(&"governance_worker_b")
			print("GOVERNANCE_B restored_event=%s resolved=%s food=%d" % [String(event_id), str(result.get("success", false)), city.food])
		"C":
			var state: Dictionary = city.get_city_governance_read_model()
			passed = int(city.current_day) == 4 and StringName(Dictionary(state.active_event).phase) == &"IDLE" and city.food == 3 and city._city_governance.resolved_event_ids.size() == 1
			print("GOVERNANCE_C event_phase=%s resolved=%d food=%d" % [String(Dictionary(state.active_event).phase), city._city_governance.resolved_event_ids.size(), city.food])
	_write_marker(save_directory, mode, passed)
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _write_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("city_governance_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("CITY_GOVERNANCE_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])

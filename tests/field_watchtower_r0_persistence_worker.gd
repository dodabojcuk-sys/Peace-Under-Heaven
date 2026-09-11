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
			city._war_loop_state = WarLoopState.new()
			city._ensure_war_loop_initialized()
			var field: FieldTacticsState = city._war_loop_state.field_tactics
			field.patrols_by_id.clear()
			field.camps_by_id[&"camp.watchtower.persist"] = {
				"camp_id": &"camp.watchtower.persist", "point_id": &"camp.watchtower.persist.point",
				"road_id": &"road.blackstone.northwatch.ridge", "display_name": "持久化工程驻点",
				"world_position": Vector2i(360, 610), "durability": 80, "connected": true,
			}
			var engineer_id := StringName(Dictionary(city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER).get("specialist", {})).get("specialist_id", &""))
			var started: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.watchtower.persist", Vector2i(430, 620))
			city.advance_war_loop_time(500)
			var project := Dictionary(started.get("project", {}))
			var restored_project := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {}).get(StringName(project.get("project_id", &"")), {}))
			print("WATCHTOWER_MID phase=%s travel=%d progress=%d" % [restored_project.get("phase", &""), restored_project.get("travel_milliseconds", -1), restored_project.get("progress_milliseconds", -1)])
			passed = bool(started.get("success", false)) and StringName(restored_project.get("phase", &"")) == &"TRAVELING" and scene.flush_runtime_persistence(&"watchtower_worker_a")
		"B":
			city._ensure_war_loop_initialized()
			var field: FieldTacticsState = city._war_loop_state.field_tactics
			var project := _first_watchtower_project(field)
			var restored_phase := StringName(project.get("phase", &""))
			print("WATCHTOWER_RESTORED_MID phase=%s progress=%d" % [restored_phase, project.get("progress_milliseconds", -1)])
			var remaining := maxi(int(project.get("travel_milliseconds", 0)) - 500, 0) + maxi(int(project.get("required_milliseconds", 0)) - int(project.get("progress_milliseconds", 0)), 0)
			city.advance_war_loop_time(remaining + 1)
			var towers := Dictionary(city.get_field_tactics_read_model().get("watchtowers_by_id", {}))
			print("WATCHTOWER_COMPLETE count=%d" % towers.size())
			# Completion itself crosses the Controller's normal field checkpoint. C
			# proves that published state through a fresh process; do not add a
			# test-only second write just to make this worker green.
			passed = restored_phase == &"TRAVELING" and towers.size() == 1
		"C":
			city._ensure_war_loop_initialized()
			var towers := Dictionary(city.get_field_tactics_read_model().get("watchtowers_by_id", {}))
			city.advance_war_loop_time(5000)
			var after := Dictionary(city.get_field_tactics_read_model().get("watchtowers_by_id", {}))
			print("WATCHTOWER_RESTORED_COMPLETE count=%d stable=%s" % [towers.size(), towers == after])
			passed = towers.size() == 1 and towers == after
	print("FIELD_WATCHTOWER_R0_WORKER_%s %s pid=%d" % [mode, "PASS" if passed else "FAIL", OS.get_process_id()])
	_write_marker(save_directory, mode, passed)
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _first_watchtower_project(field: FieldTacticsState) -> Dictionary:
	for project_value in field.projects_by_id.values():
		var project: Dictionary = Dictionary(project_value)
		if StringName(project.get("project_kind", &"")) == &"WATCHTOWER":
			return project
	return {}


func _write_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var file := FileAccess.open(save_directory.path_join("watchtower_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if file != null:
		file.store_string("FIELD_WATCHTOWER_R0_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var passed := false
	match mode:
		"A":
			city.food = 80
			var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
			var project: Dictionary = city.begin_field_road_project(
				StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
				&"blackstone_city", &"reedbank_garrison",
				[Vector2i(150, 430), Vector2i(440, 570), Vector2i(850, 505)],
				FieldTacticsState.ROAD_NORMAL, true
			)
			city.advance_war_loop_time(2500)
			passed = bool(project.get("success", false)) and scene.flush_runtime_persistence(&"field_worker_a")
		"B":
			var model: Dictionary = city.get_field_tactics_read_model()
			for project_value in Dictionary(model.get("projects_by_id", {})).values():
				var project: Dictionary = project_value
				if StringName(project.get("phase", &"")) == &"BUILDING":
					city.advance_war_loop_time(int(project.required_milliseconds) - int(project.progress_milliseconds))
					break
			var field: Dictionary = city.get_field_tactics_read_model()
			passed = not Dictionary(field.get("camps_by_id", {})).is_empty() and scene.flush_runtime_persistence(&"field_worker_b")
		"C":
			var field: Dictionary = city.get_field_tactics_read_model()
			var road_open := false
			for road_value in Dictionary(field.get("roads_by_id", {})).values():
				var road: Dictionary = road_value
				if StringName(road.get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL:
					road_open = StringName(road.get("state", &"")) == FieldTacticsState.ROAD_OPEN
			passed = road_open and not Dictionary(field.get("camps_by_id", {})).is_empty()
		"D":
			city.food = 80
			var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
			var project: Dictionary = city.begin_field_road_project(
				StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
				&"blackstone_city", &"reedbank_garrison",
				[Vector2i(150, 430), Vector2i(440, 570), Vector2i(850, 505)],
				FieldTacticsState.ROAD_NORMAL, true
			)
			city.advance_war_loop_time(int(Dictionary(project.get("project", {})).get("required_milliseconds", 0)))
			var road_id := StringName(Dictionary(project.get("project", {})).get("road_id", &""))
			var state: FieldTacticsState = city._war_loop_state.field_tactics
			state.damage_road(road_id, 999)
			var repair: Dictionary = city.begin_field_road_repair(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), road_id)
			var moving := Dictionary(state.specialists_by_id[StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))])
			city.advance_war_loop_time(maxi(1, int(moving.get("move_remaining_milliseconds", 0)) / 2))
			passed = bool(repair.get("success", false)) and not state.is_route_open(road_id) and scene.flush_runtime_persistence(&"field_worker_d")
		"E":
			var state: FieldTacticsState = city._war_loop_state.field_tactics
			var repair_project: Dictionary = _first_repair_project(state)
			var engineer := Dictionary(state.specialists_by_id[StringName(repair_project.get("engineer_id", &""))])
			city.advance_war_loop_time(int(engineer.get("move_remaining_milliseconds", 0)) + 500)
			repair_project = _first_repair_project(state)
			passed = StringName(repair_project.get("phase", &"")) == &"BUILDING" and int(repair_project.get("progress_milliseconds", 0)) == 500 and scene.flush_runtime_persistence(&"field_worker_e")
		"F":
			var state: FieldTacticsState = city._war_loop_state.field_tactics
			var repair_project: Dictionary = _first_repair_project(state)
			city.advance_war_loop_time(int(repair_project.get("required_milliseconds", 0)) - int(repair_project.get("progress_milliseconds", 0)))
			var road := Dictionary(state.roads_by_id.get(StringName(repair_project.get("road_id", &"")), {}))
			passed = StringName(repair_project.get("phase", &"")) == &"COMPLETE" and StringName(road.get("state", &"")) == FieldTacticsState.ROAD_OPEN
	print("FIELD_TACTICS_WORKER_%s %s pid=%d" % [mode, "PASS" if passed else "FAIL", OS.get_process_id()])
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _first_repair_project(state: FieldTacticsState) -> Dictionary:
	for project_value in state.projects_by_id.values():
		var project: Dictionary = project_value
		if StringName(project.get("project_kind", &"")) == &"REPAIR":
			return project
	return {}

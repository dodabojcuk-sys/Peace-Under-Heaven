extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")


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
			# Construction leaves its engineer at the far endpoint.  Return through
			# the actual specialist movement entry before creating the repair so this
			# chain exercises a genuine persisted repair-arrival phase.
			var return_move := state.order_specialist_move(
				StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
				&"northwatch_garrison"
			)
			city.advance_war_loop_time(int(return_move.get("move_remaining_milliseconds", 0)))
			state.damage_road(road_id, 999)
			var repair: Dictionary = city.begin_field_road_repair(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), road_id)
			var moving := Dictionary(state.specialists_by_id[StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))])
			city.advance_war_loop_time(maxi(1, int(moving.get("move_remaining_milliseconds", 0)) / 2))
			passed = bool(repair.get("success", false)) and not return_move.is_empty() and int(moving.get("move_remaining_milliseconds", 0)) > 0 and not state.is_route_open(road_id) and scene.flush_runtime_persistence(&"field_worker_d")
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
		"G":
			city.food = 200
			var roster: Array[Dictionary] = city.get_formation_roster()
			var lowland: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
			var northwatch_reedbank: Dictionary = THEATER.get_route(&"road.northwatch.reedbank")
			var draw_points := Array(lowland.points).duplicate(true)
			draw_points.pop_back()
			draw_points.append_array(Array(northwatch_reedbank.points))
			var plan: Dictionary = city.plan_field_path(&"blackstone_city", &"reedbank_garrison", draw_points)
			var issued: Dictionary = city.commit_macro_march_from_city(
				[StringName(roster[0].formation_id)], &"reedbank_garrison", StringName(plan.get("route_id", &"")), Array(plan.get("points", []))
			)
			var macro: Dictionary = Dictionary(Dictionary(issued.get("army", {})).get("macro_march", {}))
			city._advance_all_macro_marches_seconds(float(int(plan.get("duration_milliseconds", 0))) * 0.7 / 1000.0)
			var advanced: Dictionary = city._army_registry.get_army(StringName(Dictionary(issued.get("army", {})).get("army_id", &"")))
			passed = bool(plan.get("valid", false)) and bool(issued.get("success", false)) and Array(macro.get("route_segments", [])).size() == 2 and int(Dictionary(advanced.get("macro_march", {})).get("progress_millis", 0)) > 0 and scene.flush_runtime_persistence(&"field_worker_g")
		"H":
			var marching: Dictionary = _first_macro_army(city)
			var marching_macro: Dictionary = Dictionary(marching.get("macro_march", {}))
			city._advance_all_macro_marches_seconds(float(int(marching_macro.get("total_millis", 0)) - int(marching_macro.get("progress_millis", 0))) / 1000.0)
			var arrived: Dictionary = city._army_registry.get_army(StringName(marching.get("army_id", &"")))
			passed = StringName(marching.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING and Array(marching_macro.get("route_segments", [])).size() == 2 and StringName(arrived.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and scene.flush_runtime_persistence(&"field_worker_h")
		"I":
			var arrived: Dictionary = _first_macro_army(city)
			var arrived_macro: Dictionary = Dictionary(arrived.get("macro_march", {}))
			passed = StringName(arrived.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and StringName(arrived.get("target_node_id", &"")) == &"reedbank_garrison" and Array(arrived_macro.get("route_segments", [])).size() == 2
		"J":
			passed = _start_blocked_transfer(city, scene)
		"K":
			var army := _first_macro_army(city)
			var transfer := Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
			city._advance_all_macro_marches_seconds(float(int(transfer.get("total_millis", 0)) - int(transfer.get("progress_millis", 0))) / 1000.0)
			army = _first_macro_army(city)
			transfer = Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
			passed = StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED and StringName(transfer.get("phase", &"")) == &"WAITING" and scene.flush_runtime_persistence(&"field_worker_k")
		"L":
			var army := _first_macro_army(city)
			var macro := Dictionary(army.get("macro_march", {}))
			var transfer := Dictionary(macro.get("blocked_transfer", {}))
			var road_id := StringName(Dictionary(Array(macro.get("route_segments", [])).back()).get("road_id", &""))
			var engineer_id := _first_engineer_id(city)
			var repair := city.begin_field_road_repair(engineer_id, road_id)
			var engineer := Dictionary(city._war_loop_state.field_tactics.specialists_by_id[engineer_id])
			city.advance_war_loop_time(int(engineer.get("move_remaining_milliseconds", 0)) + int(Dictionary(repair.get("project", {})).get("required_milliseconds", 0)))
			army = _first_macro_army(city)
			transfer = Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
			city._advance_all_macro_marches_seconds(float(int(transfer.get("total_millis", 0)) / 2) / 1000.0)
			army = _first_macro_army(city)
			transfer = Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
			passed = bool(repair.get("success", false)) and StringName(transfer.get("phase", &"")) == &"TO_RESUME" and int(transfer.get("progress_millis", 0)) > 0 and scene.flush_runtime_persistence(&"field_worker_l")
		"M":
			var army := _first_macro_army(city)
			var macro := Dictionary(army.get("macro_march", {}))
			var transfer := Dictionary(macro.get("blocked_transfer", {}))
			city._advance_all_macro_marches_seconds(float(int(transfer.get("total_millis", 0)) - int(transfer.get("progress_millis", 0))) / 1000.0)
			city.advance_war_loop_time(1)
			army = _first_macro_army(city)
			macro = Dictionary(army.get("macro_march", {}))
			var resume_progress := int(macro.get("progress_millis", 0))
			city._advance_all_macro_marches_seconds(1.0)
			army = _first_macro_army(city)
			passed = StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING and int(Dictionary(army.get("macro_march", {})).get("progress_millis", 0)) > resume_progress
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


func _first_macro_army(city: Node) -> Dictionary:
	for army_value in city.get_macro_march_armies():
		return Dictionary(army_value)
	return {}


func _first_engineer_id(city: Node) -> StringName:
	for specialist_id_value in city._war_loop_state.field_tactics.specialists_by_id:
		var specialist: Dictionary = city._war_loop_state.field_tactics.specialists_by_id[specialist_id_value]
		if StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_ENGINEER:
			return StringName(specialist_id_value)
	return &""


func _start_blocked_transfer(city: Node, scene: Node) -> bool:
	city.food = 200
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))
	var safe := city.begin_field_road_project(engineer_id, &"blackstone_city", &"camp.site.transfer_safe", [Vector2i(150, 430), Vector2i(150, 555)], FieldTacticsState.ROAD_NORMAL, true)
	city.advance_war_loop_time(int(Dictionary(safe.get("project", {})).get("required_milliseconds", 0)))
	var target := city.begin_field_road_project(engineer_id, &"northwatch_garrison", &"camp.site.transfer_target", [Vector2i(790, 170), Vector2i(895, 245)], FieldTacticsState.ROAD_NORMAL, true)
	var target_project := Dictionary(target.get("project", {}))
	city.advance_war_loop_time(int(target_project.get("travel_milliseconds", 0)) + int(target_project.get("required_milliseconds", 0)))
	var lowland := THEATER.get_route(&"road.blackstone.northwatch.lowland")
	var drawn := Array(lowland.points).duplicate(true)
	drawn.pop_back()
	drawn.append_array([Vector2i(790, 170), Vector2i(895, 245)])
	var plan := city.plan_field_path(&"blackstone_city", &"camp.site.transfer_target", drawn)
	var roster: Array[Dictionary] = city.get_formation_roster()
	var issued := city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"camp.site.transfer_target", StringName(plan.get("route_id", &"")), Array(plan.get("points", [])))
	city._advance_all_macro_marches_seconds(4.5)
	city._war_loop_state.field_tactics.damage_road(StringName(target_project.get("road_id", &"")), 999)
	city._advance_all_macro_marches_seconds(0.1)
	var army := _first_macro_army(city)
	var transfer := Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
	city._advance_all_macro_marches_seconds(float(int(transfer.get("total_millis", 0)) / 2) / 1000.0)
	army = _first_macro_army(city)
	transfer = Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
	return bool(safe.get("success", false)) and bool(target.get("success", false)) and bool(plan.get("valid", false)) and bool(issued.get("success", false)) and StringName(transfer.get("phase", &"")) == &"TO_CAMP" and int(transfer.get("progress_millis", 0)) > 0 and scene.flush_runtime_persistence(&"field_worker_j")

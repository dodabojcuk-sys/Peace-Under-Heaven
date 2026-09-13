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
			city.wood = 100

			city.food = 100
			var cell := _find_legal_cell(city, &"building.farm.t1")
			var placement_id: int = city.place_definition_at_cell(&"building.farm.t1", cell, false, true)
			passed = placement_id > 0 and bool(city.begin_building_upgrade(placement_id).success) and scene.flush_runtime_persistence(&"building_growth_active")
		"B":
			var active_id := _find_definition_placement(city, &"building.farm.t1")
			passed = active_id > 0 and bool(city.preview_building_upgrade_state(active_id).active)
			city.advance_city_time_for_test(360.0)
			passed = passed and StringName(city.get_building_record(active_id).definition_id) == &"building.farm.t2" and scene.flush_runtime_persistence(&"building_growth_complete")
		"C":
			var completed_id := _find_definition_placement(city, &"building.farm.t2")
			passed = completed_id > 0 and not bool(city.preview_building_upgrade_state(completed_id).active) and int(city.get_building_record(completed_id).level) == 2
	print("BUILDING_GROWTH_%s day=%d state=%s" % [mode, city.current_day, "PASS" if passed else "FAIL"])
	_write_marker(save_directory, mode, passed)
	quit(0 if passed else 1)


func _find_definition_placement(city: Node, definition_id: StringName) -> int:
	for placement_id in city.get_placement_ids():
		if StringName(city.get_building_record(placement_id).definition_id) == definition_id:
			return placement_id
	return -1


func _find_legal_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if bool(validation.get("valid", false)) and StringName(validation.get("connection_state", &"")) == &"connected":
				return cell
	return Vector2i(-1, -1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _write_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("building_growth_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("BUILDING_GROWTH_%s %s" % [mode, "PASS" if passed else "FAIL"])

extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const CASE_ID := &"refugee.blackstone.northroad.001"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
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
			var cell := _find_legal_cell(city, &"building.housing.t1")
			city.place_definition_at_cell(&"building.housing.t1", cell, false, true)
			while city.current_day < 6:
				city._advance_day_boundary(true)
			city.decide_refugee_case(CASE_ID, &"ACCEPT")
			city.city_security = 40
			while city.current_day < 8:
				city._advance_day_boundary(true)
			city._city_governance.health_permille = 750
			while city.current_day < 10:
				city._advance_day_boundary(true)
			city._garrison_state.try_remove_units(city.INFANTRY_ROLE.role_id, 2)
			city._population_recovery.record_casualties(2, city.RECOVERY_RULES.wounded_permille)
			city._population_recovery.begin_treatment(1, 1, 1000)
			city._advance_population_recovery(500)
			city.set_city_time_paused(true)
			passed = _matches(city) and scene.flush_runtime_persistence(&"population_pressure_a")
		"B", "C":
			passed = _matches(city) and scene.flush_runtime_persistence(StringName("population_pressure_%s" % mode.to_lower()))
	var population: Dictionary = city.get_population_recovery_read_model()
	var governance: Dictionary = city.get_city_governance_read_model()
	print("POPULATION_PRESSURE_%s day=%d total=%d unsettled=%d growth=%d event=%s treatment=%d winter_shortfall=%d" % [mode, city.current_day, int(population.total_living), int(population.unsettled_refugees), int(population.growth_progress), String(Dictionary(governance.active_event).event_id), int(Dictionary(population.treatment).progress_milliseconds), int(governance.housing_shortfall)])
	_write_marker(save_directory, mode, passed)
	quit(0 if passed else 1)


func _matches(city: Node) -> bool:
	var population: Dictionary = city.get_population_recovery_read_model()
	var governance: Dictionary = city.get_city_governance_read_model()
	var refugee_case: Dictionary = Dictionary(Dictionary(governance.refugee_cases_by_id).get(CASE_ID, {}))
	return (
		city.current_day == 10
		and int(population.unsettled_refugees) == 9
		and int(population.growth_progress) == 750
		and StringName(refugee_case.phase) == &"WAITING_HOUSING"
		and StringName(Dictionary(governance.active_event).phase) == &"ACTIVE"
		and bool(Dictionary(governance.active_event).consequence_applied)
		and int(Dictionary(population.treatment).progress_milliseconds) == 500
		and int(governance.housing_shortfall) == 1
		and int(governance.consecutive_housing_pressure_days) == 1
		and bool(population.accounted)
	)


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
	var marker := FileAccess.open(save_directory.path_join("population_pressure_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("POPULATION_PRESSURE_%s %s" % [mode, "PASS" if passed else "FAIL"])

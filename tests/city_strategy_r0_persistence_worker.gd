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
			var appointed: Dictionary = city.appoint_city_official(&"official.physician")
			var support: Dictionary = city.activate_city_official_support()
			var crafted: Dictionary = city.craft_city_equipment(&"equipment.marching_kit")
			var equipped: Dictionary = city.equip_city_troops(&"equipment.marching_kit")
			city.food = 0
			var traded: Dictionary = city.execute_city_trade(&"trade.wood_for_food")
			var route: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison")
			var roster: Array[Dictionary] = city.get_formation_roster()
			var issued: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(route.route_id), Array(route.points))
			passed = bool(appointed.success) and bool(support.success) and bool(crafted.success) and bool(equipped.success) and bool(traded.success) and bool(issued.success) and scene.flush_runtime_persistence(&"strategy_worker_a")
			print("STRATEGY_A energy=%d receipts=%d army=%s duration=%d" % [int(city.get_city_strategy_read_model().campaign_energy), Array(city.get_city_strategy_read_model().trade_receipts).size(), String(Dictionary(issued.get("army", {})).get("army_id", &"")), int(Dictionary(issued.get("army", {})).get("duration_milliseconds", 0))])
		"B":
			var model: Dictionary = city.get_city_strategy_read_model()
			var armies: Dictionary = city.get_army_registry_snapshot().armies_by_id
			var duplicate_trade: Dictionary = city.execute_city_trade(&"trade.wood_for_food")
			var day_advanced: bool = bool(city._advance_day_boundary(true))
			passed = int(model.campaign_energy) == 2 and StringName(Dictionary(model.active_support).phase) == &"ACTIVE" and Array(model.trade_receipts).size() == 1 and armies.size() == 1 and not bool(duplicate_trade.success) and day_advanced and scene.flush_runtime_persistence(&"strategy_worker_b")
			print("STRATEGY_B restored_energy=%d support=%s receipts=%d armies=%d day=%d" % [int(model.campaign_energy), String(Dictionary(model.active_support).phase), Array(model.trade_receipts).size(), armies.size(), city.current_day])
		"C":
			var model: Dictionary = city.get_city_strategy_read_model()
			var armies: Dictionary = city.get_army_registry_snapshot().armies_by_id
			passed = city.current_day == 2 and int(model.campaign_energy) == 2 and StringName(Dictionary(model.active_support).phase) == &"IDLE" and Array(model.trade_receipts).size() == 1 and armies.size() == 1
			print("STRATEGY_C day=%d energy=%d support=%s receipts=%d armies=%d" % [city.current_day, int(model.campaign_energy), String(Dictionary(model.active_support).phase), Array(model.trade_receipts).size(), armies.size()])
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
	var marker := FileAccess.open(save_directory.path_join("city_strategy_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("CITY_STRATEGY_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])

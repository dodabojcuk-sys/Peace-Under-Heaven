extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const SAVE_STORE = preload("res://scripts/state/v5_campaign_save_store.gd")

var failures: Array[String] = []


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	_require(mode in ["A", "B", "C"], "worker mode 必须为 A、B 或 C")
	_require(not save_directory.is_empty(), "worker 必须使用隔离 V5 存档目录")
	if not failures.is_empty():
		_finish(mode)
		return
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var store := SAVE_STORE.new(save_directory)
	match mode:
		"A": _run_a(city, store)
		"B": _run_b(city, store)
		"C": _run_c(city, store)
	scene.queue_free()
	await process_frame
	_finish(mode)


func _run_a(city: Node, store: RefCounted) -> void:
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id), StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points))
	var army: Dictionary = issued.get("army", {})
	var macro: Dictionary = army.get("macro_march", {})
	city.advance_macro_march_time(StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.get("army_id", &"")), &"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points))
	var before: Dictionary = city.get_parent().get_runtime_persistence_status()
	var attack_macro: Dictionary = Dictionary(attack.get("army", {})).get("macro_march", {})
	var arrival: Dictionary = city.advance_macro_march_time(StringName(Dictionary(attack.get("army", {})).get("army_id", &"")), StringName(attack_macro.get("order_id", &"")), 0, int(attack_macro.get("total_millis", 0)))
	var disk: Dictionary = store.load_latest(Callable(city, "validate_v5_campaign_snapshot"))
	_require(bool(arrival.get("success", false)) and int(city.get_parent().get_runtime_persistence_status().get("save_sequence", 0)) > int(before.get("save_sequence", 0)) and bool(disk.get("success", false)) and not Dictionary(Dictionary(disk.get("snapshot", {})).get("war_loop", {})).get("active_siege", {}).is_empty(), "A 敌城抵达后立即发布攻城会话到磁盘")
	print("WAR_LOOP_ARRIVAL_A sequence=%d pid=%d" % [int(city.get_parent().get_runtime_persistence_status().get("save_sequence", 0)), OS.get_process_id()])


func _run_b(city: Node, store: RefCounted) -> void:
	for _index in range(30):
		var result: Dictionary = city.advance_war_loop_time(250)
		if bool(result.get("level_cleared", false)) or StringName(city.get_macro_march_army().get("phase", &"")) == ArmyRegistry.PHASE_STATIONED:
			break
	var red_army: Dictionary = city.get_macro_march_army()
	_require(StringName(red_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and StringName(red_army.get("target_node_id", &"")) == &"redcliff_city", "B 冷恢复后可完成首城破门清守并驻扎")
	if not failures.is_empty():
		return
	var to_silverford: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
	var issued: Dictionary = city.commit_macro_march_from_station(StringName(red_army.get("army_id", &"")), &"silverford_city", StringName(to_silverford.route_id), Array(to_silverford.points))
	var before: Dictionary = city.get_parent().get_runtime_persistence_status()
	var macro: Dictionary = Dictionary(issued.get("army", {})).get("macro_march", {})
	var arrival: Dictionary = city.advance_macro_march_time(StringName(Dictionary(issued.get("army", {})).get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var disk: Dictionary = store.load_latest(Callable(city, "validate_v5_campaign_snapshot"))
	var cities: Dictionary = Dictionary(Dictionary(disk.get("snapshot", {})).get("war_loop", {})).get("cities_by_id", {})
	var silverford: Dictionary = cities.get(&"silverford_city", {})
	_require(bool(arrival.get("success", false)) and int(city.get_parent().get_runtime_persistence_status().get("save_sequence", 0)) > int(before.get("save_sequence", 0)) and StringName(silverford.get("military_controller_faction_id", &"")) == &"player", "B 即时招降占领返回后立即读盘为玩家控制")
	print("WAR_LOOP_ARRIVAL_B sequence=%d pid=%d" % [int(city.get_parent().get_runtime_persistence_status().get("save_sequence", 0)), OS.get_process_id()])


func _run_c(city: Node, _store: RefCounted) -> void:
	var model: Dictionary = city.get_macro_march_read_model()
	var cities: Dictionary = Dictionary(model.get("war_loop", {})).get("cities_by_id", {})
	_require(StringName(Dictionary(cities.get(&"redcliff_city", {})).get("military_controller_faction_id", &"")) == &"player" and StringName(Dictionary(cities.get(&"silverford_city", {})).get("military_controller_faction_id", &"")) == &"player" and bool(model.get("level_cleared", false)), "C 新进程直接恢复双城控制与完成状态")
	print("WAR_LOOP_ARRIVAL_C pid=%d" % OS.get_process_id())


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WAR_LOOP_ARRIVAL_WORKER_FAIL: %s" % description)


func _finish(mode: String) -> void:
	if failures.is_empty():
		print("WAR_LOOP_ARRIVAL_WORKER_%s PASS" % mode)
		quit(0)
		return
	quit(1)

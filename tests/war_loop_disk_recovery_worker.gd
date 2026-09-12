extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

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
	# Freeze the formal scene before its first idle frame: this runner advances
	# siege time only through the explicit calls below, never through startup
	# frame timing that a cold process happens to receive.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	match mode:
		"A":
			_run_a(scene, city)
		"B":
			_run_b(scene, city)
		"C":
			_run_c(city)
	scene.queue_free()
	await process_frame
	_finish(mode)


func _run_a(scene: Node, city: Node) -> void:
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points)
	)
	_require(bool(issued.get("success", false)), "A 建立黑石至北望军令")
	if issued.is_empty():
		return
	var army: Dictionary = issued.army
	var macro: Dictionary = army.macro_march
	city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.army_id), &"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points))
	_require(bool(attack.get("success", false)), "A 建立北望至赤崖军令")
	if attack.is_empty():
		return
	var attack_macro: Dictionary = attack.army.macro_march
	var arrival: Dictionary = city.advance_macro_march_time(StringName(attack.army.army_id), StringName(attack_macro.order_id), 0, int(attack_macro.total_millis))
	var partial: Dictionary = city.advance_war_loop_time(250)
	_require(bool(arrival.get("success", false)) and int(partial.get("tick", 0)) == 1, "A 在首个攻城 tick 后写入磁盘")
	_require(scene.flush_runtime_persistence(&"war_loop_disk_a"), "A 刷新真实 V5 代次")
	if not partial.is_empty():
		print("WAR_LOOP_DISK_A tick=%d gate=%d pid=%d" % [int(partial.tick), int(partial.gate_hp), OS.get_process_id()])


func _run_b(scene: Node, city: Node) -> void:
	var siege: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).active_siege
	_require(int(siege.get("tick", 0)) == 1 and int(siege.get("gate_hp", 0)) < 240, "B 冷启动恢复 A 的攻城 tick 与受损城门")
	var advanced: Dictionary = city.advance_war_loop_time(250)
	_require(int(advanced.get("tick", 0)) == 2, "B 仅推进一个后续攻城 tick")
	_require(scene.flush_runtime_persistence(&"war_loop_disk_b"), "B 刷新第二个真实 V5 代次")
	if not advanced.is_empty():
		print("WAR_LOOP_DISK_B tick=%d gate=%d pid=%d" % [int(advanced.tick), int(advanced.gate_hp), OS.get_process_id()])


func _run_c(city: Node) -> void:
	var siege: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).active_siege
	_require(int(siege.get("tick", 0)) == 2 and int(siege.get("gate_hp", 0)) < 230, "C 再次冷启动保留 B 的唯一后续推进")
	print("WAR_LOOP_DISK_C tick=%d gate=%d pid=%d" % [int(siege.get("tick", 0)), int(siege.get("gate_hp", 0)), OS.get_process_id()])


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WAR_LOOP_DISK_WORKER_FAIL: %s" % description)


func _finish(mode: String) -> void:
	if failures.is_empty():
		print("WAR_LOOP_DISK_WORKER_%s PASS" % mode)
		quit(0)
		return
	print("WAR_LOOP_DISK_WORKER_%s FAIL: %s" % [mode, failures])
	quit(1)

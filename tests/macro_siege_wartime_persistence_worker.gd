extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	_require(mode in ["A", "B", "C", "D"], "worker mode 必须为 A、B、C 或 D")
	_require(not _argument_value("--txwzs-v5-save-dir=").is_empty(), "worker 必须使用隔离 V5 存档目录")
	if not failures.is_empty():
		_finish(mode)
		return
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	# Explicit calls below own the test timeline; disabling only the controller
	# freezes world advancement without preventing the independently-instanced
	# C0 scene from running its normal _ready request construction.
	city.set_process(false)
	match mode:
		"A": await _run_a(scene, city)
		"B": await _run_b(scene, city)
		"C": await _run_c(scene, city)
		"D": _run_d(city)
	scene.queue_free()
	await process_frame
	_finish(mode)


func _run_a(scene: Node, city: Node) -> void:
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var first_leg: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var north: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	_require(bool(north.get("success", false)), "A 建立首段正式军令")
	if north.is_empty():
		return
	var army: Dictionary = north.army
	var macro: Dictionary = army.macro_march
	city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.army_id), &"redcliff_city", StringName(attack_route.route_id), Array(attack_route.points))
	_require(bool(attack.get("success", false)), "A 建立围城军令")
	if attack.is_empty():
		return
	army = attack.army
	macro = army.macro_march
	city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
	_require(city.enter_macro_siege_wartime(StringName(army.army_id), &"redcliff_city"), "A 从真实围城进入战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_require(battle != null and battle.start_battle(), "A 激活唯一战时会话")
	var active_siege: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	_require(
		StringName(Dictionary(active_siege.get("wartime_handoff", {})).get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_ACTIVE,
		"A 激活后运行时围城已让出推进权"
	)
	_require(not city.export_v5_campaign_snapshot().is_empty(), "A 活动接管可导出当前 V5 快照")
	_require(scene.flush_runtime_persistence(&"macro_siege_wartime_a"), "A 保存接管完成且战斗进行中的真实 V5 代次")
	if battle != null:
		print("MACRO_SIEGE_WARTIME_DISK_A army=%s transaction=%s" % [army.army_id, battle.request.transaction_id])


func _run_b(scene: Node, city: Node) -> void:
	var siege: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).active_siege
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	var army_id := StringName(siege.get("army_id", &""))
	_require(StringName(handoff.get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_ACTIVE, "B 冷启动读取 A 的活动接管")
	_require(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "B 从活动接管重开同一战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_require(battle != null and battle.coordinator.active_session != null, "B 恢复同一活动战斗会话")
	if battle == null or battle.coordinator.active_session == null:
		return
	var session := battle.coordinator.active_session
	_require(session.request_forced_retreat(), "B 建立真实撤退请求")
	battle.coordinator.advance_battle_tick()
	for squad in session.squads:
		if int(squad.get("total_hp", 0)) > 0 and not bool(squad.get("exited", false)):
			battle.coordinator.issue_order(int(squad.get("squad_id", 0)), BattleOrder.Command.RETREAT)
	var result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		result = battle.coordinator.advance_battle_tick()
		if result != null:
			break
	var pending: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	_require(result != null and StringName(Dictionary(pending.get("wartime_handoff", {})).get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_RESULT_PENDING, "B 终局只发布待回写结果")
	_require(scene.flush_runtime_persistence(&"macro_siege_wartime_b"), "B 保存终局待回写的真实 V5 代次")
	print("MACRO_SIEGE_WARTIME_DISK_B result=%s" % String(result.result_id if result != null else &""))


func _run_c(scene: Node, city: Node) -> void:
	var siege: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).active_siege
	var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
	var army_id := StringName(siege.get("army_id", &""))
	_require(StringName(handoff.get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_RESULT_PENDING, "C 冷启动读取待回写结果")
	_require(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "C 重新进入同一待回写战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_require(battle != null and battle.result_panel.visible and battle.coordinator.active_session.completed, "C 显示已保存战果而不重演战斗")
	if battle == null:
		return
	var settled := battle.confirm_pending_result()
	_require(not settled.is_empty(), "C 一次回写原军队、围城与目标")
	_require(scene.flush_runtime_persistence(&"macro_siege_wartime_c"), "C 保存已回写的真实 V5 代次")
	print("MACRO_SIEGE_WARTIME_DISK_C army=%s" % army_id)


func _run_d(city: Node) -> void:
	var armies: Array = Array(city.get_macro_march_read_model().armies)
	var retreating := false
	for army_value in armies:
		if StringName(Dictionary(army_value).get("phase", &"")) == ArmyRegistry.PHASE_RETREATING:
			retreating = true
	_require(
		Dictionary(city.get_macro_march_read_model().war_loop).active_siege.is_empty()
		and retreating,
		"D 冷启动保持一次回写后的围城关闭与原军队撤退状态"
	)
	print("MACRO_SIEGE_WARTIME_DISK_D complete")


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("MACRO_SIEGE_WARTIME_DISK_WORKER_FAIL: %s" % description)


func _finish(mode: String) -> void:
	if failures.is_empty():
		print("MACRO_SIEGE_WARTIME_DISK_WORKER_%s PASS" % mode)
		quit(0)
		return
	print("MACRO_SIEGE_WARTIME_DISK_WORKER_%s FAIL: %s" % [mode, failures])
	quit(1)

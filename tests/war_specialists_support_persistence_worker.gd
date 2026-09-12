extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/c0_battle_graybox.tscn")
const FACILITY_ID := &"facility.redcliff.lookout.001"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	_require(mode in ["A", "B", "C"], "worker mode 必须为 A、B 或 C")
	_require(not save_directory.is_empty(), "worker 必须使用隔离 V5 存档目录")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	match mode:
		"A": await _run_a(scene, city)
		"B": await _run_b(scene, city)
		"C": await _run_c(city)
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("WAR_SPECIALISTS_SUPPORT_WORKER_%s PASS" % mode)
		quit(0)
		return
	quit(1)


func _run_a(scene: Node, city: Node) -> void:
	city.restart_first_map()
	city._war_loop_state.field_tactics.patrols_by_id.clear()
	var dispatched: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SABOTEUR)
	var specialist_id := StringName(Dictionary(dispatched.get("specialist", {})).get("specialist_id", &""))
	var facility := Dictionary(city._war_loop_state.field_tactics.watchtowers_by_id.get(FACILITY_ID, {}))
	var discovered: Array = Array(facility.get("discovered_by_faction_ids", [])).duplicate()
	discovered.append(&"player")
	facility.discovered_by_faction_ids = discovered
	city._war_loop_state.field_tactics.watchtowers_by_id[FACILITY_ID] = facility
	var begun: Dictionary = city.begin_field_specialist_action(specialist_id, FieldTacticsState.ACTION_SABOTAGE, FACILITY_ID)
	city.advance_war_loop_time(1000)
	var action := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(specialist_id, {}))
	_require(bool(dispatched.get("success", false)) and bool(begun.get("success", false)), "A 经正式事务创建破坏任务")
	_require(StringName(action.get("action_stage", &"")) == FieldTacticsState.ACTION_TRAVELING and int(action.get("move_elapsed_milliseconds", 0)) > 0, "A 保存途中位置和进度")

	_require(bool(city.appoint_city_official(&"official.strategist").get("success", false)), "A 正式任命军谋官")
	var roster: Array[Dictionary] = city.get_formation_roster()
	_require(bool(city.commit_expedition_attempt([StringName(roster[0].formation_id)]).get("success", false)), "A 创建正式出征")
	var request := BattleRequest.from_expedition_attempt(city.get_expedition_attempt())
	var battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	battle.configure_formal_expedition(scene, city, request)
	root.add_child(battle)
	await process_frame
	await process_frame
	_require(battle.start_battle(), "A 启动正式战斗")
	battle.tick_timer.stop()
	var support := battle.coordinator.issue_official_support(BattleSession.SUPPORT_MOVE, 1)
	_require(bool(support.get("success", false)) and int(city.get_city_strategy_read_model().campaign_energy) == 2, "A 战中命令消耗共享能量")
	_require(scene.flush_runtime_persistence(&"war_specialists_support_a"), "A 发布专员途中和战中效果的真实 V5 代次")
	battle.queue_free()
	await process_frame


func _run_b(scene: Node, city: Node) -> void:
	var specialists: Dictionary = city._war_loop_state.field_tactics.specialists_by_id
	var specialist_id := StringName(specialists.keys()[0]) if not specialists.is_empty() else &""
	var action := Dictionary(specialists.get(specialist_id, {}))
	_require(StringName(action.get("action_stage", &"")) == FieldTacticsState.ACTION_TRAVELING and int(action.get("move_elapsed_milliseconds", 0)) > 0, "B 独立进程读取同一途中破坏任务")

	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	var resumed: bool = battle != null or city.resume_persisted_expedition()
	_require(resumed, "B 从标准城市入口重开持久战斗")
	await process_frame
	await process_frame
	battle = city.get_formal_battle_scene() as C0BattleGraybox
	_require(battle != null and battle.coordinator.active_session != null, "B 恢复同一活动 BattleSession")
	if battle == null or battle.coordinator.active_session == null:
		return
	battle.tick_timer.stop()
	var support_state := battle.coordinator.active_session.get_official_support_state()
	_require(Array(support_state.get("receipts", [])).size() == 1 and Array(support_state.get("effects", [])).size() == 1 and int(city.get_city_strategy_read_model().campaign_energy) == 2, "B 冷恢复命令回执、持续效果和共享能量")
	for _step in range(80):
		city.advance_war_loop_time(2000)
		action = Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(specialist_id, {}))
		if StringName(action.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED:
			break
	_require(StringName(action.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED, "B 从保存进度继续并只完成一次破坏")
	_require(scene.flush_runtime_persistence(&"war_specialists_support_b"), "B 发布完成动作和仍可恢复战斗的 V5 代次")
	battle.queue_free()
	await process_frame


func _run_c(city: Node) -> void:
	var specialists: Dictionary = city._war_loop_state.field_tactics.specialists_by_id
	var specialist_id := StringName(specialists.keys()[0]) if not specialists.is_empty() else &""
	var action := Dictionary(specialists.get(specialist_id, {}))
	var facility := Dictionary(city._war_loop_state.field_tactics.watchtowers_by_id.get(FACILITY_ID, {}))
	_require(StringName(action.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED and int(facility.get("durability", 0)) == 60, "C 冷恢复完成结果且不重复破坏")
	_require(int(city.get_city_strategy_read_model().campaign_energy) == 2, "C 重开不补充已消费的关卡能量")


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WAR_SPECIALISTS_SUPPORT_WORKER_FAIL: %s" % description)

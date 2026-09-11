extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	_require(mode in ["A", "B", "C", "D", "E", "F", "G"], "worker mode 必须有效")
	_require(not save_directory.is_empty(), "worker 必须使用隔离存档目录")
	if not failures.is_empty():
		_finish(mode, save_directory)
		return
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	match mode:
		"A": await _run_a(scene, city)
		"B": await _run_b(scene, city)
		"C": await _run_c(scene, city)
		"D": await _run_d(scene, city)
		"E": _run_e(city)
		"F": await _run_f(scene, city)
		"G": await _run_g(scene, city)
	scene.queue_free()
	await process_frame
	_finish(mode, save_directory)


func _run_a(scene: Node, city: Node) -> void:
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_id := StringName(roster[0].formation_id)
	var food_before := int(city.get("food"))
	var started: Dictionary = city.begin_wartime_defense_attempt([formation_id])
	_require(bool(started.get("success", false)), "A 从正式守城入口创建冻结尝试")
	if not bool(started.get("success", false)):
		return
	_require(city.enter_wartime_defense_battle(), "A 打开正式 C0 守城实例")
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_require(false, "A 守城实例存在")
		return
	var panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var barricade_button := panel.get_node("BarricadeButton") as Button
	var confirm_button := panel.get_node("ConfirmButton") as Button
	barricade_button.emit_signal("pressed")
	await process_frame
	confirm_button.emit_signal("pressed")
	await process_frame
	_require(battle.start_battle(), "A 由正式计划启动施工中的守城战斗")
	battle.tick_timer.stop()
	battle.step_battle_for_test(1)
	var facilities: Array = Array(battle.coordinator.active_session.get_wartime_facility_state().get("facilities", []))
	_require(
		facilities.size() == 1
			and StringName(Dictionary(facilities[0]).get("phase", &"")) == BattleSession.FACILITY_PHASE_CONSTRUCTING
			and int(Dictionary(facilities[0]).get("progress_ticks", -1)) == 1,
		"A 保存未完工拒马的真实施工刻"
	)
	_require(scene.flush_runtime_persistence(&"wartime_defense_a"), "A 发布施工中守城的真实 V5 代次")
	_require(int(city.get("food")) == food_before, "A 守城施工不创建出征粮食扣费")


func _run_b(scene: Node, city: Node) -> void:
	var attempt: Dictionary = city.get_expedition_attempt()
	_require(
		StringName(attempt.get("source_id", &"")) == BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(attempt.get("phase", &"")) == BattleRequest.PHASE_ACTIVE,
		"B 冷启动读取 A 的活动守城尝试"
	)
	if failures.size() > 0:
		return
	var opened: bool = city.get_formal_battle_scene() != null or city.enter_wartime_defense_battle()
	_require(opened, "B 重开同一守城实例")
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_require(false, "B 恢复 C0 守城实例")
		return
	var session := battle.coordinator.active_session
	var restored: Array = Array(session.get_wartime_facility_state().get("facilities", []))
	_require(
		restored.size() == 1
			and StringName(Dictionary(restored[0]).get("phase", &"")) == BattleSession.FACILITY_PHASE_CONSTRUCTING
			and int(Dictionary(restored[0]).get("progress_ticks", -1)) >= 1
			and int(Dictionary(restored[0]).get("progress_ticks", -1)) < int(Dictionary(restored[0]).get("required_ticks", 0)),
		"B 独立进程保留未完成施工阶段和非零进度，不从零重建或提前生效"
	)
	battle.tick_timer.stop()
	battle.step_battle_for_test(BattleSession.FACILITY_BUILD_TICKS[WartimeFacilityPlan.KIND_BARRICADE] - 1)
	# Advance through real enemy route movement until the completed barricade is
	# damaged by the protection objective rather than constructing damage data.
	battle.step_battle_for_test(126)
	var barricade := _barricade(session)
	battle._refresh_battle_ui()
	var repair_button := battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	_require(
		StringName(barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED
			and repair_button.visible and not repair_button.disabled,
		"B 自然抵达城门后的受损拒马提供正式维修操作"
	)
	repair_button.emit_signal("pressed")
	await process_frame
	barricade = _barricade(session)
	_require(
		StringName(barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING
			and int(barricade.get("progress_ticks", -1)) == 0,
		"B 维修一次写入同一会话，不复制设施"
	)
	_require(scene.flush_runtime_persistence(&"wartime_defense_b"), "B 发布维修中守城的真实 V5 代次")


func _run_c(scene: Node, city: Node) -> void:
	var opened: bool = city.get_formal_battle_scene() != null or city.enter_wartime_defense_battle()
	_require(opened, "C 从维修中重开相同守城实例")
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_require(false, "C 恢复维修中 C0 实例")
		return
	var session := battle.coordinator.active_session
	var repairing := _barricade(session)
	_require(StringName(repairing.get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING, "C 冷启动读取维修态")
	battle.tick_timer.stop()
	var remaining_repair_ticks := maxi(
		int(repairing.get("required_ticks", 0)) - int(repairing.get("progress_ticks", 0)),
		0
	)
	battle.step_battle_for_test(remaining_repair_ticks)
	var repaired := _barricade(session)
	_require(
		int(repaired.get("durability", 0)) > int(repairing.get("durability", 0))
			and StringName(repaired.get("phase", &"")) in [
				BattleSession.FACILITY_PHASE_ACTIVE,
				BattleSession.FACILITY_PHASE_DAMAGED,
			],
		"C 只消费剩余战斗刻完成维修；同刻再次遭到真实敌军攻击后保留新耐久"
	)
	_require(session.request_forced_retreat(), "C 以正式撤离规则结束已恢复守城")
	var terminal_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		terminal_result = battle.step_battle_for_test(1)
		if terminal_result != null:
			break
	_require(
		terminal_result != null,
		"C 正常战斗推进进入待确认守城战果"
	)
	_require(
		StringName(city.get_expedition_attempt().get("phase", &""))
			== BattleRequest.PHASE_RESULT_PENDING
			and not Dictionary(
				city.get_expedition_attempt().get("terminal_result_snapshot", {})
			).is_empty(),
		"C 待确认战果与终局快照作为同一真实 V5 检查点保存"
	)
	_require(scene.flush_runtime_persistence(&"wartime_defense_c"), "C 发布待回写守城的真实 V5 代次")


func _run_d(scene: Node, city: Node) -> void:
	var attempt: Dictionary = city.get_expedition_attempt()
	_require(
		StringName(attempt.get("phase", &"")) == BattleRequest.PHASE_RESULT_PENDING
			and not Dictionary(attempt.get("terminal_result_snapshot", {})).is_empty(),
		"D 冷启动读取待回写守城战果"
	)
	if not failures.is_empty():
		return
	var opened: bool = city.get_formal_battle_scene() != null or city.enter_wartime_defense_battle()
	_require(opened, "D 重开同一待确认守城实例")
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_require(
		battle != null
			and battle.coordinator.active_request.phase == BattleRequest.PHASE_RESULT_PENDING
			and battle.result_panel.visible
			and battle.confirm_button.visible
			and not battle.confirm_button.disabled,
		"D 冷启动恢复结果确认界面而不重放战斗"
	)
	if battle == null:
		return
	_require(
		not battle.confirm_pending_result().is_empty(),
		"D 经正式确认入口一次回写已恢复守城战果"
	)
	_require(scene.flush_runtime_persistence(&"wartime_defense_d"), "D 发布已结算守城的真实 V5 代次")


func _run_e(city: Node) -> void:
	var attempt: Dictionary = city.get_expedition_attempt()
	var summary: Dictionary = city.get_committed_battle_result_summary(StringName(attempt.get("result_id", &"")))
	_require(
		StringName(attempt.get("phase", &"")) == BattleRequest.PHASE_APPLIED
			and StringName(summary.get("source_id", &"")) == BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(summary.get("mission_id", &"")) == &"wartime_defense.blackstone_gate.v0"
			and city.get_formal_battle_scene() == null,
		"E 冷启动保留已结算守城结果，不重开或重放战斗"
	)


## F-G receive a separate isolated save directory from the runner. That keeps
## the first A-E chain's settled retreat fact intact while proving a distinct
## victory terminal record remains pending across a real process.
func _run_f(scene: Node, city: Node) -> void:
	var formation_ids: Array[StringName] = []
	for formation_value in city.get_formation_roster():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			formation_ids.append(StringName(formation.get("formation_id", &"")))
	var started: Dictionary = city.begin_wartime_defense_attempt(formation_ids)
	_require(bool(started.get("success", false)), "F 从正式守城入口冻结三支真实编队")
	if not bool(started.get("success", false)) or not city.enter_wartime_defense_battle():
		_require(false, "F 打开正式守城胜利实例")
		return
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null or not battle.start_battle():
		_require(false, "F 启动正式守城胜利战斗")
		return
	battle.tick_timer.stop()
	var advance_button := battle.get_node(
		"UI/RootPanel/SelectedSquadPanel/AdvanceButton"
	) as Button
	for squad_id in [1, 2, 3]:
		var select_button := battle.get_node(
			"UI/RootPanel/SquadControls/Squad%d/SelectButton" % squad_id
		) as Button
		select_button.emit_signal("pressed")
		advance_button.emit_signal("pressed")
		await process_frame
	var terminal_result: BattleResult = battle.step_battle_for_test(260)
	_require(
		terminal_result != null
			and terminal_result.outcome == BattleOutcome.Value.VICTORY
			and StringName(city.get_expedition_attempt().get("phase", &""))
				== BattleRequest.PHASE_RESULT_PENDING,
		"F 正式三编队操作产生待回写守城胜利而非测试伪造战果"
	)
	_require(scene.flush_runtime_persistence(&"wartime_defense_f"), "F 发布待回写守城胜利的真实 V5 代次")


func _run_g(scene: Node, city: Node) -> void:
	var attempt: Dictionary = city.get_expedition_attempt()
	_require(
		StringName(attempt.get("phase", &"")) == BattleRequest.PHASE_RESULT_PENDING
			and not Dictionary(attempt.get("terminal_result_snapshot", {})).is_empty(),
		"G 冷启动读取 F 的待回写守城胜利"
	)
	var opened: bool = city.get_formal_battle_scene() != null or city.enter_wartime_defense_battle()
	if not failures.is_empty() or not opened:
		_require(false, "G 重开同一待回写守城胜利实例")
		return
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	var summary: Dictionary = (
		battle.confirm_pending_result()
		if battle != null and battle.result_panel.visible
		else {}
	)
	_require(
		not summary.is_empty()
			and StringName(summary.get("outcome", &"")) == &"VICTORY"
			and not bool(city.get("city_fallen"))
			and city.get_city_defense() > 0,
		"G 重开后一次确认守城胜利，保留真实城门且不重演战斗"
	)
	_require(scene.flush_runtime_persistence(&"wartime_defense_g"), "G 发布已回写守城胜利的真实 V5 代次")


func _barricade(session: BattleSession) -> Dictionary:
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE:
			return record
	return {}


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WARTIME_DEFENSE_DISK_WORKER_FAIL: %s" % description)


func _finish(mode: String, save_directory: String) -> void:
	var passed := failures.is_empty()
	print("WARTIME_DEFENSE_DISK_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("wartime_defense_worker_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("WARTIME_DEFENSE_DISK_WORKER_%s %s" % [mode, "PASS" if passed else "FAIL"])
	quit(0 if passed else 1)

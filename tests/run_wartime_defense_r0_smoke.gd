extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var city_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(city_scene)
	await process_frame
	await process_frame
	var city: Node = city_scene.get_node("ConstructionController")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_id := StringName(roster[0].formation_id)
	var food_before := int(city.get("food"))
	var started: Dictionary = city.begin_wartime_defense_attempt([formation_id])
	_check(
		bool(started.get("success", false))
			and StringName(city.get_expedition_attempt().source_id) == BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(city.get_expedition_attempt().mission_id) == &"wartime_defense.blackstone_gate.v0"
			and int(city.get("food")) == food_before,
		"正式守城入口保存冻结编队和守城来源，不创建第二次出征粮食事务"
	)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var snapshot_validation: Dictionary = city.validate_v5_campaign_snapshot(snapshot)
	_check(
		not snapshot.is_empty()
			and bool(snapshot_validation.get("valid", false)),
		"守城 RESERVED 状态进入严格 V5 快照，而非公告板临时状态"
	)
	_check(city.enter_wartime_defense_battle(), "正式守城入口打开独立 C0 战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	watch_button.emit_signal("pressed")
	await process_frame
	_check(
		battle != null and plan_panel.visible and not confirm_button.disabled,
		"守城实例复用正式工事草稿与确认入口，不调用公告板临时战斗"
	)
	confirm_button.emit_signal("pressed")
	await process_frame
	_check(battle.start_battle(), "守城工事确认后由同一正式 C0 时钟启动")
	battle.tick_timer.stop()
	var objective: Dictionary = battle.coordinator.active_session.get_mission_objective_state()
	_check(
		StringName(objective.get("objective_type", &"")) == MissionDefinition.OBJECTIVE_PROTECT
			and str(objective.get("protect_target_name", "")) == "黑石城门"
			and int(objective.get("protect_target_hp", 0)) > 0,
		"守城实例从冻结任务读取真实城门保护目标，而非复用攻城胜利条件"
	)
	var active_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	battle.abort_formal_entry()
	await process_frame
	var restored_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(restored_scene)
	await process_frame
	var restored_city: Node = restored_scene.get_node("ConstructionController")
	var restored: Dictionary = restored_city.restore_v5_campaign_snapshot(active_snapshot)
	_check(
		bool(restored.get("success", false))
			and restored_city.enter_wartime_defense_battle(),
		"守城 RESERVED 状态冷恢复后仍只打开同一冻结防守实例"
	)
	await process_frame
	var restored_battle := restored_city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		restored_battle != null
			and restored_battle.start_battle()
			and restored_battle.open_exit_confirmation()
			and restored_battle.confirm_exit_as_retreat()
			and StringName(restored_city.get_expedition_attempt().phase) == BattleRequest.PHASE_APPLIED
			and int(restored_city.get("food")) == food_before,
		"守城撤离通过同一待回写结果事务结算幸存编队，不重复扣粮或改写主线出征"
	)
	city_scene.queue_free()
	restored_scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("WARTIME_DEFENSE_R0_SMOKE PASS")
		quit(0)
	else:
		print("WARTIME_DEFENSE_R0_SMOKE FAIL (%d)" % failures.size())
		quit(1)

extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/c0_battle_graybox.tscn")

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
	_check(city != null, "正式城市入口提供唯一 ConstructionController")
	if city == null:
		_finish()
		return
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_id := StringName(roster[0].formation_id)
	var departure: Dictionary = city.commit_expedition_attempt([formation_id])
	_check(bool(departure.get("success", false)), "正式出征先建立持久 RESERVED 尝试")
	if not bool(departure.get("success", false)):
		_finish()
		return
	var wood_before: int = int(city.get("wood"))
	var building_count_before: int = city.get_building_count()
	var request := BattleRequest.from_expedition_attempt(city.get_expedition_attempt())
	var battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	battle.configure_formal_expedition(city_scene, city, request)
	root.add_child(battle)
	await process_frame
	await process_frame
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var ram_button := plan_panel.get_node("RamButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	_check(
		plan_panel.visible and confirm_button.disabled,
		"正式战前界面显示可操作的临时工事计划，而非城市永久建造"
	)
	watch_button.emit_signal("pressed")
	ram_button.emit_signal("pressed")
	await process_frame
	_check(
		watch_button.text.contains("已选")
			and ram_button.text.contains("已选")
			and not confirm_button.disabled,
		"瞭望台和攻城槌在确认前仅修改战前草稿"
	)
	var before_confirm: Dictionary = city.export_v5_campaign_snapshot()
	confirm_button.emit_signal("pressed")
	await process_frame
	var attempt: Dictionary = city.get_expedition_attempt()
	var plan: Dictionary = attempt.wartime_facility_plan
	_check(
		Array(plan.facilities).size() == 2
			and city.wood == wood_before - 14
			and city.get_building_count() == building_count_before,
		"确认工事只扣一次木材并写入出征尝试，不污染常态内城 placement"
	)
	var duplicate: Dictionary = city.commit_wartime_facility_plan(
		StringName(attempt.attempt_id), plan
	)
	_check(
		not bool(duplicate.get("success", false))
			and city.export_v5_campaign_snapshot() != before_confirm
			and city.wood == wood_before - 14,
		"重复确认被拒绝，资源不重复扣除"
	)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var validation: Dictionary = city.validate_v5_campaign_snapshot(snapshot)
	_check(
		bool(validation.get("valid", false))
			and Dictionary(validation.snapshot).expedition_attempt == attempt,
		"当前 V5 快照严格保留战时工事计划"
	)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.schema_version = 7
	legacy.expedition_attempt.erase("wartime_facility_plan")
	legacy.expedition_attempt.erase("battle_session_snapshot")
	var legacy_validation: Dictionary = city.validate_v5_campaign_snapshot(legacy)
	_check(
		bool(legacy_validation.get("valid", false))
			and Array(Dictionary(legacy_validation.snapshot).expedition_attempt.wartime_facility_plan.facilities).is_empty(),
		"V7 活动出征快照迁移为空战时计划，不会补发工事或资源"
	)
	_check(battle.start_battle(), "确认工事后的正式 C0 仍能启动唯一战斗会话")
	var effects := battle.coordinator.active_session.get_wartime_facility_state()
	_check(
		bool(effects.get("enemy_observation_ready", false))
			and int(effects.get("siege_ram_gate_damage", 0)) == BattleSession.SIEGE_RAM_GATE_DAMAGE,
		"战斗会话只读取确认后的临时计划，并把观察与攻城效果写入真实战斗状态"
	)
	battle.tick_timer.stop()
	battle.issue_squad_order(1, BattleOrder.Command.ADVANCE)
	battle.step_battle_for_test(3)
	attempt = city.get_expedition_attempt()
	var active_session_snapshot: Dictionary = attempt.battle_session_snapshot
	var restored_request := BattleRequest.from_expedition_attempt(attempt)
	var restored_session := BattleSession.new(restored_request)
	_check(
		not active_session_snapshot.is_empty()
			and restored_session.restore_snapshot(active_session_snapshot)
			and restored_session.get_state_digest()
				== battle.coordinator.active_session.get_state_digest(),
		"活动战时实例检查点保存真实战斗刻、命令和路线，可由同一出征恢复"
	)
	var expected_digest := battle.coordinator.active_session.get_state_digest()
	battle.queue_free()
	await process_frame
	var resumed_request := BattleRequest.from_expedition_attempt(
		city.get_expedition_attempt()
	)
	var resumed_battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	resumed_battle.configure_formal_expedition(city_scene, city, resumed_request)
	root.add_child(resumed_battle)
	await process_frame
	await process_frame
	_check(
		resumed_battle.coordinator.active_session != null
			and resumed_battle.coordinator.active_session.get_state_digest()
				== expected_digest
			and not resumed_battle.tick_timer.is_stopped(),
		"正式 C0 重开自动恢复活动实例并继续同一世界战斗刻"
	)
	resumed_battle.tick_timer.stop()
	var cold_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	resumed_battle.abort_formal_entry()
	await process_frame
	var restored_city_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(restored_city_scene)
	await process_frame
	var restored_city: Node = restored_city_scene.get_node("ConstructionController")
	var restore: Dictionary = restored_city.restore_v5_campaign_snapshot(cold_snapshot)
	_check(
		bool(restore.get("success", false))
			and restored_city.enter_first_war_battle(),
		"V5 恢复后的正式城市入口能重新打开同一活动战时实例"
	)
	await process_frame
	var cold_battle := restored_city.get_formal_battle_scene() as C0BattleGraybox
	if cold_battle != null:
		cold_battle.tick_timer.stop()
	_check(
		cold_battle != null
			and cold_battle.coordinator.active_session.get_state_digest() == expected_digest,
		"恢复后的 C0 从保存战斗刻继续，不从 tick 0 或城市起点重算"
	)
	var tampered_active: Dictionary = city.export_v5_campaign_snapshot()
	tampered_active.expedition_attempt.battle_session_snapshot.squads[0].position_fixed = -1
	_check(
		not bool(city.validate_v5_campaign_snapshot(tampered_active).get("valid", false)),
		"非法活动战时实例被严格拒绝，不能污染城市或重置为伪造胜利"
	)
	if cold_battle != null:
		cold_battle.abort_formal_entry()
	if is_instance_valid(resumed_battle):
		resumed_battle.queue_free()
	city_scene.queue_free()
	restored_city_scene.queue_free()
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
		print("WARTIME_INNER_CITY_R0_SMOKE PASS")
		quit(0)
	else:
		print("WARTIME_INNER_CITY_R0_SMOKE FAIL (%d)" % failures.size())
		quit(1)

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
	var arrow_tower_button := plan_panel.get_node("ArrowTowerButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	var repair_button := battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	_check(
		plan_panel.visible and confirm_button.disabled,
		"正式战前界面显示可操作的临时工事计划，而非城市永久建造"
	)
	watch_button.emit_signal("pressed")
	ram_button.emit_signal("pressed")
	arrow_tower_button.emit_signal("pressed")
	barricade_button.emit_signal("pressed")
	await process_frame
	_check(
		watch_button.text.contains("已选")
			and ram_button.text.contains("已选")
			and arrow_tower_button.text.contains("已选")
			and barricade_button.text.contains("已选")
			and not confirm_button.disabled,
		"瞭望台、攻城槌、箭塔和拒马在确认前仅修改战前草稿"
	)
	var before_confirm: Dictionary = city.export_v5_campaign_snapshot()
	confirm_button.emit_signal("pressed")
	await process_frame
	var attempt: Dictionary = city.get_expedition_attempt()
	var plan: Dictionary = attempt.wartime_facility_plan
	_check(
		Array(plan.facilities).size() == 4
			and city.wood == wood_before - 29
			and city.get_building_count() == building_count_before,
		"确认工事只扣一次木材并写入出征尝试，不污染常态内城 placement"
	)
	var duplicate: Dictionary = city.commit_wartime_facility_plan(
		StringName(attempt.attempt_id), plan
	)
	_check(
		not bool(duplicate.get("success", false))
			and city.export_v5_campaign_snapshot() != before_confirm
		and city.wood == wood_before - 29,
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
	legacy.expedition_attempt.erase("source_id")
	legacy.expedition_attempt.erase("mission_id")
	var legacy_validation: Dictionary = city.validate_v5_campaign_snapshot(legacy)
	_check(
		bool(legacy_validation.get("valid", false))
			and Array(Dictionary(legacy_validation.snapshot).expedition_attempt.wartime_facility_plan.facilities).is_empty(),
		"V7 活动出征快照迁移为空战时计划，不会补发工事或资源"
	)
	var legacy_v9: Dictionary = snapshot.duplicate(true)
	legacy_v9.schema_version = 9
	legacy_v9.expedition_attempt.erase("source_id")
	legacy_v9.expedition_attempt.erase("mission_id")
	var legacy_v9_validation: Dictionary = city.validate_v5_campaign_snapshot(legacy_v9)
	_check(
		bool(legacy_v9_validation.get("valid", false))
			and StringName(Dictionary(legacy_v9_validation.snapshot).expedition_attempt.source_id) == &"FIRST_WAR"
			and StringName(Dictionary(legacy_v9_validation.snapshot).expedition_attempt.mission_id) == &"",
		"V9 既有出征迁移为显式 FIRST_WAR 来源，不错误补成守城任务"
	)
	_check(battle.start_battle(), "确认工事后的正式 C0 仍能启动唯一战斗会话")
	var effects := battle.coordinator.active_session.get_wartime_facility_state()
	_check(
		not bool(effects.get("enemy_observation_ready", false))
			and Array(effects.get("facilities", [])).all(func(record: Dictionary) -> bool: return StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_CONSTRUCTING),
		"确认后的临时工事先进入真实施工状态，尚未提前获得观察、破门或火力"
	)
	battle.tick_timer.stop()
	battle.issue_squad_order(1, BattleOrder.Command.ADVANCE)
	battle.step_battle_for_test(4)
	effects = battle.coordinator.active_session.get_wartime_facility_state()
	_check(
		bool(effects.get("enemy_observation_ready", false))
			and StringName(effects.get("siege_ram_route_id", &"")) == CommittedForceSnapshot.FRONT_ROUTE
			and int(effects.get("arrow_tower_damage_per_volley", 0)) == BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY,
		"工事完成后才把观察、攻城和箭塔火力接入真实战斗状态"
	)
	var enemy_hp_before_arrow_tower := int(
		battle.coordinator.active_session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).enemy_total_hp
	)
	battle.step_battle_for_test(4)
	_check(
		int(battle.coordinator.active_session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).enemy_total_hp)
			== enemy_hp_before_arrow_tower - BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY,
		"箭塔按既有战斗间隔向所选路线的真实敌军生命值提交一次伤害"
	)
	var tower_events := battle.coordinator.active_session.get_last_tick_facility_events()
	_check(
		tower_events.size() == 1
			and StringName(tower_events[0].get("kind", &"")) == WartimeFacilityPlan.KIND_ARROW_TOWER
			and int(tower_events[0].get("damage", 0)) == BattleSession.ARROW_TOWER_DAMAGE_PER_VOLLEY,
		"箭塔表现只消费已提交战斗刻的真实齐射事实，不独立计算伤亡"
	)
	var session := battle.coordinator.active_session
	var front_distance := int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).distance_fixed)
	session.squads[0].position_fixed = front_distance
	var hp_before_barricade := int(session.squads[0].total_hp)
	var enemy_members := int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).enemy_initial_members)
	var raw_enemy_damage := session._calculate_enemy_damage(enemy_members, BattleSession.BASIS_POINTS)
	battle.step_battle_for_test(4)
	_check(
		int(session.squads[0].total_hp)
			== hp_before_barricade - (raw_enemy_damage * BattleSession.BARRICADE_INCOMING_DAMAGE_BASIS_POINTS / BattleSession.BASIS_POINTS)
			and StringName(effects.get("barricade_route_id", &"")) == CommittedForceSnapshot.FRONT_ROUTE,
		"拒马完工后通过同一敌军伤害意图减少该路线真实战损"
	)
	var damaged_facilities: Array = Array(session.get_wartime_facility_state().get("facilities", []))
	var barricade_record: Dictionary = {}
	for record_value in damaged_facilities:
		var record: Dictionary = record_value
		if StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE:
			barricade_record = record
			break
	_check(
		StringName(barricade_record.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED
			and int(barricade_record.get("durability", 0)) < int(barricade_record.get("max_durability", 0)),
		"敌军同一刻的未抵消伤害写入拒马耐久与受损状态，而非丢失为表现事件"
	)
	var wood_before_repair := int(city.get("wood"))
	battle._refresh_battle_ui()
	_check(
		repair_button.visible and not repair_button.disabled
			and repair_button.text.contains("拒马"),
		"受损拒马通过正式战时界面显示可用维修入口"
	)
	var repair_snapshot_before_failure := session.get_snapshot()
	city.set_wartime_session_checkpoint_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	repair_button.emit_signal("pressed")
	await process_frame
	_check(
		int(city.get("wood")) == wood_before_repair
			and session.get_snapshot() == repair_snapshot_before_failure
			and repair_button.visible
			and battle.status_label.text.contains("已回滚"),
		"维修检查点保存失败会原子回滚维修资源和战时设施状态，允许原计划重试"
	)
	repair_button.emit_signal("pressed")
	await process_frame
	var repairing_facilities: Array = Array(session.get_wartime_facility_state().get("facilities", []))
	for record_value in repairing_facilities:
		var record: Dictionary = record_value
		if StringName(record.get("facility_id", &"")) == StringName(barricade_record.get("facility_id", &"")):
			barricade_record = record
			break
	var repair_cost := int(WartimeFacilityPlan.get_repair_costs(WartimeFacilityPlan.KIND_BARRICADE).get(&"wood", 0))
	_check(
		StringName(barricade_record.get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING
			and int(city.get("wood")) == wood_before_repair - repair_cost,
		"正式维修按钮一次扣除权威维修费用并将同一拒马置为可保存维修态"
	)
	repair_button.emit_signal("pressed")
	await process_frame
	_check(
		int(city.get("wood")) == wood_before_repair - repair_cost,
		"维修已开始后重复点击不会重复扣除战时维修资源"
	)
	# Keep the hostile contact out of the repair fixture: these two simulation
	# ticks prove repair completion rather than a deliberately concurrent new
	# enemy hit on the exact completion tick.
	session.squads[0].position_fixed = 0
	for _tick in range(BattleSession.FACILITY_REPAIR_TICKS):
		_check(session.step_tick(), "维修中的战时实例继续推进同一正式战斗刻")
	_check(battle._checkpoint_active_battle_session(), "维修完成态通过既有战时检查点保存")
	var repaired_facilities: Array = Array(session.get_wartime_facility_state().get("facilities", []))
	for record_value in repaired_facilities:
		var record: Dictionary = record_value
		if StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE:
			barricade_record = record
			break
	_check(
		StringName(barricade_record.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
			and int(barricade_record.get("durability", 0)) == int(barricade_record.get("max_durability", -1)),
		"维修完成只恢复同一拒马的战时耐久与路线作用"
	)
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
	var duplicate_squad_snapshot := active_session_snapshot.duplicate(true)
	duplicate_squad_snapshot.squads.append(
		Dictionary(duplicate_squad_snapshot.squads[0]).duplicate(true)
	)
	_check(
		not BattleSession.new(restored_request).restore_snapshot(duplicate_squad_snapshot),
		"活动会话恢复拒绝重复小队身份，不能借重复记录覆盖参战编队"
	)
	var malformed_numeric_snapshot := active_session_snapshot.duplicate(true)
	malformed_numeric_snapshot.squads[0].total_hp = "not-a-number"
	_check(
		not BattleSession.new(restored_request).restore_snapshot(malformed_numeric_snapshot),
		"活动会话恢复在转换前拒绝错误数值类型"
	)
	var conflicting_pending_snapshot := active_session_snapshot.duplicate(true)
	conflicting_pending_snapshot.pending_orders = [
		Dictionary(conflicting_pending_snapshot.accepted_orders[0]).duplicate(true)
	]
	conflicting_pending_snapshot.pending_orders[0].command = BattleOrder.Command.RETREAT
	_check(
		not BattleSession.new(restored_request).restore_snapshot(conflicting_pending_snapshot),
		"活动会话恢复拒绝与已接受军令身份相同但内容冲突的待执行记录"
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

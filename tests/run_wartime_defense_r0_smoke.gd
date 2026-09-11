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
	var gate_button := city_scene.get_node("UI/Shell/BuildingDetailPanel/CityGateActions/EnterWartimeDefenseButton") as Button
	gate_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null,
		"黑石城门的已连接正式守城按钮打开独立 C0 战时实例"
	)
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var ram_button := plan_panel.get_node("RamButton") as Button
	var arrow_button := plan_panel.get_node("ArrowTowerButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	var wood_before_plan := int(city.get("wood"))
	var invalid_plan := WartimeFacilityPlan.empty_snapshot()
	invalid_plan.facilities.append(WartimeFacilityPlan.make_facility(
		WartimeFacilityPlan.KIND_SIEGE_RAM,
		CommittedForceSnapshot.FRONT_ROUTE
	))
	var rejected_ram: Dictionary = city.commit_wartime_facility_plan(
		StringName(city.get_expedition_attempt().attempt_id), invalid_plan
	)
	_check(
		not ram_button.visible
			and not bool(rejected_ram.get("success", false))
			and int(city.get("wood")) == wood_before_plan,
		"守城界面隐藏攻城槌，权威提交也拒绝绕过界面的攻城设施且不扣木材"
	)
	watch_button.emit_signal("pressed")
	barricade_button.emit_signal("pressed")
	await process_frame
	_check(
		battle != null and plan_panel.visible and not confirm_button.disabled,
		"守城实例复用正式工事草稿与确认入口，不调用公告板临时战斗"
	)
	confirm_button.emit_signal("pressed")
	await process_frame
	_check(battle.start_battle(), "守城工事确认后由同一正式 C0 时钟启动")
	battle.tick_timer.stop()
	var session := battle.coordinator.active_session
	var objective: Dictionary = session.get_mission_objective_state()
	_check(
		StringName(objective.get("objective_type", &"")) == MissionDefinition.OBJECTIVE_PROTECT
			and str(objective.get("protect_target_name", "")) == "黑石城门"
			and int(objective.get("protect_target_hp", 0)) > 0,
		"守城实例从冻结任务读取真实城门保护目标，而非复用攻城胜利条件"
	)
	var target_hp_before := int(objective.get("protect_target_hp", 0))
	battle.step_battle_for_test(4)
	_check(
		int(session.get_mission_objective_state().get("protect_target_hp", 0)) == target_hp_before
			and int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_position_fixed", 0)) > 0
			and int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_position_fixed", 0))
				< int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).distance_fixed),
		"守城敌军先沿真实路线推进；未抵达城门前不偷扣保护目标生命"
	)
	var legacy_session_snapshot := session.get_snapshot()
	legacy_session_snapshot.schema_version = 3
	for route_id in [CommittedForceSnapshot.FRONT_ROUTE, CommittedForceSnapshot.SIDE_ROUTE]:
		var legacy_route: Dictionary = Dictionary(legacy_session_snapshot.routes[route_id])
		legacy_route.erase("enemy_position_fixed")
		legacy_session_snapshot.routes[route_id] = legacy_route
	var legacy_session := BattleSession.new(battle.request)
	_check(
		legacy_session.restore_snapshot(legacy_session_snapshot)
			and int(legacy_session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_position_fixed", -1)) == 0,
		"V3 活动战时会话升级为从路线起点推进的防守敌军，不伪造旧档的抵近进度"
	)
	battle.step_battle_for_test(124)
	var after_construction: Dictionary = session.get_wartime_facility_state()
	var barricade: Dictionary = {}
	for record_value in Array(after_construction.get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE:
			barricade = record
			break
	_check(
		int(session.get_mission_objective_state().get("protect_target_hp", 0))
			< target_hp_before
			and int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("enemy_position_fixed", 0))
				== int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).distance_fixed)
			and int(session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).get("enemy_position_fixed", 0))
				== int(session.get_route_state(CommittedForceSnapshot.SIDE_ROUTE).distance_fixed)
			and StringName(barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED
			and int(barricade.get("durability", 0)) < int(barricade.get("max_durability", 0)),
		"守城拒马完工后分担城门的真实敌军伤害，并进入可维修的受损状态"
	)
	var repair_button := battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	battle._refresh_battle_ui()
	repair_button.emit_signal("pressed")
	await process_frame
	var repair_started := false
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("facility_id", &"")) == StringName(barricade.get("facility_id", &"")):
			repair_started = StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING
			break
	_check(repair_started, "守城受损拒马可通过正式维修按钮进入可保存的维修阶段")
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
		"守城施工后的 ACTIVE 状态冷恢复后仍只打开同一冻结防守实例"
	)
	await process_frame
	var restored_battle := restored_city.get_formal_battle_scene() as C0BattleGraybox
	var reactivated := restored_battle != null and restored_battle.start_battle()
	if restored_battle != null:
		restored_battle.tick_timer.stop()
		restored_battle.step_battle_for_test(BattleSession.FACILITY_REPAIR_TICKS)
	var repaired_after_restore := false
	for record_value in Array(restored_battle.coordinator.active_session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("facility_id", &"")) == StringName(barricade.get("facility_id", &"")):
			repaired_after_restore = (
				StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
				and int(record.get("durability", 0)) == int(record.get("max_durability", -1))
			)
			break
	var retreat_applied := (
		reactivated
		and repaired_after_restore
		and restored_battle.open_exit_confirmation()
		and restored_battle.confirm_exit_as_retreat()
		and StringName(restored_city.get_expedition_attempt().phase) == BattleRequest.PHASE_APPLIED
		and int(restored_city.get("food")) == food_before
	)
	var retreat_result_id := StringName(restored_city.get_expedition_attempt().result_id)
	var retreat_summary: Dictionary = restored_city.get_committed_battle_result_summary(retreat_result_id)
	var retreat_return_requested := (
		retreat_applied and restored_battle.request_return_to_city() != null
	)
	await process_frame
	await process_frame
	_check(
		retreat_return_requested
			and StringName(retreat_summary.get("source_id", &""))
				== BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(retreat_summary.get("mission_id", &""))
				== &"wartime_defense.blackstone_gate.v0"
			and restored_city.get_formal_battle_scene() == null
			and int(restored_city.get("first_war_state"))
				== 0,
		"守城维修跨进程恢复后通过来源专属撤离回写返回城市，保留守城身份且不伪装为主线出征"
	)

	# Do not forge a loss state: let the formal protection objective resolve
	# through the same enemy-route and gate-damage clock used in the scene.
	var defeat_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(defeat_scene)
	await process_frame
	var defeat_city: Node = defeat_scene.get_node("ConstructionController")
	var defeat_roster: Array[Dictionary] = defeat_city.get_formation_roster()
	var defeat_formation_id := StringName(defeat_roster[0].formation_id)
	var defeat_food_before := int(defeat_city.get("food"))
	var defeat_started: Dictionary = defeat_city.begin_wartime_defense_attempt([defeat_formation_id])
	var defeat_entered: bool = (
		bool(defeat_started.get("success", false))
		and defeat_city.enter_wartime_defense_battle()
	)
	await process_frame
	var defeat_battle := defeat_city.get_formal_battle_scene() as C0BattleGraybox
	var defeat_result: BattleResult
	if defeat_battle != null and defeat_battle.start_battle():
		defeat_battle.tick_timer.stop()
		defeat_result = defeat_battle.step_battle_for_test(260)
	var defeat_summary: Dictionary = (
		defeat_battle.confirm_pending_result()
		if defeat_battle != null and defeat_result != null
		else {}
	)
	var defeat_snapshot: Dictionary = defeat_city.export_v5_campaign_snapshot()
	_check(
		defeat_entered
			and defeat_result != null
			and defeat_result.outcome == BattleOutcome.Value.DEFEAT
			and not defeat_summary.is_empty()
			and StringName(defeat_summary.get("source_id", &""))
				== BattleRequest.SOURCE_WARTIME_DEFENSE
			and StringName(defeat_summary.get("mission_id", &""))
				== &"wartime_defense.blackstone_gate.v0"
			and bool(defeat_city.get("city_fallen"))
			and defeat_city.get_city_defense() == 0
			and int(defeat_city.get("food")) == defeat_food_before,
		"敌军自然抵达并击破城门后，守城失败只写回同一守城结果与真实城防，不产生第二次出征粮食事务"
	)
	if defeat_battle != null:
		defeat_battle.abort_formal_entry()
	await process_frame
	var defeat_restored_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(defeat_restored_scene)
	await process_frame
	var defeat_restored_city: Node = defeat_restored_scene.get_node("ConstructionController")
	var defeat_restored: Dictionary = defeat_restored_city.restore_v5_campaign_snapshot(defeat_snapshot)
	_check(
		bool(defeat_restored.get("success", false))
			and bool(defeat_restored_city.get("city_fallen"))
			and defeat_restored_city.get_city_defense() == 0
			and StringName(
				Dictionary(defeat_restored_city.get_committed_battle_result_summary(
					StringName(defeat_city.get_expedition_attempt().result_id)
				)).get("mission_id", &"")
			) == &"wartime_defense.blackstone_gate.v0",
		"已结算的守城失守在 V5 冷恢复后保留原结果与城门状态，不会被主线运行时投影忽略"
	)
	city_scene.queue_free()
	restored_scene.queue_free()
	defeat_scene.queue_free()
	defeat_restored_scene.queue_free()
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

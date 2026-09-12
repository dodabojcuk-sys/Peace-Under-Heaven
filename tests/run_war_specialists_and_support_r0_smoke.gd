extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/c0_battle_graybox.tscn")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_field_specialist_actions()
	await _check_official_battle_support()
	await _check_strategist_battle_support()
	await _check_domain_battle_support()
	if failures.is_empty():
		print("WAR_SPECIALISTS_AND_SUPPORT_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("WAR_SPECIALISTS_AND_SUPPORT_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	return {"scene": scene, "city": city, "field": city._war_loop_state.field_tactics}


func _dispatch(city: Node, role: StringName) -> StringName:
	var result: Dictionary = city.dispatch_field_specialist(role)
	return StringName(Dictionary(result.get("specialist", {})).get("specialist_id", &""))


func _advance_until_action_settles(city: Node, specialist_id: StringName) -> Dictionary:
	for _step in range(60):
		city.advance_war_loop_time(2000)
		var specialist := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(specialist_id, {}))
		if StringName(specialist.get("action_stage", &"")) in [FieldTacticsState.ACTION_COMPLETED, FieldTacticsState.ACTION_INTERRUPTED]:
			return specialist
	return Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(specialist_id, {}))


func _check_field_specialist_actions() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var field: FieldTacticsState = fixture.field
	field.patrols_by_id.clear()

	var saboteur_id := _dispatch(city, FieldTacticsState.SPECIALIST_SABOTEUR)
	field = city._war_loop_state.field_tactics
	var facility_id := &"facility.redcliff.lookout.001"
	var facility := Dictionary(field.watchtowers_by_id.get(facility_id, {}))
	var discovered: Array = Array(facility.get("discovered_by_faction_ids", []))
	discovered.append(&"player")
	facility.discovered_by_faction_ids = discovered
	field.watchtowers_by_id[facility_id] = facility
	var sabotage_before := int(facility.get("durability", 0))
	var sabotage: Dictionary = city.begin_field_specialist_action(saboteur_id, FieldTacticsState.ACTION_SABOTAGE, facility_id)
	var sabotaged: Dictionary = await _advance_until_action_settles(city, saboteur_id)
	_check(
		bool(sabotage.get("success", false))
			and StringName(sabotaged.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED
			and int(Dictionary(city._war_loop_state.field_tactics.watchtowers_by_id[facility_id]).durability) == sabotage_before - 60,
		"破坏员经正式事务前往已发现敌方设施并修改同一耐久事实"
	)

	var thief_id := _dispatch(city, FieldTacticsState.SPECIALIST_THIEF)
	var field_before_theft: FieldTacticsState = city._war_loop_state.field_tactics
	var stock_before := int(field_before_theft.supply_inventory_by_point_id.get(&"silverford_city", 0))
	var food_before_theft := int(city.food)
	var unscouted: Dictionary = city.preview_field_specialist_action(thief_id, FieldTacticsState.ACTION_THEFT, &"silverford_city")
	_check(not bool(unscouted.get("valid", false)) and int(field_before_theft.supply_inventory_by_point_id.get(&"silverford_city", 0)) == stock_before, "盗取未侦察城市时拒绝且不泄露或扣减真实库存")
	var scout_id := _dispatch(city, FieldTacticsState.SPECIALIST_SCOUT)
	var scout_move: Dictionary = city.order_field_specialist_move(scout_id, &"silverford_city")
	for _step in range(60):
		city.advance_war_loop_time(2000)
		if StringName(Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(scout_id, {})).get("current_point_id", &"")) == &"silverford_city":
			break
	var silverford_intel := Dictionary(city._war_loop_state.field_tactics.intel_by_subject_id.get(&"silverford_city", {}))
	_check(bool(scout_move.get("success", false)) and StringName(silverford_intel.get("subject_kind", &"")) == &"POINT", "侦察兵通过正式移动建立敌城持久侦察事实")
	city._war_loop_state.begin_siege(&"army.theft.handoff", &"order.theft.handoff", &"silverford_city", 1, 100, 0, 1, 10000, city.WAR_LOOP_RULES)
	city._war_loop_state.begin_wartime_handoff(&"silverford_city", &"battle.theft.handoff", {"source_id": &"MACRO_SIEGE"})
	var handed_off_theft: Dictionary = city.preview_field_specialist_action(thief_id, FieldTacticsState.ACTION_THEFT, &"silverford_city")
	_check(not bool(handed_off_theft.get("valid", false)) and int(field_before_theft.supply_inventory_by_point_id.get(&"silverford_city", 0)) == stock_before, "敌城交接战时实例后，战区盗取预检拒绝同源并发且不扣库存")
	city._war_loop_state.active_siege = {}
	city.food = city.get_resource_capacity(&"food")
	var no_capacity: Dictionary = city.preview_field_specialist_action(thief_id, FieldTacticsState.ACTION_THEFT, &"silverford_city")
	var rejected_thief := Dictionary(city._war_loop_state.field_tactics.specialists_by_id[thief_id])
	_check(
		not bool(no_capacity.get("valid", false))
			and StringName(rejected_thief.get("action_stage", &"")) == FieldTacticsState.ACTION_NONE
			and int(field_before_theft.supply_inventory_by_point_id.get(&"silverford_city", 0)) == stock_before,
		"盗取在黑石粮仓无容量时由权威预检拒绝且不扣敌方库存"
	)
	city.food = food_before_theft
	var theft: Dictionary = city.begin_field_specialist_action(thief_id, FieldTacticsState.ACTION_THEFT, &"silverford_city")
	var food_after_cost := int(city.food)
	var returning := false
	for _step in range(60):
		city.advance_war_loop_time(2000)
		var active_thief := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(thief_id, {}))
		if StringName(active_thief.get("action_stage", &"")) == FieldTacticsState.ACTION_RETURNING:
			returning = true
			city.food = city.get_resource_capacity(&"food")
			break
	for _step in range(60):
		city.advance_war_loop_time(2000)
		if StringName(Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(thief_id, {})).get("action_stage", &"")) == FieldTacticsState.ACTION_READY_DEPOSIT:
			break
	var waiting_thief := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(thief_id, {}))
	_check(returning and StringName(waiting_thief.get("action_stage", &"")) == FieldTacticsState.ACTION_READY_DEPOSIT and int(waiting_thief.get("action_cargo_food", 0)) == 5, "盗取货物返城时仓满则保留同一货物等待，不丢失或提前完成")
	city.food = food_after_cost
	city.advance_war_loop_time(1)
	var stolen := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(thief_id, {}))
	_check(
		bool(theft.get("success", false))
			and StringName(stolen.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED
			and int(city._war_loop_state.field_tactics.supply_inventory_by_point_id.get(&"silverford_city", 0)) == stock_before - 5
			and int(city.food) == food_after_cost + 5,
		"盗取从敌城真实库存扣除、携带返回后才向国家资源单次入账"
	)

	var sniper_id := _dispatch(city, FieldTacticsState.SPECIALIST_SNIPER)
	field = city._war_loop_state.field_tactics
	field.patrols_by_id[&"patrol.sniper.test"] = {
		"patrol_id": &"patrol.sniper.test", "display_name": "试射巡逻",
		"current_point_id": &"northwatch_garrison", "world_position": Vector2i(680, 210),
		"strength": 3, "phase": &"PATROL", "route_point_ids": [&"northwatch_garrison", &"forest_garrison"],
		"target_route_index": 1, "wait_remaining_milliseconds": 999999, "last_engagement": {},
	}
	field.camps_by_id[&"camp.sniper.observer"] = {
		"camp_id": &"camp.sniper.observer", "point_id": &"northwatch_garrison",
		"road_id": &"road.blackstone.northwatch.ridge", "display_name": "观察驻点",
		"world_position": Vector2i(680, 210), "durability": 80, "connected": true,
	}
	field.intel_by_subject_id[&"patrol.sniper.test"] = {
		"subject_id": &"patrol.sniper.test", "fog_state": FieldTacticsState.FOG_VISIBLE,
		"last_known_point_id": &"northwatch_garrison", "last_known_world_position": Vector2i(680, 210),
		"last_observed_milliseconds": field.world_milliseconds, "known_strength": 3,
	}
	var sniper: Dictionary = city.begin_field_specialist_action(sniper_id, FieldTacticsState.ACTION_SNIPER, &"patrol.sniper.test")
	var sniped: Dictionary = await _advance_until_action_settles(city, sniper_id)
	_check(
		bool(sniper.get("success", false))
			and StringName(sniped.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED
			and int(Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.sniper.test"]).strength) == 2,
		"狙击只作用于当前可见且未交接的真实巡逻兵力"
	)

	field = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	var redcliff := Dictionary(city._war_loop_state.cities_by_id[&"redcliff_city"])
	redcliff.defender_attack_per_member = 0
	redcliff.gate_hp = 999999
	city._war_loop_state.cities_by_id[&"redcliff_city"] = redcliff
	var siege: Dictionary = city._war_loop_state.begin_siege(&"army.medical.test", &"order.medical.test", &"redcliff_city", 3, 100, 0, 1, 10000, city.WAR_LOOP_RULES)
	city._war_loop_state.active_siege.attacker_total_hp = 250
	var medic_id := _dispatch(city, FieldTacticsState.SPECIALIST_MEDIC)
	var medic := Dictionary(city._war_loop_state.field_tactics.specialists_by_id[medic_id])
	medic.world_position = Vector2i(1250, 235)
	medic.current_point_id = &""
	city._war_loop_state.field_tactics.specialists_by_id[medic_id] = medic
	var medical: Dictionary = city.begin_field_specialist_action(medic_id, FieldTacticsState.ACTION_MEDICAL, &"army.medical.test")
	var field_step: Dictionary = city._war_loop_state.field_tactics.advance_world(5000)
	city._resolve_ready_field_specialist_actions(Array(field_step.get("ready_specialist_action_ids", [])))
	var healed := Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(medic_id, {}))
	_check(
		not siege.is_empty() and bool(medical.get("success", false))
			and StringName(healed.get("action_stage", &"")) == FieldTacticsState.ACTION_COMPLETED
			and int(city._war_loop_state.active_siege.attacker_total_hp) == 300,
		"医疗官只修复存活成员受损生命，不越过人数边界复活阵亡者"
	)

	city._war_loop_state.active_siege = {}
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_fixture: Dictionary = await _new_city()
	var restored: Node = restored_fixture.city
	_check(bool(restored.restore_v5_campaign_snapshot(snapshot).get("success", false)) and restored.export_v5_campaign_snapshot().war_loop == snapshot.war_loop, "专员任务结果和稳定身份通过正式 V5 恢复且不重复结算")
	restored_fixture.scene.queue_free()
	scene.queue_free()
	await process_frame


func _check_official_battle_support() -> void:
	var fixture := await _new_city()
	var city_scene: Node = fixture.scene
	var city: Node = fixture.city
	city.appoint_city_official(&"official.physician")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var departure: Dictionary = city.commit_expedition_attempt([StringName(roster[0].formation_id)])
	var request := BattleRequest.from_expedition_attempt(city.get_expedition_attempt())
	var battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	battle.configure_formal_expedition(city_scene, city, request)
	root.add_child(battle)
	await process_frame
	await process_frame
	var started := battle.start_battle()
	battle.tick_timer.stop()
	var session: BattleSession = battle.coordinator.active_session
	var squad_before := session.get_squad_state(1)
	session.squads[0].total_hp = int(squad_before.total_hp) - 25
	var energy_before := int(city.get_city_strategy_read_model().campaign_energy)
	var strategy_before: Dictionary = city.get_city_strategy_read_model()
	var session_before: Dictionary = session.get_snapshot()
	city.set_wartime_session_checkpoint_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var rejected := battle.coordinator.issue_official_support(BattleSession.SUPPORT_HEAL, 1)
	_check(
		not bool(rejected.get("success", false))
			and city.get_city_strategy_read_model() == strategy_before
			and session.get_snapshot() == session_before,
		"战中支援关键保存失败时共享能量和 BattleSession 效果共同回滚"
	)
	var support := battle.coordinator.issue_official_support(BattleSession.SUPPORT_HEAL, 1)
	var support_snapshot := session.get_snapshot()
	var restored_session := BattleSession.new(request)
	_check(
		started and bool(support.get("success", false))
			and int(session.get_squad_state(1).total_hp) == int(squad_before.total_hp)
			and int(city.get_city_strategy_read_model().campaign_energy) == energy_before - 1,
		"战中医疗命令通过正式协调器原子消耗共享能量并治疗合法存活目标"
	)
	_check(restored_session.restore_snapshot(support_snapshot) and restored_session.get_official_support_state() == session.get_official_support_state(), "战中命令回执和持续效果进入 BattleSession 快照恢复")
	battle.queue_free()
	city_scene.queue_free()
	await process_frame


func _check_strategist_battle_support() -> void:
	var fixture := await _new_city()
	var city_scene: Node = fixture.scene
	var city: Node = fixture.city
	city.appoint_city_official(&"official.strategist")
	var roster: Array[Dictionary] = city.get_formation_roster()
	city.commit_expedition_attempt([StringName(roster[0].formation_id)])
	var request := BattleRequest.from_expedition_attempt(city.get_expedition_attempt())
	var battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	battle.configure_formal_expedition(city_scene, city, request)
	root.add_child(battle)
	await process_frame
	await process_frame
	var started := battle.start_battle()
	battle.tick_timer.stop()
	var session: BattleSession = battle.coordinator.active_session
	var move := battle.coordinator.issue_official_support(BattleSession.SUPPORT_MOVE, 1)
	var energy_after_move := int(city.get_city_strategy_read_model().campaign_energy)
	var duplicate_move := battle.coordinator.issue_official_support(BattleSession.SUPPORT_MOVE, 1)
	_check(not bool(duplicate_move.get("success", false)) and int(city.get_city_strategy_read_model().campaign_energy) == energy_after_move, "同目标同类战中效果不叠加，也不浪费第二点能量")
	var attack := battle.coordinator.issue_official_support(BattleSession.SUPPORT_ATTACK, 1)
	var protect := battle.coordinator.issue_official_support(BattleSession.SUPPORT_PROTECT, 1)
	var snapshot := session.get_snapshot()
	var restored := BattleSession.new(request)
	var restored_ok := restored.restore_snapshot(snapshot)
	_check(
		started and bool(move.get("success", false)) and bool(attack.get("success", false))
			and bool(protect.get("success", false))
			and int(city.get_city_strategy_read_model().campaign_energy) == 0,
		"军谋官移动、攻击与防护命令均经正式入口消耗同一份关卡能量"
	)
	_check(
		restored_ok
			and restored._support_basis_points(BattleSession.SUPPORT_MOVE, 1, CommittedForceSnapshot.FRONT_ROUTE) == 12500
			and restored._support_basis_points(BattleSession.SUPPORT_ATTACK, 1, CommittedForceSnapshot.FRONT_ROUTE) == 12500
			and restored._support_basis_points(BattleSession.SUPPORT_PROTECT, 1, CommittedForceSnapshot.FRONT_ROUTE) == 7000,
		"移动、攻击与防护效果从正式战斗快照恢复并进入权威倍率计算"
	)
	for _tick in range(7):
		restored.step_tick()
	_check(
		restored._support_basis_points(BattleSession.SUPPORT_MOVE, 1, CommittedForceSnapshot.FRONT_ROUTE) == 12500
			and restored._support_basis_points(BattleSession.SUPPORT_ATTACK, 1, CommittedForceSnapshot.FRONT_ROUTE) == 12500
			and restored._support_basis_points(BattleSession.SUPPORT_PROTECT, 1, CommittedForceSnapshot.FRONT_ROUTE) == 7000,
		"战中文官临时效果完整覆盖配置的前七个战斗刻"
	)
	restored.step_tick()
	_check(
		restored._support_basis_points(BattleSession.SUPPORT_MOVE, 1, CommittedForceSnapshot.FRONT_ROUTE) == 10000
			and restored._support_basis_points(BattleSession.SUPPORT_ATTACK, 1, CommittedForceSnapshot.FRONT_ROUTE) == 10000
			and restored._support_basis_points(BattleSession.SUPPORT_PROTECT, 1, CommittedForceSnapshot.FRONT_ROUTE) == 10000,
		"战中文官临时效果按保存的战斗刻到期，不残留或误改永久属性"
	)
	battle.queue_free()
	city_scene.queue_free()
	await process_frame


func _check_domain_battle_support() -> void:
	var fixture := await _new_city()
	var city_scene: Node = fixture.scene
	var city: Node = fixture.city
	city.appoint_city_official(&"official.strategist")
	var roster: Array[Dictionary] = city.get_formation_roster()
	city.commit_expedition_attempt([StringName(roster[0].formation_id)])
	var request := BattleRequest.from_expedition_attempt(city.get_expedition_attempt())
	var battle := BATTLE_SCENE.instantiate() as C0BattleGraybox
	battle.configure_formal_expedition(city_scene, city, request)
	root.add_child(battle)
	await process_frame
	await process_frame
	var started := battle.start_battle()
	battle.tick_timer.stop()
	var session: BattleSession = battle.coordinator.active_session
	var energy_before := int(city.get_city_strategy_read_model().campaign_energy)
	var domain := battle.coordinator.issue_official_support(BattleSession.SUPPORT_DOMAIN, 1, CommittedForceSnapshot.FRONT_ROUTE)
	var restored := BattleSession.new(request)
	var restored_ok := restored.restore_snapshot(session.get_snapshot())
	_check(
		started and bool(domain.get("success", false))
			and int(city.get_city_strategy_read_model().campaign_energy) == energy_before - 1
			and restored_ok
			and restored._support_basis_points(BattleSession.SUPPORT_ATTACK, 1, CommittedForceSnapshot.FRONT_ROUTE) == 11000
			and restored._support_basis_points(BattleSession.SUPPORT_PROTECT, 1, CommittedForceSnapshot.FRONT_ROUTE) == 9000,
		"领域支援通过正式命令消耗共享能量，并按实际路线范围从快照恢复"
	)
	battle.queue_free()
	city_scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)

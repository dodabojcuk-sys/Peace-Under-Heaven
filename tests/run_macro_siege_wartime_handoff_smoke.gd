extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var first_leg: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var north_order: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	var north_army: Dictionary = Dictionary(north_order.get("army", {}))
	var north_macro: Dictionary = Dictionary(north_army.get("macro_march", {}))
	city.advance_macro_march_time(
		StringName(north_army.get("army_id", &"")), StringName(north_macro.get("order_id", &"")),
		0, int(north_macro.get("total_millis", 0))
	)
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var siege_order: Dictionary = city.commit_macro_march_from_station(
		StringName(north_army.get("army_id", &"")), &"redcliff_city",
		StringName(attack_route.route_id), Array(attack_route.points)
	)
	var siege_army: Dictionary = Dictionary(siege_order.get("army", {}))
	var siege_macro: Dictionary = Dictionary(siege_army.get("macro_march", {}))
	city.advance_macro_march_time(
		StringName(siege_army.get("army_id", &"")), StringName(siege_macro.get("order_id", &"")),
		0, int(siege_macro.get("total_millis", 0))
	)
	var army_id := StringName(siege_army.get("army_id", &""))
	# Let the ordinary macro simulation inflict real, partial pre-handoff damage.
	# The C0 request must inherit these values rather than rebuild full squads.
	city.advance_war_loop_time(250)
	var before: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	var food_before_entry := int(city.get("food"))
	_check(StringName(city.get_army_state(army_id).get("phase", &"")) == ArmyRegistry.PHASE_SIEGING, "正式行军抵达后保留原军队并建立围城")
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "宏观围城可从正式控制器进入独立战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null or battle.request == null:
		print("MACRO_WARTIME_DEBUG army=%s siege=%s handoff=%s" % [city.get_army_state(army_id), city.get_macro_march_read_model().war_loop.active_siege, city.get_macro_march_read_model().war_loop.active_siege.get("wartime_handoff", {})])
	var after_entry: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	var handoff: Dictionary = Dictionary(after_entry.get("wartime_handoff", {}))
	_check(
		battle != null
		and battle.request != null
		and battle.request.source_id == BattleRequest.SOURCE_MACRO_SIEGE
		and battle.request.committed_force.get_committed_total() == _formation_total(city.get_army_state(army_id))
		and int(city.get("food")) == food_before_entry
		and battle.request.committed_food_cost == 0,
		"战时请求读取原编队与既有粮食事务，不重新派兵或扣粮"
	)
	_check(
		StringName(handoff.get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_RESERVED
		and StringName(handoff.get("transaction_id", &"")) == battle.request.transaction_id,
		"围城持久关联先于战时界面开放并保留原军令身份"
	)
	var frozen_request: Dictionary = Dictionary(handoff.get("battle_request_snapshot", {}))
	_check(
		not frozen_request.is_empty()
		and int(before.get("attacker_total_hp", 0)) < int(before.get("attacker_initial_count", 0)) * int(before.get("attacker_hp_per_member", 1))
		and Dictionary(frozen_request.get("macro_siege_start_state", {})).get("attacker_total_hp", -1) == before.get("attacker_total_hp", -2)
		and Dictionary(frozen_request.get("macro_siege_start_state", {})).get("defender_total_hp", -1) == before.get("defender_total_hp", -2),
		"首次接管冻结宏观已发生的双方 HP，而非以人数重建满血队伍"
	)
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var plan_confirm_button := plan_panel.get_node("ConfirmButton") as Button
	var repair_button := battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	var wood_before_plan := int(city.get("wood"))
	_check(
		plan_panel.visible
			and watch_button.visible
			and not watch_button.disabled
			and plan_confirm_button.visible
			and plan_confirm_button.disabled,
		"宏观围城正式界面也提供战时工事草稿入口，尚未扣除建设资源"
	)
	watch_button.emit_signal("pressed")
	barricade_button.emit_signal("pressed")
	await process_frame
	plan_confirm_button.emit_signal("pressed")
	await process_frame
	handoff = Dictionary(city.get_macro_march_read_model().war_loop.active_siege.get("wartime_handoff", {}))
	frozen_request = Dictionary(handoff.get("battle_request_snapshot", {}))
	_check(
		Array(battle.request.wartime_facility_plan.get("facilities", [])).size() == 2
			and Array(Dictionary(frozen_request.get("wartime_facility_plan", {})).get("facilities", [])).size() == 2
			and int(city.get("wood")) == wood_before_plan - 11
			and plan_confirm_button.visible == false,
		"宏观围城确认工事只扣一次建设木材，并写入冻结接管请求"
	)
	var duplicate_plan: Dictionary = city.commit_macro_siege_wartime_facility_plan(
		army_id, &"redcliff_city", battle.request.transaction_id, battle.request.wartime_facility_plan
	)
	_check(
		not bool(duplicate_plan.get("success", false))
			and int(city.get("wood")) == wood_before_plan - 11,
		"宏观围城工事重复提交被权威入口拒绝，不重复扣费"
	)
	var frozen_day := battle.request.created_day
	var frozen_force_digest := battle.request.committed_force.get_digest()
	var frozen_enemy_digest := battle.request.enemy_force.get_digest()
	var live_day_before_mutation: int = int(city.current_day)
	city.current_day += 3
	city.selected_general_id = &"general.vanguard"
	city.researched_tech_ids.clear()
	city.researched_tech_ids.append(&"tech.formation_drill")
	city.supply_shortage = not city.supply_shortage
	battle.queue_free()
	await process_frame
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "跨日或改变城市选择后仍可打开同一冻结围城请求")
	await process_frame
	await process_frame
	battle = city.get_formal_battle_scene() as C0BattleGraybox
	repair_button = battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	_check(
		battle != null
		and battle.request != null
		and battle.request.created_day == frozen_day
		and battle.request.committed_force.get_digest() == frozen_force_digest
		and battle.request.enemy_force.get_digest() == frozen_enemy_digest,
		"恢复不重新读取当前日期、将领、科技或补给来构造参战参数"
	)
	# The following V5 checkpoint verifies the handoff itself, not unrelated
	# city-day mutation APIs. Restore those live choices after proving rebuild.
	city.current_day = live_day_before_mutation
	city.selected_general_id = &""
	city.researched_tech_ids.clear()
	city.supply_shortage = false
	city.advance_war_loop_time(1000)
	var skipped: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	_check(
		int(skipped.get("tick", -1)) == int(before.get("tick", -1))
		and int(skipped.get("gate_hp", -1)) == int(before.get("gate_hp", -1)),
		"世界时间跳过被战时实例接管的同一围城，不重复推进伤亡或城门"
	)
	var started := battle.start_battle()
	if not started:
		print("MACRO_WARTIME_DEBUG_START request=%s handoff=%s coordinator=%s" % [battle.request, city.get_macro_march_read_model().war_loop.active_siege.get("wartime_handoff", {}), battle.coordinator])
	_check(started, "接管后的正式战时实例可激活唯一战斗会话")
	await process_frame
	# Drive the formal scene timer signal so each construction tick uses the
	# same checkpoint path as a running battle rather than an unpersisted unit
	# test advance on the coordinator.
	for _tick in range(BattleSession.FACILITY_BUILD_TICKS[WartimeFacilityPlan.KIND_BARRICADE]):
		(battle.get_node("TickTimer") as Timer).emit_signal("timeout")
	var macro_facility_state := battle.coordinator.active_session.get_wartime_facility_state()
	var macro_facilities: Array = Array(macro_facility_state.get("facilities", []))
	_check(
		macro_facilities.size() == 2
			and macro_facilities.all(func(record: Dictionary) -> bool: return StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE),
		"宏观围城确认的瞭望台和拒马随正式战斗刻施工完成后才生效"
	)
	var session := battle.coordinator.active_session
	var front_distance := int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).distance_fixed)
	session.squads[0].position_fixed = front_distance
	(battle.get_node("TickTimer") as Timer).emit_signal("timeout")
	var damaged_barricade: Dictionary = {}
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("kind", &"")) == WartimeFacilityPlan.KIND_BARRICADE:
			damaged_barricade = record
			break
	battle._refresh_battle_ui()
	var wood_before_repair := int(city.get("wood"))
	_check(
		StringName(damaged_barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED
			and repair_button.visible and not repair_button.disabled,
		"宏观围城中真实受损拒马显示正式维修入口"
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
		"宏观围城维修保存失败同样回滚资源和冻结接管会话，不留下半成品维修态"
	)
	repair_button.emit_signal("pressed")
	await process_frame
	var repair_cost := int(WartimeFacilityPlan.get_repair_costs(WartimeFacilityPlan.KIND_BARRICADE).get(&"wood", 0))
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("facility_id", &"")) == StringName(damaged_barricade.get("facility_id", &"")):
			damaged_barricade = record
			break
	_check(
		StringName(damaged_barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING
			and int(city.get("wood")) == wood_before_repair - repair_cost,
		"宏观围城维修使用同一接管事务扣一次资源并保存工事阶段"
	)
	session.squads[0].position_fixed = 0
	for _tick in range(BattleSession.FACILITY_REPAIR_TICKS):
		(battle.get_node("TickTimer") as Timer).emit_signal("timeout")
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("facility_id", &"")) == StringName(damaged_barricade.get("facility_id", &"")):
			damaged_barricade = record
			break
	_check(
		StringName(damaged_barricade.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
			and int(damaged_barricade.get("durability", 0)) == int(damaged_barricade.get("max_durability", -1)),
		"宏观围城维修在正式战斗刻完成后恢复同一拒马的实际防护"
	)
	var active: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	_check(
		StringName(Dictionary(active.get("wartime_handoff", {})).get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_ACTIVE
		and not Dictionary(active.get("wartime_handoff", {})).get("battle_session_snapshot", {}).is_empty(),
		"战时首刻保存到围城关联，可由同一来源恢复"
	)
	var active_campaign_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(not active_campaign_snapshot.is_empty(), "活动围城接管可通过正式 V5 快照校验后发布")
	var active_digest := battle.coordinator.active_session.get_state_digest()
	battle.queue_free()
	await process_frame
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "重复进入恢复同一围城接管，不创建第二个实例")
	await process_frame
	await process_frame
	battle = city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null
		and battle.coordinator.active_session != null
		and battle.coordinator.active_session.get_state_digest() == active_digest,
		"重开战时界面从持久围城关联恢复同一活动实例"
	)
	var pending_result: BattleResult
	var forced_retreat := battle.coordinator.active_session.request_forced_retreat()
	battle.coordinator.advance_battle_tick()
	for squad in battle.coordinator.active_session.squads:
		if int(squad.get("total_hp", 0)) > 0 and not bool(squad.get("exited", false)):
			battle.coordinator.issue_order(int(squad.get("squad_id", 0)), BattleOrder.Command.RETREAT)
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		pending_result = battle.coordinator.advance_battle_tick()
		if pending_result != null:
			break
	_check(
		forced_retreat and pending_result != null,
		"终局结果先持久化为待回写事实，而不立即改写宏观围城"
	)
	var pending: Dictionary = city.get_macro_march_read_model().war_loop.active_siege
	var terminal_state := battle.coordinator.active_session.get_macro_siege_terminal_state()
	_check(
		StringName(Dictionary(pending.get("wartime_handoff", {})).get("phase", &""))
			== WarLoopState.WARTIME_HANDOFF_RESULT_PENDING
		and not Dictionary(pending.get("wartime_handoff", {})).get("result_authority_snapshot", {}).is_empty(),
		"待回写结果与围城接管关联一同保存，重开无需重打"
	)
	_check(
		Dictionary(Dictionary(pending.get("wartime_handoff", {})).get("terminal_combat_state", {})) == terminal_state,
		"终局回写保存实际残余 HP 与城门耐久，而非由伤亡人数反推"
	)
	# Use the production V5 export rather than the UI read projection: the
	# latter deliberately omits validation-only WarLoop fields such as parallel
	# siege state and is not itself a restorable snapshot.
	var legacy_campaign_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var legacy_pending_snapshot: Dictionary = Dictionary(
		legacy_campaign_snapshot.get("war_loop", {})
	).duplicate(true)
	legacy_pending_snapshot.schema_version = 5
	legacy_pending_snapshot.active_siege.wartime_handoff.erase("terminal_combat_state")
	legacy_pending_snapshot.active_siege.wartime_handoff.erase("battle_request_snapshot")
	var legacy_probe := WarLoopState.new()
	var legacy_restored := legacy_probe.restore_snapshot(legacy_pending_snapshot)
	_check(
		legacy_restored
		and StringName(legacy_probe.get_wartime_handoff(&"redcliff_city").get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_RESULT_PENDING
		and not Dictionary(legacy_probe.get_wartime_handoff(&"redcliff_city").get("terminal_combat_state", {})).is_empty(),
		"旧 schema 5 待回写战果一次迁移为可领取状态，不重演战斗"
	)
	battle.queue_free()
	await process_frame
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "待回写结果可从同一围城再次打开")
	await process_frame
	await process_frame
	battle = city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null
		and battle.request != null
		and battle.request.phase == BattleRequest.PHASE_RESULT_PENDING
		and battle.coordinator.active_session != null
		and battle.coordinator.active_session.completed
		and battle.result_panel.visible,
		"重开战时界面恢复待确认战果，不重复推进或重复播放战斗"
	)
	var retreated: Dictionary = battle.confirm_pending_result()
	if retreated.is_empty():
		print("MACRO_WARTIME_DEBUG_RETREAT phase=%s handoff=%s error=%s status=%s" % [battle.request.phase, city.get_macro_march_read_model().war_loop.active_siege.get("wartime_handoff", {}), battle.coordinator.last_result_error_id, battle.status_label.text])
	_check(not retreated.is_empty(), "战时实例可将撤退结果提交回原宏观围城")
	await process_frame
	var retreating: Dictionary = city.get_army_state(army_id)
	_check(
		StringName(retreating.get("phase", &"")) == ArmyRegistry.PHASE_RETREATING
		and city.get_macro_march_read_model().war_loop.active_siege.is_empty(),
		"撤退回写关闭原围城并保留同一军队的合法返程，而非重建城市出征"
	)
	battle.queue_free()
	scene.queue_free()
	await process_frame
	_finish()


func _formation_total(army: Dictionary) -> int:
	var total := 0
	for formation_value in Array(Dictionary(army.get("macro_march", {})).get("formation_snapshots", [])):
		total += int(Dictionary(formation_value).get("member_count", 0))
	return total


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("MACRO_SIEGE_WARTIME_HANDOFF_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_SIEGE_WARTIME_HANDOFF_SMOKE FAIL: %s" % failure)
	quit(1)

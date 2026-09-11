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
		and Dictionary(frozen_request.get("macro_siege_start_state", {})).get("attacker_total_hp", -1) == before.get("attacker_total_hp", -2)
		and Dictionary(frozen_request.get("macro_siege_start_state", {})).get("defender_total_hp", -1) == before.get("defender_total_hp", -2),
		"首次接管冻结宏观已发生的双方 HP，而非以人数重建满血队伍"
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

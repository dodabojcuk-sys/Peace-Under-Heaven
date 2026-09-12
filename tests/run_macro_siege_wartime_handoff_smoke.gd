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
	var ram_button := plan_panel.get_node("RamButton") as Button
	var arrow_button := plan_panel.get_node("ArrowTowerButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var plan_confirm_button := plan_panel.get_node("ConfirmButton") as Button
	var macro_route_button := battle.get_node(
		"UI/RootPanel/SquadControls/Squad1/RouteButton"
	) as Button
	var wood_before_plan := int(city.get("wood"))
	_check(
		battle.spatial_view.visible
			and not watch_button.visible
			and ram_button.visible and not ram_button.disabled
			and arrow_button.visible and not arrow_button.disabled
			and not barricade_button.visible
			and plan_confirm_button.visible
			and plan_confirm_button.disabled
			and macro_route_button.disabled,
		"宏观围城只提供会实际生效的攻城槌和箭塔，不允许临时改写已冻结的原军队部署"
	)
	var legacy_defense_plan := WartimeFacilityPlan.empty_snapshot()
	legacy_defense_plan.facilities.append(WartimeFacilityPlan.make_facility(
		WartimeFacilityPlan.KIND_BARRICADE, CommittedForceSnapshot.FRONT_ROUTE, 1
	))
	var rejected_legacy_effect: Dictionary = city.commit_macro_siege_wartime_facility_plan(
		army_id, &"redcliff_city", battle.request.transaction_id, legacy_defense_plan
	)
	_check(
		not bool(rejected_legacy_effect.get("success", false))
			and bool(WartimeFacilityPlan.validate_for_source(
				legacy_defense_plan, BattleRequest.SOURCE_MACRO_SIEGE
			).get("valid", false))
			and int(city.get("wood")) == wood_before_plan,
		"宏观围城新提交拒绝没有攻城实际效果的拒马，旧结构计划仍可由恢复校验读取且不扣木材"
	)
	ram_button.emit_signal("pressed")
	arrow_button.emit_signal("pressed")
	await process_frame
	plan_confirm_button.emit_signal("pressed")
	await process_frame
	handoff = Dictionary(city.get_macro_march_read_model().war_loop.active_siege.get("wartime_handoff", {}))
	frozen_request = Dictionary(handoff.get("battle_request_snapshot", {}))
	_check(
		Array(battle.request.wartime_facility_plan.get("facilities", [])).size() == 2
			and Array(Dictionary(frozen_request.get("wartime_facility_plan", {})).get("facilities", [])).size() == 2
			and int(city.get("wood")) == wood_before_plan - 18
			and plan_confirm_button.visible == false,
		"宏观围城确认工事只扣一次建设木材，并写入冻结接管请求"
	)
	var duplicate_plan: Dictionary = city.commit_macro_siege_wartime_facility_plan(
		army_id, &"redcliff_city", battle.request.transaction_id, battle.request.wartime_facility_plan
	)
	_check(
		not bool(duplicate_plan.get("success", false))
			and int(city.get("wood")) == wood_before_plan - 18,
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
	var gate_before_ram := int(battle.coordinator.active_session.get_route_state(
		CommittedForceSnapshot.FRONT_ROUTE
	).get("gate_hp", 0))
	battle.tick_timer.stop()
	battle.step_battle_for_test(8)
	var session := battle.coordinator.active_session
	var works: Array = session.get_wartime_facility_state().facilities
	_check(works.size() == 2 and works.all(func(r: Dictionary): return r.phase == BattleSession.FACILITY_PHASE_CONSTRUCTING and int(r.progress_ticks) == 0), "工事人员仍在接近工位，不提前授予建设效果")
	_check(int(session.routes[CommittedForceSnapshot.FRONT_ROUTE].gate_hp) == gate_before_ram and int(session.spatial_state.units["1"][0]) > 0, "途中位置推进，远离城门时攻城槌不改变耐久")
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
	await _run_formal_macro_victory_chain()
	await _run_formal_macro_defeat_chain()
	await _run_formal_macro_full_wipe_chain()
	_finish()


## This is a separate city and army so the existing retreat proof above keeps
## its exact source facts.  It drives the visible C0 squad-selection and
## advance buttons, then the same timeout callback that a running battle uses;
## it never turns a siege into a victory by modifying route HP or ownership.
func _run_formal_macro_victory_chain() -> void:
	var victory_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(victory_scene)
	await process_frame
	await process_frame
	var victory_city: Node = victory_scene.get_node("ConstructionController")
	victory_city.set_process(false)
	victory_city.food = 120
	var victory_roster: Array[Dictionary] = victory_city.get_formation_roster()
	var first_leg: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var station_order: Dictionary = victory_city.commit_macro_march_from_city(
		[
			StringName(victory_roster[0].formation_id),
			StringName(victory_roster[1].formation_id),
			StringName(victory_roster[2].formation_id),
		],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	var station_army: Dictionary = Dictionary(station_order.get("army", {}))
	var station_macro: Dictionary = Dictionary(station_army.get("macro_march", {}))
	victory_city.advance_macro_march_time(
		StringName(station_army.get("army_id", &"")), StringName(station_macro.get("order_id", &"")),
		0, int(station_macro.get("total_millis", 0))
	)
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var siege_order: Dictionary = victory_city.commit_macro_march_from_station(
		StringName(station_army.get("army_id", &"")), &"redcliff_city",
		StringName(attack_route.route_id), Array(attack_route.points)
	)
	var siege_army: Dictionary = Dictionary(siege_order.get("army", {}))
	var siege_macro: Dictionary = Dictionary(siege_army.get("macro_march", {}))
	victory_city.advance_macro_march_time(
		StringName(siege_army.get("army_id", &"")), StringName(siege_macro.get("order_id", &"")),
		0, int(siege_macro.get("total_millis", 0))
	)
	var army_id := StringName(siege_army.get("army_id", &""))
	var food_before_handoff := int(victory_city.get("food"))
	_check(
		victory_city.enter_macro_siege_wartime(army_id, &"redcliff_city"),
		"胜利链由正式宏观围城入口打开唯一战时实例"
	)
	await process_frame
	await process_frame
	var victory_battle := victory_city.get_formal_battle_scene() as C0BattleGraybox
	if victory_battle == null or not victory_battle.start_battle():
		_check(false, "胜利链正式 C0 实例可以激活")
		victory_scene.queue_free()
		await process_frame
		return
	victory_battle.tick_timer.stop()
	var selected_and_advanced := true
	for squad_id in range(1, victory_battle.request.committed_force.squads.size() + 1):
		var select_button := victory_battle.get_node_or_null(
			"UI/RootPanel/SquadControls/Squad%d/SelectButton" % squad_id
		) as Button
		if select_button == null or select_button.disabled:
			selected_and_advanced = false
			continue
		select_button.emit_signal("pressed")
		await process_frame
		if victory_battle.selected_advance_button.disabled:
			selected_and_advanced = false
			continue
		victory_battle.selected_advance_button.emit_signal("pressed")
		await process_frame
	var pending_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		victory_battle.step_battle_for_test(1)
		await process_frame
		if victory_battle.coordinator.active_session != null:
			pending_result = victory_battle.coordinator.active_session.result
		if pending_result != null:
			break
	var committed_result: Dictionary = victory_battle.confirm_pending_result()
	await process_frame
	var settled_army: Dictionary = victory_city.get_army_state(army_id)
	var redcliff_state: Dictionary = victory_city.get_macro_march_read_model().war_loop.cities_by_id.get(
		&"redcliff_city", {}
	)
	_check(
		selected_and_advanced
			and pending_result != null
			and pending_result.outcome == BattleOutcome.Value.VICTORY
			and not committed_result.is_empty()
			and StringName(committed_result.get("army_id", &"")) == army_id
			and StringName(committed_result.get("outcome", &""))
				== BattleOutcome.to_id(BattleOutcome.Value.VICTORY)
			and StringName(settled_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED
			and StringName(settled_army.get("target_node_id", &"")) == &"redcliff_city"
			and StringName(redcliff_state.get("military_controller_faction_id", &"")) == &"player"
			and victory_city.get_macro_march_read_model().war_loop.active_siege.is_empty()
			and int(victory_city.get("food")) == food_before_handoff,
		"宏观来源经正式 C0 前进、胜利回写后只更新原军队驻扎和目标控制权，不重复扣粮"
	)
	victory_battle.queue_free()
	victory_scene.queue_free()
	await process_frame


## This chain intentionally issues no advance order after the formal siege
## takeover. The normal C0 time-limit resolution therefore produces a DEFEAT
## with real survivors, proving that a macro-origin loss becomes one lawful
## return journey rather than an occupation or a synthetic city expedition.
func _run_formal_macro_defeat_chain() -> void:
	var defeat_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(defeat_scene)
	await process_frame
	await process_frame
	var defeat_city: Node = defeat_scene.get_node("ConstructionController")
	defeat_city.set_process(false)
	defeat_city.food = 120
	var defeat_roster: Array[Dictionary] = defeat_city.get_formation_roster()
	var first_leg: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var station_order: Dictionary = defeat_city.commit_macro_march_from_city(
		[StringName(defeat_roster[0].formation_id)],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	var station_army: Dictionary = Dictionary(station_order.get("army", {}))
	var station_macro: Dictionary = Dictionary(station_army.get("macro_march", {}))
	defeat_city.advance_macro_march_time(
		StringName(station_army.get("army_id", &"")), StringName(station_macro.get("order_id", &"")),
		0, int(station_macro.get("total_millis", 0))
	)
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var siege_order: Dictionary = defeat_city.commit_macro_march_from_station(
		StringName(station_army.get("army_id", &"")), &"redcliff_city",
		StringName(attack_route.route_id), Array(attack_route.points)
	)
	var siege_army: Dictionary = Dictionary(siege_order.get("army", {}))
	var siege_macro: Dictionary = Dictionary(siege_army.get("macro_march", {}))
	defeat_city.advance_macro_march_time(
		StringName(siege_army.get("army_id", &"")), StringName(siege_macro.get("order_id", &"")),
		0, int(siege_macro.get("total_millis", 0))
	)
	var army_id := StringName(siege_army.get("army_id", &""))
	var food_before_handoff := int(defeat_city.get("food"))
	var entered: bool = defeat_city.enter_macro_siege_wartime(army_id, &"redcliff_city")
	await process_frame
	await process_frame
	var defeat_battle := defeat_city.get_formal_battle_scene() as C0BattleGraybox
	if defeat_battle == null or not defeat_battle.start_battle():
		_check(false, "战败链正式 C0 实例可以激活")
		defeat_scene.queue_free()
		await process_frame
		return
	defeat_battle.tick_timer.stop()
	var pending_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		defeat_battle.step_battle_for_test(1)
		await process_frame
		if defeat_battle.coordinator.active_session != null:
			pending_result = defeat_battle.coordinator.active_session.result
		if pending_result != null:
			break
	var committed_result: Dictionary = defeat_battle.confirm_pending_result()
	await process_frame
	var returned_army: Dictionary = defeat_city.get_army_state(army_id)
	var redcliff_state: Dictionary = defeat_city.get_macro_march_read_model().war_loop.cities_by_id.get(
		&"redcliff_city", {}
	)
	_check(
		entered
			and pending_result != null
			and pending_result.outcome == BattleOutcome.Value.DEFEAT
			and pending_result.survivor_count > 0
			and not committed_result.is_empty()
			and StringName(committed_result.get("army_id", &"")) == army_id
			and StringName(committed_result.get("outcome", &""))
				== BattleOutcome.to_id(BattleOutcome.Value.DEFEAT)
			and StringName(returned_army.get("phase", &"")) == ArmyRegistry.PHASE_RETREATING
			and StringName(redcliff_state.get("military_controller_faction_id", &"")) != &"player"
			and defeat_city.get_macro_march_read_model().war_loop.active_siege.is_empty()
			and int(defeat_city.get("food")) == food_before_handoff,
		"宏观来源的正式战败保留幸存原军队返程，不占城且不重复扣粮"
	)
	defeat_battle.queue_free()
	defeat_scene.queue_free()
	await process_frame


## A deliberately stronger **regression-theatre** Redcliff force gives the
## formal macro source a reproducible full-wipe outcome.  This changes only the
## isolated fixture before the city is created; it does not manufacture a
## result, edit an army, or alter the playable Resource.  The normal C0 UI
## selection, advance command, ticks and result confirmation remain the path
## under test.
func _run_formal_macro_full_wipe_chain() -> void:
	var regression_definition = THEATER._regression_definition
	var original_redcliff: Dictionary = Dictionary(
		regression_definition.points[&"redcliff_city"]
	).duplicate(true)
	var overwhelming_redcliff := original_redcliff.duplicate(true)
	overwhelming_redcliff.gate_hp = 0
	overwhelming_redcliff.defender_count = 20
	overwhelming_redcliff.defender_attack_per_member = 12
	regression_definition.points[&"redcliff_city"] = overwhelming_redcliff
	var wipe_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(wipe_scene)
	await process_frame
	await process_frame
	var wipe_city: Node = wipe_scene.get_node("ConstructionController")
	wipe_city.set_process(false)
	wipe_city.food = 120
	var wipe_roster: Array[Dictionary] = wipe_city.get_formation_roster()
	var first_leg: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var station_order: Dictionary = wipe_city.commit_macro_march_from_city(
		[StringName(wipe_roster[0].formation_id)],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	var station_army: Dictionary = Dictionary(station_order.get("army", {}))
	var station_macro: Dictionary = Dictionary(station_army.get("macro_march", {}))
	wipe_city.advance_macro_march_time(
		StringName(station_army.get("army_id", &"")), StringName(station_macro.get("order_id", &"")),
		0, int(station_macro.get("total_millis", 0))
	)
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var siege_order: Dictionary = wipe_city.commit_macro_march_from_station(
		StringName(station_army.get("army_id", &"")), &"redcliff_city",
		StringName(attack_route.route_id), Array(attack_route.points)
	)
	var siege_army: Dictionary = Dictionary(siege_order.get("army", {}))
	var siege_macro: Dictionary = Dictionary(siege_army.get("macro_march", {}))
	wipe_city.advance_macro_march_time(
		StringName(siege_army.get("army_id", &"")), StringName(siege_macro.get("order_id", &"")),
		0, int(siege_macro.get("total_millis", 0))
	)
	var army_id := StringName(siege_army.get("army_id", &""))
	var food_before_handoff := int(wipe_city.get("food"))
	var entered: bool = wipe_city.enter_macro_siege_wartime(army_id, &"redcliff_city")
	await process_frame
	await process_frame
	var wipe_battle := wipe_city.get_formal_battle_scene() as C0BattleGraybox
	if wipe_battle == null or not wipe_battle.start_battle():
		_check(false, "全灭链正式 C0 实例可以激活")
		regression_definition.points[&"redcliff_city"] = original_redcliff
		wipe_scene.queue_free()
		await process_frame
		return
	wipe_battle.tick_timer.stop()
	var select_button := wipe_battle.get_node_or_null(
		"UI/RootPanel/SquadControls/Squad1/SelectButton"
	) as Button
	var issued_advance := select_button != null and not select_button.disabled
	if issued_advance:
		select_button.emit_signal("pressed")
		await process_frame
		issued_advance = not wipe_battle.selected_advance_button.disabled
		if issued_advance:
			wipe_battle.selected_advance_button.emit_signal("pressed")
			await process_frame
	var pending_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		wipe_battle.step_battle_for_test(1)
		await process_frame
		if wipe_battle.coordinator.active_session != null:
			pending_result = wipe_battle.coordinator.active_session.result
		if pending_result != null:
			break
	var committed_result: Dictionary = wipe_battle.confirm_pending_result()
	var repeated_result: Dictionary = wipe_battle.confirm_pending_result()
	await process_frame
	var closed_army: Dictionary = wipe_city.get_army_state(army_id)
	var closed_macro: Dictionary = Dictionary(closed_army.get("macro_march", {}))
	var remaining_formation_count := -1
	for formation_value in Array(closed_macro.get("formation_snapshots", [])):
		var formation: Dictionary = Dictionary(formation_value)
		if StringName(formation.get("formation_id", &"")) == StringName(wipe_roster[0].formation_id):
			remaining_formation_count = int(formation.get("member_count", -1))
			break
	var redcliff_state: Dictionary = wipe_city.get_macro_march_read_model().war_loop.cities_by_id.get(
		&"redcliff_city", {}
	)
	_check(
		entered
			and issued_advance
			and pending_result != null
			and pending_result.outcome == BattleOutcome.Value.DEFEAT
			and pending_result.survivor_count == 0
			and not committed_result.is_empty()
			and repeated_result == committed_result
			and StringName(committed_result.get("army_id", &"")) == army_id
			and StringName(closed_army.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED
			and StringName(closed_macro.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED
			and Dictionary(closed_army.get("units_by_definition_id", {})).is_empty()
			and remaining_formation_count == 0
			and StringName(redcliff_state.get("military_controller_faction_id", &"")) != &"player"
			and wipe_city.get_macro_march_read_model().war_loop.active_siege.is_empty()
			and int(wipe_city.get("food")) == food_before_handoff,
		"宏观来源全灭关闭原军队和围城，不占城、不留空壳且不重复扣粮或回写"
	)
	regression_definition.points[&"redcliff_city"] = original_redcliff
	wipe_battle.queue_free()
	wipe_scene.queue_free()
	await process_frame


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

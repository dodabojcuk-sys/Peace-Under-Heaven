extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	var city := await _fresh_city()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	var invasion := field.get_blackstone_invasion()
	_check(
		StringName(invasion.get("phase", &"")) == FieldTacticsState.INVASION_DORMANT
		and StringName(invasion.get("source_point_id", &"")) == &"redcliff_city"
		and StringName(invasion.get("target_point_id", &"")) == &"blackstone_city",
		"新战役保存一支来自赤崖、目标黑石的一次性敌军，而非点击城门临时生成"
	)
	city.current_day = 4
	var warning: Dictionary = city.get_blackstone_invasion_read_model()
	_check(
		bool(warning.get("known", false))
		and not bool(warning.get("exact_strength_known", true))
		and int(warning.get("known_strength", 0)) == -1,
		"第 4 日预警公开来源、目标与道路，但未侦察时不公开精确兵力"
	)
	_check(
		field.activate_configured_invasions(4).is_empty()
		and StringName(field.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_DORMANT,
		"预警日不会提前出发"
	)
	city.current_day = 5
	var activated: Array[StringName] = field.activate_configured_invasions(5)
	_check(
		activated == [&"invasion.blackstone.001"]
		and field.activate_configured_invasions(5).is_empty(),
		"出发条件只激活同一稳定 ID 一次"
	)
	var interception: Dictionary = field.apply_patrol_encounter(
		&"invasion.blackstone.001", [&"army.intercept.probe"], 3, [],
		{"world_position": Vector2i(field.get_blackstone_invasion().get("world_position", Vector2i.ZERO))}
	)
	_check(
		int(interception.get("strength", 0)) == 13,
		"来袭军复用既有战区遭遇结算，截击战损写回同一敌军而非生成防守副本"
	)
	var steps := 0
	while StringName(field.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_MARCHING and steps < 120:
		city.advance_war_loop_time(1000)
		steps += 1
	invasion = field.get_blackstone_invasion()
	_check(
		StringName(invasion.get("phase", &"")) == FieldTacticsState.INVASION_ARRIVED
		and StringName(invasion.get("current_point_id", &"")) == &"blackstone_city"
		and int(invasion.get("strength", 0)) == 13,
		"来袭军沿真实道路抵达黑石，并保留实际剩余兵力"
	)
	var formation_ids := _available_formation_ids(city)
	var started: Dictionary = city.begin_wartime_defense_attempt(formation_ids)
	var attempt: Dictionary = started.get("attempt", {})
	var enemy := EnemyForceSnapshot.from_dictionary(Dictionary(attempt.get("enemy_force_snapshot", {})))
	var handed_off := field.get_blackstone_invasion()
	_check(
		bool(started.get("success", false))
		and enemy != null and enemy.enemy_count == 13
		and StringName(attempt.get("source_patrol_id", &"")) == &"invasion.blackstone.001"
		and StringName(handed_off.get("phase", &"")) == FieldTacticsState.INVASION_HANDED_OFF
		and StringName(handed_off.get("handoff_attempt_id", &"")) == StringName(attempt.get("attempt_id", &"")),
		"抵达交接把同一敌军的实际人数冻结进守城事务，并停止战区重复模拟"
	)
	var before_repeat: Dictionary = field.get_blackstone_invasion()
	city.advance_war_loop_time(30000)
	_check(
		field.get_blackstone_invasion() == before_repeat
		and not bool(city.begin_wartime_defense_attempt(formation_ids).get("success", false)),
		"交接后时间推进和重复操作不会复制敌军或第二场守城"
	)
	var restored := FieldTacticsState.new()
	_check(
		restored.restore_snapshot(field.get_snapshot())
		and StringName(restored.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_HANDED_OFF
		and StringName(restored.get_blackstone_invasion().get("handoff_attempt_id", &"")) == StringName(attempt.get("attempt_id", &"")),
		"战区快照恢复保留同一敌军的交接身份"
	)
	var legacy_v11: Dictionary = city.export_v5_campaign_snapshot()
	legacy_v11.schema_version = 11
	legacy_v11.erase("population_recovery")
	legacy_v11.erase("city_governance")
	for key in ["source_patrol_id", "source_force_name", "source_point_id", "source_route_name"]:
		Dictionary(legacy_v11.expedition_attempt).erase(key)
	var migrated_v11: Dictionary = V5CampaignSnapshot.validate_structure(legacy_v11, city.get_unit_definition_ids())
	_check(
		bool(migrated_v11.get("valid", false))
		and int(Dictionary(migrated_v11.get("snapshot", {})).get("schema_version", 0)) == V5CampaignSnapshot.SCHEMA_VERSION
		and StringName(Dictionary(Dictionary(migrated_v11.get("snapshot", {})).get("expedition_attempt", {})).get("source_patrol_id", &"missing")) == &"",
		"V11 守城尝试迁移为空外部来源，不给旧存档补造一支来袭军"
	)
	var entered: bool = city.enter_wartime_defense_battle()
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	var battle_result: BattleResult
	if entered and battle != null and battle.start_battle():
		battle.tick_timer.stop()
		var advance_button := battle.get_node("UI/RootPanel/SelectedSquadPanel/AdvanceButton") as Button
		for squad_id in [1, 2, 3]:
			var select_button := battle.get_node("UI/RootPanel/SquadControls/Squad%d/SelectButton" % squad_id) as Button
			select_button.pressed.emit()
			advance_button.pressed.emit()
			await process_frame
		battle_result = battle.step_battle_for_test(300)
	var summary: Dictionary = battle.confirm_pending_result() if battle != null and battle_result != null else {}
	var returned: bool = battle.request_return_to_city() != null if battle != null and not summary.is_empty() else false
	await process_frame
	await process_frame
	var resolved_invasion: Dictionary = field.get_blackstone_invasion()
	print("BLACKSTONE_INVASION_DEFENSE_TRACE patrol=%s outcome=%s remaining=%d returned=%s" % [String(resolved_invasion.get("patrol_id", &"")), String(resolved_invasion.get("resolution_outcome", &"")), int(resolved_invasion.get("strength", -1)), str(returned)])
	_check(
		entered and battle_result != null and battle_result.outcome == BattleOutcome.Value.VICTORY
		and returned and city.get_formal_battle_scene() == null
		and int(summary.get("wounded_added", -1)) + int(summary.get("fallen_added", -1)) == battle_result.casualty_count
		and bool(city.get_population_recovery_read_model().get("accounted", false))
		and StringName(resolved_invasion.get("phase", &"")) == FieldTacticsState.INVASION_RESOLVED
		and int(resolved_invasion.get("strength", -1)) == 0
		and StringName(resolved_invasion.get("resolution_outcome", &"")) == &"VICTORY",
		"同一来源敌军进入正式守城、经真实部署和推进获胜后结算一次，并回到黑石常态内城"
	)
	var recovery_before: Dictionary = city.get_population_recovery_read_model()
	var treatment_result: Dictionary = {}
	var treated_wounded_remaining := int(recovery_before.get("wounded", 0))
	if int(recovery_before.get("wounded", 0)) > 0:
		treatment_result = city.begin_wounded_treatment()
		var treatment := Dictionary(city.get_population_recovery_read_model().get("treatment", {}))
		city.advance_city_time(float(int(treatment.get("required_milliseconds", 0))) / 1000.0)
		treated_wounded_remaining = int(city.get_population_recovery_read_model().get("wounded", -1))
	var counterattack_formations: Array[StringName] = _available_formation_ids(city)
	var route_north: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison")
	var north_order: Dictionary = city.commit_macro_march_from_city(counterattack_formations, &"northwatch_garrison", StringName(route_north.get("route_id", &"")), Array(route_north.get("points", [])))
	var counter_army := Dictionary(north_order.get("army", {}))
	var counter_macro := Dictionary(counter_army.get("macro_march", {}))
	city.advance_macro_march_time(StringName(counter_army.get("army_id", &"")), StringName(counter_macro.get("order_id", &"")), 0, int(counter_macro.get("total_millis", 0)))
	var route_redcliff: Dictionary = city.plan_field_path(&"northwatch_garrison", &"redcliff_city")
	var attack_order: Dictionary = city.commit_macro_march_from_station(StringName(counter_army.get("army_id", &"")), &"redcliff_city", StringName(route_redcliff.get("route_id", &"")), Array(route_redcliff.get("points", [])))
	counter_army = Dictionary(attack_order.get("army", {}))
	counter_macro = Dictionary(counter_army.get("macro_march", {}))
	city.advance_macro_march_time(StringName(counter_army.get("army_id", &"")), StringName(counter_macro.get("order_id", &"")), 0, int(counter_macro.get("total_millis", 0)))
	var counter_army_id := StringName(counter_army.get("army_id", &""))
	var siege_entered: bool = city.enter_macro_siege_wartime(counter_army_id, &"redcliff_city")
	await process_frame
	await process_frame
	var siege_battle := city.get_formal_battle_scene() as C0BattleGraybox
	var siege_result: BattleResult
	var siege_summary: Dictionary = {}
	if siege_entered and siege_battle != null and siege_battle.start_battle(true):
		siege_result = siege_battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
		if siege_result != null:
			siege_battle._show_pending_result(siege_result)
			siege_summary = siege_battle.confirm_pending_result()
	var redcliff := Dictionary(Dictionary(city.get_macro_march_read_model().war_loop).cities_by_id.get(&"redcliff_city", {}))
	print("BLACKSTONE_COUNTERATTACK_TRACE treated_remaining=%d north=%s attack=%s army=%s outcome=%s controller=%s food=%d" % [treated_wounded_remaining, str(north_order.get("success", false)), str(attack_order.get("success", false)), String(counter_army_id), String(siege_summary.get("outcome", &"")), String(redcliff.get("military_controller_faction_id", &"")), int(city.food)])
	_check(
		(int(recovery_before.get("wounded", 0)) == 0 or (bool(treatment_result.get("success", false)) and treated_wounded_remaining == 0))
		and bool(north_order.get("success", false)) and bool(attack_order.get("success", false))
		and siege_result != null and siege_result.outcome == BattleOutcome.Value.VICTORY
		and not siege_summary.is_empty()
		and StringName(redcliff.get("military_controller_faction_id", &"")) == &"player"
		and bool(city.get_population_recovery_read_model().get("accounted", false)),
		"同一正常战役在守城后支付治疗成本、重用幸存编队反攻，并通过原围城事务占领赤崖"
	)
	city.get_parent().queue_free()
	await process_frame
	await _check_destroyed_invasion_no_handoff()
	await _check_external_defense_line()
	if failures.is_empty():
		print("BLACKSTONE_INVASION_R0_SMOKE PASS assertions=%d steps=%d" % [assertions, steps])
		quit(0)
		return
	for failure in failures:
		push_error("BLACKSTONE_INVASION_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _fresh_city() -> Node:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	return city


func _available_formation_ids(city: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	for formation_value in city._garrison_state.get_formations():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			result.append(StringName(formation.get("formation_id", &"")))
	return result


func _check_destroyed_invasion_no_handoff() -> void:
	var city := await _fresh_city()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.activate_configured_invasions(5)
	var invasion := field.get_blackstone_invasion()
	var strength := int(invasion.get("strength", 0))
	var eliminated: Dictionary = field.apply_patrol_encounter(
		&"invasion.blackstone.001", [&"army.elimination.probe"], strength, [],
		{"world_position": Vector2i(invasion.get("world_position", Vector2i.ZERO))}
	)
	city.advance_war_loop_time(1)
	var entered: bool = city.enter_wartime_defense_battle(_available_formation_ids(city))
	_check(
		int(eliminated.get("strength", -1)) == 0
		and StringName(field.get_blackstone_invasion().get("phase", &"")) == FieldTacticsState.INVASION_DEFEATED
		and not entered,
		"外部遭遇已消灭同一来袭军时标记为战区战败，不再生成黑石城门防守"
	)
	# The rejected formal entry owns a short player-facing feedback timer. Let it
	# finish before tearing down this isolated scene so the smoke does not create
	# a test-only SceneTreeTimer leak.
	await create_timer(2.6).timeout
	city.get_parent().queue_free()
	await process_frame


func _check_external_defense_line() -> void:
	var city := await _fresh_city()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	field.camps_by_id[&"camp.defense.test"] = {
		"camp_id": &"camp.defense.test", "point_id": &"camp.defense.test.point",
		"road_id": &"road.blackstone.northwatch.ridge", "display_name": "首关防线驻点",
		"world_position": Vector2i(360, 610), "durability": 80, "connected": true,
	}
	var engineer_id := StringName(Dictionary(city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER).get("specialist", {})).get("specialist_id", &""))
	var arrow: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.defense.test", Vector2i(430, 610), FieldTacticsState.FACILITY_ARROW_TOWER)
	var arrow_project: Dictionary = arrow.get("project", {})
	city.advance_war_loop_time(int(arrow_project.get("travel_milliseconds", 0)) + int(arrow_project.get("required_milliseconds", 0)))
	var barricade: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.defense.test", Vector2i(470, 610), FieldTacticsState.FACILITY_BARRICADE)
	var barricade_project: Dictionary = barricade.get("project", {})
	city.advance_war_loop_time(int(barricade_project.get("travel_milliseconds", 0)) + int(barricade_project.get("required_milliseconds", 0)))
	field.patrols_by_id[&"invasion.facility.test"] = {
		"patrol_id": &"invasion.facility.test", "display_name": "防线测试敌军",
		"phase": FieldTacticsState.INVASION_MARCHING, "invasion_kind": FieldTacticsState.INVASION_KIND_BLACKSTONE_FIRST,
		"strength": 4, "world_position": Vector2i(450, 610), "current_point_id": &"",
		"route_point_ids": [], "wait_remaining_milliseconds": 0, "resolved_army_ids": [],
	}
	var first_effect: Dictionary = city.advance_war_loop_time(4000)
	var patrol := Dictionary(field.patrols_by_id[&"invasion.facility.test"])
	var facilities: Dictionary = city.get_field_tactics_read_model().get("watchtowers_by_id", {})
	var arrow_record: Dictionary = {}
	var barricade_record: Dictionary = {}
	for facility_value in facilities.values():
		var facility: Dictionary = Dictionary(facility_value)
		if StringName(facility.get("facility_kind", &"")) == FieldTacticsState.FACILITY_ARROW_TOWER:
			arrow_record = facility
		elif StringName(facility.get("facility_kind", &"")) == FieldTacticsState.FACILITY_BARRICADE:
			barricade_record = facility
	_check(
		bool(arrow.get("success", false)) and bool(barricade.get("success", false))
		and int(patrol.get("strength", 0)) == 3
		and int(patrol.get("wait_remaining_milliseconds", 0)) == 8000
		and int(barricade_record.get("durability", 0)) == 115
		and Array(first_effect.get("facility_events", [])).size() == 2,
		"外部箭塔攻击同一真实敌军，拒马为其实际行军增加一次延迟并承受持久损伤"
	)
	patrol.phase = FieldTacticsState.INVASION_ARRIVED
	field.patrols_by_id[&"invasion.facility.test"] = patrol
	var repair_engineer_id := StringName(Dictionary(city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER).get("specialist", {})).get("specialist_id", &""))
	var repair: Dictionary = city.begin_field_facility_repair(repair_engineer_id, StringName(barricade_record.get("watchtower_id", &"")))
	var repair_project: Dictionary = repair.get("project", {})
	city.advance_war_loop_time(int(repair_project.get("travel_milliseconds", 0)) + int(repair_project.get("required_milliseconds", 0)))
	barricade_record = Dictionary(field.watchtowers_by_id.get(StringName(barricade_record.get("watchtower_id", &"")), {}))
	_check(
		bool(repair.get("success", false))
		and int(barricade_record.get("durability", 0)) == int(barricade_record.get("max_durability", -1))
		and StringName(barricade_record.get("state", &"")) == FieldTacticsState.FACILITY_ACTIVE,
		"受损外部拒马由另一名真实工程师到场施工后恢复同一设施"
	)
	var restored := FieldTacticsState.new()
	_check(
		restored.restore_snapshot(field.get_snapshot())
		and Dictionary(restored.watchtowers_by_id.get(StringName(arrow_record.get("watchtower_id", &"")), {})).get("facility_kind", &"") == FieldTacticsState.FACILITY_ARROW_TOWER
		and int(Dictionary(restored.watchtowers_by_id.get(StringName(barricade_record.get("watchtower_id", &"")), {})).get("durability", 0)) == 160,
		"外部防线身份、作用参数与战损通过既有 Field 快照恢复"
	)
	var invalid_snapshot := field.get_snapshot()
	var invalid_arrow := Dictionary(Dictionary(invalid_snapshot.watchtowers_by_id).get(StringName(arrow_record.get("watchtower_id", &"")), {}))
	invalid_arrow.durability = int(invalid_arrow.get("max_durability", 0)) + 1
	invalid_snapshot.watchtowers_by_id[StringName(arrow_record.get("watchtower_id", &""))] = invalid_arrow
	var invalid_probe := FieldTacticsState.new()
	_check(
		not invalid_probe.restore_snapshot(invalid_snapshot)
		and invalid_probe.watchtowers_by_id.is_empty(),
		"非法外部设施耐久快照被拒绝，且不会污染当前战区状态"
	)
	city.get_parent().queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

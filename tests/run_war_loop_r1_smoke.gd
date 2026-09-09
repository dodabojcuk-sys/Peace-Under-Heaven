extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const WAR_LOOP_STATE = preload("res://scripts/war/war_loop_state.gd")
const WAR_LOOP_RULES: WarLoopRules = preload("res://resources/war/war_loop_r1_rules.tres")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var surrender_state: WarLoopState = WAR_LOOP_STATE.new()
	surrender_state.initialize_from_theater(THEATER.get_points())
	var surrender := surrender_state.begin_siege(&"army.test", &"macro.order.000001", &"silverford_city", 20, 100, 10, 0, 10000, WAR_LOOP_RULES)
	_check(StringName(surrender.phase) == WarLoopState.PHASE_OCCUPIED and StringName(surrender.resolution) == WarLoopState.RESOLUTION_SURRENDER, "数值配置满足比例时先行招降，不进入攻门流程")
	_run_war_loop_regression_probes()
	await _run_controller_time_probe()
	var context := await _new_city()
	var city: Node = context.city
	var roster: Array[Dictionary] = city.get_formation_roster()
	var selected: Array[StringName] = [StringName(roster[0].formation_id), StringName(roster[1].formation_id)]
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city(selected, &"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points))
	var army: Dictionary = issued.army
	var initial_count := int(army.units_by_definition_id[city.INFANTRY_ROLE.role_id])
	var macro: Dictionary = army.macro_march
	var north: Dictionary = city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
	_check(bool(north.success) and StringName(north.army.phase) == ArmyRegistry.PHASE_STATIONED, "军队抵达友方驻扎点后保留同一军队身份")
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack_issue: Dictionary = city.commit_macro_march_from_station(StringName(army.army_id), &"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points))
	var attack_army: Dictionary = attack_issue.army
	var attack_macro: Dictionary = attack_army.macro_march
	var arrival: Dictionary = city.advance_macro_march_time(StringName(attack_army.army_id), StringName(attack_macro.order_id), 0, int(attack_macro.total_millis))
	_check(bool(arrival.success) and StringName(city.get_macro_march_army().phase) == ArmyRegistry.PHASE_SIEGING, "抵达拒降敌城自动进入攻城，不走旧战斗结算")
	var partial: Dictionary = city.advance_war_loop_time(250)
	var partial_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	if partial_snapshot.is_empty():
		push_error("WAR_LOOP_EXPORT_EMPTY")
		await _drop(context.scene)
		quit(1)
		return
	await _drop(context.scene)
	var restored_context := await _new_city()
	var restored: Node = restored_context.city
	var restore: Dictionary = restored.restore_v5_campaign_snapshot(partial_snapshot)
	var restored_siege: Dictionary = restored.get_macro_march_read_model().war_loop.active_siege
	_check(bool(restore.success) and int(restored_siege.tick) == int(partial.tick) and int(restored_siege.gate_hp) < 240, "冷恢复保留攻城 tick、城门和守军状态")
	var final_result: Dictionary = {}
	for _index in range(30):
		final_result = restored.advance_war_loop_time(250)
		if bool(final_result.get("level_cleared", false)):
			break
	var final_army: Dictionary = restored.get_macro_march_army()
	var redcliff: Dictionary = Dictionary(Dictionary(restored.get_macro_march_read_model().war_loop).get("cities_by_id", {})).get(&"redcliff_city", {})
	_check(StringName(final_army.phase) == ArmyRegistry.PHASE_STATIONED and StringName(redcliff.military_controller_faction_id) == &"player", "破门、清剿守军后正式占领并成为驻兵点")
	_check(not bool(restored.get_macro_march_read_model().level_cleared), "双城胜利不会在仅占领赤崖城时提前成立")
	_check(int(final_army.units_by_definition_id[restored.INFANTRY_ROLE.role_id]) < initial_count, "攻城伤亡同步回同一支宏观军队，不回填黑石城 roster")
	var to_silverford: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
	var silverford_order: Dictionary = restored.commit_macro_march_from_station(StringName(final_army.army_id), &"silverford_city", StringName(to_silverford.route_id), Array(to_silverford.points))
	var silverford_army: Dictionary = silverford_order.army
	var silverford_macro: Dictionary = silverford_army.macro_march
	var silverford_arrival: Dictionary = restored.advance_macro_march_time(StringName(silverford_army.army_id), StringName(silverford_macro.order_id), 0, int(silverford_macro.total_millis))
	var silverford_state: Dictionary = Dictionary(Dictionary(restored.get_macro_march_read_model().war_loop).get("cities_by_id", {})).get(&"silverford_city", {})
	_check(bool(silverford_arrival.success) and StringName(restored.get_macro_march_army().phase) == ArmyRegistry.PHASE_STATIONED and StringName(silverford_state.military_controller_faction_id) == &"player" and bool(restored.get_macro_march_read_model().level_cleared), "第二座必占敌城自动招降后，双城军事控制权共同完成胜利")
	await _drop(restored_context.scene)
	await _run_formal_retreat_route_contract()
	_finish()


func _run_war_loop_regression_probes() -> void:
	var state: WarLoopState = WAR_LOOP_STATE.new()
	state.initialize_from_theater(THEATER.get_points())
	var started := state.begin_siege(&"army.regression", &"macro.order.000002", &"redcliff_city", 1, 100, 10, 0, 10000, WAR_LOOP_RULES)
	state.advance_siege(WAR_LOOP_RULES)
	var retreat := state.mark_retreat(WAR_LOOP_RULES)
	_check(int(retreat.attacker_total_hp) == 0, "单兵撤逃会承担最小损失，不会被强制保留一人")
	var close := state.close_failed_siege(&"regression.retreat")
	var restarted := state.begin_siege(&"army.regression", &"macro.order.000003", &"redcliff_city", 1, 100, 10, 0, 10000, WAR_LOOP_RULES)
	_check(not close.is_empty() and int(restarted.gate_hp) == int(close.gate_hp), "撤逃后的受损城门会写回城市并保留到再次进攻")
	var mutual: WarLoopState = WAR_LOOP_STATE.new()
	mutual.initialize_from_theater(THEATER.get_points())
	var mutual_siege := mutual.begin_siege(&"army.mutual", &"macro.order.000004", &"redcliff_city", 1, 1, 1, 0, 10000, WAR_LOOP_RULES)
	mutual.active_siege.gate_hp = 0
	mutual.active_siege.gate_breached = true
	mutual.active_siege.attacker_total_hp = 1
	mutual.active_siege.attacker_hp_per_member = 1
	mutual.active_siege.attacker_attack_per_member = 1
	mutual.active_siege.defender_total_hp = 1
	mutual.active_siege.defender_hp_per_member = 1
	mutual.active_siege.defender_attack_per_member = 1
	var mutual_result := mutual.advance_siege(WAR_LOOP_RULES)
	_check(StringName(mutual_siege.phase) == WarLoopState.PHASE_SIEGING and StringName(mutual_result.phase) == WarLoopState.PHASE_FAILED, "攻守同时阵亡时优先判定攻方失败，不会错误占领")
	var malformed := mutual.get_snapshot()
	Dictionary(malformed.cities_by_id)[&"redcliff_city"].defender_count = -9
	var malformed_probe: WarLoopState = WAR_LOOP_STATE.new()
	_check(not malformed_probe.restore_snapshot(malformed), "嵌套战争快照的负守军数据会被恢复校验拒绝")
	var registry := ArmyRegistry.new()
	var formations: Array = [
		{"formation_id": &"left", "definition_id": &"infantry", "display_name": "左队", "member_count": 7, "max_members": 7},
		{"formation_id": &"right", "definition_id": &"infantry", "display_name": "右队", "member_count": 7, "max_members": 7},
	]
	var outbound_segments: Array = [
		{"road_id": &"road.test.first", "forward": true},
		{"road_id": &"road.test.second", "forward": false},
	]
	var macro_army := registry.create_macro_march(&"player", &"blackstone_city", &"northwatch_garrison", &"redcliff_city", &"path.road.test.first:f|road.test.second:r", [Vector2i.ZERO, Vector2i.ONE], {&"infantry": 14}, formations, 1, 100, outbound_segments)
	var macro_order: Dictionary = macro_army.macro_march
	registry.advance_macro_march(StringName(macro_army.army_id), StringName(macro_order.order_id), 0, 100)
	registry.begin_macro_siege(StringName(macro_army.army_id), StringName(macro_order.order_id))
	var survivors := registry.replace_macro_composition(StringName(macro_army.army_id), StringName(macro_order.order_id), 7)
	var survivor_formations: Array = Array(Dictionary(survivors.macro_march).formation_snapshots)
	var retreating := registry.begin_macro_retreat(StringName(macro_army.army_id), StringName(macro_order.order_id))
	_check(int(Dictionary(survivor_formations[0]).member_count) == 7 and int(Dictionary(survivor_formations[1]).member_count) == 0, "两支各七人的编队伤亡写回保持原队列，不会回填为十四人与零人")
	var retreat_macro: Dictionary = Dictionary(retreating.macro_march)
	var retreat_segments: Array = Array(retreat_macro.get("route_segments", []))
	var blocked_retreat := registry.block_macro_march(
		StringName(retreating.army_id), StringName(retreat_macro.order_id), 0, 0, &"northwatch_garrison"
	)
	var resumed_retreat := registry.resume_blocked_macro_march(
		StringName(retreating.army_id), StringName(retreat_macro.order_id)
	)
	_check(
		StringName(retreat_macro.order_id) != StringName(macro_order.order_id)
			and Array(retreating.macro_order_history).size() == 1
			and StringName(Dictionary(Array(retreating.macro_order_history)[0]).order_id) == StringName(macro_order.order_id)
			and StringName(retreat_macro.route_id) == StringName(macro_order.route_id)
			and retreat_segments.size() == 2
			and StringName(Dictionary(retreat_segments[0]).get("road_id", &"")) == &"road.test.second"
			and bool(Dictionary(retreat_segments[0]).get("forward", true))
			and StringName(Dictionary(retreat_segments[1]).get("road_id", &"")) == &"road.test.first"
			and StringName(blocked_retreat.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED
			and StringName(resumed_retreat.get("phase", &"")) == ArmyRegistry.PHASE_RETREATING
			and StringName(Dictionary(resumed_retreat.get("macro_march", {})).get("phase", &"")) == ArmyRegistry.PHASE_RETREATING
			and not bool(Dictionary(retreat_segments[1]).get("forward", true)),
		"撤逃创建独立返程军令，反转同一路网段和方向并保留原攻城军令"
	)


func _run_formal_retreat_route_contract() -> void:
	var context := await _new_city()
	var city: Node = context.city
	city.set_process(false)
	city.food = 160
	var roster: Array[Dictionary] = city.get_formation_roster()
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var first_leg: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points))
	var first_army: Dictionary = Dictionary(first_leg.get("army", {}))
	var first_macro: Dictionary = Dictionary(first_army.get("macro_march", {}))
	city.advance_macro_march_time(StringName(first_army.get("army_id", &"")), StringName(first_macro.get("order_id", &"")), 0, int(first_macro.get("total_millis", 0)))
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack_leg: Dictionary = city.commit_macro_march_from_station(StringName(first_army.get("army_id", &"")), &"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points))
	var attack_army: Dictionary = Dictionary(attack_leg.get("army", {}))
	var attack_macro: Dictionary = Dictionary(attack_army.get("macro_march", {}))
	city.advance_macro_march_time(StringName(attack_army.get("army_id", &"")), StringName(attack_macro.get("order_id", &"")), 0, int(attack_macro.get("total_millis", 0)))
	city.advance_war_loop_time(250)
	var retreat: Dictionary = city.request_macro_siege_retreat(&"redcliff_city")
	var retreat_army: Dictionary = Dictionary(retreat.get("army", {}))
	var retreat_macro: Dictionary = Dictionary(retreat_army.get("macro_march", {}))
	city._advance_all_macro_marches_seconds(float(int(retreat_macro.get("total_millis", 0))) / 1000.0)
	var returned: Dictionary = city._army_registry.get_army(StringName(retreat_army.get("army_id", &"")))
	_check(
		bool(first_leg.get("success", false)) and bool(attack_leg.get("success", false)) and bool(retreat.get("success", false))
			and StringName(retreat_macro.get("route_id", &"")) == StringName(attack_macro.get("route_id", &""))
			and StringName(returned.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED
			and StringName(returned.get("target_node_id", &"")) == &"northwatch_garrison",
		"正式攻城撤逃复用物理道路返回驻点，不会因伪造路线 ID 受阻"
	)
	await _drop(context.scene)


func _run_controller_time_probe() -> void:
	var first_context := await _new_city()
	var second_context := await _new_city()
	var first: Node = first_context.city
	var second: Node = second_context.city
	for city in [first, second]:
		var roster: Array[Dictionary] = city.get_formation_roster()
		var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
		var issued: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id), StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(route.route_id), Array(route.points))
		var army: Dictionary = issued.army
		var macro: Dictionary = army.macro_march
		city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, int(macro.total_millis))
		var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
		var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.army_id), &"redcliff_city", StringName(attack_route.route_id), Array(attack_route.points))
		var attack_macro: Dictionary = attack.army.macro_march
		city.advance_macro_march_time(StringName(attack.army.army_id), StringName(attack_macro.order_id), 0, int(attack_macro.total_millis))
	first.advance_war_loop_time(1000)
	for _index in range(100):
		second.advance_war_loop_time(10)
	var first_tick := int(Dictionary(first.get_macro_march_read_model().war_loop).active_siege.tick)
	var second_tick := int(Dictionary(second.get_macro_march_read_model().war_loop).active_siege.tick)
	_check(first_tick == second_tick and first_tick == 4, "同样经过一秒时，单次与一百次调用只按累计战斗间隔推进四次")
	await _drop(first_context.scene)
	await _drop(second_context.scene)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	return {"scene": scene, "city": city}


func _drop(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("WAR_LOOP_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error("WAR_LOOP_R1_SMOKE FAIL: %s" % failure)
		quit(1)

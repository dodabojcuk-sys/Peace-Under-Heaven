extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const WAR_LOOP_STATE = preload("res://scripts/war/war_loop_state.gd")
const WAR_LOOP_RULES: WarLoopRules = preload("res://resources/war/war_loop_r1_rules.tres")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var surrender_state: WarLoopState = WAR_LOOP_STATE.new()
	surrender_state.initialize_from_theater(THEATER.get_points())
	var surrender := surrender_state.begin_siege(&"army.test", &"macro.order.000001", &"silverford_city", 20, 100, 10, 0, 10000, WAR_LOOP_RULES)
	_check(StringName(surrender.phase) == WarLoopState.PHASE_OCCUPIED and StringName(surrender.resolution) == WarLoopState.RESOLUTION_SURRENDER, "数值配置满足比例时先行招降，不进入攻门流程")
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
	_check(bool(restored.get_macro_march_read_model().level_cleared), "单城胜利规则只在必占赤崖城军事控制权转为玩家后成立")
	_check(int(final_army.units_by_definition_id[restored.INFANTRY_ROLE.role_id]) < initial_count, "攻城伤亡同步回同一支宏观军队，不回填黑石城 roster")
	await _drop(restored_context.scene)
	var retreat_context := await _new_city()
	var retreat_city: Node = retreat_context.city
	var retreat_roster: Array[Dictionary] = retreat_city.get_formation_roster()
	var retreat_selected: Array[StringName] = [StringName(retreat_roster[0].formation_id), StringName(retreat_roster[1].formation_id)]
	var retreat_north: Dictionary = retreat_city.commit_macro_march_from_city(retreat_selected, &"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points))
	var retreat_north_army: Dictionary = retreat_north.army
	var retreat_north_macro: Dictionary = retreat_north_army.macro_march
	retreat_city.advance_macro_march_time(StringName(retreat_north_army.army_id), StringName(retreat_north_macro.order_id), 0, int(retreat_north_macro.total_millis))
	var retreat_attack: Dictionary = retreat_city.commit_macro_march_from_station(StringName(retreat_north_army.army_id), &"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points))
	var retreat_attack_army: Dictionary = retreat_attack.army
	var retreat_attack_macro: Dictionary = retreat_attack_army.macro_march
	retreat_city.advance_macro_march_time(StringName(retreat_attack_army.army_id), StringName(retreat_attack_macro.order_id), 0, int(retreat_attack_macro.total_millis))
	retreat_city.advance_war_loop_time(250)
	var retreat: Dictionary = retreat_city.request_macro_siege_retreat()
	var retreating: Dictionary = retreat_city.get_macro_march_army()
	var retreat_food := int(retreat_city.food)
	var retreat_arrival: Dictionary = retreat_city.advance_macro_march_time(StringName(retreating.army_id), StringName(retreating.macro_march.order_id), 0, int(retreating.macro_march.total_millis))
	_check(bool(retreat.success) and StringName(retreating.phase) == ArmyRegistry.PHASE_RETREATING and int(retreating.units_by_definition_id[retreat_city.INFANTRY_ROLE.role_id]) < initial_count and bool(retreat_arrival.arrived) and int(retreat_city.food) == retreat_food, "撤逃按伤亡回流同一军队，沿原路返回且不重复扣粮")
	await _drop(retreat_context.scene)
	var surrender_context := await _new_city()
	var surrender_city: Node = surrender_context.city
	var surrender_roster: Array[Dictionary] = surrender_city.get_formation_roster()
	var surrender_selected: Array[StringName] = [StringName(surrender_roster[0].formation_id), StringName(surrender_roster[1].formation_id)]
	var surrender_departure: Dictionary = surrender_city.commit_macro_march_from_city(surrender_selected, &"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points))
	var surrender_army: Dictionary = surrender_departure.army
	var surrender_macro: Dictionary = surrender_army.macro_march
	surrender_city.advance_macro_march_time(StringName(surrender_army.army_id), StringName(surrender_macro.order_id), 0, int(surrender_macro.total_millis))
	var to_reedbank: Dictionary = THEATER.get_route(&"road.northwatch.reedbank")
	var reedbank_order: Dictionary = surrender_city.commit_macro_march_from_station(StringName(surrender_army.army_id), &"reedbank_garrison", StringName(to_reedbank.route_id), Array(to_reedbank.points))
	var reedbank_army: Dictionary = reedbank_order.army
	var reedbank_macro: Dictionary = reedbank_army.macro_march
	surrender_city.advance_macro_march_time(StringName(reedbank_army.army_id), StringName(reedbank_macro.order_id), 0, int(reedbank_macro.total_millis))
	var to_silverford: Dictionary = THEATER.get_route(&"road.reedbank.silverford")
	var silverford_order: Dictionary = surrender_city.commit_macro_march_from_station(StringName(surrender_army.army_id), &"silverford_city", StringName(to_silverford.route_id), Array(to_silverford.points))
	var silverford_army: Dictionary = silverford_order.army
	var silverford_macro: Dictionary = silverford_army.macro_march
	var silverford_arrival: Dictionary = surrender_city.advance_macro_march_time(StringName(silverford_army.army_id), StringName(silverford_macro.order_id), 0, int(silverford_macro.total_millis))
	var silverford_state: Dictionary = Dictionary(Dictionary(surrender_city.get_macro_march_read_model().war_loop).get("cities_by_id", {})).get(&"silverford_city", {})
	_check(bool(silverford_arrival.success) and StringName(surrender_city.get_macro_march_army().phase) == ArmyRegistry.PHASE_STATIONED and StringName(silverford_state.military_controller_faction_id) == &"player", "抵达可招降敌城后自动占领为驻兵点，不创建攻城 tick")
	await _drop(surrender_context.scene)
	_finish()


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

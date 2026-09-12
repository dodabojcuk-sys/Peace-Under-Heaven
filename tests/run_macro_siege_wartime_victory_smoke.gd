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
	var north: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(first_leg.route_id), Array(first_leg.points)
	)
	var army: Dictionary = north.get("army", {})
	var macro: Dictionary = army.get("macro_march", {})
	city.advance_macro_march_time(StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var attack_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.get("army_id", &"")), &"redcliff_city", StringName(attack_route.route_id), Array(attack_route.points))
	army = attack.get("army", {})
	macro = army.get("macro_march", {})
	city.advance_macro_march_time(StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var army_id := StringName(army.get("army_id", &""))
	_check(bool(north.get("success", false)) and bool(attack.get("success", false)), "正式路线建立原军队围城")
	_check(city.enter_macro_siege_wartime(army_id, &"redcliff_city"), "围城通过正式入口交给战时实例")
	await process_frame
	await process_frame
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(battle != null and battle.start_battle(false), "战时实例激活原军队而非新建部队")
	if battle == null:
		_finish(scene)
		return
	for squad in battle.coordinator.active_session.squads:
		_check(BattlefieldSpace.command(battle.coordinator.active_session, int(squad.squad_id), "ATTACK", [], &"FRONT_GATE").is_empty(), "通过空间进攻命令接近目标城门")
	var result: BattleResult = battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	_check(result != null and result.outcome == BattleOutcome.Value.VICTORY, "真实战斗刻达到围城胜利")
	if result != null:
		battle._show_pending_result(result)
	var summary := battle.confirm_pending_result()
	_check(not summary.is_empty(), "围城胜利只通过结果事务回写一次")
	var city_state: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).cities_by_id.get(&"redcliff_city", {})
	var resolved_army: Dictionary = city.get_army_state(army_id)
	_check(
		StringName(city_state.get("military_controller_faction_id", &"")) == &"player"
		and StringName(resolved_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"胜利更新一次目标控制权，原军队按规则驻扎"
	)
	var repeated := battle.confirm_pending_result()
	_check(
		repeated == summary
		and StringName(city.get_army_state(army_id).get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"重复确认只返回同一已提交战果，不重复占城或改变原军队"
	)
	_finish(scene)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish(scene: Node) -> void:
	scene.queue_free()
	if failures.is_empty():
		print("MACRO_SIEGE_WARTIME_VICTORY_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_SIEGE_WARTIME_VICTORY_SMOKE FAIL: %s" % failure)
	quit(1)

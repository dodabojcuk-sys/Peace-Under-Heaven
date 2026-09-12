extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id), StringName(roster[1].formation_id)],
		&"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points)
	)
	var army: Dictionary = issued.get("army", {})
	var macro: Dictionary = army.get("macro_march", {})
	var north: Dictionary = city.advance_macro_march_time(
		StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")),
		0, int(macro.get("total_millis", 0))
	)
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(
		StringName(Dictionary(north.get("army", {})).get("army_id", &"")),
		&"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points)
	)
	var attack_macro: Dictionary = Dictionary(attack.get("army", {})).get("macro_march", {})
	var arrival: Dictionary = city.advance_macro_march_time(
		StringName(Dictionary(attack.get("army", {})).get("army_id", &"")),
		StringName(attack_macro.get("order_id", &"")), 0,
		int(attack_macro.get("total_millis", 0))
	)
	_check(bool(arrival.get("success", false)), "正式城市入口可建立拒降攻城")
	city.set_process(true)
	_check(scene.open_macro_march_r0(), "正式城市入口可打开外城视图")
	await create_timer(0.8).timeout
	var tick_while_open := _active_tick(city)
	_check(tick_while_open >= 3, "外城视图保持打开时，权威攻城时钟持续推进")
	_check(scene.return_from_macro_march_r0(), "正式城市入口可返回城市视图")
	await create_timer(0.3).timeout
	_check(_active_tick(city) > tick_while_open, "返回城市视图后继续同一时钟，不重复或补打外城停留时间")
	city.set_city_time_paused(true)
	var paused_tick := _active_tick(city)
	await create_timer(0.3).timeout
	_check(_active_tick(city) == paused_tick, "只有全局暂停会停止外城攻城时钟")
	scene.queue_free()
	await process_frame
	await _run_closed_army_reissue_probe()
	await _run_frame_rate_probe()
	_finish()


func _run_closed_army_reissue_probe() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"northwatch_garrison",
		StringName(to_north.route_id), Array(to_north.points)
	)
	var army: Dictionary = issued.get("army", {})
	var macro: Dictionary = army.get("macro_march", {})
	city.advance_macro_march_time(StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	for attempt in range(7):
		var stationed: Dictionary = city.get_macro_march_army()
		var attack: Dictionary = city.commit_macro_march_from_station(
			StringName(stationed.get("army_id", &"")), &"redcliff_city",
			StringName(to_redcliff.route_id), Array(to_redcliff.points)
		)
		var attack_macro: Dictionary = Dictionary(attack.get("army", {})).get("macro_march", {})
		city.advance_macro_march_time(StringName(Dictionary(attack.get("army", {})).get("army_id", &"")), StringName(attack_macro.get("order_id", &"")), 0, int(attack_macro.get("total_millis", 0)))
		var retreat: Dictionary = city.request_macro_siege_retreat()
		if attempt < 6:
			var returning: Dictionary = retreat.get("army", {})
			var return_macro: Dictionary = returning.get("macro_march", {})
			city.advance_macro_march_time(StringName(returning.get("army_id", &"")), StringName(return_macro.get("order_id", &"")), 0, int(return_macro.get("total_millis", 0)))
	_check(city.get_macro_march_army().is_empty(), "全灭关闭军队不会被当作当前可指挥军令")
	var reissued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[1].formation_id)], &"northwatch_garrison",
		StringName(to_north.route_id), Array(to_north.points)
	)
	_check(bool(reissued.get("success", false)), "有其他驻军与粮食时，全灭后可从城市重新发令")
	scene.queue_free()
	await process_frame


func _run_frame_rate_probe() -> void:
	var thirty := await _new_formal_siege()
	var sixty := await _new_formal_siege()
	var irregular := await _new_formal_siege()
	for _index in range(30):
		thirty.city._process(1.0 / 30.0)
	for _index in range(60):
		sixty.city._process(1.0 / 60.0)
	for delta in [0.11, 0.07, 0.19, 0.03, 0.22, 0.38]:
		irregular.city._process(float(delta))
	var thirty_siege: Dictionary = Dictionary(thirty.city.get_macro_march_read_model().war_loop).active_siege
	var sixty_siege: Dictionary = Dictionary(sixty.city.get_macro_march_read_model().war_loop).active_siege
	var irregular_siege: Dictionary = Dictionary(irregular.city.get_macro_march_read_model().war_loop).active_siege
	_check(thirty_siege == sixty_siege and sixty_siege == irregular_siege, "正式 _process 的 30 帧、60 帧与不规则浮点拆分在同一秒得到相同攻城状态")
	var speed_context := await _new_formal_siege()
	speed_context.city.set_city_time_paused(true)
	speed_context.city._process(0.5)
	speed_context.city.set_city_time_paused(false)
	speed_context.city.set_city_time_speed(2.0)
	speed_context.city._process(0.5)
	_check(_active_tick(speed_context.city) == 4, "暂停不累积补打，2 倍速只对恢复后的半秒计算一次")
	for context in [thirty, sixty, irregular, speed_context]:
		context.scene.queue_free()
	await process_frame


func _new_formal_siege() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var to_north: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var issued: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id), StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(to_north.route_id), Array(to_north.points))
	var army: Dictionary = issued.get("army", {})
	var macro: Dictionary = army.get("macro_march", {})
	city.advance_macro_march_time(StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var to_redcliff: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var attack: Dictionary = city.commit_macro_march_from_station(StringName(army.get("army_id", &"")), &"redcliff_city", StringName(to_redcliff.route_id), Array(to_redcliff.points))
	var attack_macro: Dictionary = Dictionary(attack.get("army", {})).get("macro_march", {})
	city.advance_macro_march_time(StringName(Dictionary(attack.get("army", {})).get("army_id", &"")), StringName(attack_macro.get("order_id", &"")), 0, int(attack_macro.get("total_millis", 0)))
	return {"scene": scene, "city": city}


func _active_tick(city: Node) -> int:
	return int(Dictionary(city.get_macro_march_read_model().war_loop).active_siege.get("tick", 0))


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("WAR_LOOP_FORMAL_SCENE_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("WAR_LOOP_FORMAL_SCENE_SMOKE FAIL: %s" % failure)
	quit(1)

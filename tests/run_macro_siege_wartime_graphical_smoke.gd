extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var assertions := 0
var failures: Array[String] = []
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MACRO_SIEGE_WARTIME_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	THEATER.use_regression_definition_for_tests()
	evidence_directory = _argument_value("--txwzs-macro-siege-evidence-dir=")
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var city_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(city_scene)
	await _frames(3)
	var city: Node = city_scene.get_node("ConstructionController")
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
	var entered: bool = city.enter_macro_siege_wartime(army_id, &"redcliff_city")
	await _frames(3)
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "正式宏观围城入口创建可见的 C0 场景")
		_finish(city_scene)
		return
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var ram_button := plan_panel.get_node("RamButton") as Button
	var arrow_button := plan_panel.get_node("ArrowTowerButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var spike_trap_button := plan_panel.get_node("SpikeTrapButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	_capture("macro-siege-01-effectful-plan-engine-gui.png")
	_check(
		entered
			and plan_panel.visible
			and not watch_button.visible
			and ram_button.visible and not ram_button.disabled
			and arrow_button.visible and not arrow_button.disabled
			and not barricade_button.visible
			and not spike_trap_button.visible
			and confirm_button.visible and confirm_button.disabled,
		"可见宏观围城面板仅显示实际参与攻城的攻城槌和箭塔"
	)
	_check(
		not _action_controls_cover_battlefield(battle, [plan_panel]),
		"宏观围城工事面板位于独立操作区，不覆盖战斗路线"
	)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await _frames(2)
		_check(
			not _action_controls_cover_battlefield(battle, [plan_panel]),
			"%d×%d 下宏观围城工事面板不覆盖路线" % [viewport_size.x, viewport_size.y]
		)
	root.size = Vector2i(1152, 648)
	ram_button.emit_signal("pressed")
	arrow_button.emit_signal("pressed")
	await _frames(2)
	_capture("macro-siege-02-effectful-plan-selected-engine-gui.png")
	var wood_before := int(city.get("wood"))
	confirm_button.emit_signal("pressed")
	await _frames(2)
	_capture("macro-siege-03-construction-engine-gui.png")
	_check(
		Array(battle.request.wartime_facility_plan.get("facilities", [])).size() == 2
			and int(city.get("wood")) == wood_before - 18
			and battle.start_battle(),
		"正式按钮确认两项有效攻城工事，建设事务只扣一次木材并启动同一战斗"
	)
	battle.tick_timer.stop()
	var session := battle.coordinator.active_session
	var gate_before := int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("gate_hp", 0))
	for _tick in range(BattleSession.FACILITY_BUILD_TICKS[WartimeFacilityPlan.KIND_SIEGE_RAM]):
		(battle.get_node("TickTimer") as Timer).emit_signal("timeout")
	await _frames(2)
	_capture("macro-siege-04-effectful-complete-engine-gui.png")
	var gate_after := int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("gate_hp", 0))
	_check(
		gate_after == maxi(0, gate_before - BattleSession.SIEGE_RAM_GATE_DAMAGE),
		"完成后的攻城槌从可见战斗刻写入真实城门耐久"
	)
	print("MACRO_SIEGE_WARTIME_GUI_EVIDENCE ram_button_signal=true arrow_button_signal=true plan_confirm_signal=true")
	_finish(city_scene)


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var image := root.get_texture().get_image()
	if image.save_png(evidence_directory.path_join(filename)) != OK:
		failures.append("保存引擎 GUI 截图失败：%s" % filename)


func _action_controls_cover_battlefield(battle: C0BattleGraybox, controls: Array) -> bool:
	var battlefield := battle.get_node("UI/RootPanel/Battlefield") as Control
	if battlefield == null:
		return true
	var battlefield_rect := battlefield.get_global_rect()
	for control_value in controls:
		var control := control_value as Control
		if control != null and control.visible and battlefield_rect.intersects(control.get_global_rect()):
			return true
	return false


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
		return
	failures.append(description)
	push_error("MACRO_SIEGE_WARTIME_GRAPHICAL_SMOKE FAIL: %s" % description)


func _finish(city_scene: Node) -> void:
	city_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("MACRO_SIEGE_WARTIME_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	quit(1)

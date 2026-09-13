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
	_check(city_scene.open_macro_march_r0(), "玩家可从常态内城打开正式黑石战区")
	var macro_screen := city_scene.get_node("UI/MacroMarchR0") as MacroMarchR0
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
	macro_screen._selected_army_id = army_id
	macro_screen.refresh()
	await _frames(2)
	var siege_entry_button := macro_screen._siege_battle_button as Button
	var entry_visible := siege_entry_button.visible and not siege_entry_button.disabled
	siege_entry_button.emit_signal("pressed")
	var entered := entry_visible
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
	var squad_controls := battle.get_node("UI/RootPanel/SquadControls") as Control
	var selected_panel := battle.get_node("UI/RootPanel/SelectedSquadPanel") as Control
	var start_button := battle.get_node("UI/RootPanel/StartButton") as Button
	_capture("macro-siege-01-effectful-plan-engine-gui.png")
	_check(
		battle.title_label.text.contains("赤崖城攻城战")
			and battle.title_label.text.contains("我方攻城")
			and battle.status_label.text.contains(String(army_id))
			and battle.instruction_label.text.contains("胜利后原军队驻扎")
			and battle.front_route_name_label.text.contains("赤崖攻城道")
			and battle.side_route_name_label.text.contains("无外部军令")
			and battle.exit_button.text.contains("返回战区"),
		"宏观围城显示真实目标、攻城身份、原军队、外部道路来源和战区返回去向"
	)
	_check(
		entered
			and battle.request.phase == BattleRequest.PHASE_RESERVED
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
	_check(
		not _visible_controls_overlap([
			plan_panel, squad_controls, selected_panel, start_button,
		]),
		"宏观围城工事、小队选择、人数路线按钮、当前命令和开始按钮互不重叠"
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
	var second_squad_select := battle.get_node("UI/RootPanel/SquadControls/Squad2/SelectButton") as Button
	second_squad_select.emit_signal("pressed")
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
	# Spatial crews must first walk to their work positions. Advance through the
	# bounded travel plus build window, stopping on the first real gate strike.
	for _tick in range(360):
		if battle.spatial_view != null:
			battle.advance_spatial_frame(0.25)
		else:
			(battle.get_node("TickTimer") as Timer).emit_signal("timeout")
		await _frames(1)
		if int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("gate_hp", 0)) < gate_before:
			break
	await _frames(2)
	_capture("macro-siege-04-effectful-complete-engine-gui.png")
	var gate_after := int(session.get_route_state(CommittedForceSnapshot.FRONT_ROUTE).get("gate_hp", 0))
	var facility_records: Array = Array(session.wartime_facility_state.get("facilities", []))
	var ram_record: Dictionary = Dictionary(facility_records[0])
	var arrow_record: Dictionary = Dictionary(facility_records[1])
	_check(
		int(ram_record.get("progress_ticks", 0)) > 0
			and StringName(ram_record.get("phase", &"")) in [
				BattleSession.FACILITY_PHASE_ACTIVE,
				BattleSession.FACILITY_PHASE_DAMAGED,
				BattleSession.FACILITY_PHASE_DESTROYED,
			]
			and StringName(arrow_record.get("phase", &"")) == BattleSession.FACILITY_PHASE_ACTIVE
			and gate_after <= gate_before,
		"可见战斗刻真实推进攻城工事；箭塔完工，暴露的攻城槌可被摧毁且不会伪造城门伤害"
	)
	for squad_value in battle.request.committed_force.squads:
		var squad_id := int(Dictionary(squad_value).get("squad_id", 0))
		var select_button := battle.get_node(
			"UI/RootPanel/SquadControls/Squad%d/SelectButton" % squad_id
		) as Button
		select_button.emit_signal("pressed")
		battle.selected_advance_button.emit_signal("pressed")
	var battle_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		battle_result = battle.step_battle_for_test(1)
		if battle_result != null:
			break
	_check(
		battle_result != null and battle_result.outcome == BattleOutcome.Value.VICTORY,
		"原军队经可见小队选择和推进命令完成同一场赤崖攻城"
	)
	if battle_result == null:
		_finish(city_scene)
		return
	_capture("macro-siege-05-victory-pending-engine-gui.png")
	var summary := battle.confirm_pending_result()
	await _frames(2)
	_capture("macro-siege-06-victory-confirmed-engine-gui.png")
	_check(
		not summary.is_empty()
			and battle.return_button.text == "返回黑石战区"
			and battle.result_label.text.contains("原军队已驻扎赤崖城")
			and battle.result_label.text.contains("本战 %d = 存活 %d + 新伤 %d + 新亡 %d" % [
				int(summary.get("committed_count", 0)), int(summary.get("survivor_count", 0)),
				int(summary.get("wounded_added", 0)), int(summary.get("fallen_added", 0)),
			])
			and battle.result_label.text.contains("军籍 20 + 新增 0"),
		"胜利结算说明本战损失、完整军籍去向、目标控制变化和正确返回位置"
	)
	battle.return_button.emit_signal("pressed")
	await _frames(4)
	_capture("macro-siege-07-returned-war-zone-engine-gui.png")
	var redcliff: Dictionary = Dictionary(
		Dictionary(city.get_macro_march_read_model().get("war_loop", {})).get(
			"cities_by_id", {}
		)
	).get(&"redcliff_city", {})
	_check(
		city_scene.is_macro_march_r0_open()
			and macro_screen.visible
			and StringName(redcliff.get("military_controller_faction_id", &"")) == &"player"
			and StringName(city.get_army_state(army_id).get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"确认后回到仍可操作的黑石战区，赤崖控制权和同一原军驻扎均已写回"
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


func _visible_controls_overlap(controls: Array) -> bool:
	for left_index in range(controls.size()):
		var left := controls[left_index] as Control
		if left == null or not left.visible:
			continue
		for right_index in range(left_index + 1, controls.size()):
			var right := controls[right_index] as Control
			if right != null and right.visible and left.get_global_rect().intersects(right.get_global_rect()):
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

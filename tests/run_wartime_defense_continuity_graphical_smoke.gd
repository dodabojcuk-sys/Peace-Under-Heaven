extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var assertions := 0
var failures: Array[String] = []
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WARTIME_DEFENSE_CONTINUITY_GRAPHICAL_SMOKE requires graphical Godot")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-wartime-defense-continuity-evidence-dir=")
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var city_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(city_scene)
	await _frames(3)
	var city: Node = city_scene.get_node("ConstructionController")
	var selection: Node = city_scene.get_node("BuildingSelectionController")
	var city_gate_id := _placement_id_for_template(city, &"city_gate")
	selection.select_placement(city_gate_id)
	await _frames(2)
	var gate_actions := city_scene.get_node(
		"UI/Shell/BuildingDetailPanel/CityGateActions"
	) as Control
	var defense_button := gate_actions.get_node("EnterWartimeDefenseButton") as Button
	_capture("wartime-defense-continuity-01-city-gate-entry.png")
	_check(
		city_gate_id >= 0
			and gate_actions.visible
			and defense_button.visible
			and not defense_button.disabled,
		"玩家选择常态内城城门后获得正式守城入口"
	)
	var food_before := int(city.get("food"))
	defense_button.emit_signal("pressed")
	await _frames(4)
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "城门按钮创建守城 C0 场景")
		_finish(city_scene)
		return
	_check(
		battle.title_label.text == "黑石城门防守"
			and int(city.get("food")) == food_before
			and battle.status_label.text.contains("黑石守军")
			and battle.instruction_label.text.contains("消灭全部来袭敌军"),
		"正式入口沿用真实守军且不创建第二次出征粮食事务"
	)
	# Keep one real squad on the north-gate work while the remaining formations
	# clear the east approach. This is a player-visible deployment choice, not a
	# direct rewrite of the frozen request.
	for squad_value in battle.request.committed_force.squads:
		var squad: Variant = squad_value
		var target_route := (
			CommittedForceSnapshot.FRONT_ROUTE
			if int(squad.squad_id) <= 2
			else CommittedForceSnapshot.SIDE_ROUTE
		)
		if StringName(squad.route_id) != target_route:
			var route_button := battle.get_node(
				"UI/RootPanel/SquadControls/Squad%d/RouteButton" % squad.squad_id
			) as Button
			route_button.emit_signal("pressed")
			await _frames(1)
	var north_work_squad_button := battle.get_node(
		"UI/RootPanel/SquadControls/Squad1/SelectButton"
	) as Button
	north_work_squad_button.emit_signal("pressed")
	await _frames(1)

	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var arrow_button := plan_panel.get_node("ArrowTowerButton") as Button
	var confirm_plan_button := plan_panel.get_node("ConfirmButton") as Button
	barricade_button.emit_signal("pressed")
	var east_tower_squad_button := battle.get_node(
		"UI/RootPanel/SquadControls/Squad3/SelectButton"
	) as Button
	east_tower_squad_button.emit_signal("pressed")
	await _frames(1)
	arrow_button.emit_signal("pressed")
	await _frames(2)
	_capture("wartime-defense-continuity-02-defense-plan.png")
	confirm_plan_button.emit_signal("pressed")
	await _frames(2)
	var start_button := battle.get_node("UI/RootPanel/StartButton") as Button
	_check(
		not Array(battle.request.wartime_facility_plan.get("facilities", [])).is_empty()
			and start_button.visible
			and not start_button.disabled,
		"两路守城专用拒马与箭塔进入同一冻结请求后允许开战"
	)
	start_button.emit_signal("pressed")
	await _frames(2)
	battle.tick_timer.stop()

	var session: BattleSession = battle.coordinator.active_session
	for early_squad_id in [3]:
		if early_squad_id > battle.request.committed_force.squads.size():
			continue
		var early_select_button := battle.get_node(
			"UI/RootPanel/SquadControls/Squad%d/SelectButton" % early_squad_id
		) as Button
		early_select_button.emit_signal("pressed")
		await _frames(1)
		var early_advance_button := battle.get_node(
			"UI/RootPanel/SelectedSquadPanel/AdvanceButton"
		) as Button
		early_advance_button.emit_signal("pressed")
		await _frames(1)
	var damaged_facility: Dictionary = {}
	var terminal_result: BattleResult
	for _tick in range(220):
		terminal_result = battle.step_battle_for_test(1)
		battle._refresh_battle_ui()
		if terminal_result != null:
			break
		for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
			var record := Dictionary(record_value)
			if StringName(record.get("phase", &"")) == BattleSession.FACILITY_PHASE_DAMAGED:
				damaged_facility = record
				break
		if not damaged_facility.is_empty():
			break
	await _frames(2)
	_capture("wartime-defense-continuity-03-facility-damaged.png")
	_check(
		terminal_result == null and not damaged_facility.is_empty(),
		"敌军自然推进并实际打伤本场临时工事，城门尚未产生终局"
	)

	# Commit the visible response before the next battle tick: the route's real
	# squad repairs its own temporary work while every formation advances.
	for squad_value in battle.request.committed_force.squads:
		var squad: Variant = squad_value
		var select_button := battle.get_node(
			"UI/RootPanel/SquadControls/Squad%d/SelectButton" % squad.squad_id
		) as Button
		select_button.emit_signal("pressed")
		await _frames(1)
		var advance_button := battle.get_node(
			"UI/RootPanel/SelectedSquadPanel/AdvanceButton"
		) as Button
		advance_button.emit_signal("pressed")
		await _frames(1)
	var repair_squad_id := int(damaged_facility.get("construction_squad_id", 0))
	if repair_squad_id > 0:
		var repair_select_button := battle.get_node(
			"UI/RootPanel/SquadControls/Squad%d/SelectButton" % repair_squad_id
		) as Button
		repair_select_button.emit_signal("pressed")
		await _frames(1)
	var repair_button := battle.get_node("UI/RootPanel/WartimeRepairButton") as Button
	var repair_available := repair_button.visible and not repair_button.disabled
	if repair_available:
		repair_button.emit_signal("pressed")
	var gate_repair_button := battle.get_node(
		"UI/RootPanel/WartimeGateRepairButton"
	) as Button
	var gate_repair_available := gate_repair_button.visible and not gate_repair_button.disabled
	if gate_repair_available:
		gate_repair_button.emit_signal("pressed")
	await _frames(2)
	_capture("wartime-defense-continuity-04-repair-and-advance.png")
	_check(
		repair_available
			and battle.recent_actions_label.text.contains("维修")
			and Array(session.get_wartime_facility_state().get("facilities", [])).any(
				func(record: Variant) -> bool: return StringName(Dictionary(record).get("phase", &"")) == BattleSession.FACILITY_PHASE_REPAIRING
			)
			and battle.request.committed_force.squads.any(
				func(squad: Variant) -> bool: return int(squad.squad_id) != repair_squad_id and int(session.get_squad_state(squad.squad_id).active_order) == BattleOrder.Command.ADVANCE
			),
		"玩家用可见按钮派真实小队维修并向两路来敌推进"
	)
	# Repair work deliberately holds its crew. Once the production repair clock
	# completes, the player explicitly sends that same squad forward again.
	battle.step_battle_for_test(BattleSession.FACILITY_REPAIR_TICKS)
	battle._refresh_battle_ui()
	var repaired_squad_button := battle.get_node(
		"UI/RootPanel/SquadControls/Squad%d/SelectButton" % repair_squad_id
	) as Button
	repaired_squad_button.emit_signal("pressed")
	await _frames(1)
	var repaired_squad_advance := battle.get_node(
		"UI/RootPanel/SelectedSquadPanel/AdvanceButton"
	) as Button
	repaired_squad_advance.emit_signal("pressed")
	await _frames(1)

	if terminal_result == null:
		terminal_result = battle.step_battle_for_test(320)
	battle._refresh_battle_ui()
	await _frames(3)
	_capture("wartime-defense-continuity-05-victory-pending.png")
	_check(
		terminal_result != null
			and terminal_result.outcome == BattleOutcome.Value.VICTORY
			and battle.result_panel.visible
			and battle.result_label.text.contains("写回黑石城"),
		"真实战斗刻清除来敌后显示守城胜利及返回黑石城去向"
	)

	var confirm_result_button := battle.get_node(
		"UI/RootPanel/ResultPanel/Margin/Content/Actions/ConfirmButton"
	) as Button
	confirm_result_button.emit_signal("pressed")
	await _frames(3)
	var return_button := battle.get_node(
		"UI/RootPanel/ResultPanel/Margin/Content/Actions/ReturnButton"
	) as Button
	_capture("wartime-defense-continuity-06-victory-confirmed.png")
	_check(
		return_button.visible
			and return_button.text == "返回黑石城"
			and battle.result_label.text.contains("黑石城门守住"),
		"确认战果后说明城门状态并只提供返回黑石城操作"
	)
	return_button.emit_signal("pressed")
	await _frames(5)
	_capture("wartime-defense-continuity-07-returned-city.png")
	_check(
		city.get_formal_battle_scene() == null
			and not bool(city.get("city_fallen"))
			and city.get_city_defense() > 0
			and city_scene.get_node("UI/Shell").visible,
		"守城胜利写回同一城市状态并恢复常态内城界面"
	)
	_finish(city_scene)


func _placement_id_for_template(city: Node, template_id: StringName) -> int:
	for placement_id_value in city.get_placement_ids():
		var placement_id := int(placement_id_value)
		var record: Dictionary = city.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == template_id:
			return placement_id
	return -1


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var image := root.get_texture().get_image()
	if image.save_png(evidence_directory.path_join(filename)) != OK:
		failures.append("保存引擎 GUI 截图失败：%s" % filename)


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
	push_error("WARTIME_DEFENSE_CONTINUITY_GRAPHICAL_SMOKE FAIL: %s" % description)


func _finish(city_scene: Node) -> void:
	city_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("WARTIME_DEFENSE_CONTINUITY_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	quit(1)

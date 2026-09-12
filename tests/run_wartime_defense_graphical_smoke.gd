extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var assertions := 0
var failures: Array[String] = []
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WARTIME_DEFENSE_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-wartime-defense-evidence-dir=")
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var city_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(city_scene)
	await _frames(3)
	var city: Node = city_scene.get_node("ConstructionController")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_id := StringName(roster[0].get("formation_id", &"")) if not roster.is_empty() else &""
	var started: Dictionary = city.begin_wartime_defense_attempt([formation_id])
	var entered: bool = bool(started.get("success", false)) and city.enter_wartime_defense_battle()
	await _frames(3)
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "正式黑石城门入口创建可见的守城 C0 场景")
		_finish(city_scene)
		return
	var route_button := battle.get_node(
		"UI/RootPanel/SquadControls/Squad1/RouteButton"
	) as Button
	route_button.emit_signal("pressed")
	await _frames(2)
	var plan_panel := battle.get_node("UI/RootPanel/WartimePlanPanel") as Panel
	var watch_button := plan_panel.get_node("WatchButton") as Button
	var arrow_button := plan_panel.get_node("ArrowTowerButton") as Button
	var barricade_button := plan_panel.get_node("BarricadeButton") as Button
	var spike_trap_button := plan_panel.get_node("SpikeTrapButton") as Button
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	var squad_controls := battle.get_node("UI/RootPanel/SquadControls") as Control
	var selected_panel := battle.get_node("UI/RootPanel/SelectedSquadPanel") as Control
	var start_button := battle.get_node("UI/RootPanel/StartButton") as Button
	watch_button.emit_signal("pressed")
	arrow_button.emit_signal("pressed")
	barricade_button.emit_signal("pressed")
	spike_trap_button.emit_signal("pressed")
	await _frames(2)
	_capture("wartime-defense-01-plan-engine-gui.png")
	_check(
		entered
		and plan_panel.visible
		and confirm_button.visible
		and not confirm_button.disabled
		and spike_trap_button.visible
		and spike_trap_button.text.contains("已选")
		and str(plan_panel.get_node("Title").text).contains("东门壕沟"),
		"可见守城工事面板经正式按钮选择侧翼瞭望台、箭塔和拒马"
	)
	_check(
		battle.title_label.text == "黑石城门防守"
			and battle.status_label.text.contains("黑石守军")
			and battle.status_label.text.contains("保护黑石城门")
			and battle.instruction_label.text.contains("消灭全部来袭敌军")
			and battle.direction_label.text.contains("敌军由北门与东门方向推进")
			and battle.exit_button.text == "守城已确认",
		"正式守城显示被保护地点、守军身份、敌军推进方向、保护目标和正确返回语义"
	)
	_check(
		not _action_controls_cover_battlefield(battle, [plan_panel]),
		"战前工事计划位于独立操作区，不覆盖可见路线"
	)
	_check(
		not _visible_controls_overlap([
			plan_panel, squad_controls, selected_panel, start_button,
		]),
		"守城工事、小队选择、人数路线按钮、当前命令和开始按钮互不重叠"
	)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await _frames(2)
		_check(
			not _action_controls_cover_battlefield(battle, [plan_panel]),
			"%d×%d 下战前工事计划仍不覆盖路线" % [viewport_size.x, viewport_size.y]
		)
	root.size = Vector2i(1152, 648)
	await _frames(2)
	confirm_button.emit_signal("pressed")
	await _frames(2)
	_capture("wartime-defense-02-construction-engine-gui.png")
	_check(
		not Array(battle.request.wartime_facility_plan.get("facilities", [])).is_empty()
		and battle.start_battle(),
		"正式确认后的同一守城请求进入施工中战斗状态"
	)
	battle.tick_timer.stop()
	var session := battle.coordinator.active_session
	## The production gate falls quickly. This isolated graphical fixture raises
	## only its in-memory target capacity so the real route arrival can expose
	## the repair control without prematurely ending the evidence scene.
	session.mission_objective_state.protect_target_hp = 10000
	session.mission_objective_state.protect_target_max_hp = 10000
	## The visible plan and confirmation above are the normal C0 flow. For this
	## focused graphical fixture, advance the invader to that route's real
	## objective immediately before its first attack interval. This exposes the
	## production construction-interruption transition without asking the
	## capture to wait through an otherwise uninformative approach march.
	var selected_route_id := StringName(
		battle.request.committed_force.squads[0].route_id
	)
	var interrupted_route: Dictionary = session.get_route_state(selected_route_id)
	interrupted_route.enemy_position_fixed = int(interrupted_route.get("distance_fixed", 0))
	session.routes[selected_route_id] = interrupted_route
	session.current_tick = BattleSession.ATTACK_INTERVAL_TICKS - 1
	battle.step_battle_for_test(1)
	battle._refresh_battle_ui()
	await _frames(1)
	_capture("wartime-defense-03b-construction-interrupted-engine-gui.png")
	var interrupted_barricade := _facility_by_kind(
		session, WartimeFacilityPlan.KIND_BARRICADE
	)
	var interruption_projection: Dictionary = session.get_wartime_facility_state()
	_check(
		StringName(interrupted_barricade.get("phase", &""))
			== BattleSession.FACILITY_PHASE_INTERRUPTED
		and not interruption_projection.has("barricade_route_id"),
		"可见战斗刻在敌军先于施工完工抵达时中断拒马，未完成设施不提供阻挡投影"
	)
	var facility_repair_button := battle.get_node(
		"UI/RootPanel/WartimeRepairButton"
	) as Button
	var facility_repair_was_available := (
		facility_repair_button.visible and not facility_repair_button.disabled
	)
	facility_repair_button.emit_signal("pressed")
	await _frames(2)
	battle._refresh_battle_ui()
	await _frames(1)
	_capture("wartime-defense-03d-facility-repair-crew-engine-gui.png")
	var repairing_barricade := _facility_by_kind(
		session, WartimeFacilityPlan.KIND_BARRICADE
	)
	var expected_repair_crew := str(battle.request.committed_force.squads[0].display_name)
	_check(
		facility_repair_was_available
		and StringName(repairing_barricade.get("phase", &""))
			== BattleSession.FACILITY_PHASE_REPAIRING
		and int(repairing_barricade.get("construction_squad_id", 0))
			== int(battle.request.committed_force.squads[0].squad_id)
		and battle.recent_actions_label.text.contains(expected_repair_crew),
		"正式维修按钮显示并保存玩家当前选中编队作为维修分队"
	)
	_check(
		not _action_controls_cover_battlefield(
			battle,
			[
				facility_repair_button,
				battle.get_node("UI/RootPanel/WartimeFacilityStatusLabel") as Label,
			]
		),
		"施工中断后的工事状态和维修入口不覆盖侧门路线"
	)
	## The trap finishes on the next normal tick while that same invader is still
	## at the endpoint, so this capture proves a real route-arrival trigger
	## rather than a manually decremented enemy counter.
	battle.step_battle_for_test(1)
	battle._refresh_battle_ui()
	await _frames(1)
	_capture("wartime-defense-03c-spike-trap-triggered-engine-gui.png")
	var triggered_trap := _facility_by_kind(
		session, WartimeFacilityPlan.KIND_SPIKE_TRAP
	)
	var trap_triggered := false
	for event_value in session.get_last_tick_facility_events():
		var facility_event: Dictionary = Dictionary(event_value)
		if StringName(facility_event.get("event", &"")) == &"TRAP_TRIGGERED":
			trap_triggered = true
			break
	_check(
		StringName(triggered_trap.get("phase", &"")) == BattleSession.FACILITY_PHASE_DESTROYED
		and trap_triggered,
		"可见战斗刻在完工刺钉陷阱处产生一次路线伤害并耗尽同一工事记录"
	)
	## Return the invader to the beginning only after recording the interrupted
	## state, so the following gate-repair evidence remains a readable scene.
	interrupted_route = session.get_route_state(selected_route_id)
	interrupted_route.enemy_position_fixed = 0
	session.routes[selected_route_id] = interrupted_route
	battle.step_battle_for_test(168)
	battle._refresh_battle_ui()
	await _frames(1)
	_capture("wartime-defense-03-damaged-gate-engine-gui.png")
	var repair_button := battle.get_node(
		"UI/RootPanel/WartimeGateRepairButton"
	) as Button
	var hp_before := int(session.get_mission_objective_state().get("protect_target_hp", 0))
	repair_button.emit_signal("pressed")
	await _frames(2)
	battle._refresh_battle_ui()
	await _frames(1)
	_capture("wartime-defense-04-gate-repair-engine-gui.png")
	var repair_state := session.get_mission_objective_state()
	_check(
		repair_button.visible
		and StringName(repair_state.get("protect_target_repair_phase", &""))
			== BattleSession.PROTECT_TARGET_REPAIRING
		and int(repair_state.get("protect_target_hp", 0)) == hp_before
		and repair_button.text.contains("维修中"),
		"受损城门的可见正式按钮只启动保存中的维修工期，不提前恢复城防"
	)
	_check(
		not _action_controls_cover_battlefield(
			battle,
			[
				repair_button,
				battle.get_node("UI/RootPanel/WartimeFacilityStatusLabel") as Label,
				battle.get_node("UI/RootPanel/WartimeRepairButton") as Button,
			]
		),
		"城门维修期间的状态和操作保持在路线画面之外"
	)
	battle.step_battle_for_test(BattleSession.PROTECT_TARGET_REPAIR_TICKS)
	battle._refresh_battle_ui()
	await _frames(1)
	_capture("wartime-defense-05-gate-repaired-engine-gui.png")
	var repaired := session.get_mission_objective_state()
	_check(
		StringName(repaired.get("protect_target_repair_phase", &""))
			== BattleSession.PROTECT_TARGET_REPAIR_IDLE
		and int(repaired.get("protect_target_hp", 0)) > hp_before,
		"真实战斗刻完成城门维修并仅恢复本场防线目标"
	)
	print("WARTIME_DEFENSE_GUI_EVIDENCE route_button_signal=true plan_button_signal=true gate_repair_button_signal=true")
	_finish(city_scene)


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


func _facility_by_kind(session: BattleSession, kind: StringName) -> Dictionary:
	for record_value in Array(session.get_wartime_facility_state().get("facilities", [])):
		var record: Dictionary = Dictionary(record_value)
		if StringName(record.get("kind", &"")) == kind:
			return record
	return {}


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


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
		return
	failures.append(description)
	push_error("WARTIME_DEFENSE_GRAPHICAL_SMOKE FAIL: %s" % description)


func _finish(city_scene: Node) -> void:
	city_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("WARTIME_DEFENSE_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	quit(1)

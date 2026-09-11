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
	var confirm_button := plan_panel.get_node("ConfirmButton") as Button
	watch_button.emit_signal("pressed")
	arrow_button.emit_signal("pressed")
	barricade_button.emit_signal("pressed")
	await _frames(2)
	_capture("wartime-defense-01-plan-engine-gui.png")
	_check(
		entered
		and plan_panel.visible
		and confirm_button.visible
		and not confirm_button.disabled
		and str(plan_panel.get_node("Title").text).contains("东门壕沟"),
		"可见守城工事面板经正式按钮选择侧翼瞭望台、箭塔和拒马"
	)
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

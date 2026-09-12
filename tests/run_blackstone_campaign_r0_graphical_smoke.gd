extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("BLACKSTONE_CAMPAIGN_R0_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-blackstone-campaign-evidence-dir=")
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(3)
	var city: Node = scene.get_node("ConstructionController")
	# This runner owns an in-memory, isolated campaign. Each simulated 100 ms is
	# consumed by ConstructionController._process, the same world-time entry used
	# by the visible scene; it is accelerated test pacing, not a player recording.
	city.set_process(false)
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	city.food = 80
	city._war_loop_state.field_tactics.patrols_by_id.clear()
	scene.open_macro_march_r0()
	await _frames(3)
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro._camera_center = Vector2(520, 590)
	macro._camera_zoom = 0.56
	macro.refresh()
	_capture("campaign-01-overview-engine-gui.png")

	# The isolated graphical fixture creates the engineer through the authority
	# entry; map clicks and all planning/confirmation states below remain GUI
	# evidence. The full playthrough runner separately covers UI dispatch.
	var engineer_result: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_result.get("specialist", {})).get("specialist_id", &""))
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	macro._side_road_button.pressed.emit()
	await _frames(2)
	var camp_points: Array = [Vector2(135, 650), Vector2(310, 640), Vector2(500, 620)]
	var camp_draft := await _draw_engineering(macro, camp_points)
	print("BLACKSTONE_CAMPAIGN_R0_GUI_TRACE camp engineer=%s valid=%s confirm=%s/%s status=%s" % [String(engineer_id), str(bool(camp_draft.get("valid", false))), str(macro._confirm_button.visible), str(macro._confirm_button.disabled), macro._status_label.text])
	var camp_preview_visible := bool(camp_draft.get("valid", false)) \
		and bool(camp_draft.get("build_camp", false)) \
		and macro._confirm_button.is_inside_tree() and macro._confirm_button.visible and not macro._confirm_button.disabled
	_capture("campaign-02-camp-plan-engine-gui.png")
	var camp_project := await _confirm_project(macro, city, engineer_id)
	await _advance_project_with_controller_frames(city, macro, StringName(camp_project.get("project_id", &"")), 12)
	_capture("campaign-03-camp-construction-engine-gui.png")
	var camp_complete := await _advance_project_with_controller_frames(city, macro, StringName(camp_project.get("project_id", &"")), 90)
	var completed_camp := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(StringName(camp_project.get("project_id", &"")), {}))
	var camp_id := StringName(completed_camp.get("camp_id", &""))
	var camp := Dictionary(city._war_loop_state.field_tactics.camps_by_id.get(camp_id, {}))
	_capture("campaign-04-camp-complete-engine-gui.png")

	# The second formal plan crosses water. Its completed physical segments are
	# the same roads that the full campaign regression later marches across.
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	macro._side_road_button.pressed.emit()
	await _frames(2)
	var link_points: Array = [
		Vector2(camp.get("world_position", Vector2.ZERO)), Vector2(560, 620),
		Vector2(660, 610), Vector2(THEATER.get_point(&"forest_garrison").get("world_position", Vector2.ZERO)),
	]
	var bridge_draft := await _draw_engineering(macro, link_points)
	print("BLACKSTONE_CAMPAIGN_R0_GUI_TRACE bridge camp=%s valid=%s confirm=%s/%s status=%s" % [String(camp_id), str(bool(bridge_draft.get("valid", false))), str(macro._confirm_button.visible), str(macro._confirm_button.disabled), macro._status_label.text])
	var bridge_preview_visible := bool(bridge_draft.get("valid", false)) \
		and bool(bridge_draft.get("contains_bridge", false)) \
		and macro._confirm_button.visible and not macro._confirm_button.disabled
	_capture("campaign-05-bridge-plan-engine-gui.png")
	var bridge_project := await _confirm_project(macro, city, engineer_id)
	await _advance_project_with_controller_frames(city, macro, StringName(bridge_project.get("project_id", &"")), 30)
	_capture("campaign-06-bridge-construction-engine-gui.png")
	var bridge_complete := await _advance_project_with_controller_frames(city, macro, StringName(bridge_project.get("project_id", &"")), 280)
	_capture("campaign-07-bridge-complete-engine-gui.png")

	# This is the player-visible valid A -> invalid B -> valid A sequence. The
	# invalid water click must clear the actionable plan before the final choice.
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	macro._watchtower_button.pressed.emit()
	await _frames(2)
	_click_map(macro, macro._world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO))))
	var valid_a := Vector2i(435, 620)
	_click_map(macro, macro._world_to_screen(Vector2(valid_a)))
	var first_tower_draft := macro._watchtower_draft.duplicate(true)
	_capture("campaign-08-tower-valid-a-engine-gui.png")
	var invalid_b := Vector2i(620, 620)
	_click_map(macro, macro._world_to_screen(Vector2(invalid_b)))
	var invalid_clears_draft := macro._watchtower_draft.is_empty() \
		and macro._watchtower_preview_position == Vector2(invalid_b) \
		and macro._confirm_button.disabled
	_capture("campaign-09-tower-invalid-b-engine-gui.png")
	_click_map(macro, macro._world_to_screen(Vector2(valid_a)))
	var replanned_tower_draft := macro._watchtower_draft.duplicate(true)
	var tower_confirm_visible := macro._confirm_button.visible and not macro._confirm_button.disabled
	_capture("campaign-10-tower-replanned-a-engine-gui.png")
	var tower_project := await _confirm_project(macro, city, engineer_id)
	print("BLACKSTONE_CAMPAIGN_R0_GUI_TRACE tower first=%s invalid=%s replanned=%s project=%s" % [str(not first_tower_draft.is_empty()), str(invalid_clears_draft), str(not replanned_tower_draft.is_empty()), str(not tower_project.is_empty())])
	await _advance_project_with_controller_frames(city, macro, StringName(tower_project.get("project_id", &"")), 10)
	_capture("campaign-11-tower-engineer-travel-engine-gui.png")
	var tower_complete := await _advance_project_with_controller_frames(city, macro, StringName(tower_project.get("project_id", &"")), 120)
	var towers: Dictionary = city.get_field_tactics_read_model().get("watchtowers_by_id", {})
	_capture("campaign-12-tower-complete-engine-gui.png")

	# The same persistent camp supports one facility of each explicit field kind.
	# These buttons do not create C0 facilities: their projects remain in the
	# field snapshot and consume the engineer's real travel/work time.
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	macro._arrow_tower_button.pressed.emit()
	await _frames(2)
	_click_map(macro, macro._world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO))))
	_click_map(macro, macro._world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO)) + Vector2(0, 60)))
	var arrow_draft := macro._watchtower_draft.duplicate(true)
	var arrow_project := await _confirm_project(macro, city, engineer_id)
	var arrow_complete := await _advance_project_with_controller_frames(city, macro, StringName(arrow_project.get("project_id", &"")), 160)
	_capture("campaign-13-field-arrow-tower-complete-engine-gui.png")
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	macro._barricade_button.pressed.emit()
	await _frames(2)
	_click_map(macro, macro._world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO))))
	_click_map(macro, macro._world_to_screen(Vector2(camp.get("world_position", Vector2.ZERO)) + Vector2(40, 80)))
	var barricade_draft := macro._watchtower_draft.duplicate(true)
	var barricade_project := await _confirm_project(macro, city, engineer_id)
	var barricade_complete := await _advance_project_with_controller_frames(city, macro, StringName(barricade_project.get("project_id", &"")), 140)
	var field_facilities: Dictionary = city.get_field_tactics_read_model().get("watchtowers_by_id", {})
	print("BLACKSTONE_CAMPAIGN_R0_DEFENSE_GUI_TRACE arrow_draft=%s arrow_project=%s/%s barricade_draft=%s barricade_project=%s/%s facilities=%d status=%s" % [str(not arrow_draft.is_empty()), str(not arrow_project.is_empty()), str(arrow_complete), str(not barricade_draft.is_empty()), str(not barricade_project.is_empty()), str(barricade_complete), field_facilities.size(), macro._status_label.text])
	_capture("campaign-14-field-defense-line-engine-gui.png")

	_check(camp_preview_visible and camp_complete and camp_id != &"", "正式 GUI 工程计划创建新驻点，并在 Controller 世界帧中经历施工至完工")
	_check(bridge_preview_visible and bridge_complete, "正式 GUI 跨河工程清楚显示桥段计划、施工中和已开放状态")
	_check(not first_tower_draft.is_empty() and invalid_clears_draft and not replanned_tower_draft.is_empty() and tower_confirm_visible and tower_complete and towers.size() == 1, "瞭望塔选址按合法 A、无效 B、重新合法 A 的顺序更新可见草稿与实际工程")
	_check(StringName(arrow_draft.get("facility_kind", &"")) == FieldTacticsState.FACILITY_ARROW_TOWER and arrow_complete and StringName(barricade_draft.get("facility_kind", &"")) == FieldTacticsState.FACILITY_BARRICADE and barricade_complete and field_facilities.size() == 3, "正式 GUI 分别选择并完成瞭望、外部火力与外部阻挡三类持久防线")
	print("BLACKSTONE_CAMPAIGN_R0_ENGINE_GUI_EVIDENCE pointer_input=true button_action_signal=true controller_frame_ms=100 camps=%d facilities=%d" % [city._war_loop_state.field_tactics.camps_by_id.size(), field_facilities.size()])
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("BLACKSTONE_CAMPAIGN_R0_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("BLACKSTONE_CAMPAIGN_R0_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _draw_engineering(macro: MacroMarchR0, points: Array) -> Dictionary:
	if points.size() < 2:
		return {}
	_frame_world_points(macro, points)
	_click_map(macro, macro._world_to_screen(Vector2(points.front())))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = macro._world_to_screen(Vector2(points.front()))
	macro._on_gui_input(press)
	var deadline := Time.get_ticks_msec() + ceili((MacroMarchR0.DRAW_HOLD_SECONDS + 0.35) * 1000.0)
	while Time.get_ticks_msec() <= deadline and not macro._is_drawing:
		await process_frame
	if not macro._is_drawing:
		return {}
	for point_value in points.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro._world_to_screen(Vector2(point_value))
		macro._on_gui_input(motion)
		await _frames(3)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = macro._world_to_screen(Vector2(points.back()))
	macro._on_gui_input(release)
	await _frames(2)
	macro.refresh()
	return macro._engineering_draft.duplicate(true)


func _confirm_project(macro: MacroMarchR0, city: Node, engineer_id: StringName) -> Dictionary:
	if not macro._confirm_button.is_inside_tree() or not macro._confirm_button.visible or macro._confirm_button.disabled:
		return {}
	macro._confirm_button.pressed.emit()
	await process_frame
	var specialists: Dictionary = city.get_field_tactics_read_model().get("specialists_by_id", {})
	var specialist := Dictionary(specialists.get(engineer_id, {}))
	return Dictionary(Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).get(StringName(specialist.get("project_id", &"")), {}))


func _advance_project_with_controller_frames(city: Node, macro: MacroMarchR0, project_id: StringName, maximum_frames: int) -> bool:
	for _step in range(maximum_frames):
		var project := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {}).get(project_id, {}))
		if StringName(project.get("phase", &"")) == &"COMPLETE":
			macro.refresh()
			return true
		city._process(0.1)
		macro.refresh()
		await process_frame
	var final_project := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {}).get(project_id, {}))
	return StringName(final_project.get("phase", &"")) == &"COMPLETE"


func _frame_world_points(macro: MacroMarchR0, points: Array) -> void:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point_value in points:
		minimum = minimum.min(Vector2(point_value))
		maximum = maximum.max(Vector2(point_value))
	var bounds := THEATER.get_world_bounds()
	var normalized := (((minimum + maximum) * 0.5) - bounds.position) / bounds.size
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = macro._minimap_rect().position + normalized * macro._minimap_rect().size
	macro._on_gui_input(click)
	click.pressed = false
	macro._on_gui_input(click)
	for _step in 4:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = macro._map_rect().get_center()
		macro._on_gui_input(wheel)


func _click_map(macro: MacroMarchR0, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	macro._on_gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	macro._on_gui_input(release)


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	root.get_texture().get_image().save_png(evidence_directory.path_join(filename))


func _frames(count: int) -> void:
	for _frame in range(maxi(count, 0)):
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
	else:
		failures.append(description)

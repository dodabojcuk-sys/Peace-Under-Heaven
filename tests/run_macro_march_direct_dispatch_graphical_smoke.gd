extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var evidence_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MACRO_MARCH_DIRECT_DISPATCH_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _user_argument_value("--txwzs-direct-dispatch-evidence-dir=")
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.food = 80
	scene.open_macro_march_r0()
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	var source_id: StringName = &"blackstone_city"
	var scout_target_id: StringName = &"ridge_watch"
	var target_id: StringName = &"northwatch_garrison"
	var source_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	var scout_target_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), scout_target_id).get("world_position", Vector2.ZERO)))
	var target_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), target_id).get("world_position", Vector2.ZERO)))

	# The strip must visibly distinguish a reversible candidate hover from the
	# later locked subject. Capture both real rendered states before continuing.
	await _open_picker(macro, source_screen)
	var visible_formation_index := _option_index(macro, &"FORMATION")
	var expected_formation_id := StringName(Dictionary(macro._direct_dispatch_options[visible_formation_index] if visible_formation_index >= 0 else {}).get("formation_id", &""))
	var picker_before_hover := await _capture_viewport_image()
	_hover_option(macro, visible_formation_index)
	var picker_hover := await _capture_viewport_image()
	var hover_remains_unlocked := macro._direct_dispatch_locked.is_empty()
	_send_map_motion(macro, target_screen)
	var picker_locked := await _capture_viewport_image()
	_capture_evidence(picker_hover, "01-picker-hover-engine-gui.png")
	_capture_evidence(picker_locked, "02-picker-locked-engine-gui.png")
	var hover_rect := macro._direct_dispatch_option_rect(visible_formation_index).grow(2.0)
	var hover_is_visible := _changed_pixels(picker_before_hover, picker_hover, hover_rect) > 30 \
		and hover_remains_unlocked
	var lock_is_visible := _changed_pixels(picker_hover, picker_locked, hover_rect) > 30 \
		and StringName(macro._direct_dispatch_locked.get("formation_id", &"")) == expected_formation_id
	_send_map_release(macro, macro._direct_dispatch_option_rect(visible_formation_index).get_center())
	await process_frame

	# Focus loss must cancel the new direct gesture just as it cancels legacy
	# drawing. A later release cannot issue from a stale object-strip selection.
	await _open_picker(macro, source_screen)
	var focus_option_index := _option_index(macro, &"NEW_SCOUT")
	_hover_option(macro, focus_option_index)
	macro._notification(Window.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_send_map_release(macro, scout_target_screen)
	await process_frame
	var focus_clears_direct_gesture := not macro._direct_dispatch_pending \
		and macro._direct_dispatch_locked.is_empty() \
		and macro._direct_dispatch_preview.is_empty()

	# An invalid direct-scout release must not create a specialist or spend food.
	var food_before_invalid := int(city.food)
	var specialists_before := Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).size()
	await _open_picker(macro, source_screen)
	var new_scout_index := _option_index(macro, &"NEW_SCOUT")
	_hover_option(macro, new_scout_index)
	_send_map_motion(macro, macro._map_rect().position + Vector2(8, 8))
	_send_map_release(macro, macro._map_rect().position + Vector2(8, 8))
	await process_frame
	var invalid_scout_has_no_side_effect := int(city.food) == food_before_invalid \
		and Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).size() == specialists_before \
		and Array(macro._model().get("armies", [])).is_empty()

	# Releasing inside the object strip is a cancellation, not a hidden command.
	# This verifies the final release position is checked before any authority call.
	await _open_picker(macro, source_screen)
	_hover_option(macro, new_scout_index)
	var food_before_picker_release := int(city.food)
	_send_map_release(macro, macro._direct_dispatch_option_rect(new_scout_index).get_center())
	await process_frame
	var picker_release_has_no_side_effect := not macro._direct_dispatch_pending \
		and int(city.food) == food_before_picker_release \
		and Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).size() == specialists_before

	# A valid new-scout gesture atomically creates and orders the specialist.
	await _open_picker(macro, source_screen)
	new_scout_index = _option_index(macro, &"NEW_SCOUT")
	_hover_option(macro, new_scout_index)
	_send_map_motion(macro, scout_target_screen)
	_send_map_release(macro, scout_target_screen)
	var direct_scout_status := macro._status_label.text
	await process_frame
	var field_after_scout: Dictionary = city.get_field_tactics_read_model()
	var moving_scout := _first_role(field_after_scout, FieldTacticsState.SPECIALIST_SCOUT)
	var direct_scout_commits_once := not moving_scout.is_empty() \
		and StringName(moving_scout.get("phase", &"")) == FieldTacticsState.SPECIALIST_MOVING \
		and StringName(moving_scout.get("target_point_id", &"")) == scout_target_id \
		and int(city.food) == food_before_invalid - 4
	print("DIRECT_SCOUT_TRACE target=%s food=%d moving=%s release_status=%s" % [scout_target_id, int(city.food), str(moving_scout), direct_scout_status])

	# Zoom changes the map transform but not the source/target hit relationship.
	macro._zoom_at_screen_position(source_screen, 0.82)
	source_screen = macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	target_screen = macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), target_id).get("world_position", Vector2.ZERO)))
	var food_before_march := int(city.food)
	var armies_before := Array(macro._model().get("armies", [])).size()
	# Follow the natural line from the anchor through the strip to the first row.
	# It crosses lower rows first; only the last highlighted row may lock after
	# leaving the strip, otherwise the older eager-lock bug selects the wrong one.
	await _open_picker(macro, source_screen)
	var formation_index := _option_index(macro, &"FORMATION")
	_move_through_option_to_target(macro, formation_index, scout_target_screen)
	var crossed_strip_locks_intended_option := StringName(macro._direct_dispatch_locked.get("kind", &"")) == &"FORMATION" \
		and StringName(macro._direct_dispatch_locked.get("formation_id", &"")) == expected_formation_id
	var preview_route_id := StringName(macro._direct_dispatch_preview.get("route_id", &""))
	# No final motion event is sent for northwatch. Release must replan from the
	# actual release point rather than commit the prior ridge-watch preview.
	_send_map_release(macro, target_screen)
	await process_frame
	var issued_armies: Array = Array(macro._model().get("armies", []))
	var issued_army := Dictionary(issued_armies.back()) if not issued_armies.is_empty() else {}
	var issued_macro: Dictionary = Dictionary(issued_army.get("macro_march", {}))
	var direct_march_commits_once := issued_armies.size() == armies_before + 1 \
		and int(issued_macro.get("food_cost", 0)) > 0 \
		and int(city.food) == food_before_march - int(issued_macro.get("food_cost", 0)) \
		and StringName(issued_macro.get("target_point_id", &"")) == target_id \
		and StringName(issued_macro.get("route_id", &"")) == &"road.blackstone.northwatch.ridge" \
		and _macro_uses_formation(issued_macro, expected_formation_id) \
		and macro._draft_route.is_empty() \
		and macro._engineering_draft.is_empty() \
		and macro._confirm_button.disabled

	# Viewing a stationed army on the map must not turn its own camp into the old
	# confirmation-only flow. The same long hold opens the strip and can issue a
	# new direct station order.
	var reached_station: Dictionary = city.advance_macro_march_time(
		StringName(issued_army.get("army_id", &"")), StringName(issued_macro.get("order_id", &"")),
		int(issued_macro.get("progress_millis", 0)), int(issued_macro.get("total_millis", 0))
	)
	await process_frame
	var stationed_army := Dictionary(reached_station.get("army", {}))
	var station_source_id: StringName = &"northwatch_garrison"
	var station_target_id: StringName = &"forest_garrison"
	macro._selected_army_id = StringName(stationed_army.get("army_id", &""))
	macro.refresh()
	var station_source_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), station_source_id).get("world_position", Vector2.ZERO)))
	var station_target_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), station_target_id).get("world_position", Vector2.ZERO)))
	var station_food_before := int(city.food)
	await _open_picker(macro, station_source_screen)
	var stationed_army_index := _option_index(macro, &"ARMY")
	_move_through_option_to_target(macro, stationed_army_index, station_target_screen)
	var station_preview_route := StringName(macro._direct_dispatch_preview.get("route_id", &""))
	_send_map_release(macro, station_target_screen)
	await process_frame
	var station_reissue := Dictionary(macro._selected_army(macro._model()).get("macro_march", {}))
	var viewed_station_can_direct_dispatch := bool(reached_station.get("success", false)) \
		and StringName(stationed_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED \
		and stationed_army_index >= 0 \
		and StringName(station_reissue.get("route_id", &"")) == station_preview_route \
		and StringName(station_reissue.get("target_point_id", &"")) == station_target_id \
		and int(city.food) < station_food_before

	# A direct authority-preview failure persists over refresh instead of being
	# replaced next frame by context copy, and it does not add an army or charge
	# food. Restore the fixture food only after this isolated negative check.
	var food_before_shortage := int(city.food)
	city.food = 0
	macro._selected_army_id = &""
	macro.refresh()
	source_screen = macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	target_screen = macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), target_id).get("world_position", Vector2.ZERO)))
	var armies_before_shortage := Array(macro._model().get("armies", [])).size()
	await _open_picker(macro, source_screen)
	formation_index = _option_index(macro, &"FORMATION")
	_move_through_option_to_target(macro, formation_index, target_screen)
	_send_map_release(macro, target_screen)
	await process_frame
	macro.refresh()
	var shortage_persists_over_refresh := macro._status_label.text.contains("粮食不足") \
		and Array(macro._model().get("armies", [])).size() == armies_before_shortage \
		and int(city.food) == 0
	city.food = food_before_shortage
	macro.refresh()

	# A damaged non-main fixture road gives the direct engineer gesture one
	# unambiguous repair intent. Preview failures must not fall through into an
	# unrelated open-land construction draft.
	var repair_engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var repair_engineer_id := StringName(Dictionary(repair_engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	var field_state: FieldTacticsState = city._war_loop_state.field_tactics
	var repair_road_id: StringName = &"road.direct-dispatch.repair"
	var repair_road_points: Array = [Vector2i(150, 430), Vector2i(280, 430), Vector2i(410, 430)]
	field_state.roads_by_id[repair_road_id] = {
		"road_id": repair_road_id, "source_point_id": source_id, "target_point_id": target_id,
		"route_world_points": repair_road_points, "road_kind": FieldTacticsState.ROAD_NORMAL,
		"state": FieldTacticsState.ROAD_DAMAGED, "durability": 0, "max_durability": 70, "built": true,
	}
	macro._selected_army_id = &""
	macro.refresh()
	source_screen = macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	var repair_screen := macro._world_to_screen(Vector2(repair_road_points[1]))
	var projects_before_repair_attempts := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	var repair_engineer_index := _specialist_option_index(macro, FieldTacticsState.SPECIALIST_ENGINEER)
	var food_before_repair_shortage := int(city.food)
	city.food = 0
	await _open_picker(macro, source_screen)
	repair_engineer_index = _specialist_option_index(macro, FieldTacticsState.SPECIALIST_ENGINEER)
	_move_through_option_to_target(macro, repair_engineer_index, repair_screen)
	_send_map_release(macro, repair_screen)
	await process_frame
	macro.refresh()
	var repair_shortage_stays_repair := macro._status_label.text.contains("粮食不足") \
		and macro._engineering_draft.is_empty() \
		and Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size() == projects_before_repair_attempts \
		and StringName(Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).get(repair_engineer_id, {}).get("project_id", &"")) == &"" \
		and int(city.food) == 0
	city.food = food_before_repair_shortage
	macro.refresh()

	# Keep the visible damaged road fixed while replacing both repair endpoints
	# with water-locked fixture points. This forces the same authority preview
	# through its "engineer cannot reach" branch without touching user data.
	var repair_road_for_unreachable := Dictionary(field_state.roads_by_id[repair_road_id]).duplicate(true)
	var unreachable_source_id: StringName = &"fixture.repair.unreachable.source"
	var unreachable_target_id: StringName = &"fixture.repair.unreachable.target"
	field_state.point_positions_by_id[unreachable_source_id] = Vector2i(540, 370)
	field_state.point_positions_by_id[unreachable_target_id] = Vector2i(600, 420)
	repair_road_for_unreachable.source_point_id = unreachable_source_id
	repair_road_for_unreachable.target_point_id = unreachable_target_id
	field_state.roads_by_id[repair_road_id] = repair_road_for_unreachable
	await _open_picker(macro, source_screen)
	repair_engineer_index = _specialist_option_index(macro, FieldTacticsState.SPECIALIST_ENGINEER)
	_move_through_option_to_target(macro, repair_engineer_index, repair_screen)
	_send_map_release(macro, repair_screen)
	await process_frame
	macro.refresh()
	var repair_unreachable_stays_repair := macro._status_label.text.contains("无法到达") \
		and macro._engineering_draft.is_empty() \
		and Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size() == projects_before_repair_attempts \
		and StringName(Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).get(repair_engineer_id, {}).get("project_id", &"")) == &"" \
		and int(city.food) == food_before_repair_shortage
	field_state.roads_by_id[repair_road_id] = {
		"road_id": repair_road_id, "source_point_id": source_id, "target_point_id": target_id,
		"route_world_points": repair_road_points, "road_kind": FieldTacticsState.ROAD_NORMAL,
		"state": FieldTacticsState.ROAD_DAMAGED, "durability": 0, "max_durability": 70, "built": true,
	}
	field_state.point_positions_by_id.erase(unreachable_source_id)
	field_state.point_positions_by_id.erase(unreachable_target_id)
	macro.refresh()

	await _open_picker(macro, source_screen)
	repair_engineer_index = _specialist_option_index(macro, FieldTacticsState.SPECIALIST_ENGINEER)
	_move_through_option_to_target(macro, repair_engineer_index, repair_screen)
	_send_map_release(macro, repair_screen)
	await process_frame
	var repair_commits_once := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size() == projects_before_repair_attempts + 1 \
		and StringName(Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).get(repair_engineer_id, {}).get("project_id", &"")) != &"" \
		and macro._engineering_draft.is_empty() \
		and int(city.food) == food_before_repair_shortage - 3

	# A separate local engineer can turn the same picker gesture into an editable
	# road plan. It spends nothing until the explicit map-side 开工 control.
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	macro.refresh()
	var engineering_endpoint := macro._world_to_screen(Vector2(330, 650))
	var food_before_engineering := int(city.food)
	await _open_picker(macro, source_screen)
	var engineer_index := _specialist_option_index(macro, FieldTacticsState.SPECIALIST_ENGINEER)
	_hover_option(macro, engineer_index)
	_send_map_motion(macro, engineering_endpoint)
	_send_map_release(macro, engineering_endpoint)
	await process_frame
	var plan_cost := int(macro._engineering_draft.get("food_cost", 0))
	var engineering_plan_is_editable := bool(engineer_dispatch.get("success", false)) \
		and engineer_index >= 0 \
		and not macro._engineering_draft.is_empty() \
		and macro._confirm_button.visible and not macro._confirm_button.disabled \
		and macro._engineering_start_rect().has_point(macro._engineering_start_rect().get_center()) \
		and int(city.food) == food_before_engineering
	var projects_before := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	_send_map_press(macro, macro._engineering_start_rect().get_center())
	_send_map_release(macro, macro._engineering_start_rect().get_center())
	await process_frame
	var map_start_commits_once := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size() == projects_before + 1 \
		and int(city.food) == food_before_engineering - plan_cost
	print("DIRECT_DISPATCH_TRACE hover=%s lock=%s invalid=%s scout=%s march=%s repair_shortage=%s repair_unreachable=%s repair_commit=%s engineering=%s start=%s scout_index=%d formation_index=%d engineer_index=%d preview_route=%s issued_macro=%s food=%d armies=%d specialist=%s status=%s" % [
		str(hover_is_visible), str(lock_is_visible), str(invalid_scout_has_no_side_effect), str(direct_scout_commits_once), str(direct_march_commits_once), str(repair_shortage_stays_repair), str(repair_unreachable_stays_repair), str(repair_commits_once), str(engineering_plan_is_editable), str(map_start_commits_once), new_scout_index, formation_index, engineer_index, preview_route_id, str(issued_macro), int(city.food), issued_armies.size(), str(moving_scout), macro._status_label.text,
	])

	_check(new_scout_index >= 0 and formation_index >= 0, "选择条包含新侦察兵与编队")
	_check(focus_clears_direct_gesture, "失焦会清理新的直接派遣手势")
	_check(invalid_scout_has_no_side_effect, "无效侦察目标不派遣也不扣粮")
	_check(picker_release_has_no_side_effect, "松手仍在选择条内会取消而不提交")
	_check(hover_is_visible and lock_is_visible, "引擎画面清楚区分条内悬停候选与拖出后的锁定对象")
	_check(direct_scout_commits_once, "新侦察兵创建与下令保持单次事务")
	_check(crossed_strip_locks_intended_option, "连续穿过选择条后锁定预期编队身份")
	_check(direct_march_commits_once, "松手以最终目标重校验，并只为预期编队提交一次军令")
	_check(viewed_station_can_direct_dispatch, "查看驻军后仍可从同一驻点直接续令")
	_check(shortage_persists_over_refresh, "粮食失败提示跨刷新保留且不创建军队")
	_check(repair_shortage_stays_repair, "维修缺粮跨刷新保留原因，不转入新工程或扣费")
	_check(repair_unreachable_stays_repair, "维修不可达跨刷新保留原因，不转入新工程或改动任务")
	_check(repair_commits_once, "合法维修仍经原权威入口单次创建维修项目")
	_check(engineering_plan_is_editable and map_start_commits_once, "工程师拖到空地仅生成计划，开工按钮单次提交")
	scene.queue_free()
	await process_frame
	_finish()


func _open_picker(macro: MacroMarchR0, source_screen: Vector2) -> void:
	_send_map_press(macro, source_screen)
	await create_timer(MacroMarchR0.DRAW_HOLD_SECONDS + 0.04).timeout
	await process_frame


func _option_index(macro: MacroMarchR0, kind: StringName) -> int:
	for index in range(macro._direct_dispatch_options.size()):
		if StringName(Dictionary(macro._direct_dispatch_options[index]).get("kind", &"")) == kind:
			return index
	return -1


func _hover_option(macro: MacroMarchR0, index: int) -> void:
	if index < 0:
		return
	_send_map_motion(macro, macro._direct_dispatch_option_rect(index).get_center())


func _move_through_option_to_target(macro: MacroMarchR0, index: int, target_screen: Vector2) -> void:
	if index < 0:
		return
	var anchor := macro._direct_dispatch_anchor_screen
	var option_center := macro._direct_dispatch_option_rect(index).get_center()
	for step in range(1, 9):
		_send_map_motion(macro, anchor.lerp(option_center, float(step) / 8.0))
	_send_map_motion(macro, target_screen)


func _macro_uses_formation(macro_order: Dictionary, formation_id: StringName) -> bool:
	for snapshot_value in Array(macro_order.get("formation_snapshots", [])):
		if StringName(Dictionary(snapshot_value).get("formation_id", &"")) == formation_id:
			return true
	return false


func _specialist_option_index(macro: MacroMarchR0, role: StringName) -> int:
	for index in range(macro._direct_dispatch_options.size()):
		var option: Dictionary = Dictionary(macro._direct_dispatch_options[index])
		if StringName(option.get("kind", &"")) == &"SPECIALIST" and StringName(option.get("role", &"")) == role:
			return index
	return -1


func _first_role(field: Dictionary, role: StringName) -> Dictionary:
	for specialist_value in Dictionary(field.get("specialists_by_id", {})).values():
		var specialist: Dictionary = Dictionary(specialist_value)
		if StringName(specialist.get("role", &"")) == role:
			return specialist
	return {}


func _send_map_press(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	macro._on_gui_input(event)


func _send_map_release(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	macro._on_gui_input(event)


func _send_map_motion(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	macro._on_gui_input(event)


func _capture_viewport_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _capture_evidence(image: Image, file_name: String) -> void:
	if evidence_directory.is_empty() or image == null:
		return
	var absolute_directory := ProjectSettings.globalize_path(evidence_directory)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		failures.append("无法创建直接派遣图形证据目录：%s" % absolute_directory)
		return
	var path := absolute_directory.path_join(file_name)
	if image.save_png(path) != OK:
		failures.append("无法保存直接派遣图形证据：%s" % path)
		return
	print("CAPTURED: %s" % path)


func _changed_pixels(before: Image, after: Image, rect: Rect2) -> int:
	if before == null or after == null:
		return 0
	var clip := rect.intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
	var changes := 0
	for y in range(int(clip.position.y), int(clip.end.y)):
		for x in range(int(clip.position.x), int(clip.end.x)):
			var first := before.get_pixel(x, y)
			var second := after.get_pixel(x, y)
			var difference := absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) + absf(first.a - second.a)
			if difference > 0.08:
				changes += 1
	return changes


func _user_argument_value(prefix: String) -> String:
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


func _finish() -> void:
	if failures.is_empty():
		print("MACRO_MARCH_DIRECT_DISPATCH_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_MARCH_DIRECT_DISPATCH_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)

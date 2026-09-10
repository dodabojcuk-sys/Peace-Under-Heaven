extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MACRO_MARCH_COMMAND_STATUS_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
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
	macro._selected_specialist_id = &""
	macro._selected_scout_id = &""
	var formation_id := _first_available_formation_id(city)
	macro._selected_formation_ids = [formation_id]
	macro.refresh()
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var route_points: Array = Array(route.get("points", []))
	_draw_route_with_gui(macro, route_points)
	await process_frame
	var draft_cost := int(macro._draft_route.get("food_cost", 0))
	var armies_before := Array(macro._model().get("armies", [])).size()

	# Step 1: an actual visible confirm button refuses insufficient food without
	# creating an army, and the failure must survive the normal refresh loop.
	city.food = 0
	await _click_control_with_gui_input(macro._confirm_button)
	macro._process(0.10)
	var failure_survives_refresh := not macro._status_error_text.is_empty() \
		and macro._status_label.text == macro._status_error_text \
		and Array(macro._model().get("armies", [])).size() == armies_before \
		and int(city.food) == 0
	_print_trace("failure", macro, city)

	# Step 2: right-click cancels only the unconfirmed draft. The city formation
	# stays selected so retry does not require an accidental second click.
	_send_map_right_click(macro, macro._world_to_screen(Vector2(route_points.front())))
	var cancel_keeps_command_subject := macro._selected_formation_ids == [formation_id] \
		and macro._draft_route.is_empty() \
		and macro._engineering_draft.is_empty() \
		and macro._confirm_button.is_inside_tree() and macro._confirm_button.disabled \
		and macro._status_error_text.is_empty() \
		and int(city.food) == 0 \
		and Array(macro._model().get("armies", [])).size() == armies_before
	_print_trace("cancel", macro, city)

	# Step 3: record the separate, intentional formation-toggle behavior. This
	# prevents a regression test from mistaking a second formation click for a
	# side effect of cancellation.
	macro._toggle_formation(formation_id)
	var second_click_deselects := macro._selected_formation_ids.is_empty()
	_print_trace("second_click", macro, city)
	macro._toggle_formation(formation_id)

	# Step 4: retry the real hold-and-draw gesture, then click the visible
	# confirmation control. Starting a replacement intent and succeeding both
	# clear the prior error without duplicate resource transactions.
	city.food = 80
	_draw_route_with_gui(macro, route_points)
	await process_frame
	var retry_confirm_ready := macro._confirm_button.is_inside_tree() and macro._confirm_button.visible and not macro._confirm_button.disabled
	var retry_clears_failure := macro._status_error_text.is_empty()
	_print_trace("retry_draft", macro, city)
	await _click_control_with_gui_input(macro._confirm_button)
	await process_frame
	var retry_commits_once := Array(macro._model().get("armies", [])).size() == armies_before + 1 \
		and int(city.food) == 80 - draft_cost \
		and macro._status_error_text.is_empty()
	_print_trace("retry_confirmed", macro, city)

	var issued_army: Dictionary = Dictionary(Array(macro._model().get("armies", [])).back())
	var issued_macro: Dictionary = Dictionary(issued_army.get("macro_march", {}))
	var progress_before_pause := int(issued_macro.get("progress_millis", 0))
	city.set_city_time_paused(true)
	city._process(0.50)
	macro.refresh()
	var paused_army: Dictionary = Dictionary(Array(macro._model().get("armies", [])).back())
	var paused_progress := int(Dictionary(paused_army.get("macro_march", {})).get("progress_millis", -1))
	var paused_copy_visible := macro._status_label.text.contains("世界已暂停")
	city.set_city_time_paused(false)
	city.set_city_time_speed(1.0)
	city._process(0.50)
	macro.refresh()
	var resumed_army: Dictionary = Dictionary(Array(macro._model().get("armies", [])).back())
	var resumed_progress := int(Dictionary(resumed_army.get("macro_march", {})).get("progress_millis", -1))
	var resumed_copy_visible := macro._status_label.text.contains("世界正常推进")

	_check(
		formation_id != &""
			and failure_survives_refresh
			and cancel_keeps_command_subject
			and second_click_deselects
			and retry_confirm_ready
			and retry_clears_failure
			and retry_commits_once
			and paused_progress == progress_before_pause
			and paused_copy_visible
			and resumed_progress > paused_progress
			and resumed_copy_visible,
		"图形进程记录失败→取消→第二次编队点击→重试四步：失败提示不会被逐帧刷新覆盖且不扣资源；取消保留发令编队、第二次显式点击才取消选择；重试只提交一次；正常行军暂停保持进度、恢复后继续并显示明确世界时间原因"
	)
	scene.queue_free()
	await process_frame
	_finish()


func _first_available_formation_id(city: Node) -> StringName:
	for roster_value in city.get_formation_roster():
		var roster_entry: Dictionary = Dictionary(roster_value)
		if int(roster_entry.get("member_count", 0)) > 0:
			return StringName(roster_entry.get("formation_id", &""))
	return &""


func _draw_route_with_gui(macro: MacroMarchR0, points: Array) -> void:
	if points.is_empty():
		return
	_send_map_press(macro, macro._world_to_screen(Vector2(points.front())))
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for point_value in points.slice(1):
		_send_map_motion(macro, macro._world_to_screen(Vector2(point_value)))
	_send_map_release(macro, macro._world_to_screen(Vector2(points.back())))


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


func _send_map_right_click(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	macro._on_gui_input(event)


func _click_control_with_gui_input(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame


func _print_trace(stage: String, macro: MacroMarchR0, city: Node) -> void:
	print("COMMAND_CANCEL_TRACE stage=%s selected=%s draft=%s confirm_visible=%s confirm_disabled=%s error=%s food=%d armies=%d" % [
		stage,
		str(macro._selected_formation_ids),
		str(not macro._draft_route.is_empty() or not macro._engineering_draft.is_empty()),
		str(macro._confirm_button.visible),
		str(macro._confirm_button.disabled),
		macro._status_label.text,
		int(city.food),
		Array(macro._model().get("armies", [])).size(),
	])


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("MACRO_MARCH_COMMAND_STATUS_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_MARCH_COMMAND_STATUS_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)

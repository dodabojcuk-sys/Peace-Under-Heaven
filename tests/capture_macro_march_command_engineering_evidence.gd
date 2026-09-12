extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("COMMAND_ENGINEERING_EVIDENCE requires a graphical Godot process")
		quit(2)
		return
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(3)
	var city: Node = scene.get_node("ConstructionController")
	city.food = 80
	scene.open_macro_march_r0()
	await _frames(3)
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	var formation_id := StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))
	macro._toggle_formation(formation_id)
	await _frames(18)

	# First show the default destination command, then cancel it before any
	# authority write. The second gesture crosses the ridge road choice point.
	var target := macro._world_to_screen(Vector2(THEATER.get_point(&"northwatch_garrison").get("world_position", Vector2.ZERO)))
	_send_click(macro, target)
	await _frames(20)
	_send_right_click(macro, target)
	await _frames(14)
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var ridge_points: Array = Array(ridge.get("points", []))
	var source := macro._world_to_screen(Vector2(ridge_points.front()))
	_send_press(macro, source)
	var march_hold_activated := await _wait_for_draw_activation(macro)
	for point_value in ridge_points.slice(1):
		_send_motion(macro, macro._world_to_screen(Vector2(point_value)))
		await _frames(10)
	_send_release(macro, macro._world_to_screen(Vector2(ridge_points.back())))
	await _frames(24)
	var route_ready := not macro._draft_route.is_empty() \
		and StringName(macro._draft_route.get("required_road_id", &"")) == &"road.blackstone.northwatch.ridge" \
		and macro._confirm_button.is_inside_tree() and macro._confirm_button.visible and not macro._confirm_button.disabled
	var food_before_march := int(city.food)
	await _click_control_with_gui_input(macro._confirm_button)
	await _frames(24)
	var march_committed_once := Array(macro._model().get("armies", [])).size() == 1 and int(city.food) < food_before_march

	# Use the same visible map interaction for a cross-water construction plan.
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	var city_screen := macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	var engineer_selected := await _select_specialist_with_gui(macro, city, city_screen, engineer_id)
	await _click_control_with_gui_input(macro._side_road_button)
	await _frames(12)
	_send_click(macro, city_screen)
	await _frames(2)
	var construction_points := [Vector2(150, 650), Vector2(430, 605), Vector2(610, 565), Vector2(760, 610)]
	_send_press(macro, macro._world_to_screen(construction_points.front()))
	var engineering_hold_activated := await _wait_for_draw_activation(macro)
	for point_value in construction_points.slice(1):
		_send_motion(macro, macro._world_to_screen(point_value))
		await _frames(10)
	_send_release(macro, macro._world_to_screen(construction_points.back()))
	await _frames(20)
	var engineering_ready := not macro._engineering_draft.is_empty() \
		and macro._confirm_button.is_inside_tree() and macro._confirm_button.visible and not macro._confirm_button.disabled
	var food_before_engineering := int(city.food)
	var projects_before_engineering := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	await _click_control_with_gui_input(macro._confirm_button)
	var engineering_committed_once := macro._engineering_draft.is_empty() \
		and Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size() == projects_before_engineering + 1 \
		and int(city.food) < food_before_engineering
	for _index in range(8):
		city.advance_war_loop_time(2000)
		macro.refresh()
		await _frames(8)
	var project_count := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	var passed := march_hold_activated and route_ready and march_committed_once and bool(engineer_dispatch.get("success", false)) and engineer_selected and engineering_hold_activated and engineering_ready and engineering_committed_once
	if not passed:
		push_error("COMMAND_ENGINEERING_ENGINE_GUI_EVIDENCE FAIL march_hold=%s route_ready=%s march_once=%s engineer_selected=%s engineering_hold=%s engineering_ready=%s engineering_once=%s projects=%d" % [march_hold_activated, route_ready, march_committed_once, engineer_selected, engineering_hold_activated, engineering_ready, engineering_committed_once, project_count])
		scene.queue_free()
		await process_frame
		quit(1)
		return
	print("COMMAND_ENGINEERING_ENGINE_GUI_EVIDENCE PASS natural_hold=true route=road.blackstone.northwatch.ridge march_once=true engineering_once=true projects=%d" % project_count)
	scene.queue_free()
	await process_frame
	quit(0)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _wait_for_draw_activation(macro: MacroMarchR0) -> bool:
	# Keep the press held through real scene frames. This deliberately avoids
	# calling MacroMarchR0._process() directly so the evidence captures the same
	# elapsed-time gate that the visible candidate uses.
	var deadline := Time.get_ticks_msec() + ceili((MacroMarchR0.DRAW_HOLD_SECONDS + 0.35) * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		await process_frame
		if macro._is_drawing:
			return true
	return false


func _send_click(macro: MacroMarchR0, position: Vector2) -> void:
	_send_press(macro, position)
	_send_release(macro, position)


func _send_press(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	macro._on_gui_input(event)


func _send_motion(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	macro._on_gui_input(event)


func _send_release(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	macro._on_gui_input(event)


func _send_right_click(macro: MacroMarchR0, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	macro._on_gui_input(event)


func _click_control_with_gui_input(control: Control) -> void:
	if control == null:
		return
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


func _select_specialist_with_gui(macro: MacroMarchR0, city: Node, position: Vector2, specialist_id: StringName) -> bool:
	for _attempt in range(4):
		_send_click(macro, position)
		await process_frame
		if macro._selected_specialist_id == specialist_id:
			return true
	return false

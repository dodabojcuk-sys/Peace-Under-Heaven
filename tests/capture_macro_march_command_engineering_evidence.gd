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
	await _frames(10)
	for point_value in ridge_points.slice(1):
		_send_motion(macro, macro._world_to_screen(Vector2(point_value)))
		await _frames(10)
	_send_release(macro, macro._world_to_screen(Vector2(ridge_points.back())))
	await _frames(24)
	var route_ready := not macro._draft_route.is_empty() and macro._confirm_button.visible and not macro._confirm_button.disabled
	macro._confirm_button.emit_signal("pressed")
	await _frames(24)

	# Use the same visible map interaction for a cross-water construction plan.
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	macro._side_road_button.emit_signal("pressed")
	await _frames(12)
	var construction_points := [Vector2(150, 650), Vector2(430, 605), Vector2(610, 565), Vector2(760, 610)]
	_send_press(macro, macro._world_to_screen(construction_points.front()))
	for point_value in construction_points.slice(1):
		_send_motion(macro, macro._world_to_screen(point_value))
		await _frames(10)
	_send_release(macro, macro._world_to_screen(construction_points.back()))
	await _frames(20)
	# Continue one visible uncommitted stroke, undo it, then commit the original
	# authority preview. Neither edit creates a second project or a charge.
	_send_press(macro, macro._world_to_screen(construction_points.back()))
	_send_motion(macro, macro._world_to_screen(Vector2(790, 590)))
	_send_release(macro, macro._world_to_screen(Vector2(790, 590)))
	await _frames(14)
	macro._engineering_undo_button.emit_signal("pressed")
	await _frames(14)
	var engineering_ready := not macro._engineering_draft.is_empty() and macro._confirm_button.visible and not macro._confirm_button.disabled
	macro._confirm_button.emit_signal("pressed")
	for _index in range(8):
		city.advance_war_loop_time(2000)
		macro.refresh()
		await _frames(8)
	print("COMMAND_ENGINEERING_ENGINE_GUI_EVIDENCE PASS route_ready=%s engineering_ready=%s projects=%d" % [route_ready, engineering_ready, Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size()])
	scene.queue_free()
	await process_frame
	quit(0)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


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

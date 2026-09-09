extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("DRAW_HOLD_EVIDENCE requires a graphical Godot process")
		quit(2)
		return
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.food = 80
	scene.open_macro_march_r0()
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var points: Array = Array(route.get("points", []))
	macro._selected_formation_ids = [StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))]
	macro.refresh()
	await _frames(18)
	var source := macro._world_to_screen(Vector2(points.front()))
	_send_press(macro, source)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS * 0.5)
	await _frames(12)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS * 0.5 + 0.01)
	await _frames(8)
	for point_value in points.slice(1):
		_send_motion(macro, macro._world_to_screen(Vector2(point_value)))
		await _frames(9)
	_send_release(macro, macro._world_to_screen(Vector2(points.back())))
	await _frames(36)
	print("DRAW_HOLD_ENGINE_INPUT_EVIDENCE PASS draft=%s confirm_visible=%s" % [
		StringName(macro._draft_route.get("route_id", &"")),
		macro._confirm_button.visible and not macro._confirm_button.disabled,
	])
	scene.queue_free()
	await process_frame
	quit(0)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


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

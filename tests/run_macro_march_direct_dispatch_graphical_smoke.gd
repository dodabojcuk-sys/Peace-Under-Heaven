extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MACRO_MARCH_DIRECT_DISPATCH_GRAPHICAL_SMOKE requires a graphical Godot process")
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
	var source_id: StringName = &"blackstone_city"
	var scout_target_id: StringName = &"ridge_watch"
	var target_id: StringName = &"northwatch_garrison"
	var source_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	var scout_target_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), scout_target_id).get("world_position", Vector2.ZERO)))
	var target_screen := macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), target_id).get("world_position", Vector2.ZERO)))

	# An invalid direct-scout release must not create a specialist or spend food.
	var food_before_invalid := int(city.food)
	var specialists_before := Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).size()
	_open_picker(macro, source_screen)
	var new_scout_index := _option_index(macro, &"NEW_SCOUT")
	_lock_option(macro, new_scout_index)
	_send_map_motion(macro, macro._map_rect().position + Vector2(8, 8))
	_send_map_release(macro, macro._map_rect().position + Vector2(8, 8))
	await process_frame
	var invalid_scout_has_no_side_effect := int(city.food) == food_before_invalid \
		and Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {})).size() == specialists_before \
		and Array(macro._model().get("armies", [])).is_empty()

	# A valid new-scout gesture atomically creates and orders the specialist.
	_open_picker(macro, source_screen)
	new_scout_index = _option_index(macro, &"NEW_SCOUT")
	_lock_option(macro, new_scout_index)
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
	_open_picker(macro, source_screen)
	var formation_index := _option_index(macro, &"FORMATION")
	_lock_option(macro, formation_index)
	_send_map_motion(macro, target_screen)
	var preview_route_id := StringName(macro._direct_dispatch_preview.get("route_id", &""))
	var preview_food := int(macro._direct_dispatch_preview.get("food_cost", 0))
	_send_map_release(macro, target_screen)
	await process_frame
	var issued_armies: Array = Array(macro._model().get("armies", []))
	var issued_army := Dictionary(issued_armies.back()) if not issued_armies.is_empty() else {}
	var issued_macro: Dictionary = Dictionary(issued_army.get("macro_march", {}))
	var direct_march_commits_once := issued_armies.size() == armies_before + 1 \
		and int(city.food) == food_before_march - preview_food \
		and StringName(issued_macro.get("route_id", &"")) == preview_route_id \
		and macro._draft_route.is_empty() \
		and macro._engineering_draft.is_empty() \
		and macro._confirm_button.disabled

	# A local engineer can turn the same picker gesture into an editable road
	# plan. It spends nothing until the explicit map-side 开工 control is clicked.
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	macro._selected_army_id = &""
	macro.refresh()
	source_screen = macro._world_to_screen(Vector2(macro._point_from_model(macro._model(), source_id).get("world_position", Vector2.ZERO)))
	var engineering_endpoint := macro._world_to_screen(Vector2(330, 650))
	var food_before_engineering := int(city.food)
	_open_picker(macro, source_screen)
	var engineer_index := _specialist_option_index(macro, FieldTacticsState.SPECIALIST_ENGINEER)
	_lock_option(macro, engineer_index)
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
	print("DIRECT_DISPATCH_TRACE invalid=%s scout=%s march=%s engineering=%s start=%s scout_index=%d formation_index=%d engineer_index=%d route=%s food=%d armies=%d specialist=%s status=%s" % [
		str(invalid_scout_has_no_side_effect), str(direct_scout_commits_once), str(direct_march_commits_once), str(engineering_plan_is_editable), str(map_start_commits_once), new_scout_index, formation_index, engineer_index, preview_route_id, int(city.food), issued_armies.size(), str(moving_scout), macro._status_label.text,
	])

	_check(
		new_scout_index >= 0
			and formation_index >= 0
			and invalid_scout_has_no_side_effect
			and direct_scout_commits_once
			and direct_march_commits_once
			and engineering_plan_is_editable
			and map_start_commits_once,
		"图形 GUI 事件经过按住→对象条→拖向目标→松手：无效侦察目标不派遣不扣粮；有效侦察与单编队军令各只提交一次，缩放后实际目标和道路仍正确；工程师拖到空地只生成可编辑计划，地图终点的开工按钮才提交一次"
	)
	scene.queue_free()
	await process_frame
	_finish()


func _open_picker(macro: MacroMarchR0, source_screen: Vector2) -> void:
	_send_map_press(macro, source_screen)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.02)


func _option_index(macro: MacroMarchR0, kind: StringName) -> int:
	for index in range(macro._direct_dispatch_options.size()):
		if StringName(Dictionary(macro._direct_dispatch_options[index]).get("kind", &"")) == kind:
			return index
	return -1


func _lock_option(macro: MacroMarchR0, index: int) -> void:
	if index < 0:
		return
	_send_map_motion(macro, macro._direct_dispatch_option_rect(index).get_center())


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

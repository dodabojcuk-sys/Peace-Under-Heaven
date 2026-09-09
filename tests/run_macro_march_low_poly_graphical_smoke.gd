extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LOW_POLY_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _check_projection_at_size(viewport_size)
	await _check_dynamic_actor_and_mode_switch()
	await _check_engineering_input()
	_finish()


func _check_projection_at_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.food = 80
	scene.open_macro_march_r0()
	await process_frame
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	macro.refresh()
	var presentation: MacroMarchLowPolyPresentation = macro._low_poly_presentation
	var map_rect := macro._map_rect()
	var max_error := 0.0
	for anchor in _projection_anchors():
		var expected := macro._world_to_screen(anchor) - map_rect.position
		var actual := presentation.project_world_to_viewport(anchor)
		max_error = maxf(max_error, expected.distance_to(actual))
	_check(
		presentation.visible and max_error <= 2.0,
		"图形进程 %d×%d 中 Camera3D 与二维锚点最大误差 %.3f 像素" % [viewport_size.x, viewport_size.y, max_error]
	)
	var road_geometry_error := _max_road_geometry_error(presentation)
	_check(
		road_geometry_error <= 0.01,
		"图形进程 %d×%d 中道路与桥段按实际端点居中、朝向，最大几何误差 %.4f" % [viewport_size.x, viewport_size.y, road_geometry_error]
	)
	scene.queue_free()
	await process_frame


func _check_dynamic_actor_and_mode_switch() -> void:
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
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var formation_id := StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))
	macro._selected_formation_ids = [formation_id]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = macro._world_to_screen(Vector2(Array(route.get("points", [])).front()))
	macro._on_gui_input(press)
	for point_value in Array(route.get("points", [])).slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro._world_to_screen(Vector2(point_value))
		macro._on_gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = macro._world_to_screen(Vector2(Array(route.get("points", [])).back()))
	macro._on_gui_input(release)
	var drafted_correct_route := StringName(macro._draft_route.get("route_id", &"")) == StringName(route.get("route_id", &""))
	macro._confirm_button.emit_signal("pressed")
	macro.refresh()
	var army: Dictionary = Dictionary(macro._selected_army(macro._model()))
	var army_id := StringName(army.get("army_id", &""))
	var presentation: MacroMarchLowPolyPresentation = macro._low_poly_presentation
	var actor: Node3D = presentation._army_nodes.get(army_id, null)
	var before := actor.global_position if actor != null else Vector3.ZERO
	var macro_order: Dictionary = Dictionary(army.get("macro_march", {}))
	city.advance_macro_march_time(army_id, StringName(macro_order.get("order_id", &"")), 0, 1000)
	macro.refresh()
	actor = presentation._army_nodes.get(army_id, null)
	var after := actor.global_position if actor != null else Vector3.ZERO
	var snapshot_before_toggle: Dictionary = city.export_v5_campaign_snapshot()
	macro._toggle_low_poly_presentation()
	var two_dimensional_visible := not presentation.visible
	macro._toggle_low_poly_presentation()
	_check(
		drafted_correct_route
			and actor != null
			and before.distance_to(after) > 0.01
			and two_dimensional_visible
			and presentation.visible
			and city.export_v5_campaign_snapshot() == snapshot_before_toggle,
		"图形进程在低模模式接收鼠标绘线、确认军令并更新军队位置，二维/三维切换不重发军令或改写状态"
	)
	scene.queue_free()
	await process_frame


func _check_engineering_input() -> void:
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
	var dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(dispatch.get("specialist", {})).get("specialist_id", &""))
	macro._selected_specialist_id = engineer_id
	macro._side_road_button.emit_signal("pressed")
	var source_click := InputEventMouseButton.new()
	source_click.button_index = MOUSE_BUTTON_LEFT
	source_click.pressed = true
	source_click.position = macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	macro._on_gui_input(source_click)
	var construction_points := [Vector2(150, 650), Vector2(430, 605), Vector2(610, 565), Vector2(760, 610)]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = macro._world_to_screen(construction_points.front())
	macro._on_gui_input(press)
	for point in construction_points.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro._world_to_screen(point)
		macro._on_gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = macro._world_to_screen(construction_points.back())
	macro._on_gui_input(release)
	var draft := macro._engineering_draft.duplicate(true)
	var food_before := int(city.food)
	macro._confirm_button.emit_signal("pressed")
	var field: Dictionary = city.get_field_tactics_read_model()
	_check(
		bool(dispatch.get("success", false))
			and StringName(draft.get("source_point_id", &"")) == &"blackstone_city"
			and THEATER.route_crosses_water(Array(draft.get("route_world_points", [])))
			and int(draft.get("food_cost", 0)) > 0
			and int(city.food) < food_before
			and not Dictionary(field.get("projects_by_id", {})).is_empty(),
		"图形进程在低模模式通过工程师选择、可见施工起点、跨河拖线与确认创建权威道路桥梁工程"
	)
	scene.queue_free()
	await process_frame


func _projection_anchors() -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	for point_id in [&"blackstone_city", &"northwatch_garrison", &"forest_garrison", &"redcliff_city", &"silverford_city"]:
		anchors.append(Vector2(THEATER.get_point(point_id).get("world_position", Vector2.ZERO)))
	anchors.append(Vector2(585, 575)) # southern bridge head
	anchors.append(Vector2(405, 315)) # a road midpoint
	return anchors


func _max_road_geometry_error(presentation: MacroMarchLowPolyPresentation) -> float:
	var max_error := 0.0
	for child in presentation._road_root.get_children():
		var segment := child as Node3D
		if segment == null:
			continue
		var start: Vector3 = segment.get_meta("road_start", Vector3.ZERO)
		var end: Vector3 = segment.get_meta("road_end", Vector3.ZERO)
		var midpoint_error := segment.global_position.distance_to(start.lerp(end, 0.5))
		var expected_direction := (end - start).normalized()
		var facing_error := 1.0 - absf((-segment.global_transform.basis.z).normalized().dot(expected_direction))
		max_error = maxf(max_error, maxf(midpoint_error, facing_error))
	return max_error


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_MARCH_LOW_POLY_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)

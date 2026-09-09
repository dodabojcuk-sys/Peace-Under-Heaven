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
	await _check_formal_art_assets()
	await _record_render_baseline()
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
	var ground_error := _ground_surface_error(presentation)
	_check(
		ground_error <= 0.001,
		"图形进程 %d×%d 中基础地面保持水平、网格法线与实际几何一致，最大误差 %.5f" % [viewport_size.x, viewport_size.y, ground_error]
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
	var has_selection_marker := actor != null and actor.find_child("ArmySelectionMarker", true, false) != null
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
			and has_selection_marker
			and before.distance_to(after) > 0.01
			and two_dimensional_visible
			and presentation.visible
			and city.export_v5_campaign_snapshot() == snapshot_before_toggle,
		"图形进程在低模模式接收鼠标绘线、确认军令并更新军队位置；选中部队具有不受建筑遮挡的标记，二维/三维切换不重发军令或改写状态"
	)
	scene.queue_free()
	await process_frame


func _check_formal_art_assets() -> void:
	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.open_macro_march_r0()
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	var presentation: MacroMarchLowPolyPresentation = macro._low_poly_presentation
	var asset_paths: Dictionary = {}
	var anchors_match := true
	var visible_meshes := 0
	var material_partitions_match := true
	var grounding_match := true
	var plausible_sizes := true
	var screen_mapping_match := true
	var map_rect := macro._map_rect()
	for node in presentation._static_root.find_children("*", "Node3D", true, false):
		if not node.has_meta("asset_path"):
			continue
		asset_paths[String(node.get_meta("asset_path"))] = true
		var anchor := Vector2(node.get_meta("world_anchor", Vector2.INF))
		var expected_anchor := presentation._ground_position(anchor)
		var horizontal_delta := Vector2(node.global_position.x - expected_anchor.x, node.global_position.z - expected_anchor.z)
		anchors_match = anchors_match and horizontal_delta.length() <= 0.001 and absf(float(node.get_meta("ground_contact_y", INF)) - expected_anchor.y) <= 0.001
		var lowest_y := INF
		var highest_y := -INF
		var node_has_visible_mesh := false
		for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible or mesh_instance.mesh.get_surface_count() <= 0:
				continue
			node_has_visible_mesh = true
			visible_meshes += 1
			material_partitions_match = material_partitions_match and mesh_instance.material_override == null
			for surface in mesh_instance.mesh.get_surface_count():
				material_partitions_match = material_partitions_match and mesh_instance.get_surface_override_material(surface) != null
			var bounds := _world_aabb(mesh_instance)
			lowest_y = minf(lowest_y, bounds.position.y)
			highest_y = maxf(highest_y, bounds.end.y)
		var expected_ground := presentation._ground_position(anchor).y
		grounding_match = grounding_match and node_has_visible_mesh and absf(lowest_y - expected_ground) <= 0.25
		plausible_sizes = plausible_sizes and highest_y - lowest_y > 1.0 and highest_y - lowest_y < 120.0
		var expected_screen := macro._world_to_screen(anchor) - map_rect.position
		var actual_screen := presentation.project_world_to_viewport(anchor)
		screen_mapping_match = screen_mapping_match and expected_screen.distance_to(actual_screen) <= 2.0 and Rect2(Vector2.ZERO, presentation.size).has_point(actual_screen)
	var has_gatehouse := presentation._point_root.find_child("Gatehouse", true, false) != null
	var has_watchtower := presentation._point_root.find_child("Watchtower", true, false) != null
	_check(
		asset_paths.size() == 7 and visible_meshes >= 7 and anchors_match and grounding_match and plausible_sizes and material_partitions_match and screen_mapping_match and has_gatehouse and has_watchtower,
		"图形进程实例化七项已登记 CC0 自然素材的非空网格；材质分区、落地锚点、合理包围尺寸及相机/点击投影均有效（素材=%d，网格=%d，锚点=%s，落地=%s，尺寸=%s，材质=%s，投影=%s）" % [asset_paths.size(), visible_meshes, anchors_match, grounding_match, plausible_sizes, material_partitions_match, screen_mapping_match]
	)
	scene.queue_free()
	await process_frame


func _record_render_baseline() -> void:
	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.open_macro_march_r0()
	await process_frame
	await process_frame
	var frame_total_usec := 0
	var frame_peak_usec := 0
	for frame_index in range(30):
		var started := Time.get_ticks_usec()
		await process_frame
		var elapsed := Time.get_ticks_usec() - started
		frame_total_usec += elapsed
		frame_peak_usec = maxi(frame_peak_usec, elapsed)
	var mean_ms := float(frame_total_usec) / 30000.0
	var peak_ms := float(frame_peak_usec) / 1000.0
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var static_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	print("BLACKSTONE_ART_RENDER_BASELINE resolution=1280x720 frames=30 mean_process_frame_ms=%.3f peak_process_frame_ms=%.3f draw_calls=%d render_objects=%d static_memory_bytes=%d" % [mean_ms, peak_ms, int(draw_calls), int(objects), int(static_memory)])
	_check(
		mean_ms >= 0.0 and peak_ms >= mean_ms and draw_calls > 0 and objects > 0 and static_memory > 0.0,
		"图形进程记录固定 1280×720 场景的首份帧时、绘制与内存基线；该记录用于后续比较而不宣称性能提升"
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
	var scout_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	var scout_id := StringName(Dictionary(scout_dispatch.get("specialist", {})).get("specialist_id", &""))
	macro._selected_specialist_id = scout_id
	macro.refresh()
	var scout_visual: Node3D = macro._low_poly_presentation._specialist_nodes.get(scout_id, null)
	var scout_marker_visible := scout_visual != null and scout_visual.find_child("SpecialistSelectionMarker", true, false) != null
	var dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(dispatch.get("specialist", {})).get("specialist_id", &""))
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	var engineer_visual: Node3D = macro._low_poly_presentation._specialist_nodes.get(engineer_id, null)
	var engineer_marker_visible := engineer_visual != null and engineer_visual.find_child("SpecialistSelectionMarker", true, false) != null
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
	var overlay_segments := macro._engineering_overlay_segments(draft)
	var planned_normal := 0
	var planned_bridge := 0
	for segment in overlay_segments:
		if StringName(segment.get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE:
			planned_bridge += 1
		else:
			planned_normal += 1
	var food_before := int(city.food)
	macro._confirm_button.emit_signal("pressed")
	city.advance_war_loop_time(2500)
	macro.refresh()
	var has_active_road := _has_named_descendant(macro._low_poly_presentation._project_root, "ProjectRoadSegment")
	city.advance_war_loop_time(8000)
	macro.refresh()
	var has_active_bridge := _has_named_descendant(macro._low_poly_presentation._project_root, "ProjectBridgeSegment")
	var field: Dictionary = city.get_field_tactics_read_model()
	_check(
		bool(dispatch.get("success", false))
			and bool(scout_dispatch.get("success", false))
			and scout_marker_visible
			and engineer_marker_visible
			and StringName(draft.get("source_point_id", &"")) == &"blackstone_city"
			and THEATER.route_crosses_water(Array(draft.get("route_world_points", [])))
			and macro._draw_points.is_empty()
			and planned_normal >= 2
			and planned_bridge == 1
			and has_active_road
			and has_active_bridge
			and int(draft.get("food_cost", 0)) > 0
			and int(city.food) < food_before
			and not Dictionary(field.get("projects_by_id", {})).is_empty(),
		"图形进程为选中侦察兵和工程师保留可见标记，并在低模模式保留松手后的工程草稿、按权威陆路-桥梁-陆路计划显示分段施工"
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


func _ground_surface_error(presentation: MacroMarchLowPolyPresentation) -> float:
	var ground := presentation._static_root.get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return INF
	var heights: Array = Array(ground.get_meta("ground_corner_heights", []))
	var normal := Vector3(ground.get_meta("ground_surface_normal", Vector3.ZERO))
	if heights.size() != 4:
		return INF
	var min_height := float(heights.front())
	var max_height := min_height
	for height_value in heights:
		min_height = minf(min_height, float(height_value))
		max_height = maxf(max_height, float(height_value))
	return maxf(max_height - min_height, 1.0 - normal.normalized().dot(Vector3.UP))


func _world_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var local := mesh_instance.get_aabb()
	var result := AABB(mesh_instance.global_transform * local.position, Vector3.ZERO)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				result = result.expand(mesh_instance.global_transform * (local.position + local.size * Vector3(x, y, z)))
	return result


func _has_named_descendant(node: Node, expected_name: String) -> bool:
	for child in node.get_children():
		if child.name == expected_name or _has_named_descendant(child, expected_name):
			return true
	return false


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

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
	await _check_location_detail_panel()
	await _check_gui_specialist_selection_overlays()
	await _check_draft_confirmation_priority()
	await _check_long_hold_draw_interaction()
	await _check_engineering_input()
	await _check_continuous_engineering_strokes()
	await _check_replanning_and_specialist_switch_state()
	_finish()


func _check_projection_at_size(viewport_size: Vector2i) -> void:
	_clear_isolated_campaign_generations()
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
	_clear_isolated_campaign_generations()
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
	_draw_route_with_gui(macro, Array(route.get("points", [])))
	var drafted_correct_route := not macro._draft_route.is_empty() and Array(macro._draft_route.get("points", [])).size() >= 2 \
		and StringName(macro._draft_route.get("required_road_id", &"")) == &"road.blackstone.northwatch.ridge"
	await _click_control_with_gui_input(macro._confirm_button)
	macro.refresh()
	var route_constraint_cleared_after_confirm := macro._selected_route_road_id == &"" and macro._draft_route.is_empty()
	var army: Dictionary = Dictionary(macro._selected_army(macro._model()))
	var army_id := StringName(army.get("army_id", &""))
	macro._selected_army_id = &""
	var displayed_army: Dictionary = Dictionary(macro._selected_army(macro._model()))
	var default_army_is_view_only := not displayed_army.is_empty() and macro._selected_army_id == &"" and not macro._has_explicit_command_subject(macro._model(), displayed_army)
	macro._selected_army_id = army_id
	var presentation: MacroMarchLowPolyPresentation = macro._low_poly_presentation
	var actor: Node3D = presentation._army_nodes.get(army_id, null)
	var before := actor.global_position if actor != null else Vector3.ZERO
	var has_selection_marker := actor != null and actor.find_child("ArmySelectionMarker", true, false) != null
	var selection_marker_is_hollow := actor != null and actor.find_child("SelectionRing", true, false) == null and actor.find_child("SelectionPennant", true, false) != null
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
				and route_constraint_cleared_after_confirm
				and default_army_is_view_only
			and actor != null
			and has_selection_marker
			and selection_marker_is_hollow
			and before.distance_to(after) > 0.01
			and two_dimensional_visible
			and presentation.visible
			and city.export_v5_campaign_snapshot() == snapshot_before_toggle,
		"图形进程在低模模式接收鼠标绘线、确认军令并更新军队位置；选中部队使用旗帜配合既有空心圈而非遮挡模型的实心圆盘，二维/三维切换不重发军令或改写状态"
	)
	scene.queue_free()
	await process_frame


func _check_location_detail_panel() -> void:
	_clear_isolated_campaign_generations()
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	# Other graphical fixtures publish campaign generations. Rebuild the playable
	# authority for this formal new-game entry path instead of inheriting a
	# previous fixture's marching army through the persistence coordinator.
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	city.food = 80
	scene.open_macro_march_r0()
	await process_frame
	var macro: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	# Keep the western gate, both the northern route target and the eastern enemy
	# inside the clipped map before injecting the player-facing pointer sequence.
	macro._camera_center = Vector2(650, 500)
	macro._camera_zoom = 0.52
	macro.refresh()
	# Freeze the authoritative clock before comparing snapshots so these GUI entry
	# paths prove only a view change. Map clicks are actual press/release pairs;
	# the location button is activated through the GUI input dispatcher.
	city.set_city_time_paused(true)
	var blackstone_position := macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	var before_blackstone_inspection: Dictionary = city.export_v5_campaign_snapshot()
	_click_map(macro, blackstone_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var blackstone_snapshot_unchanged: bool = city.export_v5_campaign_snapshot() == before_blackstone_inspection
	var blackstone_opened: bool = macro._location_detail_mode \
		and macro._selected_point_id == &"blackstone_city" \
		and macro._detail_label.text.contains("黑石城") \
		and macro._location_garrison_list.visible
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	macro.refresh()
	_click_map(macro, blackstone_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var engineer_selected: bool = macro._selected_specialist_id == engineer_id \
		and macro._location_details_button.is_inside_tree() \
		and macro._location_details_button.visible \
		and not macro._location_details_button.disabled
	var silverford_position := macro._world_to_screen(Vector2(THEATER.get_point(&"silverford_city").get("world_position", Vector2.ZERO)))
	var before_enemy_inspection: Dictionary = city.export_v5_campaign_snapshot()
	_click_map(macro, silverford_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var enemy_view_wins_over_specialist: bool = macro._location_detail_mode \
		and macro._selected_specialist_id == engineer_id \
		and macro._selected_point_id == &"silverford_city" \
		and macro._detail_label.text.contains("控制方：河主军") \
		and city.export_v5_campaign_snapshot() == before_enemy_inspection
	# A short tap at the engineer's anchor restores its subject view. The visible
	# button must then open the actual location with no resource or order write.
	_click_map(macro, blackstone_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var button_precondition: bool = macro._selected_specialist_id == engineer_id \
		and macro._location_details_button.is_inside_tree() \
		and macro._location_details_button.visible \
		and not macro._location_details_button.disabled
	var before_specialist_location: Dictionary = city.export_v5_campaign_snapshot()
	# The visible Button owns this action. SceneTree test scripts do not receive
	# native Button mouse activation for synthetic map events, so keep pointer
	# proof above and exercise this connected Button signal separately rather than
	# pretending an unavailable system mouse path was observed.
	macro._location_details_button.pressed.emit()
	await process_frame
	var specialist_location_opened: bool = macro._location_detail_mode \
		and macro._selected_point_id == &"blackstone_city" \
		and macro._detail_label.text.contains("黑石城") \
		and city.export_v5_campaign_snapshot() == before_specialist_location
	# A direct dispatch after viewing an enemy must replace the old location view
	# with the new army task. Its food delta must be exactly the UI preview cost.
	var formation_id := StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))
	var northwatch_position := macro._world_to_screen(Vector2(THEATER.get_point(&"northwatch_garrison").get("world_position", Vector2.ZERO)))
	var dispatch_food_before := int(city.food)
	_send_map_press(macro, blackstone_position)
	await create_timer(MacroMarchR0.DRAW_HOLD_SECONDS + 0.08).timeout
	await process_frame
	var formation_option_index := -1
	for index in range(macro._direct_dispatch_options.size()):
		var option: Dictionary = Dictionary(macro._direct_dispatch_options[index])
		if StringName(option.get("kind", &"")) == &"FORMATION" and StringName(option.get("formation_id", &"")) == formation_id:
			formation_option_index = index
			break
	if formation_option_index >= 0:
		_send_map_motion(macro, macro._direct_dispatch_option_rect(formation_option_index).get_center())
		_send_map_motion(macro, northwatch_position)
	var dispatch_preview_food := int(macro._direct_dispatch_preview.get("food_cost", -1))
	_send_map_release(macro, northwatch_position)
	await process_frame
	var dispatched_army: Dictionary = Dictionary(macro._selected_army(macro._model()))
	var direct_dispatch_replaces_location_view: bool = formation_option_index >= 0 \
		and not macro._location_detail_mode \
		and macro._selected_point_id == &"" \
		and macro._selected_specialist_id == &"" \
		and StringName(dispatched_army.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING \
		and macro._status_label.text.contains("行军中") \
		and dispatch_preview_food >= 0 \
		and int(city.food) == dispatch_food_before - dispatch_preview_food
	# Complete an engineered camp and exercise the same actual specialist-location
	# entry. World time runs only for the authority construction, then pauses.
	var camp_project: Dictionary = city.begin_field_road_project(
		engineer_id, &"blackstone_city", &"camp.site.location.graphical", [Vector2i(135, 650), Vector2i(250, 650)], FieldTacticsState.ROAD_NORMAL, true
	)
	city.set_city_time_paused(false)
	city.advance_war_loop_time(40000)
	city.set_city_time_paused(true)
	macro.refresh()
	var runtime_points: Dictionary = city._war_loop_state.field_tactics.get_runtime_points()
	var camp_point: Dictionary = Dictionary(runtime_points.get(&"camp.site.location.graphical", {}))
	var camp_position := macro._world_to_screen(Vector2(camp_point.get("world_position", Vector2.ZERO)))
	_click_map(macro, camp_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var camp_engineer_selected: bool = macro._selected_specialist_id == engineer_id \
		and macro._location_details_button.is_inside_tree() \
		and macro._location_details_button.visible
	var before_camp_inspection: Dictionary = city.export_v5_campaign_snapshot()
	macro._location_details_button.pressed.emit()
	await process_frame
	var camp_location_opened: bool = macro._location_detail_mode \
		and macro._selected_point_id == &"camp.site.location.graphical" \
		and macro._detail_label.text.contains("工程驻点") \
		and city.export_v5_campaign_snapshot() == before_camp_inspection
	var before_panel := await _capture_viewport_image()
	_click_map(macro, silverford_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var after_panel := await _capture_viewport_image()
	var changed_pixels := _changed_pixels(before_panel, after_panel, macro._side_panel_rect())
	var panel_changed := changed_pixels > 30
	var has_controller := macro._detail_label.text.contains("控制方：河主军")
	var has_source_restriction := macro._detail_label.text.contains("不能作为我方派遣起点")
	_check(
		blackstone_opened
			and blackstone_snapshot_unchanged
			and bool(engineer_dispatch.get("success", false))
			and engineer_selected
			and enemy_view_wins_over_specialist
			and button_precondition
			and specialist_location_opened
			and direct_dispatch_replaces_location_view
			and not camp_project.is_empty()
			and camp_engineer_selected
			and camp_location_opened
			and macro._location_detail_mode
			and macro._selected_point_id == &"silverford_city"
			and has_controller
			and has_source_restriction
			and macro._location_garrison_list.visible
			and panel_changed,
		"图形入口验证：新局轻点黑石城可只读查看；专员可从敌城视图返回所在地点；快捷派遣成功后显示真实行军；工程完工驻点仍可通过可见按钮查看地点，所有查看快照均无副作用"
	)
	scene.queue_free()
	await process_frame


func _check_formal_art_assets() -> void:
	_clear_isolated_campaign_generations()
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
	var nature_materials_non_metallic := true
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
				var surface_material := mesh_instance.get_surface_override_material(surface)
				material_partitions_match = material_partitions_match and surface_material != null
				nature_materials_non_metallic = nature_materials_non_metallic and surface_material is BaseMaterial3D and absf((surface_material as BaseMaterial3D).metallic) <= 0.0001
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
		asset_paths.size() == 7 and visible_meshes >= 7 and anchors_match and grounding_match and plausible_sizes and material_partitions_match and nature_materials_non_metallic and screen_mapping_match and has_gatehouse and has_watchtower,
		"图形进程实例化七项已登记 CC0 自然素材的非空网格；材质分区、非金属运行时变体、落地锚点、合理包围尺寸及相机/点击投影均有效（素材=%d，网格=%d，锚点=%s，落地=%s，尺寸=%s，材质=%s，非金属=%s，投影=%s）" % [asset_paths.size(), visible_meshes, anchors_match, grounding_match, plausible_sizes, material_partitions_match, nature_materials_non_metallic, screen_mapping_match]
	)
	scene.queue_free()
	await process_frame


func _record_render_baseline() -> void:
	_clear_isolated_campaign_generations()
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


func _check_draft_confirmation_priority() -> void:
	_clear_isolated_campaign_generations()
	root.size = Vector2i(1152, 648)
	var engineering_scene := CITY_SCENE.instantiate()
	root.add_child(engineering_scene)
	await process_frame
	await process_frame
	var engineering_city: Node = engineering_scene.get_node("ConstructionController")
	engineering_city.food = 80
	engineering_scene.open_macro_march_r0()
	await process_frame
	var engineering_macro: MacroMarchR0 = engineering_scene.get_node("UI/MacroMarchR0")
	var engineer_dispatch: Dictionary = engineering_city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var city_screen := engineering_macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	var engineer_selected_by_gui := await _select_specialist_role_with_gui(
		engineering_macro, engineering_city, city_screen, FieldTacticsState.SPECIALIST_ENGINEER
	)
	await _click_control_with_gui_input(engineering_macro._side_road_button)
	_click_map(engineering_macro, city_screen, MOUSE_BUTTON_LEFT)
	_draw_route_with_gui(engineering_macro, [Vector2(150, 650), Vector2(430, 605), Vector2(610, 565), Vector2(760, 610)])
	await process_frame
	var engineering_draft: Dictionary = engineering_macro._engineering_draft.duplicate(true)
	var engineering_confirm_ready := engineering_macro._confirm_button.is_inside_tree() \
		and engineering_macro._confirm_button.visible \
		and not engineering_macro._confirm_button.disabled \
		and engineering_macro._confirm_button.text == "确认施工"
	var engineering_food_before := int(engineering_city.food)
	var engineering_projects_before := Dictionary(engineering_city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	await _click_control_with_gui_input(engineering_macro._confirm_button)
	await process_frame
	var engineering_projects_after := Dictionary(engineering_city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	var engineering_committed_once := engineering_projects_after == engineering_projects_before + 1 \
		and int(engineering_city.food) == engineering_food_before - int(engineering_draft.get("food_cost", 0))
	engineering_scene.queue_free()
	await process_frame
	_clear_isolated_campaign_generations()

	var marching_scene := CITY_SCENE.instantiate()
	root.add_child(marching_scene)
	await process_frame
	await process_frame
	var marching_city: Node = marching_scene.get_node("ConstructionController")
	marching_city.food = 80
	marching_scene.open_macro_march_r0()
	await process_frame
	var marching_macro: MacroMarchR0 = marching_scene.get_node("UI/MacroMarchR0")
	var scout_dispatch: Dictionary = marching_city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	var march_city_screen := marching_macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	var scout_selected_by_gui := await _select_specialist_role_with_gui(
		marching_macro, marching_city, march_city_screen, FieldTacticsState.SPECIALIST_SCOUT
	)
	var formation_button: Button = null
	for candidate_value in marching_macro._formation_buttons:
		var candidate := candidate_value as Button
		if candidate != null and not candidate.disabled:
			formation_button = candidate
			break
	await _click_control_with_gui_input(formation_button)
	var formation_selected := not marching_macro._selected_formation_ids.is_empty() and marching_macro._selected_specialist_id == &""
	var march_route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	_draw_route_with_gui(marching_macro, Array(march_route.get("points", [])))
	await process_frame
	var marching_draft: Dictionary = marching_macro._draft_route.duplicate(true)
	var marching_confirm_ready := marching_macro._confirm_button.is_inside_tree() \
		and marching_macro._confirm_button.visible \
		and not marching_macro._confirm_button.disabled \
		and marching_macro._confirm_button.text == "确认并锁定军令"
	var marching_preview: Dictionary = marching_city.get_macro_march_command_preview(marching_macro._selected_formation_ids)
	var marching_food_before := int(marching_city.food)
	var armies_before := Array(marching_macro._model().get("armies", [])).size()
	await _click_control_with_gui_input(marching_macro._confirm_button)
	await process_frame
	var armies_after := Array(marching_macro._model().get("armies", [])).size()
	var marching_committed_once := armies_after == armies_before + 1 \
		and int(marching_city.food) == marching_food_before - int(marching_preview.get("food_cost", 0))
	_check(
		bool(engineer_dispatch.get("success", false))
			and engineer_selected_by_gui
			and not engineering_draft.is_empty()
			and engineering_confirm_ready
			and engineering_committed_once
			and bool(scout_dispatch.get("success", false))
			and scout_selected_by_gui
			and formation_selected
			and not marching_draft.is_empty()
			and marching_confirm_ready
			and marching_committed_once,
		"图形进程经 GUI 事件完成工程师选中→绘线与专员选中→城市编队绘线；两种有效草稿都在场景树中显示可用确认按钮，并通过实际按钮输入各只提交一次资源事务"
	)
	marching_scene.queue_free()
	await process_frame


func _check_replanning_and_specialist_switch_state() -> void:
	_clear_isolated_campaign_generations()
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
	# This contract exercises the shared 2D input/overlay layer. Keep the
	# unrelated active-project 3D reconstruction out of this state-isolated UI
	# fixture; dedicated low-poly checks above cover that presentation path.
	macro._low_poly_enabled = false
	macro.refresh()
	var formation_button: Button = null
	for candidate_value in macro._formation_buttons:
		var candidate := candidate_value as Button
		if candidate != null and not candidate.disabled:
			formation_button = candidate
			break
	await _click_control_with_gui_input(formation_button)
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var lowland: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
	_draw_route_with_gui(macro, Array(ridge.get("points", [])))
	await process_frame
	var food_before_replan := int(city.food)
	var armies_before_replan := Array(macro._model().get("armies", [])).size()
	var first_draft_is_ridge := StringName(macro._draft_route.get("required_road_id", &"")) == &"road.blackstone.northwatch.ridge"
	var lowland_points: Array = Array(lowland.get("points", []))
	_send_map_press(macro, macro._world_to_screen(Vector2(lowland_points.front())))
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for point_value in lowland_points.slice(1):
		_send_map_motion(macro, macro._world_to_screen(Vector2(point_value)))
	macro.refresh()
	var live_replan_has_priority := macro._is_drawing \
		and StringName(macro._draft_route.get("required_road_id", &"")) == &"road.blackstone.northwatch.ridge" \
		and macro._selected_route_road_id == &"road.blackstone.northwatch.lowland" \
		and not macro._draw_preview_route.is_empty() \
		and not macro._confirm_button.visible \
		and macro._detail_label.text.contains("正在重规划军令")
	_send_map_release(macro, macro._world_to_screen(Vector2(lowland_points.back())))
	await process_frame
	var replacement_draft_ready := StringName(macro._draft_route.get("required_road_id", &"")) == &"road.blackstone.northwatch.lowland" \
		and macro._confirm_button.is_inside_tree() and macro._confirm_button.visible and not macro._confirm_button.disabled \
		and int(city.food) == food_before_replan and Array(macro._model().get("armies", [])).size() == armies_before_replan
	scene.queue_free()
	await process_frame

	_clear_isolated_campaign_generations()
	var stationed_scene := CITY_SCENE.instantiate()
	root.add_child(stationed_scene)
	await process_frame
	await process_frame
	var stationed_city: Node = stationed_scene.get_node("ConstructionController")
	stationed_city.food = 80
	stationed_city.city_time_paused = false
	stationed_city.city_time_speed = 1.0
	stationed_scene.open_macro_march_r0()
	await process_frame
	var stationed_macro: MacroMarchR0 = stationed_scene.get_node("UI/MacroMarchR0")
	stationed_macro._low_poly_enabled = false
	stationed_macro.refresh()
	var stationed_formation_button: Button = null
	for candidate_value in stationed_macro._formation_buttons:
		var candidate := candidate_value as Button
		if candidate != null and not candidate.disabled:
			stationed_formation_button = candidate
			break
	await _click_control_with_gui_input(stationed_formation_button)
	_draw_route_with_gui(stationed_macro, Array(ridge.get("points", [])))
	await _click_control_with_gui_input(stationed_macro._confirm_button)
	await process_frame
	var stationed_army: Dictionary = Dictionary(stationed_macro._selected_army(stationed_macro._model()))
	var stationed_army_id := StringName(stationed_army.get("army_id", &""))
	var stationed_order: Dictionary = Dictionary(stationed_army.get("macro_march", {}))
	var stationed_arrival: Dictionary = stationed_city.advance_macro_march_time(
		stationed_army_id, StringName(stationed_order.get("order_id", &"")), int(stationed_order.get("progress_millis", 0)), int(stationed_order.get("total_millis", 0))
	)
	stationed_macro.refresh()
	stationed_army = Dictionary(stationed_macro._selected_army(stationed_macro._model()))
	var arrived_stationed := bool(stationed_arrival.get("success", false)) and StringName(stationed_army.get("phase", &"")) == &"STATIONED"
	var forest_screen := stationed_macro._world_to_screen(Vector2(THEATER.get_point(&"forest_garrison").get("world_position", Vector2.ZERO)))
	_send_map_press(stationed_macro, forest_screen)
	_send_map_release(stationed_macro, forest_screen)
	await process_frame
	var stationed_draft_ready := not stationed_macro._draft_route.is_empty() and stationed_macro._confirm_button.visible and not stationed_macro._confirm_button.disabled
	var scout_dispatch: Dictionary = stationed_city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	stationed_macro.refresh()
	var city_screen := stationed_macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	# Freeze world time only for the no-side-effect comparison; this keeps the
	# assertion about selection UI rather than a background simulation tick.
	stationed_city.city_time_paused = true
	var snapshot_before_specialist_switch: Dictionary = stationed_city.export_v5_campaign_snapshot()
	_send_map_press(stationed_macro, city_screen)
	_send_map_release(stationed_macro, city_screen)
	await process_frame
	var selected_specialist: Dictionary = Dictionary(stationed_city.get_field_tactics_read_model().get("specialists_by_id", {}).get(stationed_macro._selected_specialist_id, {}))
	var specialist_switch_clears_command_view: bool = bool(scout_dispatch.get("success", false)) \
		and not selected_specialist.is_empty() \
		and StringName(selected_specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT \
		and stationed_macro._selected_army_id == &"" \
		and stationed_macro._draft_route.is_empty() \
		and stationed_macro._selected_route_road_id == &"" \
		and stationed_macro._selected_formation_ids.is_empty() \
		and not stationed_macro._confirm_button.visible \
		and stationed_city.export_v5_campaign_snapshot() == snapshot_before_specialist_switch
	_check(
		first_draft_is_ridge
			and live_replan_has_priority
			and replacement_draft_ready
			and arrived_stationed
			and stationed_draft_ready
			and specialist_switch_clears_command_view,
		"图形进程经连续 GUI 按下→长按→拖动→松开验证：已有山脊草稿重规划时实时低地预览与面板优先、确认按钮不会提交旧草稿；驻扎军队切换侦察兵后清除仅未确认的发令视图，军令、路线、确认入口与资源均无残留副作用"
	)
	stationed_scene.queue_free()
	await process_frame


func _check_long_hold_draw_interaction() -> void:
	_clear_isolated_campaign_generations()
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
	var formation_button: Button = null
	for candidate_value in macro._formation_buttons:
		var candidate := candidate_value as Button
		if candidate != null and not candidate.disabled:
			formation_button = candidate
			break
	await _click_control_with_gui_input(formation_button)
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var route_points: Array = Array(route.get("points", []))
	var field_roads := Dictionary(macro._dispatch_adapter.get_field_tactics_read_model().get("roads_by_id", {}))
	var road_markers := macro._road_choice_markers(field_roads)
	var ridge_marker_visible := false
	for marker_value in road_markers:
		if StringName(Dictionary(marker_value).get("road_id", &"")) == &"road.blackstone.northwatch.ridge":
			ridge_marker_visible = true
			break
	var source_screen := macro._world_to_screen(Vector2(route_points.front()))
	var initial_food := int(city.food)
	var initial_armies := Array(macro._model().get("armies", [])).size()

	# A tap is still a selection gesture.  It never leaves a line, a draft, or
	# an authority-side transaction behind.
	_send_map_press(macro, source_screen)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS * 0.45)
	_send_map_release(macro, source_screen)
	var tap_remains_selection := not macro._draw_hold_pending and not macro._is_drawing \
		and macro._draw_points.is_empty() and macro._draft_route.is_empty()
	# Moving beyond the allowed jitter before the hold completes cancels rather
	# than silently turning a click into an unrelated route draft.
	_send_map_press(macro, source_screen)
	_send_map_motion(macro, source_screen + Vector2(18.0, 0.0))
	var early_drag_cancels := not macro._draw_hold_pending and not macro._is_drawing and macro._draw_points.is_empty() and macro._draft_route.is_empty()

	# Small jitter remains a valid long-press candidate. Planning only starts
	# after elapsed UI time reaches the hold threshold.
	_send_map_press(macro, source_screen)
	_send_map_motion(macro, source_screen + Vector2(5.0, 3.0))
	var jitter_remains_pending := macro._draw_hold_pending and not macro._is_drawing
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for point_value in route_points.slice(1):
		_send_map_motion(macro, macro._world_to_screen(Vector2(point_value)))
	var live_route_matches := not macro._draw_preview_route.is_empty()
	var ridge_constraint_matches := macro._selected_route_road_id == &"road.blackstone.northwatch.ridge"
	var endpoint_follows_pointer: bool = not macro._draw_points.is_empty() and Vector2(macro._draw_points.back()).distance_to(Vector2(route_points.back())) <= 0.1
	_send_map_release(macro, macro._world_to_screen(Vector2(route_points.back())))
	var valid_draft_ready := not macro._draft_route.is_empty() \
		and macro._confirm_button.is_inside_tree() and macro._confirm_button.visible and not macro._confirm_button.disabled \
		and StringName(macro._draft_route.get("required_road_id", &"")) == &"road.blackstone.northwatch.ridge" \
		and int(city.food) == initial_food and Array(macro._model().get("armies", [])).size() == initial_armies
	# Switching the command subject discards only this unconfirmed intent. It
	# cannot leak a road constraint into the next formation's order.
	await _click_control_with_gui_input(formation_button)
	var subject_switch_clears_route_constraint := macro._draft_route.is_empty() and macro._selected_route_road_id == &""
	await _click_control_with_gui_input(formation_button)

	# Cancel is a complete terminal state: later mouse movement must not revive
	# a stale path, and a focus-loss notification shares the same cleanup path.
	_send_map_press(macro, macro._world_to_screen(Vector2(route_points.front())))
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	_send_map_motion(macro, macro._world_to_screen(Vector2(route_points[1])))
	_send_map_right_click(macro, macro._world_to_screen(Vector2(route_points[1])))
	_send_map_motion(macro, macro._world_to_screen(Vector2(route_points.back())))
	var cancel_stops_following := not macro._draw_hold_pending and not macro._is_drawing and macro._draw_points.is_empty() and macro._draw_preview_route.is_empty()

	# Start another gesture near the map edge. The camera displacement is driven
	# by elapsed UI time, not by the number of mouse motion events.
	_send_map_press(macro, source_screen)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	var edge_position := Vector2(macro._map_rect().end.x - 1.0, macro._map_rect().get_center().y)
	_send_map_motion(macro, edge_position)
	var camera_before_edge_scroll := macro._camera_center
	macro._process(0.10)
	macro._process(0.10)
	var edge_scroll_uses_elapsed_time := macro._camera_center.distance_to(camera_before_edge_scroll) > 0.1
	macro._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_send_map_motion(macro, macro._world_to_screen(Vector2(route_points.back())))
	var focus_loss_stops_following := not macro._draw_hold_pending and not macro._is_drawing and macro._draw_points.is_empty()

	# A clearly off-road drag does not get promoted to a free-form army route.
	macro._camera_center = Vector2(500, 325)
	macro._camera_zoom = 1.0
	source_screen = macro._world_to_screen(Vector2(route_points.front()))
	_send_map_press(macro, source_screen)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	_send_map_motion(macro, macro._map_rect().position + Vector2(12, 12))
	_send_map_release(macro, macro._map_rect().position + Vector2(12, 12))
	var off_road_is_rejected := macro._draft_route.is_empty() and macro._draw_points.is_empty() \
		and macro._status_label.text.contains("终点")
	print("DRAW_HOLD_INTERACTION tap=%s early_cancel=%s preview=%s endpoint=%s draft=%s cancel=%s edge=%s focus=%s offroad=%s status=%s" % [
		tap_remains_selection, early_drag_cancels, live_route_matches, endpoint_follows_pointer, valid_draft_ready,
		cancel_stops_following, edge_scroll_uses_elapsed_time, focus_loss_stops_following,
		off_road_is_rejected, macro._status_label.text,
	])
	_check(
			formation_button != null
				and tap_remains_selection
				and early_drag_cancels
		and jitter_remains_pending
		and ridge_marker_visible
		and live_route_matches
		and ridge_constraint_matches
				and endpoint_follows_pointer
				and valid_draft_ready
				and subject_switch_clears_route_constraint
			and cancel_stops_following
			and edge_scroll_uses_elapsed_time
			and focus_loss_stops_following
			and off_road_is_rejected,
		"图形进程经按下→移动→松开验证轻点、8 像素拖动阈值、道路候选预览、右键/失焦取消、离路拒绝和按时间推进的边缘滚屏；预览及取消不创建军令或扣粮"
	)
	scene.queue_free()
	await process_frame


func _check_engineering_input() -> void:
	_clear_isolated_campaign_generations()
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
	var scout_marker_is_hollow := scout_visual != null and scout_visual.find_child("SelectionRing", true, false) == null and scout_visual.find_child("SelectionPennant", true, false) != null
	var dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(dispatch.get("specialist", {})).get("specialist_id", &""))
	macro._selected_specialist_id = engineer_id
	macro.refresh()
	var engineer_visual: Node3D = macro._low_poly_presentation._specialist_nodes.get(engineer_id, null)
	var engineer_marker_visible := engineer_visual != null and engineer_visual.find_child("SpecialistSelectionMarker", true, false) != null
	var engineer_marker_is_hollow := engineer_visual != null and engineer_visual.find_child("SelectionRing", true, false) == null and engineer_visual.find_child("SelectionPennant", true, false) != null
	await _click_control_with_gui_input(macro._side_road_button)
	var source_click := InputEventMouseButton.new()
	source_click.button_index = MOUSE_BUTTON_LEFT
	source_click.pressed = true
	source_click.position = macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	macro._on_gui_input(source_click)
	var construction_points := [Vector2(150, 650), Vector2(430, 605), Vector2(610, 565), Vector2(760, 610)]
	_send_map_press(macro, macro._world_to_screen(construction_points.front()))
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	var engineering_drag_activated := false
	for point in construction_points.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro._world_to_screen(point)
		macro._on_gui_input(motion)
		engineering_drag_activated = engineering_drag_activated or macro._is_drawing
	var engineering_live_preview := not macro._draw_preview_route.is_empty() and not Array(macro._draw_preview_route.get("segment_plans", [])).is_empty()
	_send_map_release(macro, macro._world_to_screen(construction_points.back()))
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
	await _click_control_with_gui_input(macro._confirm_button)
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
			and scout_marker_is_hollow
			and engineer_marker_visible
			and engineer_marker_is_hollow
			and engineering_drag_activated
			and engineering_live_preview
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
		"图形进程为选中侦察兵和工程师保留旗帜配合空心圈的可见标记，并在低模模式保留松手后的工程草稿、按权威陆路-桥梁-陆路计划显示分段施工"
	)
	scene.queue_free()
	await process_frame


func _check_continuous_engineering_strokes() -> void:
	_clear_isolated_campaign_generations()
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
	var city_screen := macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	var engineer_selected := await _select_specialist_role_with_gui(macro, city, city_screen, FieldTacticsState.SPECIALIST_ENGINEER)
	await _click_control_with_gui_input(macro._side_road_button)
	var first_stroke := [Vector2(135, 650), Vector2(300, 630), Vector2(430, 605), Vector2(610, 565), Vector2(760, 610)]
	_draw_world_path_with_gui(macro, first_stroke, 24)
	await process_frame
	var first_draft: Dictionary = macro._engineering_draft.duplicate(true)
	var first_points: Array = Array(first_draft.get("route_world_points", [])).duplicate(true)
	var first_turns_preserved := _contains_world_point_near(first_points, Vector2(430, 605), 5.0) and _contains_world_point_near(first_points, Vector2(610, 565), 5.0)
	var food_before := int(city.food)
	var projects_before := Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size()
	var continuation := [Vector2(760, 610), Vector2(830, 630), Vector2(900, 660), Vector2(1010, 675)]
	_draw_world_path_with_gui(macro, continuation, 18)
	await process_frame
	var continued_draft: Dictionary = macro._engineering_draft.duplicate(true)
	var continued_points: Array = Array(continued_draft.get("route_world_points", [])).duplicate(true)
	var continuation_has_shape := continued_points.size() > first_points.size() and _contains_world_point_near(continued_points, Vector2(900, 660), 5.0)
	await _click_control_with_gui_input(macro._engineering_undo_button)
	await process_frame
	var undo_returns_full_stroke := Array(macro._engineering_draft.get("route_world_points", [])) == first_points and macro._engineering_strokes.size() == 1
	# New camp endpoints are validated by the same Field preview used by the
	# visible draft before any resource or project transaction. An outside-the-map
	# endpoint cannot be emitted by a real map mouse event, so keep this focused
	# authority check separate from the GUI stroke above.
	macro._clear_engineering_draft()
	var invalid_before: Dictionary = city.export_v5_campaign_snapshot()
	var outside_preview: Dictionary = macro._dispatch_adapter.preview_field_road_project(
		engineer_id, &"blackstone_city", &"", [Vector2(135, 650), Vector2(-40, 650)], FieldTacticsState.ROAD_NORMAL, true
	)
	var outside_rejected := not bool(outside_preview.get("valid", true)) and str(outside_preview.get("error", "")).contains("战区范围")
	var water_preview: Dictionary = macro._dispatch_adapter.preview_field_road_project(
		engineer_id, &"blackstone_city", &"", [Vector2(135, 650), Vector2(600, 500)], FieldTacticsState.ROAD_NORMAL, true
	)
	var water_rejected := not bool(water_preview.get("valid", true)) and str(water_preview.get("error", "")).contains("可通行陆地")
	var invalid_has_no_side_effect: bool = city.export_v5_campaign_snapshot() == invalid_before and int(city.food) == food_before and Dictionary(city.get_field_tactics_read_model().get("projects_by_id", {})).size() == projects_before
	_check(
		bool(dispatch.get("success", false))
			and engineer_selected
			and not first_draft.is_empty()
			and first_turns_preserved
			and continuation_has_shape
			and undo_returns_full_stroke
			and outside_rejected
			and water_rejected
			and invalid_has_no_side_effect,
		"图形进程用连续细小 GUI 移动保留工程转折和实时笔尖；续画撤销整笔而非一个采样点，范围外或水中新驻点在预览即拒绝且不扣资源、不建项目"
	)
	scene.queue_free()
	await process_frame


func _check_gui_specialist_selection_overlays() -> void:
	_clear_isolated_campaign_generations()
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
	# Build a real marching subject first, then select it through the map input
	# after it has left the city gate.  Specialist dispatch is fixture setup;
	# every selection below uses the same GUI event entrypoint as a player.
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var formation_id := StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))
	macro._selected_formation_ids = [formation_id]
	_draw_route_with_gui(macro, Array(route.get("points", [])))
	macro._confirm_button.emit_signal("pressed")
	macro.refresh()
	var army: Dictionary = Dictionary(macro._selected_army(macro._model()))
	var army_id := StringName(army.get("army_id", &""))
	var order: Dictionary = Dictionary(army.get("macro_march", {}))
	city.advance_macro_march_time(army_id, StringName(order.get("order_id", &"")), 0, 1000)
	macro.refresh()
	# The issued command is fixture state.  Clear only the view selection before
	# using map GUI input to select the real marching army again.
	macro._selected_formation_ids.clear()
	macro._selected_army_id = &""
	var marching_army := Dictionary(Array(macro._model().get("armies", [])).front())
	var army_position := _army_screen_position(macro, marching_army)
	var before_army_selection := await _capture_viewport_image()
	_click_map(macro, army_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var army_selection := await _capture_viewport_image()
	var army_overlay_pixels := _changed_pixels(before_army_selection, army_selection, Rect2(army_position - Vector2(56, 46), Vector2(112, 76)))
	var selected_army_after_click := macro._selected_army_id
	var army_selected := selected_army_after_click == army_id and macro._selected_specialist_id == &"" and army_overlay_pixels > 30
	var scout_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var scout_id := StringName(Dictionary(scout_dispatch.get("specialist", {})).get("specialist_id", &""))
	var engineer_id := StringName(Dictionary(engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	macro.refresh()
	var city_position := macro._world_to_screen(Vector2(THEATER.get_point(&"blackstone_city").get("world_position", Vector2.ZERO)))
	var before_selection := await _capture_viewport_image()
	_click_map(macro, city_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var first_specialist_selection := await _capture_viewport_image()
	var first_specialist_id := macro._selected_specialist_id
	var first_specialist: Dictionary = Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {}).get(first_specialist_id, {}))
	var first_role := "侦察兵" if StringName(first_specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else "工程师"
	var first_selected := first_specialist_id in [scout_id, engineer_id] and macro._detail_label.text.contains("当前选择：%s" % first_role) and macro._specialist_status_label.text.begins_with(first_role)
	_click_map(macro, city_position, MOUSE_BUTTON_LEFT)
	await process_frame
	var second_specialist_selection := await _capture_viewport_image()
	var second_specialist_id := macro._selected_specialist_id
	var second_specialist: Dictionary = Dictionary(city.get_field_tactics_read_model().get("specialists_by_id", {}).get(second_specialist_id, {}))
	var second_role := "侦察兵" if StringName(second_specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT else "工程师"
	var second_selected := second_specialist_id in [scout_id, engineer_id] and second_specialist_id != first_specialist_id and macro._detail_label.text.contains("当前选择：%s" % second_role) and macro._specialist_status_label.text.begins_with(second_role)
	_click_map(macro, city_position, MOUSE_BUTTON_RIGHT)
	await process_frame
	var cleared_selection := await _capture_viewport_image()
	var selection_rect := Rect2(city_position - Vector2(72, 56), Vector2(144, 92))
	var first_overlay_pixels := _changed_pixels(before_selection, first_specialist_selection, selection_rect)
	var second_overlay_pixels := _changed_pixels(first_specialist_selection, second_specialist_selection, selection_rect)
	var cleared_overlay_pixels := _changed_pixels(second_specialist_selection, cleared_selection, selection_rect)
	var specialist_markers_cleared := true
	for specialist_node_value in macro._low_poly_presentation._specialist_nodes.values():
		var specialist_node := specialist_node_value as Node3D
		if specialist_node != null and specialist_node.find_child("SpecialistSelectionMarker", true, false) != null:
			specialist_markers_cleared = false
	var cleared := macro._selected_specialist_id == &"" and macro._specialist_status_label.text == "专员：未选择" and specialist_markers_cleared
	_check(
		bool(scout_dispatch.get("success", false))
			and bool(engineer_dispatch.get("success", false))
			and army_selected
			and first_selected
			and second_selected
			and [first_role, second_role].has("侦察兵")
			and [first_role, second_role].has("工程师")
			and cleared
			and first_overlay_pixels > 30
			and second_overlay_pixels > 30
			and cleared_overlay_pixels > 30,
		"图形进程通过 GUI 鼠标事件依次选中军队、同城侦察兵与工程师，并从完整界面截图确认低模二维空心圈/角色状态提示出现与取消（军队=%d，%s=%d，%s=%d，取消=%d 像素变化）；不以私有选中 ID 或没有 SelectionRing 网格代替交互证据" % [army_overlay_pixels, first_role, first_overlay_pixels, second_role, second_overlay_pixels, cleared_overlay_pixels]
	)
	scene.queue_free()
	await process_frame


func _clear_isolated_campaign_generations() -> void:
	# Each graphical check creates and publishes real runtime state.  Clear only
	# generations in the caller-supplied temporary store so a previous check
	# cannot remove city formations from the next fixture.
	var save_directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--txwzs-v5-save-dir="):
			save_directory = argument.trim_prefix("--txwzs-v5-save-dir=")
			break
	if save_directory.is_empty() or not save_directory.begins_with(OS.get_temp_dir().path_join("")):
		return
	var directory := DirAccess.open(save_directory)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and (entry.begins_with("campaign_") or entry.begins_with(".pending_")):
			DirAccess.remove_absolute(save_directory.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()


func _draw_route_with_gui(macro: MacroMarchR0, points: Array) -> void:
	if points.is_empty():
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = macro._world_to_screen(Vector2(points.front()))
	macro._on_gui_input(press)
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for point_value in points.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro._world_to_screen(Vector2(point_value))
		macro._on_gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = macro._world_to_screen(Vector2(points.back()))
	macro._on_gui_input(release)


func _draw_world_path_with_gui(macro: MacroMarchR0, points: Array, samples_per_segment: int) -> void:
	if points.size() < 2:
		return
	_send_map_press(macro, macro._world_to_screen(Vector2(points.front())))
	macro._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		for sample in range(1, samples_per_segment + 1):
			_send_map_motion(macro, macro._world_to_screen(start.lerp(end, float(sample) / float(samples_per_segment))))
	_send_map_release(macro, macro._world_to_screen(Vector2(points.back())))


func _contains_world_point_near(points: Array, expected: Vector2, tolerance: float) -> bool:
	for point_value in points:
		if Vector2(point_value).distance_to(expected) <= tolerance:
			return true
	return false


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


func _click_map(macro: MacroMarchR0, position: Vector2, button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	macro._on_gui_input(event)
	# Map selection is a complete press/release click.  Leaving the release out
	# used to strand the new hold-to-dispatch recognizer in a pending state and
	# made later engineering assertions test an impossible desktop input stream.
	event = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = false
	event.position = position
	macro._on_gui_input(event)


func _click_control_with_gui_input(control: Control) -> void:
	if control == null:
		return
	var position := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	await process_frame






func _select_specialist_role_with_gui(
	macro: MacroMarchR0,
	city: Node,
	position: Vector2,
	role: StringName
) -> bool:
	for attempt in range(4):
		_click_map(macro, position, MOUSE_BUTTON_LEFT)
		await process_frame
		var field: Dictionary = city.get_field_tactics_read_model()
		var specialist := Dictionary(Dictionary(field.get("specialists_by_id", {})).get(macro._selected_specialist_id, {}))
		if StringName(specialist.get("role", &"")) == role:
			return true
	return false


func _army_screen_position(macro: MacroMarchR0, army: Dictionary) -> Vector2:
	var display_route := macro._display_route_for_army(army)
	return macro._world_to_screen(macro._point_along_route(
		Array(display_route.get("points", [])),
		float(display_route.get("progress_millis", 0)) / maxf(float(display_route.get("total_millis", 1)), 1.0)
	))


func _capture_viewport_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _changed_pixels(before: Image, after: Image, rect: Rect2) -> int:
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

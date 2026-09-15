extends SceneTree

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var city: Node
var runtime: RegularCampaignRuntime
var view: RegularCampaignView
var output_directory := "/tmp/txwzs-regular-campaign-r1a"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_directory)
	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	city = scene.get_node("ConstructionController")
	city.set_process(false)
	city.initialize_regular_campaign()
	runtime = city._regular_campaign
	city.show_regular_campaign()
	view = city._regular_campaign_view
	await process_frame
	_expect(view._map._presentation._foundation.get_script().resource_path == "res://scripts/regular_city_spatial_foundation.gd", "city surface instantiates the established spatial foundation")
	_expect(view._map._presentation._minimap.get_script().resource_path == "res://scripts/city_minimap_r1.gd", "city surface instantiates the established minimap")

	var formation_ids: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			formation_ids.append(formation.formation_id)
	_expect(runtime.command(&"depart", {"formation_ids": formation_ids, "food": 30, "wood": 55}).get("success", false), "normal departure")
	runtime.advance(1.0)
	view.refresh(true)
	await process_frame
	_expect(view._surface_mode == &"THEATER", "normal departure opens this campaign's theater")
	await _capture("00-original-theater-before-city-entry-1280x720.png")
	await create_timer(1.4).timeout
	var base_point := Dictionary(Dictionary(view._model.get("points", {})).get(&"blackstone_city", {}))
	await _click_map_local(view._map._screen(Vector2(base_point.get("world_position", Vector2.ZERO))))
	_expect(view._surface_mode == &"CITY", "mouse click on eligible city opens its wartime inner city")
	await create_timer(0.25).timeout
	print("R1A_LAYOUT root=", root.size, " view=", view.size, " frame=", view._map_frame.get_global_rect(), " stack=", view._map.get_parent().get_global_rect(), " map=", view._map.get_global_rect(), " min=", view._map.get_combined_minimum_size())
	_expect(view._map.get_global_rect().end.y <= view.size.y, "city surface fits inside the viewport")
	await _click_map_local(view._map._city_plot_rect(5).get_center())
	_expect(view._selected_plot == 5, "mouse reaches the lower-row site in the default view")
	await _capture("01-real-city-empty-1280x720.png")
	await create_timer(1.4).timeout

	await _click_map_local(view._map._city_plot_rect(0).get_center())
	await create_timer(0.25).timeout
	_expect(view._selected_plot == 0 and view._active_tab == &"BUILD", "mouse selects real plot")
	var build_button := _find_button(view, "在城内选中地块开工")
	_expect(build_button != null and not build_button.disabled, "build button is available for selected plot")
	if build_button != null:
		await _click_control(build_button)
	print("R1A_BUILD_CLICK rect=", build_button.get_global_rect() if build_button != null else Rect2(), " feedback=", view._feedback_override, " project=", runtime.data.project)
	_expect(not runtime.data.project.is_empty() and int(runtime.data.project.plot) == 0 and runtime.data.project.kind == &"FARM", "GUI build submits authoritative farm project")
	if runtime.data.project.is_empty():
		_finish(scene)
		return
	runtime.advance(32.0)
	view.refresh(true)
	await process_frame
	await _capture("02-real-farm-construction-1280x720.png")
	await create_timer(1.4).timeout

	runtime.advance(58.0)
	view.refresh(true)
	await process_frame
	_expect(runtime.data.buildings.size() == 1, "farm completes from runtime clock")
	var building_id: StringName = runtime.data.buildings[0].id
	var building_visual: Node = view._map._presentation._building_visuals.get(building_id)
	_expect(is_instance_valid(building_visual) and building_visual.get_script().resource_path == "res://scripts/graybox_building_visual.gd", "real farm is rendered by the established building visual")
	await _click_map_local(view._map._city_plot_rect(0).get_center())
	_expect(view._selected_building_id == runtime.data.buildings[0].id, "mouse selects model-backed building id")
	await _capture("03-real-farm-disconnected-1280x720.png")
	await create_timer(1.4).timeout
	var connect_button := _find_button(view, "连接农田")
	_expect(connect_button != null, "road action is visible for selected farm")
	if connect_button != null:
		await _click_control(connect_button)
	var worker_button := _find_worker_button(view, "4")
	_expect(worker_button != null, "worker action is visible for selected farm")
	if worker_button != null:
		await _click_control(worker_button)
	runtime.advance(180.0)
	view.refresh(true)
	await process_frame
	_expect(bool(runtime.data.buildings[0].connected), "road command persists on real building")
	_expect(int(runtime.data.buildings[0].workers) == 4, "worker command persists on real building")
	_expect(int(runtime._stock().food) > 30, "staffed connected real farm produces local food")
	await _capture("04-real-farm-producing-1280x720.png")
	await create_timer(1.4).timeout

	runtime.command(&"view", {"surface": &"THEATER"})
	view.refresh(true)
	await process_frame
	runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"})
	view.refresh(true)
	await process_frame
	_expect(runtime.data.buildings.size() == 1 and runtime.data.buildings[0].id == view._selected_building_id, "theater round trip preserves building identity and selection")
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	_expect(view._map.get_global_rect().end.y <= view.size.y, "compact city surface fits inside the viewport")
	await _click_map_local(view._map._city_plot_rect(5).get_center())
	_expect(view._selected_plot == 5, "compact view reaches the lower-row site")
	await _click_map_local(view._map._city_plot_rect(0).get_center())
	await _capture("05-real-farm-producing-1152x648.png")
	await create_timer(1.4).timeout

	_finish(scene)


func _finish(scene: Node) -> void:
	print("R1A_CITY_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)


func _click_map_local(local_position: Vector2) -> void:
	await _click_position(view._map.get_global_rect().position + local_position)


func _click_control(control: Control) -> void:
	print("R1A_CLICK control=", control.text, " rect=", control.get_global_rect(), " disabled=", control.disabled)
	await _click_position(control.get_global_rect().get_center())


func _click_position(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _find_button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child
	return null


func _find_worker_button(node: Node, text: String) -> Button:
	var matches: Array[Button] = []
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text == text and child.is_visible_in_tree():
			matches.append(child)
	return matches[0] if not matches.is_empty() else null


func _capture(filename: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_directory.path_join(filename)
	if image == null or image.save_png(path) != OK:
		failures.append("capture failed: " + path)
	else:
		print("R1A_IMAGE ", path, " pixels=", image.get_size())


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)

extends SceneTree

const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const PLOT_CELLS := [
	Vector2i(9, 8), Vector2i(19, 8), Vector2i(36, 8),
	Vector2i(9, 18), Vector2i(19, 18), Vector2i(36, 18),
]

var failures: Array[String] = []
var scene: Node2D
var city: Node
var runtime: RegularCampaignRuntime
var camera: Camera2D
var selection: Node
var output_directory := "/tmp/txwzs-regular-campaign-r1a-main-city"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_directory)
	root.size = Vector2i(1280, 720)
	scene = CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	city = scene.get_node("ConstructionController")
	camera = scene.get_node("Camera2D")
	selection = scene.get_node("BuildingSelectionController")
	city.set_process(false)
	city.initialize_regular_campaign()
	runtime = city._regular_campaign
	city.show_regular_campaign_home_entry()
	await process_frame

	_expect(not city.is_regular_campaign_view_visible(), "fresh campaign remains on the established permanent-city main screen")
	_expect(scene.get_node("MapWorld").visible and scene.get_node("UI/Shell").visible, "main MapWorld and original UI shell remain visible")
	_expect(is_equal_approx(camera.zoom.x, 1.0), "established default city scale is 1:1 rather than whole-city fit")

	var formation_ids: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			formation_ids.append(formation.formation_id)
	_expect(runtime.command(&"depart", {"formation_ids": formation_ids, "food": 30, "wood": 55}).get("success", false), "normal departure")
	runtime.advance(1.0)
	var permanent_building_count: int = city._building_records_by_id.size()
	var home_food_after_departure: int = city.food
	var home_wood_after_departure: int = city.wood
	city.show_regular_campaign()
	await process_frame
	_expect(city.is_regular_campaign_view_visible(), "normal departure opens the existing campaign theater")
	_expect(runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"}).get("success", false), "eligible city opens wartime inner city")
	city.show_regular_campaign_city()
	await process_frame
	await process_frame

	_expect(city.is_regular_campaign_city_active(), "wartime city is hosted by the established city scene")
	_expect(not city.is_regular_campaign_view_visible(), "left-preview campaign management surface is absent in the city")
	_expect(city._regular_campaign_city_host.get_script().resource_path == "res://scripts/regular_campaign/regular_campaign_city_host.gd", "campaign buildings use the MapWorld host adapter")
	_expect(scene.get_node("UI/Shell/TopStatusBar").visible, "original top status layout remains visible")
	_expect(scene.get_node("UI/Shell/MinimapPlaceholder").visible, "original minimap layout remains visible")
	_expect(is_equal_approx(camera.zoom.x, 1.0), "wartime city opens at established operational scale")
	_expect(city.show_regular_campaign_city() and not city.placed_buildings.visible, "repeated city presentation is idempotent")
	await _capture("01-main-city-empty-1280x720.png")

	await _click_world(_plot_center(0))
	_expect(city._regular_campaign_selected_plot == 0, "map click selects a real campaign plot")
	var farm_button := _find_button_prefix(scene, "农田 ·")
	_expect(farm_button != null and not farm_button.disabled, "original construction catalog offers the campaign farm")
	if farm_button != null:
		await _click_control(farm_button)
	_expect(not runtime.data.project.is_empty() and int(runtime.data.project.plot) == 0 and runtime.data.project.kind == &"FARM", "catalog click submits authoritative farm project")
	_expect(city._building_records_by_id.size() == permanent_building_count, "campaign construction does not create permanent-city records")
	_expect(city.food == home_food_after_departure and city.wood == home_wood_after_departure, "campaign construction does not spend permanent-city resources")
	runtime.advance(32.0)
	city.refresh_regular_campaign_city()
	await process_frame
	await _capture("02-main-city-farm-construction-1280x720.png")

	runtime.advance(58.0)
	city.refresh_regular_campaign_city()
	await process_frame
	_expect(runtime.data.buildings.size() == 1, "farm completes from the campaign runtime clock")
	if runtime.data.buildings.is_empty():
		_finish()
		return
	await _click_world(_plot_center(0))
	_expect(selection.has_selection(), "existing building selection controller selects the real campaign building")
	var selected_record: Dictionary = city.get_building_record(selection.selected_placement_id)
	_expect(StringName(selected_record.get("id", &"")) == StringName(runtime.data.buildings[0].id), "selection resolves to the authoritative campaign building id")
	var camera_before_detail := camera.position
	var zoom_before_detail := camera.zoom
	await _capture("03-main-city-farm-detail-1280x720.png")
	var connect_button := _find_button_exact(scene, "连接道路 · 木材 2")
	_expect(connect_button != null, "detail panel exposes the existing road command")
	if connect_button != null:
		await _click_control(connect_button)
	for count in range(4):
		var worker_button := _find_button_prefix(scene, "增加岗位")
		if worker_button != null and not worker_button.disabled:
			await _click_control(worker_button)
	_expect(bool(runtime.data.buildings[0].connected), "road command persists on the campaign building")
	_expect(int(runtime.data.buildings[0].workers) == 4, "worker commands persist on the campaign building")
	_expect(camera.position.is_equal_approx(camera_before_detail) and camera.zoom.is_equal_approx(zoom_before_detail), "opening and operating detail does not reset the camera")
	runtime.advance(180.0)
	city.refresh_regular_campaign_city()
	await process_frame
	_expect(int(runtime._stock().food) > 30, "staffed connected farm produces real local food")
	await _capture("04-main-city-farm-producing-1280x720.png")

	selection.clear_selection()
	var camera_before_pan := camera.position
	await _drag(Vector2(620, 430), Vector2(520, 360))
	_expect(not camera.position.is_equal_approx(camera_before_pan), "main city pans with the original map controller")
	var zoom_before_wheel := camera.zoom.x
	await _wheel(Vector2(620, 430), MOUSE_BUTTON_WHEEL_UP)
	_expect(camera.zoom.x > zoom_before_wheel, "main city zooms around the pointer")
	await _click_world(_plot_center(0))
	_expect(selection.has_selection(), "building remains hittable after pan and zoom")
	var preserved_position := camera.position
	var preserved_zoom := camera.zoom
	var elapsed_before_round_trip := int(runtime.data.mainline_elapsed_ms)
	_expect(scene.open_macro_march_r0(), "city return button opens the same campaign theater")
	await process_frame
	_expect(city.is_regular_campaign_view_visible() and not city.is_regular_campaign_city_active(), "theater hides city interaction without changing ownership")
	_expect(city.placed_buildings.visible == city._permanent_placed_buildings_visible, "leaving the campaign city restores permanent building presentation")
	_expect(int(runtime.data.mainline_elapsed_ms) == elapsed_before_round_trip, "scene return itself does not advance campaign time")
	_expect(runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"}).get("success", false), "same licensed city can be re-entered")
	city.show_regular_campaign_city()
	await process_frame
	_expect(camera.position.is_equal_approx(preserved_position) and camera.zoom.is_equal_approx(preserved_zoom), "theater round trip restores the same city camera")
	_expect(runtime.data.buildings.size() == 1 and int(runtime.data.buildings[0].workers) == 4, "theater round trip preserves building and jobs")
	_expect(city._building_records_by_id.size() == permanent_building_count and int(runtime.data.departure_ledger.food) == 30 and int(runtime.data.departure_ledger.wood) == 55, "permanent and campaign building/resource ledgers remain isolated")

	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	_expect(camera.position.is_equal_approx(preserved_position) and camera.zoom.is_equal_approx(preserved_zoom), "window resize does not reset the city camera")
	await _click_world(_plot_center(0))
	_expect(selection.has_selection(), "compact layout keeps transformed building hit testing")
	await _capture("05-main-city-farm-producing-1152x648.png")

	_finish()


func _plot_center(plot: int) -> Vector2:
	return Vector2(PLOT_CELLS[plot]) * 40.0 + Vector2(80.0, 60.0)


func _screen_for_world(world_position: Vector2) -> Vector2:
	return scene.get_node("MapWorld").get_global_transform_with_canvas() * world_position


func _click_world(world_position: Vector2) -> void:
	await _click_position(_screen_for_world(world_position))


func _click_control(control: Control) -> void:
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


func _drag(start: Vector2, finish: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = start
	down.global_position = start
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	root.push_input(motion, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = finish
	up.global_position = finish
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	root.push_input(up, true)
	await process_frame


func _wheel(position: Vector2, button_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button_index
	event.pressed = true
	root.push_input(event, true)
	await process_frame


func _find_button_exact(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child
	return null


func _find_button_prefix(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child is Button and child.text.begins_with(prefix) and child.is_visible_in_tree():
			return child
	return null


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_directory.path_join(filename)
	if image == null or image.save_png(path) != OK:
		failures.append("capture failed: " + path)
	else:
		print("R1A_MAIN_CITY_IMAGE ", path, " pixels=", image.get_size())


func _finish() -> void:
	print("R1A_MAIN_CITY_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)

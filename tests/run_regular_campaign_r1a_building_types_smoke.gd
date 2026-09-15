extends SceneTree

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var output_directory := "/tmp/txwzs-regular-campaign-r1a-types"
var city: Node
var runtime: RegularCampaignRuntime
var scene: Node2D


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
	city.set_process(false)
	city.initialize_regular_campaign()
	runtime = city._regular_campaign
	city.show_regular_campaign()
	var ids: Array = []
	for formation in city._garrison_state.get_formations():
		if int(formation.member_count) > 0:
			ids.append(formation.formation_id)
	_require(runtime.command(&"depart", {"formation_ids": ids, "food": 30, "wood": 55}), "departure")
	_require(runtime.command(&"view", {"surface": &"CITY", "city_id": &"blackstone_city"}), "enter eligible wartime inner city")
	_expect(city.show_regular_campaign_city(), "fixture uses the formal MapWorld wartime-city host")
	runtime.advance(1.0)
	await _build(&"LOGGING", 1)
	runtime.advance(360.0)
	await _build(&"FARM", 0)
	runtime.advance(720.0)
	await _build(&"WAREHOUSE", 2)
	runtime.advance(360.0)
	await _build(&"CLINIC", 3)
	city.refresh_regular_campaign_city()
	await process_frame
	_expect(runtime.data.buildings.size() == 4, "all four existing R1 building types use real records")
	var kinds: Dictionary = {}
	for building in runtime.data.buildings:
		kinds[building.kind] = building.id
		_expect(bool(building.connected), "%s has a real road record" % building.kind)
		_expect(int(building.workers) == 4, "%s has a real worker record" % building.kind)
		var placement_id := RegularCampaignCityHost.PLACEMENT_ID_BASE + int(building.plot)
		var record: Dictionary = city._regular_campaign_city_host.get_record(placement_id)
		var visual: Node = city._regular_campaign_city_host.get_visual(placement_id)
		_expect(is_instance_valid(visual), "%s has an in-scene visual bound to its real building id" % building.kind)
		if is_instance_valid(visual):
			_expect(visual.get_script().resource_path == "res://scripts/graybox_building_visual.gd", "%s uses the established building visual component" % building.kind)
			_expect(StringName(record.get("id", &"")) == building.id, "%s host record retains its authoritative building id" % building.kind)
			_expect(visual.position == Vector2(RegularCampaignCityHost.PLOT_CELLS[int(building.plot)]) * RegularCampaignCityHost.GRID_SIZE, "%s uses the authored world coordinate" % building.kind)
			var art := visual.get_node("ArtSprite") as Sprite2D
			_expect(art.texture != null and art.texture.resource_path.ends_with("/%s.png" % String(building.kind).to_lower()), "%s uses its preserved texture in the formal MapWorld" % building.kind)
			var bounds: Rect2 = record.get("selection_bounds", Rect2())
			var center: Vector2 = visual.position + bounds.size * 0.5
			_expect(city._regular_campaign_city_host.get_plot_at_world_position(center) == int(building.plot), "%s world coordinate resolves through the same hit projection" % building.kind)
			var screen: Vector2 = scene.get_node("MapWorld").get_global_transform_with_canvas() * center
			var restored_world: Vector2 = scene.get_node("MapWorld").get_global_transform_with_canvas().affine_inverse() * screen
			_expect(restored_world.is_equal_approx(center), "%s camera transform round-trips its hit coordinate" % building.kind)
			var selection := scene.get_node("BuildingSelectionController")
			selection.select_placement(placement_id)
			_expect(selection.selected_placement_id == placement_id and StringName(city.get_building_record(placement_id).get("id", &"")) == building.id, "%s detail selects the same authoritative record" % building.kind)
	_expect(kinds.size() == 4, "farm, logging, warehouse and clinic remain distinct records")
	_expect(not city._regular_campaign_city_host._buildable_plots_visible, "normal browsing does not persistently paint every empty construction range")
	await _capture("05-all-real-building-types-1280x720.png")
	var camera := scene.get_node("Camera2D") as Camera2D
	for building in runtime.data.buildings:
		var placement_id := RegularCampaignCityHost.PLACEMENT_ID_BASE + int(building.plot)
		var visual := city._regular_campaign_city_host.get_visual(placement_id) as CanvasItem
		camera.position = visual.position + Vector2(80.0, 60.0)
		scene.get_node("BuildingSelectionController").select_placement(placement_id)
		await _capture("asset-%s-formal-mapworld-1280x720.png" % String(building.kind).to_lower())
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	await _capture("06-all-real-building-types-1152x648.png")
	print("R1A_BUILDING_TYPES ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)


func _build(kind: StringName, plot: int) -> void:
	_require(runtime.command(&"build", {"point_id": &"blackstone_city", "kind": kind, "plot": plot}), "build %s" % kind)
	runtime.advance(90.0)
	var building: Dictionary = {}
	for value in runtime.data.buildings:
		if int(value.plot) == plot:
			building = value
			break
	_expect(not building.is_empty(), "%s completes on its selected plot" % kind)
	if building.is_empty():
		return
	_require(runtime.command(&"connect", {"building_id": building.id}), "connect %s" % kind)
	_require(runtime.command(&"workers", {"building_id": building.id, "count": 4}), "staff %s" % kind)


func _require(receipt: Dictionary, message: String) -> void:
	_expect(bool(receipt.get("success", false)), "%s: %s" % [message, receipt])


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
		print("R1A_TYPE_IMAGE ", path, " pixels=", image.get_size())


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)

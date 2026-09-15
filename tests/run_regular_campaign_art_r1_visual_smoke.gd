extends SceneTree

const BRIDGE := preload("res://scripts/regular_campaign/regular_campaign_presentation_bridge.gd")
var output := "/tmp/txwzs-art-r1-visual"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var bridge := BRIDGE.new()
	bridge.size = Vector2(900, 650)
	root.add_child(bridge)
	await process_frame
	var records := [
		{"id": &"art.farm", "kind": &"FARM", "plot": 0, "connected": true, "workers": 4},
		{"id": &"art.logging", "kind": &"LOGGING", "plot": 1, "connected": true, "workers": 4},
		{"id": &"art.warehouse", "kind": &"WAREHOUSE", "plot": 2, "connected": true, "workers": 4},
		{"id": &"art.clinic", "kind": &"CLINIC", "plot": 3, "connected": true, "workers": 4},
	]
	var model := {"view_context": {"city_id": &"blackstone_city"}, "local": {"buildings": records, "project": {}}, "totals": {"food_produced": 0, "wood_produced": 0}, "paused": false}
	bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	for record in records:
		var visual: GrayboxBuildingVisual = bridge._building_visuals[record.id]
		assert(visual.art_enabled and (visual.get_node("ArtSprite") as Sprite2D).texture != null)
		assert(not (visual.get_node("Outline") as Line2D).visible or visual.selected)
	await _capture("01-four-building-fixture-1280x720.png")
	root.size = Vector2i(1152, 648)
	bridge.size = Vector2(820, 578)
	await process_frame
	await _capture("02-four-building-fixture-1152x648.png")
	var farm: GrayboxBuildingVisual = bridge._building_visuals[&"art.farm"]
	farm.set_activity_state(false, true, false)
	assert(farm.work_effect_active and farm.is_processing())
	for index in range(8):
		await create_timer(0.12).timeout
		farm._process(0.12)
		await _capture("farm-work-%02d.png" % index)
	model.paused = true
	bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	assert(farm.simulation_paused and not farm.work_effect_active and not farm.is_processing())
	model.paused = false
	bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	model.totals.food_produced = 5
	bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	assert((farm.get_node("DepositPopup") as Label).visible)
	await create_timer(1.3).timeout
	bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	assert(not (farm.get_node("DepositPopup") as Label).visible)
	bridge.set_projection(model, &"THEATER", &"", &"art.farm", 0)
	bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	assert(not (farm.get_node("DepositPopup") as Label).visible)
	var restored_bridge := BRIDGE.new()
	restored_bridge.size = bridge.size
	root.add_child(restored_bridge)
	await process_frame
	restored_bridge.set_projection(model, &"CITY", &"", &"art.farm", 0)
	var restored_farm := restored_bridge._building_visuals[&"art.farm"] as GrayboxBuildingVisual
	assert(not (restored_farm.get_node("DepositPopup") as Label).visible)
	restored_bridge.queue_free()
	farm.set_activity_state(false, false, false)
	var project := {"id": &"art.project", "kind": &"FARM", "plot": 4, "connected": false, "workers": 0, "progress_ms": 45000, "required_ms": 90000, "advancing": false}
	model.local.project = project
	bridge.set_projection(model, &"CITY", &"", &"art.project", 4)
	var project_visual := bridge._building_visuals[&"art.project"] as GrayboxBuildingVisual
	assert(not project_visual.construction_effect_active and not project_visual.is_processing())
	project.advancing = true
	model.local.project = project
	bridge.set_projection(model, &"CITY", &"", &"art.project", 4)
	assert(project_visual.construction_effect_active and project_visual.is_processing())
	for index in range(8):
		await create_timer(0.12).timeout
		project_visual._process(0.12)
		await _capture("construction-%02d.png" % index)
	print("ART_R1_VISUAL PASS")
	quit()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(name)) == OK)

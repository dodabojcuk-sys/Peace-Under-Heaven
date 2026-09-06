extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"
const OUTPUT_DIRECTORY := "res://docs/evidence/city_governance_interaction_001"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		push_error("Cannot create governance evidence directory")
		quit(1)
		return
	await _capture_default(Vector2i(1152, 648), "01-city-governance-default-1152x648.png")
	await _capture_default(Vector2i(1280, 720), "02-city-governance-default-1280x720.png")
	await _capture_default(Vector2i(1440, 900), "03-city-governance-default-1440x900.png")
	await _capture_disconnected_selected()
	await _capture_unique_recommendation()
	await _capture_ambiguous_rejection()
	print("CITY_GOVERNANCE_EVIDENCE: PASS")
	quit(0)


func _capture_default(size: Vector2i, filename: String) -> void:
	var data := await _new_city(size)
	await _capture(filename)
	await _drop_city(data.scene)


func _capture_disconnected_selected() -> void:
	var data := await _new_city(Vector2i(1440, 900))
	var placement_id: int = data.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(36, 16), false, true, 0
	)
	data.selection.select_placement(placement_id)
	await process_frame
	await _capture("04-disconnected-building-selected-1440x900.png")
	await _drop_city(data.scene)


func _capture_unique_recommendation() -> void:
	var data := await _new_city(Vector2i(1440, 900))
	var placement_id: int = data.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(33, 16), false, true, 0
	)
	data.selection.select_placement(placement_id)
	await process_frame
	var primary := data.shell.get_node(
		"BuildingDetailPanel/GovernanceActionGroup/GovernancePrimaryAction"
	) as Button
	primary.emit_signal("pressed")
	await process_frame
	await _capture("05-unique-connection-preview-1440x900.png")
	await _drop_city(data.scene)


func _capture_ambiguous_rejection() -> void:
	var data := await _new_city(Vector2i(1440, 900))
	var placement_id: int = data.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(31, 17), false, true, 0
	)
	data.selection.select_placement(placement_id)
	await process_frame
	var primary := data.shell.get_node(
		"BuildingDetailPanel/GovernanceActionGroup/GovernancePrimaryAction"
	) as Button
	primary.emit_signal("pressed")
	await process_frame
	await _capture("06-ambiguous-route-manual-planning-1440x900.png")
	await _drop_city(data.scene)


func _new_city(size: Vector2i) -> Dictionary:
	root.size = size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_city_time_paused(true)
	return {
		"scene": scene,
		"city": city,
		"selection": scene.get_node("BuildingSelectionController"),
		"shell": scene.get_node("UI/Shell"),
	}


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Governance evidence viewport returned no image")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIRECTORY, filename])
	if image.save_png(path) != OK:
		push_error("Cannot save governance evidence: %s" % path)
		quit(1)


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame

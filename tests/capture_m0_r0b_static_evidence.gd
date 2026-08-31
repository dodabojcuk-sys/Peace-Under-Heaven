extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"
const OUTPUT_DIRECTORY := "res://docs/m0/evidence/r0b"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _capture_legal_1152()
	await _capture_success_1152()
	await _capture_road_failure_1152()
	await _capture_shortage_1152()
	await _capture_shortage_1280()
	await _capture_standard_1440()
	print("M0_R0B_STATIC_EVIDENCE: PASS")
	quit(0)


func _capture_legal_1152() -> void:
	var data := await _new_city(Vector2i(1152, 648), 100)
	data.city.begin_placing_definition(LOGGING_ID, _cell_center(data.city, Vector2i(18, 15)))
	await process_frame
	await _capture("01-legal-green-preview-1152x648.png")
	await _drop_city(data.scene)


func _capture_success_1152() -> void:
	var data := await _new_city(Vector2i(1152, 648), 100)
	var screen := _cell_center(data.city, Vector2i(18, 15))
	data.city.begin_placing_definition(LOGGING_ID, screen)
	data.city.commit_building_from_map_click(screen)
	await process_frame
	await _capture("02-direct-click-success-1152x648.png")
	await _drop_city(data.scene)


func _capture_road_failure_1152() -> void:
	var data := await _new_city(Vector2i(1152, 648), 100)
	var screen := _cell_center(data.city, Vector2i(18, 13))
	data.city.begin_placing_definition(LOGGING_ID, screen)
	data.city.commit_building_from_map_click(screen)
	await process_frame
	await _capture("03-road-overlap-feedback-1152x648.png")
	await create_timer(2.6).timeout
	await _drop_city(data.scene)


func _capture_shortage_1152() -> void:
	var data := await _new_city(Vector2i(1152, 648), 33)
	data.city.begin_placing_definition(LOGGING_ID, _cell_center(data.city, Vector2i(18, 15)))
	await process_frame
	await _capture("04-material-shortage-1152x648.png")
	await _drop_city(data.scene)


func _capture_shortage_1280() -> void:
	var data := await _new_city(Vector2i(1280, 720), 33)
	data.city.begin_placing_definition(LOGGING_ID, _cell_center(data.city, Vector2i(18, 15)))
	await process_frame
	await _capture("05-dense-shortage-1280x720.png")
	await _drop_city(data.scene)


func _capture_standard_1440() -> void:
	var data := await _new_city(Vector2i(1440, 900), 100)
	data.city.begin_placing_definition(LOGGING_ID, _cell_center(data.city, Vector2i(18, 15)))
	await process_frame
	await _capture("06-standard-green-preview-1440x900.png")
	await _drop_city(data.scene)


func _new_city(size: Vector2i, wood: int) -> Dictionary:
	root.size = size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_city_time_paused(true)
	city.wood = wood
	city._refresh_city_ui()
	return {"scene": scene, "city": city}


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _cell_center(city: Node, cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(
		city.cell_to_map_local(cell) + Vector2(40.0, 40.0)
	)


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIRECTORY, filename])
	var error := image.save_png(path)
	if error != OK:
		push_error("Cannot save R0B evidence: %s" % path)
		quit(1)

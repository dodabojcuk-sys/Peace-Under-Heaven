extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"
const OUTPUT_DIRECTORY := "res://docs/m0/evidence/r0c"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		push_error("Cannot create R0C evidence directory")
		quit(1)
		return
	await _capture_idle_catalog()
	await _capture_producing()
	await _capture_zero_waiting()
	await _capture_auto_resumed()
	await _capture_ready()
	await _capture_invalid_placement()
	await _capture_success()
	await _capture_dense_1280()
	await _capture_standard_1440()
	await _capture_legacy_lock()
	print("M0_R0C_STATIC_EVIDENCE: PASS")
	quit(0)


func _capture_idle_catalog() -> void:
	var data := await _new_city(Vector2i(1152, 648), 100)
	data.city.open_construction_menu()
	await _capture("01-idle-build-catalog-1152x648.png")
	await _drop_city(data.scene)


func _capture_producing() -> void:
	var data := await _new_city(Vector2i(1152, 648), 40)
	data.city.start_build_project(LOGGING_ID)
	data.city.advance_city_time_for_test(45.0)
	data.city.set_city_time_paused(true)
	await _capture("02-producing-progress-1152x648.png")
	await _drop_city(data.scene)


func _capture_zero_waiting() -> void:
	var data := await _new_city(Vector2i(1152, 648), 0)
	data.city.start_build_project(LOGGING_ID)
	await _capture("03-zero-material-waiting-1152x648.png")
	await _drop_city(data.scene)


func _capture_auto_resumed() -> void:
	var data := await _new_city(Vector2i(1152, 648), 10)
	data.city.start_build_project(LOGGING_ID)
	data.city.advance_city_time_for_test(45.0)
	data.city.advance_city_time_for_test(1.0)
	data.city.wood = 30
	data.city.advance_city_time_for_test(1.0)
	data.city.set_city_time_paused(true)
	await _capture("04-material-refill-auto-resume-1152x648.png")
	await _drop_city(data.scene)


func _capture_ready() -> void:
	var data := await _new_city(Vector2i(1152, 648), 40)
	data.city.start_build_project(LOGGING_ID)
	data.city.advance_city_time_for_test(180.0)
	await _capture("05-ready-to-place-no-world-object-1152x648.png")
	await _drop_city(data.scene)


func _capture_invalid_placement() -> void:
	var data := await _new_city(Vector2i(1152, 648), 40)
	data.city.start_build_project(LOGGING_ID)
	data.city.advance_city_time_for_test(180.0)
	var screen := _cell_center(data.city, Vector2i(18, 13))
	data.city.activate_ready_placement(screen)
	data.city.commit_building_from_map_click(screen)
	await _capture("06-paid-product-road-invalid-1152x648.png")
	await _drop_city(data.scene)


func _capture_success() -> void:
	var data := await _new_city(Vector2i(1152, 648), 40)
	data.city.start_build_project(LOGGING_ID)
	data.city.advance_city_time_for_test(180.0)
	var screen := _cell_center(data.city, Vector2i(18, 15))
	data.city.activate_ready_placement(screen)
	data.city.commit_building_from_map_click(screen)
	await _capture("07-completed-building-slot-idle-1152x648.png")
	await _drop_city(data.scene)


func _capture_dense_1280() -> void:
	var data := await _new_city(Vector2i(1280, 720), 0)
	data.city.start_build_project(LOGGING_ID)
	await _capture("08-dense-waiting-panel-1280x720.png")
	await _drop_city(data.scene)


func _capture_standard_1440() -> void:
	var data := await _new_city(Vector2i(1440, 900), 40)
	data.city.start_build_project(LOGGING_ID)
	data.city.advance_city_time_for_test(180.0)
	data.city.activate_ready_placement(_cell_center(data.city, Vector2i(18, 15)))
	await _capture("09-standard-ready-placement-1440x900.png")
	await _drop_city(data.scene)


func _capture_legacy_lock() -> void:
	var data := await _new_city(Vector2i(1152, 648), 40)
	data.city.place_definition_at_cell(
		LOGGING_ID,
		Vector2i(18, 15),
		true,
		false,
		0
	)
	data.city._sync_construction_ui()
	await _capture("10-schema4-legacy-foundation-lock-1152x648.png")
	await _drop_city(data.scene)


func _new_city(size: Vector2i, wood: int) -> Dictionary:
	root.size = size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
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
	if image == null:
		push_error("R0C evidence viewport returned no image")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(
		"%s/%s" % [OUTPUT_DIRECTORY, filename]
	)
	var result := image.save_png(path)
	if result != OK:
		push_error("Cannot save R0C evidence: %s" % path)
		quit(1)

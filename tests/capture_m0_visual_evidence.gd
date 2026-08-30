extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const EVIDENCE_DIRECTORY := "res://docs/m0/evidence"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		failures.append("Cannot create evidence directory")
		_finish()
		return

	var normal := await _new_city(Vector2i(1440, 900))
	await _capture("01-default-running-1440x900.png")
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await _capture("02-default-running-1280x720.png")
	await _drop_city(normal.scene)

	var paused := await _new_city(Vector2i(1440, 900))
	_seed_road(paused.city)
	paused.city.set_city_time_paused(true)
	var paused_id: int = paused.city.place_definition_at_cell(
		&"building.logging_camp.t1", Vector2i(10, 7), true
	)
	paused.selection.select_placement(paused_id)
	await process_frame
	await _capture("03-paused-order-no-progress-1440x900.png")
	await _drop_city(paused.scene)

	var blocked := await _new_city(Vector2i(1440, 900))
	_seed_road(blocked.city)
	blocked.city.wood = 0
	var blocked_id: int = blocked.city.place_definition_at_cell(
		&"building.logging_camp.t1", Vector2i(10, 7), true
	)
	blocked.city.advance_city_time_for_test(5.0)
	blocked.selection.select_placement(blocked_id)
	blocked.city._refresh_city_ui()
	await process_frame
	await _capture("04-blocked-missing-material-1440x900.png")
	await _drop_city(blocked.scene)

	var overdue := await _new_city(Vector2i(1440, 900))
	while overdue.city.current_day < 10:
		overdue.city.advance_one_day_for_test()
	overdue.city._refresh_city_ui()
	await process_frame
	await _capture("05-overdue-pressure-stage-1440x900.png")
	await _drop_city(overdue.scene)
	_finish()


func _new_city(size: Vector2i) -> Dictionary:
	root.size = size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	return {
		"scene": scene,
		"city": city,
		"selection": scene.get_node("BuildingSelectionController"),
	}


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _seed_road(city: Node) -> void:
	for cell in [
		Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6),
		Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6),
	]:
		city.place_definition_at_cell(&"building.road.t1", cell, false)


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [EVIDENCE_DIRECTORY, file_name]
	if image == null:
		failures.append("%s (renderer returned no viewport image)" % path)
		return
	var result := image.save_png(ProjectSettings.globalize_path(path))
	if result == OK:
		print("CAPTURED: %s" % path)
	else:
		failures.append("%s (%s)" % [path, error_string(result)])


func _finish() -> void:
	if failures.is_empty():
		print("M0_VISUAL_EVIDENCE_CAPTURE PASS")
		quit(0)
		return
	print("M0_VISUAL_EVIDENCE_CAPTURE FAIL: %s" % str(failures))
	quit(1)

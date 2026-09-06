extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const DEBUG_OVERLAY = preload("res://scripts/placement_debug_overlay_r0a.gd")
const EVIDENCE_DIRECTORY := "res://docs/m0/evidence/r0a"
const LOGGING_ID := &"building.logging_camp.t1"
const ROAD_ID := &"building.road.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		failures.append("Cannot create R0A evidence directory")
		_finish()
		return

	var illegal: Dictionary = await _new_city(Vector2i(1440, 900))
	_preview_building(illegal.city, Vector2i(18, 13))
	await _capture("01-building-on-road-invalid-1440x900.png")
	await _drop_city(illegal.scene)

	var legal: Dictionary = await _new_city(Vector2i(1440, 900))
	_preview_building(legal.city, Vector2i(18, 15))
	await _capture("02-entrance-adjacent-road-valid-1440x900.png")
	await _drop_city(legal.scene)

	var running: Dictionary = await _new_city(Vector2i(1440, 900))
	var running_id: int = running.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 15), true, false, 0
	)
	running.city.set_city_time_paused(false)
	running.city.advance_city_time_for_test(24.0)
	running.city.set_city_time_paused(true)
	running.selection.select_placement(running_id)
	await _capture("03-construction-panel-1440x900.png")
	await _drop_city(running.scene)

	var blocked: Dictionary = await _new_city(Vector2i(1440, 900))
	blocked.city.wood = 0
	var blocked_id: int = blocked.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 15), true, false, 0
	)
	blocked.city.set_city_time_paused(false)
	blocked.city.advance_city_time_for_test(5.0)
	blocked.selection.select_placement(blocked_id)
	await _capture("04-missing-material-panel-1440x900.png")
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await _capture("08-complex-panel-1280x720.png")
	await _drop_city(blocked.scene)

	var disconnected: Dictionary = await _new_city(Vector2i(1440, 900))
	var disconnected_id: int = disconnected.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(14, 9), false, true, 0
	)
	disconnected.selection.select_placement(disconnected_id)
	await _capture("05-completed-disconnected-1440x900.png")
	await _drop_city(disconnected.scene)

	var producing: Dictionary = await _new_city(Vector2i(1440, 900))
	var producing_id: int = producing.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 15), false, true, 0
	)
	producing.selection.select_placement(producing_id)
	await _capture("06-completed-producing-1440x900.png")
	await _drop_city(producing.scene)

	var road_invalid: Dictionary = await _new_city(Vector2i(1440, 900))
	var road_block_id: int = road_invalid.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 15), false, true, 0
	)
	var blocked_cell_screen := _cell_center_screen(road_invalid.city, Vector2i(18, 15))
	road_invalid.city.begin_road_mode(blocked_cell_screen)
	road_invalid.city.begin_road_drag(blocked_cell_screen)
	road_invalid.city.finish_road_drag(blocked_cell_screen)
	await _capture("07-road-through-building-invalid-1440x900.png")
	await _drop_city(road_invalid.scene)

	var debug: Dictionary = await _new_city(Vector2i(1440, 900))
	var debug_id: int = debug.city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 15), false, true, 0
	)
	debug.selection.select_placement(debug_id)
	var overlay := DEBUG_OVERLAY.new() as PlacementDebugOverlayR0A
	debug.scene.get_node("MapWorld").add_child(overlay)
	overlay.configure(debug.city, debug_id, [Vector2i(18, 13)])
	await _capture("09-debug-occupancy-overlay-1440x900.png")
	await _drop_city(debug.scene)

	var overdue: Dictionary = await _new_city(Vector2i(1440, 900))
	while overdue.city.current_day < 10:
		overdue.city.advance_one_day_for_test()
	overdue.city._refresh_city_ui()
	await _capture("10-overdue-pressure-event-1440x900.png")
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
	city.set_city_time_paused(true)
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
		city.place_definition_at_cell(ROAD_ID, cell, false, true)


func _preview_building(city: Node, origin_cell: Vector2i) -> void:
	city.begin_placing_definition(LOGGING_ID, _footprint_center_screen(city, origin_cell))


func _footprint_center_screen(city: Node, origin_cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(
		city.cell_to_map_local(origin_cell) + Vector2(40.0, 40.0)
	)


func _cell_center_screen(city: Node, cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(city.cell_to_map_local(cell) + Vector2(20.0, 20.0))


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [EVIDENCE_DIRECTORY, file_name]
	if image == null:
		failures.append("%s returned no viewport image" % path)
		return
	var result := image.save_png(ProjectSettings.globalize_path(path))
	if result == OK:
		print("CAPTURED: %s" % path)
	else:
		failures.append("%s (%s)" % [path, error_string(result)])


func _finish() -> void:
	if failures.is_empty():
		print("M0_R0A_EVIDENCE_CAPTURE PASS")
		quit(0)
		return
	print("M0_R0A_EVIDENCE_CAPTURE FAIL: %s" % str(failures))
	quit(1)

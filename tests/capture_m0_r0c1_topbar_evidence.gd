extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const OUTPUT_DIRECTORY := "res://docs/m0/evidence/r0c1"
const TARGETS := [
	{"size": Vector2i(1152, 648), "filename": "topbar-longest-state-1152x648.png"},
	{"size": Vector2i(1280, 720), "filename": "topbar-longest-state-1280x720.png"},
	{"size": Vector2i(1440, 900), "filename": "topbar-longest-state-1440x900.png"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		push_error("Cannot create R0C.1 evidence directory")
		quit(1)
		return
	for target in TARGETS:
		root.size = target.size
		var scene := CITY_SCENE.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var controller: Node = scene.get_node("ConstructionController")
		var shell: Control = scene.get_node("UI/Shell")
		controller.set_city_security_for_test(73)
		controller.advance_one_day_for_test()
		controller._refresh_city_ui()
		shell._refresh_read_model()
		await _capture(str(target.filename))
		scene.queue_free()
		await process_frame
	print("M0_R0C1_TOPBAR_EVIDENCE: PASS")
	quit(0)


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("R0C.1 evidence viewport returned no image")
		quit(1)
		return
	var result := image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIRECTORY, filename]))
	if result != OK:
		push_error("Cannot save R0C.1 evidence: %s" % filename)
		quit(1)

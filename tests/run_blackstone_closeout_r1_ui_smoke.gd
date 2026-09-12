extends SceneTree
const CITY := preload("res://scenes/blank_map.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := CITY.instantiate()
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var ui: Node = scene.get_node("UI/Shell")
	DirAccess.make_dir_recursive_absolute("/tmp/blackstone-r1-ui")
	for size in [Vector2i(1152, 648), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = size
		for frame in 5: await process_frame
		check(ui.governance_summary.text.contains("日产 0") and ui.governance_summary.text.contains("日需 7"), "visible normal-start food balance")
		check(Rect2(Vector2.ZERO, Vector2(size)).encloses(city.current_mainline_entry_button.get_global_rect()), "campaign entry stays within viewport")
		check(Rect2(Vector2.ZERO, Vector2(size)).encloses(ui.governance_workspace.get_global_rect()), "city workforce controls fit within viewport")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/blackstone-r1-ui/city-%dx%d.png" % [size.x, size.y])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var food_before: int = city.food
	ui.governance_population_summary.gui_input.emit(click)
	check(city.food == food_before, "population entry locates treatment without charging food")
	city.alert_summary.gui_input.emit(click)
	check(scene.get_node("UI/MacroMarchR0").visible, "threat text navigates to field")
	check(scene.return_from_macro_march_r0(), "field return remains available")
	print("BLACKSTONE_UI_SMOKE ", JSON.stringify(failures))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures.append(message)

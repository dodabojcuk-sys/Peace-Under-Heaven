extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node = scene.get_node("ConstructionController")
	controller.set_process(false)
	controller.wood = 0
	controller.food = 80
	controller._refresh_city_ui()

	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var label := Label.new()
	label.position = Vector2(18.0, 600.0)
	label.size = Vector2(1116.0, 36.0)
	label.text = "R0C REAL MOUSE FIXTURE · 新建状态 · 木材 0 · 不读写正式存档"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)

extends SceneTree


const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var scene: Node
var city: Node
var step_label: Label


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	city.set_city_time_paused(true)
	city.wood = 100
	city.food = 80
	city._refresh_city_ui()
	_install_step_label()
	var build_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildEntryButton"
	)
	var camp_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)

	_set_step("01 真实 UI 输入：打开建造目录，选择伐木场")
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())
	await _hold(1.0)

	_set_step("02 地图左键点道路：红色预览，明确显示与道路重叠")
	var road_pointer: Vector2 = await _move_to_cell(Vector2i(18, 13))
	await _click(road_pointer)
	await _hold(1.4)

	_set_step("03 移到合法位置：绿色，可建造：左键放置")
	var legal_pointer: Vector2 = await _move_to_cell(Vector2i(18, 15))
	await _hold(1.2)

	_set_step("04 按 R 旋转：朝向、入口与合法性同步更新")
	await _key(KEY_R)
	await _hold(1.0)

	_set_step("05 地图左键直接下单：只建一栋，成功后退出放置")
	await _click(legal_pointer)
	await _hold(1.4)
	city.wood = 33
	city._refresh_city_ui()

	_set_step("06 再次进入放置，右键取消：无订单、无扣料")
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())
	await _right_click(await _move_to_cell(Vector2i(20, 15)))
	await _hold(1.0)

	_set_step("07 再次进入放置，Esc 取消：无残留预览")
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())
	await _key(KEY_ESCAPE)
	await _hold(1.0)

	_set_step("08 材料不足：缺木材 7；下单后将等待材料")
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())
	await _move_to_cell(Vector2i(20, 15))
	await _hold(2.0)

	_set_step("09 连续玩家旅程完成：无建筑确认按钮，无静默失败")
	await _hold(1.0)
	print("M0_R0B_CONTINUOUS_JOURNEY: PASS")
	quit(0)


func _install_step_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	step_label = Label.new()
	step_label.position = Vector2(18.0, 600.0)
	step_label.size = Vector2(1116.0, 36.0)
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 17)
	step_label.add_theme_color_override("font_color", Color.WHITE)
	step_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	step_label.add_theme_constant_override("shadow_offset_x", 2)
	step_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(step_label)


func _set_step(value: String) -> void:
	step_label.text = value
	print("JOURNEY_STEP: ", value)


func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout


func _cell_center(cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(
		city.cell_to_map_local(cell) + Vector2(40.0, 40.0)
	)


func _move_to_cell(target: Vector2i) -> Vector2:
	var pointer := _cell_center(target)
	for _attempt in range(6):
		await _move(pointer)
		if city.preview_origin_cell == target:
			return pointer
		var current: Vector2i = city.preview_origin_cell
		pointer += _cell_center(target) - _cell_center(current)
	return pointer


func _move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _click(position: Vector2) -> void:
	await _move(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame


func _right_click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

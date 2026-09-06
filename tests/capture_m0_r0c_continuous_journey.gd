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
	city.set_process(false)
	city.wood = 0
	city.food = 80
	city._refresh_city_ui()
	_install_step_label()

	var build_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildEntryButton"
	)
	var camp_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)
	var primary_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotPrimaryButton"
	)

	_set_step("01 实际 UI 点击：零材料登记伐木场；0%，地图无地基")
	await _click(build_button.get_global_rect().get_center())
	await _click(camp_button.get_global_rect().get_center())
	await _hold(1.8)

	_set_step("02 补木材 10：施工推进到 25%，材料随进度扣除")
	city.wood = 10
	city.advance_city_time_for_test(45.0)
	city._refresh_city_ui()
	await _hold(1.8)

	_set_step("03 材料耗尽：停在已付款进度，仍不生成地图地基")
	city.advance_city_time_for_test(1.0)
	city._refresh_city_ui()
	await _hold(1.8)

	_set_step("04 补齐木材 30：自动复工并得到唯一待放置成品")
	city.wood = 30
	city.advance_city_time_for_test(135.0)
	city._refresh_city_ui()
	await _hold(2.0)

	_set_step("05 实际点击放置：道路位置为红色，失败后成品保留")
	await _click(primary_button.get_global_rect().get_center())
	var road_pointer := await _move_to_cell(Vector2i(18, 13))
	await _click(road_pointer)
	await _hold(1.8)

	_set_step("06 实际右键取消本次定位：同一成品返回待放置")
	await _right_click(road_pointer)
	await _hold(1.4)

	_set_step("07 再次点击放置并按 R：合法性与入口朝向同步")
	await _click(primary_button.get_global_rect().get_center())
	await _move_to_cell(Vector2i(18, 15))
	await _key(KEY_R)
	await _hold(1.6)

	_set_step("08 合法位置左键放下：完成建筑，不二次扣料，自动退出")
	var legal_pointer := await _move_to_cell(Vector2i(18, 15))
	await _click(legal_pointer)
	await _hold(2.0)

	_set_step("09 连续旅程完成：单队列已空，无连续盖章")
	await _hold(1.5)
	print("M0_R0C_CONTINUOUS_JOURNEY: PASS")
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
	await _move(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
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

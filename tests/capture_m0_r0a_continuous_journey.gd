extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"
const ROAD_ID := &"building.road.t1"

var scene: Node
var city: Node
var selection: Node
var step_label: Label
var placement_id := -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	scene = CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	selection = scene.get_node("BuildingSelectionController")
	city.set_process(false)
	city.set_city_time_paused(true)
	city.wood = 5
	_install_step_label()

	_set_step("01 进入建造目录，选择伐木场")
	city.open_construction_menu()
	await _hold(0.9)

	_set_step("02 预览覆盖道路：红色冲突 · 与道路重叠 · 无法确认")
	city.begin_placing_definition(LOGGING_ID, _footprint_center(Vector2i(18, 13)))
	await _hold(1.5)

	_set_step("03 移到道路旁：入口朝北 · 可建造")
	city.update_preview(_footprint_center(Vector2i(18, 15)))
	await _hold(1.3)

	_set_step("04 合法确认；全局暂停下进度与扣料保持不动")
	city.confirm_current_preview()
	placement_id = _latest_logging_id()
	selection.select_placement(placement_id)
	await _hold(1.8)

	_set_step("05 恢复时间：进度条与已投入材料连续推进")
	city.set_city_time_paused(false)
	for _index in range(7):
		city.advance_city_time_for_test(4.0)
		await _hold(0.28)

	_set_step("06 材料耗尽：缺料暂停 · 明确缺少木材 · ETA 等待材料")
	for _index in range(4):
		city.advance_city_time_for_test(3.0)
		await _hold(0.2)
	await _hold(1.5)

	_set_step("07 城市补给到账：补料后从原进度恢复")
	var supply_entries: Array[Dictionary] = [
		{
			"resource_id": &"wood",
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": 40,
		}
	]
	city._commit_national_resources(
		supply_entries,
		&"r0a_continuous_evidence_supply"
	)
	for _index in range(4):
		city.advance_city_time_for_test(5.0)
		await _hold(0.25)

	_set_step("08 加速施工至完工：道路已连接 · 生产中")
	for _index in range(7):
		city.advance_city_time_for_test(20.0)
		await _hold(0.22)
	await _hold(1.2)

	_set_step("09 尝试让道路穿过建筑：红色冲突 · 系统阻止")
	selection.clear_selection()
	var blocked_screen := _cell_center(Vector2i(18, 15))
	city.begin_road_mode(blocked_screen)
	city.begin_road_drag(blocked_screen)
	city.finish_road_drag(blocked_screen)
	await _hold(2.0)

	_set_step("10 连续旅程完成：建筑与道路不能占用同一空间")
	await _hold(1.0)
	print("M0_R0A_CONTINUOUS_JOURNEY PASS")
	quit(0)


func _install_step_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	step_label = Label.new()
	step_label.position = Vector2(28.0, 842.0)
	step_label.size = Vector2(1384.0, 42.0)
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 20)
	step_label.add_theme_color_override("font_color", Color.WHITE)
	step_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	step_label.add_theme_constant_override("shadow_offset_x", 2)
	step_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(step_label)


func _set_step(value: String) -> void:
	step_label.text = value
	print("JOURNEY_STEP: ", value)


func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout


func _seed_road() -> void:
	for cell in [
		Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6),
		Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6),
	]:
		city.place_definition_at_cell(ROAD_ID, cell, false, true)


func _latest_logging_id() -> int:
	var result := -1
	for candidate in city.get_placement_ids():
		var record: Dictionary = city.get_building_record(candidate)
		if StringName(record.definition_id) == LOGGING_ID:
			result = maxi(result, candidate)
	return result


func _footprint_center(origin_cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(
		city.cell_to_map_local(origin_cell) + Vector2(40.0, 40.0)
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(
		city.cell_to_map_local(cell) + Vector2(20.0, 20.0)
	)

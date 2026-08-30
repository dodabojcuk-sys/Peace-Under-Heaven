extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"
const ROAD_ID := &"building.road.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var first: Dictionary = await _new_city()
	var city: Node = first.city
	var definition: BuildingDefinition = city.get_definition(LOGGING_ID)
	city.set_city_time_paused(true)

	var building_on_road: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(28, 13), definition, false, false, 0
	)
	_check(
		not building_on_road.valid
			and building_on_road.reason_code == &"ROAD_OVERLAP"
			and building_on_road.reason == "与道路重叠",
		"占地1：建筑覆盖正式道路返回稳定 ROAD_OVERLAP"
	)
	var adjacent_connected: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(30, 15), definition, false, false, 0
	)
	var adjacent_away: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(30, 15), definition, false, false, 2
	)
	_check(
		adjacent_connected.valid
			and adjacent_connected.connection_state == &"connected",
		"占地2：入口朝向相邻道路时合法且连接"
	)
	_check(
		adjacent_away.valid
			and adjacent_away.connection_state == &"disconnected",
		"占地3：建筑相邻但入口背向道路仍合法且未连接"
	)

	var disconnected_id: int = city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 20), false, true, 0
	)
	var road_through: Dictionary = city.evaluate_road_path(_cells([Vector2i(18, 20)]))
	_check(
		not road_through.valid
			and road_through.reason_code == &"BUILDING_OVERLAP",
		"占地4：道路穿过建筑 footprint 返回 BUILDING_OVERLAP"
	)
	var entrance: Dictionary = city.get_building_entrance_info(disconnected_id)
	var road_at_entrance: Dictionary = city.evaluate_road_path(
		_cells([Vector2i(entrance.road_contact_cell)])
	)
	_check(road_at_entrance.valid, "占地5：道路可贴邻合法入口")

	var before_move: Dictionary = city.get_building_record(disconnected_id).duplicate(true)
	var move_result: Dictionary = city.move_placed_building(
		disconnected_id, Vector2i(28, 13)
	)
	var after_move: Dictionary = city.get_building_record(disconnected_id)
	_check(
		not move_result.success
			and move_result.reason_code == &"ROAD_OVERLAP"
			and after_move.origin_cell == before_move.origin_cell,
		"占地6：移动到道路失败且原位置不变"
	)

	var rectangle: BuildingDefinition = BuildingDefinition.new()
	rectangle.definition_id = &"test.r0a.rectangle"
	rectangle.display_name = "R0A 矩形 fixture"
	rectangle.building_type = "测试建筑"
	rectangle.placement_kind = &"placed"
	rectangle.footprint = Vector2i(2, 3)
	rectangle.road_anchor_offsets = [Vector2i(0, -1)]
	rectangle.build_days = 0
	city._register_definition(rectangle)
	var rectangle_id: int = city.place_definition_at_cell(
		rectangle.definition_id, Vector2i(26, 16), false, true, 0
	)
	var before_rotate: Dictionary = city.get_building_record(rectangle_id).duplicate(true)
	var rotate_result: Dictionary = city.rotate_placed_building(rectangle_id, 1)
	var after_rotate: Dictionary = city.get_building_record(rectangle_id)
	_check(
		not rotate_result.success
			and rotate_result.reason_code == &"ROAD_OVERLAP"
			and after_rotate.orientation == before_rotate.orientation,
		"占地7：旋转后 footprint 撞路失败且原朝向不变"
	)

	var second: Dictionary = await _new_city()
	var second_city: Node = second.city
	second_city.set_city_time_paused(true)
	var first_building_id: int = second_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(35, 24), false, true, 0
	)
	var building_then_road: Dictionary = second_city.evaluate_road_path(
		_cells([Vector2i(35, 24)])
	)
	var third: Dictionary = await _new_city()
	var third_city: Node = third.city
	third_city.set_city_time_paused(true)
	var placed_road: int = third_city.place_definition_at_cell(
		ROAD_ID, Vector2i(35, 24), false, true, 0
	)
	var road_then_building: Dictionary = third_city.evaluate_origin_cell_for_definition(
		Vector2i(35, 24), third_city.get_definition(LOGGING_ID), false, false, 0
	)
	_check(
		first_building_id > 0
			and placed_road > 0
			and building_then_road.reason_code == &"BUILDING_OVERLAP"
			and road_then_building.reason_code == &"ROAD_OVERLAP",
		"占地8：先建筑后道路与先道路后建筑均拒绝同格"
	)

	var entrance_signatures: Array[String] = []
	for orientation in range(4):
		var direction: Dictionary = city.get_entrance_info_for_definition(
			Vector2i(40, 20), definition, orientation
		)
		entrance_signatures.append("%s:%s" % [direction.entrance_cell, direction.entrance_facing])
	_check(
		entrance_signatures.duplicate().size() == 4
			and entrance_signatures[0] != entrance_signatures[1]
			and entrance_signatures[1] != entrance_signatures[2]
			and entrance_signatures[2] != entrance_signatures[3],
		"占地9：N/E/S/W 四向入口均由同一旋转权威产生"
	)
	var camera: Camera2D = first.scene.get_node("Camera2D")
	var before_camera: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(40, 20), definition, false, false, 0
	)
	camera.rotation = PI * 0.5
	camera.zoom = Vector2.ONE * 1.6
	var after_camera: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(40, 20), definition, false, false, 0
	)
	_check(
		before_camera.valid == after_camera.valid
			and before_camera.reason_code == after_camera.reason_code,
		"占地10：相机旋转和缩放不改变逻辑占地"
	)
	_check(city.scan_current_placement_overlaps().is_empty(), "占地11：默认 Blackstone 无建筑道路逻辑重叠")
	city.remove_placed_building(disconnected_id)
	city.remove_placed_building(rectangle_id)
	_check(
		city.switch_city(&"riverbend_city")
			and city.scan_current_placement_overlaps().is_empty(),
		"占地11：正式 Riverbend 初始地图无建筑道路逻辑重叠"
	)

	var legacy: Dictionary = await _new_city()
	var legacy_city: Node = legacy.city
	var legacy_snapshot: Dictionary = legacy_city.export_v5_campaign_snapshot()
	var legacy_id := int(legacy_snapshot.next_placement_id)
	legacy_snapshot.placements.append(_legacy_construction_placement(legacy_id))
	legacy_snapshot.next_placement_id = legacy_id + 1
	var legacy_restore: Dictionary = legacy_city.restore_v5_campaign_snapshot(legacy_snapshot)
	var legacy_record: Dictionary = legacy_city.get_building_record(legacy_id)
	_check(
		legacy_restore.success
			and legacy_record.origin_cell == Vector2i(28, 13)
			and legacy_city.get_legacy_overlap_reports().size() == 1
			and legacy_city.get_legacy_overlap_reports()[0].report_code == &"LEGACY_OVERLAP",
		"占地12：旧存档重叠不删除不移动，只报告 LEGACY_OVERLAP"
	)

	await _run_ui_state_matrix()
	for fixture in [first, second, third, legacy]:
		fixture.scene.queue_free()
	await process_frame
	_finish()


func _run_ui_state_matrix() -> void:
	var fixture: Dictionary = await _new_city()
	var city: Node = fixture.city
	var selection: Node = fixture.selection
	city.set_city_time_paused(true)
	var placement_id: int = city.place_definition_at_cell(
		LOGGING_ID, Vector2i(30, 15), true, false, 0
	)
	selection.select_placement(placement_id)
	var paused_progress := int(city.get_building_record(placement_id).construction_progress_milliseconds)
	city.advance_city_frame_for_test(4.0)
	var paused_state: Dictionary = city.get_building_detail_state(placement_id)
	_check(
		paused_state.primary_status_id == &"GLOBAL_PAUSED"
			and int(city.get_building_record(placement_id).construction_progress_milliseconds) == paused_progress,
		"UI1：全局暂停是唯一主状态且进度不增长"
	)
	city.set_city_time_paused(false)
	city.advance_city_time_for_test(10000.0 / 1000.0)
	var running_state: Dictionary = city.get_building_detail_state(placement_id)
	_check(
		running_state.primary_status_id == &"CONSTRUCTING"
			and running_state.progress_percent > 0
			and running_state.paid_text.contains("木材"),
		"UI2：施工中只显示真实进度与已投入材料"
	)

	var blocked: Dictionary = await _new_city()
	var blocked_city: Node = blocked.city
	blocked_city.wood = 0
	var blocked_id: int = blocked_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 20), true, false, 0
	)
	blocked_city.advance_city_time_for_test(5.0)
	var blocked_state: Dictionary = blocked_city.get_building_detail_state(blocked_id)
	_check(
		blocked_state.primary_status_id == &"MISSING_RESOURCES"
			and blocked_state.missing_text.contains("木材 1")
			and blocked_state.eta_text == "预计完成：等待材料",
		"UI3：缺料列出真实名称数量且 ETA 等待材料"
	)
	blocked_city.wood = 1
	blocked_city.advance_city_time_for_test(1.0)
	var resumed_state: Dictionary = blocked_city.get_building_detail_state(blocked_id)
	_check(
		resumed_state.primary_status_id == &"CONSTRUCTING"
			and resumed_state.progress_percent > 0,
		"UI4：补料后从原进度恢复施工"
	)

	var completed_disconnected: int = blocked_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(35, 24), false, true, 0
	)
	var disconnected_state: Dictionary = blocked_city.get_building_detail_state(completed_disconnected)
	_check(
		disconnected_state.primary_status_id == &"COMPLETED_DISCONNECTED"
			and disconnected_state.actual_output_text.contains("+0/日")
			and not disconnected_state.priority_visible,
		"UI5：建成未接路显示零产出且隐藏施工优先级"
	)
	var completed_connected: int = blocked_city.place_definition_at_cell(
		LOGGING_ID, Vector2i(30, 15), false, true, 0
	)
	var producing_state: Dictionary = blocked_city.get_building_detail_state(completed_connected)
	_check(
		producing_state.primary_status_id == &"PRODUCING"
			and producing_state.actual_output_text.contains("+18/日"),
		"UI6：接路后的已完成建筑显示生产中"
	)

	for priority in [0, 1, 2]:
		_check(blocked_city.set_construction_priority(blocked_id, priority), "UI7：施工优先级 %d 可写入" % priority)
	var snapshot: Dictionary = blocked_city.export_v5_campaign_snapshot()
	var restored: Dictionary = await _new_city()
	_check(
		restored.city.restore_v5_campaign_snapshot(snapshot).success
			and int(restored.city.get_building_record(blocked_id).construction_priority) == 2,
		"UI7：高/普通/低优先级通过 schema 4 保存读取"
	)
	while blocked_city.current_day < 10:
		blocked_city.advance_one_day_for_test()
	var pressure_state: Dictionary = blocked_city.get_building_detail_state(completed_connected)
	_check(
		pressure_state.primary_status_id == &"PRESSURE_AFFECTED"
			and pressure_state.base_output_text != pressure_state.actual_output_text,
		"UI8：压力状态同时显示基础值与实际值且不重复扣减"
	)
	var resource_text: String = fixture.scene.get_node("UI/Shell/TopStatusBar/ResourceSummary").text
	_check(
		resource_text.contains("木材 ")
			and resource_text.contains("粮食 ")
			and resource_text.count("/") == 2,
		"UI9：资源栏在所有状态沿用同一容量格式"
	)
	fixture.scene.queue_free()
	blocked.scene.queue_free()
	restored.scene.queue_free()
	await process_frame


func _legacy_construction_placement(placement_id: int) -> Dictionary:
	return {
		"placement_id": placement_id,
		"definition_id": LOGGING_ID,
		"origin_cell": Vector2i(28, 13),
		"lifecycle_state": &"constructing",
		"built_day": 1,
		"disabled_until_day": 0,
		"construction_started_day": 1,
		"construction_complete_day": 2,
		"orientation": 0,
		"construction_state": &"ACTIVE",
		"construction_progress_milliseconds": 0,
		"construction_required_milliseconds": 180000,
		"construction_total_costs": {&"wood": 40},
		"construction_paid_costs": {&"wood": 0},
		"construction_priority": 1,
		"construction_missing_resource_ids": [],
	}


func _new_city() -> Dictionary:
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


func _cells(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(Vector2i(value))
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("M0_R0A_BUILDING_ROAD_UI_REPAIR_SMOKE PASS")
		quit(0)
		return
	print("M0_R0A_BUILDING_ROAD_UI_REPAIR_SMOKE FAIL (%d)" % failures.size())
	for failure in failures:
		print(" - %s" % failure)
	quit(1)

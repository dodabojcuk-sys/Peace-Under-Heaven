extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const LOGGING_ID := &"building.logging_camp.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var scene: Node = CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var city: Node = scene.get_node("ConstructionController")
	var foundation: Node = scene.get_node(
		"MapWorld/RegularCitySpatialFoundation"
	)
	city.set_city_time_paused(true)

	var formal_roads: Dictionary = city.get_formal_road_cells()
	_check(
		formal_roads == foundation.get_formal_road_cells()
			and formal_roads.size() > 0
			and city.get_connected_road_cells().size() >= formal_roads.size(),
		"正式道路绘制与建造查询共享同一空间投影"
	)

	var wood_before: int = city.wood
	var road_overlap: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(22, 7),
		city.get_definition(LOGGING_ID),
		false,
		true,
		0
	)
	_check(
		not bool(road_overlap.valid)
			and str(road_overlap.reason) == "占用保留区域",
		"中央保留庭院拒绝普通建筑占位"
	)
	_check(
		city.place_definition_at_cell(LOGGING_ID, Vector2i(22, 7), true, true) < 0
			and city.wood == wood_before,
		"道路/保留区非法确认不扣资源且不写入建筑"
	)

	var wall_result: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(0, 4), city.get_definition(LOGGING_ID), false, false, 0
	)
	var gate_result: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(26, 0), city.get_definition(LOGGING_ID), false, false, 0
	)
	var occupied_result: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(2, 3), city.get_definition(LOGGING_ID), false, false, 0
	)
	_check(
		str(wall_result.reason) == "占用城墙"
			and str(gate_result.reason) == "占用城门槽位"
			and str(occupied_result.reason) == "位置已占用",
		"城墙、城门槽位和既有建筑均有明确占用原因"
	)

	var definition: BuildingDefinition = city.get_definition(LOGGING_ID)
	var expected_contacts := [
		Vector2i(30, 19),
		Vector2i(32, 20),
		Vector2i(31, 22),
		Vector2i(29, 21),
	]
	var expected_facings := [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]
	for orientation in range(4):
		var entrance: Dictionary = city.get_entrance_info_for_definition(
			Vector2i(30, 20), definition, orientation
		)
		_check(
			bool(entrance.valid)
				and Vector2i(entrance.road_contact_cell)
					== expected_contacts[orientation]
				and Vector2i(entrance.entrance_facing)
					== expected_facings[orientation],
			"朝向 %d 的入口接触格和朝向确定" % orientation
		)

	var disconnected: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(18, 20), definition, false, false, 0
	)
	var connected: Dictionary = city.evaluate_origin_cell_for_definition(
		Vector2i(30, 15), definition, false, false, 0
	)
	_check(
		bool(disconnected.valid)
			and StringName(disconnected.connection_state) == &"disconnected"
			and bool(connected.valid)
			and StringName(connected.connection_state) == &"connected",
		"合法未接路 placement 显示 amber 警告，朝西入口接入正式道路"
	)

	var disconnected_id: int = city.place_definition_at_cell(
		LOGGING_ID, Vector2i(18, 20), false, true, 0
	)
	var connected_id: int = city.place_definition_at_cell(
		LOGGING_ID, Vector2i(30, 15), false, false, 0
	)
	_check(
		disconnected_id > 0
			and connected_id > 0
			and not city.is_building_operational(disconnected_id)
			and city.get_operational_status(disconnected_id).label
				.contains("入口未接路")
			and city.get_operational_status(connected_id).state == &"constructing",
		"未接路建筑可完成但保持停用，接路建筑进入施工状态"
	)

	city.set_city_time_paused(false)
	var wood_before_day: int = city.wood
	_check(city.advance_one_day_for_test(), "正常日结推进施工")
	_check(
		city.is_building_operational(connected_id)
			and city.get_operational_status(connected_id).label
				.contains("运行中：入口已接路")
			and city.wood == wood_before_day + 18,
		"施工完成后仅接路建筑进入运行并产出既有定义数量"
	)

	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		not snapshot.is_empty()
			and int(snapshot.placements[1].orientation) == 0,
		"V5 快照保存朝向而不保存道路连通派生字段"
	)
	var restored_scene: Node = CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	var restore_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(bool(restore_result.success), "V5 兼容快照可以恢复道路入口状态")
	var restored_record: Dictionary = restored.get_building_record(connected_id)
	_check(
		int(restored_record.orientation) == 0
			and restored.get_operational_status(connected_id).state
			== &"operational"
			and restored.get_building_entrance_info(connected_id).connected,
		"重载后朝向保持且运行态从入口与道路重新派生"
	)

	scene.queue_free()
	restored_scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("R2A_ROAD_LOT_ENTRANCE_SMOKE PASS")
		quit(0)
	else:
		print("R2A_ROAD_LOT_ENTRANCE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

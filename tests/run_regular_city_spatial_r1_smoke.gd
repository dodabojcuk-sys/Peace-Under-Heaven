extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式 main scene 可加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var controller: Node = scene.get_node("ConstructionController")
	var camera: Camera2D = scene.get_node("Camera2D")
	var foundation: Node2D = scene.get_node(
		"MapWorld/RegularCitySpatialFoundation"
	)
	var map_board: Control = scene.get_node("MapWorld/MapBoard")
	var placement_grid: Node2D = scene.get_node(
		"MapWorld/ConstructionLayer/ConstructionPreview/PlacementGrid"
	)
	var shell: Control = scene.get_node("UI/Shell")
	var minimap: Control = shell.get_node("MinimapPlaceholder")
	var entry_panel: Panel = shell.get_node("ConstructionEntryPanel")
	var construction_menu: Panel = shell.get_node("ConstructionMenu")
	var detail_panel: Panel = shell.get_node("BuildingDetailPanel")
	var city_bar: Panel = shell.get_node("CityBar")
	controller.set_process(false)

	_check(foundation != null and foundation.visible,
		"规则型城池空间基础位于正式 MapWorld")
	_check(not map_board.visible,
		"旧平面背景不再作为正式城市画面")
	_check(not placement_grid.is_visible_in_tree(),
		"默认不显示全局逻辑格线")
	_check(not city_bar.visible,
		"左侧大城市栏默认收起，城市空间保持主要面积")
	_check(minimap.visible and minimap.get_script() != null,
		"右上角使用可更新的小地图组件")
	var governance_workspace: Control = scene.get_node("UI/Shell/GovernanceWorkspace")
	_check(
		governance_workspace.visible
			and governance_workspace.get_global_rect().position.x > root.size.x * 0.5,
		"右侧纵栏承载真实城市经营入口"
	)
	_check(
		is_equal_approx(entry_panel.get_global_rect().position.x, minimap.get_global_rect().position.x)
			and is_equal_approx(entry_panel.size.x, minimap.size.x)
			and is_equal_approx(detail_panel.get_global_rect().position.x, minimap.get_global_rect().position.x),
		"小地图、建造目录和详情复用同一右侧纵栏"
	)

	var gates: Node = foundation.get_node("GateInstances")
	_check(gates.get_child_count() == 4, "四向城门由四个实例表达")
	var gate_script_paths: Dictionary = {}
	var gate_orientations: Array[int] = []
	for gate in gates.get_children():
		gate_script_paths[String(gate.get_script().resource_path)] = true
		gate_orientations.append(int(gate.orientation))
	gate_orientations.sort()
	_check(gate_script_paths.size() == 1,
		"四向城门复用唯一正式组件脚本")
	_check(gate_orientations == [0, 1, 2, 3],
		"城门方向覆盖北东南西且不复制逻辑")

	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var minimap_rect := minimap.get_global_rect()
		var entry_rect := entry_panel.get_global_rect()
		_check(
			entry_rect.position.x > scene.get_viewport().get_visible_rect().size.x * 0.5
				and entry_rect.size.x >= 278.0
				and entry_rect.size.x <= 340.0,
			"%d×%d 请求下右侧纵栏保持克制且位于安全区" % [viewport_size.x, viewport_size.y]
		)
		_check(not minimap_rect.intersects(entry_rect),
			"%d×%d 下小地图与建造入口不重叠" % [viewport_size.x, viewport_size.y])

	root.size = Vector2i(1440, 900)
	camera.position = Vector2(1100.0, 700.0)
	camera.zoom = Vector2.ONE
	await process_frame
	controller.open_construction_menu()
	_check(construction_menu.visible and controller.is_choosing_template(),
		"右侧目录进入已有权威模板选择")
	_check(controller.begin_placing_definition(&"building.logging_camp.t1", Vector2(700.0, 460.0)),
		"SUPERSEDED_BY_R0C：真实建筑定义进入唯一场外建造位")
	_check(not controller.is_placing() and not placement_grid.is_visible_in_tree(),
		"场外建设阶段不出现地图 ghost 或局部格线")
	controller.advance_city_time_for_test(180.0)
	_check(
		controller.get_build_slot_state() == controller.BUILD_SLOT_READY_TO_PLACE,
		"精确付清后产生待放置成品"
	)
	controller.activate_ready_placement(Vector2(700.0, 460.0))
	_check(placement_grid.visible and controller.preview_valid,
		"待放置成品仅显示局部格线与有效 footprint")
	_check(
		not shell.has_node("ConstructionEntryPanel/ConfirmPlacementButton"),
		"建筑 placement 已删除独立确认按钮"
	)
	var rotate_button: Button = shell.get_node("ConstructionEntryPanel/RotateButton")
	var preview_before_rail_hover: bool = controller.preview_valid
	scene._input(_mouse_motion(rotate_button.get_global_rect().get_center()))
	_check(
		preview_before_rail_hover
			and controller.preview_valid,
		"鼠标进入右栏旋转按钮不会把合法 ghost 改成界面遮挡"
	)
	scene._input(_key_event(KEY_R))
	_check(controller.get_preview_orientation() == 1,
		"placement 中 R 快捷键旋转到东向")
	for expected_orientation in [2, 3, 0]:
		_check(controller.rotate_preview(), "placement 旋转动作可用")
		_check(controller.get_preview_orientation() == expected_orientation,
			"建筑旋转到朝向 %d" % expected_orientation)
	scene._input(_key_event(KEY_R))
	_check(controller.get_preview_orientation() == 1,
		"确认前建筑保持东向预览")
	var before_cancel: Dictionary = controller.export_v5_campaign_snapshot()
	controller.cancel_placing()
	var after_cancel: Dictionary = controller.export_v5_campaign_snapshot()
	_check(
		not placement_grid.is_visible_in_tree()
			and after_cancel == before_cancel,
		"取消不会留下格线、朝向或权威状态写入"
	)

	var non_square_east: Dictionary = CityGridRules.get_rotated_footprint(Vector2i(3, 2), 1)
	var non_square_south: Dictionary = CityGridRules.get_rotated_footprint(Vector2i(3, 2), 2)
	_check(
		bool(non_square_east.valid)
			and non_square_east.footprint == Vector2i(2, 3)
			and bool(non_square_south.valid)
			and non_square_south.footprint == Vector2i(3, 2),
		"非方形 footprint 复用城市网格规则并正确交换宽高"
	)

	var placement_id: int = controller.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(20, 20),
		false,
		true,
		1
	)
	_check(placement_id > 0, "权威建造命令可接受带方向的真实定义")
	var record: Dictionary = controller.get_building_record(placement_id)
	_check(int(record.get("orientation", -1)) == 1,
		"确认后的建筑方向进入唯一权威实例")
	var snapshot: Dictionary = controller.export_v5_campaign_snapshot()
	_check(snapshot.schema_version == 5,
		"含方向的 Campaign 快照使用 schema 5")
	var temp_save_root := "%s/txwzs-r1-orientation-%d" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	var store := V5CampaignSaveStore.new(temp_save_root)
	var saved: Dictionary = store.save_snapshot(
		snapshot,
		Callable(controller, "validate_v5_campaign_snapshot")
	)
	_check(bool(saved.success), "方向快照通过既有版本化存档写入")
	var restored_scene := packed_scene.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	var restored_result: Dictionary = store.load_and_restore(restored)
	var restored_record: Dictionary = restored.get_building_record(placement_id)
	_check(
		bool(restored_result.success)
			and int(restored_record.get("orientation", -1)) == 1,
		"save/load 后建筑位置记录与东向同时保留"
	)
	var legacy_v2 := snapshot.duplicate(true)
	legacy_v2.schema_version = 2
	legacy_v2.erase("mainline_level")
	legacy_v2.erase("build_slot")
	legacy_v2.city.erase("security")
	for placement in legacy_v2.placements:
		for key in [
			"orientation", "construction_state",
			"construction_progress_milliseconds",
			"construction_required_milliseconds",
			"construction_total_costs", "construction_paid_costs",
			"construction_priority", "construction_missing_resource_ids",
		]:
			placement.erase(key)
	var legacy_validation: Dictionary = controller.validate_v5_campaign_snapshot(legacy_v2)
	_check(
		bool(legacy_validation.valid)
			and int(legacy_validation.snapshot.schema_version) == 5
			and int(legacy_validation.snapshot.placements[0].orientation) == 0,
		"旧 schema 2 存档载入时稳定默认北向"
	)

	restored_scene.queue_free()
	scene.queue_free()
	await process_frame
	_remove_tree(temp_save_root)
	_finish()


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for entry in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(entry))
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	DirAccess.remove_absolute(path)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures.append(label)
	push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("REGULAR_CITY_SPATIAL_R1_SMOKE PASS")
		quit(0)
		return
	print("REGULAR_CITY_SPATIAL_R1_SMOKE FAIL (%d)" % failures.size())
	for failure in failures:
		print(" - %s" % failure)
	quit(1)

extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "主场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var construction: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	var camera: Camera2D = scene.get_node("Camera2D")
	var placed_buildings: Node2D = scene.get_node(
		"MapWorld/ConstructionLayer/PlacedBuildings"
	)
	var selection_outline: Line2D = scene.get_node(
		"MapWorld/ConstructionLayer/SelectionOutline"
	)
	var detail_panel: Panel = scene.get_node("UI/Shell/BuildingDetailPanel")
	var close_button: Button = detail_panel.get_node("CloseButton")
	var remove_button: Button = detail_panel.get_node("RemoveButton")
	var confirmation: Control = detail_panel.get_node("RemovalConfirmation")
	var confirm_button: Button = confirmation.get_node("ConfirmRemoveButton")
	var cancel_button: Button = confirmation.get_node("CancelRemoveButton")

	_check(scene.find_children("MapWorld", "Node2D", true, false).size() == 1,
		"场景仍只有一个 MapWorld")
	_check(scene.find_children("Camera2D", "Camera2D", true, false).size() == 1,
		"场景仍只有一个 Camera2D")
	_check(scene.find_children("Shell", "Control", true, false).size() == 1,
		"场景仍只有一个 UI Shell")
	_check(remove_button.text == "移除建筑（原型）",
		"详情面板使用已确认的原型移除入口")
	_check(not confirmation.visible, "移除确认初始隐藏")

	var baseline_ids: Array[int] = construction.get_placement_ids()
	var baseline_building_count: int = construction.get_building_count()
	var baseline_occupied_count: int = construction.get_occupied_cell_count()
	var first_origin := Vector2i(25, 15)
	var second_origin := Vector2i(30, 18)
	var first_id: int = construction._create_runtime_building(first_origin)
	var second_id: int = construction._create_runtime_building(second_origin)
	var first_record: Dictionary = construction.get_building_record(first_id)
	var second_record: Dictionary = construction.get_building_record(second_id)
	var first_node: Node2D = construction.get_building_node(first_id)
	var second_node: Node2D = construction.get_building_node(second_id)

	_check(first_id == baseline_ids.back() + 1 and second_id == first_id + 1,
		"运行时 placement id 在固定建筑之后单调递增")
	_check(construction.get_building_count() == baseline_building_count + 2,
		"两栋运行时建筑各增加一条权威记录")
	_check(
		construction.get_placement_ids() == baseline_ids + [first_id, second_id],
		"权威顺序索引保留固定建筑并追加运行时 placement id"
	)
	_check(placed_buildings.get_child_count() == 2, "两条记录对应两个世界节点")
	_check(
		construction.get_occupied_cell_count() == baseline_occupied_count + 12,
		"两栋建筑在固定占用基线上增加十二个世界格")
	_check(first_node.get_meta_list() == [&"placement_id"],
		"建筑节点 metadata 只保留 placement_id")
	_check(first_record.node == first_node, "权威记录持有运行时节点")
	_check(first_record.origin_cell == first_origin, "权威记录保存网格原点")
	_check(first_record.footprint == Vector2i(3, 2), "权威记录保存 3 x 2 占地")

	for cell in first_record.occupied_footprint_cells:
		_check(construction.get_occupied_placement_id(cell) == first_id,
			"第一栋建筑占用格归第一 placement id")
	for cell in second_record.occupied_footprint_cells:
		_check(construction.get_occupied_placement_id(cell) == second_id,
			"第二栋建筑占用格归第二 placement id")

	selection.select_placement(first_id)
	_check(selection.selected_placement_id == first_id,
		"选择权威状态使用 selected_placement_id")
	_check(detail_panel.visible and selection_outline.visible,
		"选中后显示详情和世界描边")
	_check(detail_panel.get_node("TargetName").text == first_record.display_name,
		"详情名称来自权威记录")
	_check(detail_panel.get_node("GridPosition").text == "网格位置：(25, 15)",
		"详情网格位置来自权威记录")

	remove_button.emit_signal("pressed")
	_check(selection.is_awaiting_removal_confirmation(),
		"移除入口只进入 REMOVE_CONFIRM")
	_check(construction.get_building_count() == baseline_building_count + 2,
		"进入确认不会删除权威记录")
	_check(is_instance_valid(first_node) and first_node.is_inside_tree(),
		"进入确认不会删除世界节点")
	_check(
		construction.get_occupied_cell_count() == baseline_occupied_count + 12,
		"进入确认不会释放占用格")
	_check(confirmation.visible and not remove_button.visible,
		"确认状态只显示确认内容")

	cancel_button.emit_signal("pressed")
	_check(not selection.is_awaiting_removal_confirmation(),
		"取消按钮返回 SELECTED")
	_check(selection.selected_placement_id == first_id,
		"取消确认保留原选择")
	_check(remove_button.visible and not confirmation.visible,
		"取消确认恢复原详情操作")
	_check(construction.get_building_count() == baseline_building_count + 2
		and construction.get_occupied_cell_count()
			== baseline_occupied_count + 12,
		"取消确认不改变记录和占用")

	remove_button.emit_signal("pressed")
	var panel_center := detail_panel.get_global_rect().get_center()
	var camera_before_panel_input := camera.position
	var zoom_before_panel_input := camera.zoom.x
	_click_via_root(scene, panel_center)
	_drag_button_via_root(
		scene,
		MOUSE_BUTTON_MIDDLE,
		panel_center,
		panel_center + Vector2(30.0, 0.0)
	)
	_drag_button_via_root(
		scene,
		MOUSE_BUTTON_RIGHT,
		panel_center,
		panel_center + Vector2(30.0, 0.0)
	)
	scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_UP, panel_center))
	_check(camera.position.is_equal_approx(camera_before_panel_input),
		"移除确认面板内左中右键不移动地图")
	_check(is_equal_approx(camera.zoom.x, zoom_before_panel_input),
		"移除确认面板内滚轮不缩放地图")
	_check(selection.is_awaiting_removal_confirmation(),
		"确认面板输入不取消或穿透当前确认状态")

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	scene._input(escape_event)
	_check(not selection.is_awaiting_removal_confirmation(),
		"REMOVE_CONFIRM 中 Esc 只取消确认")
	_check(selection.selected_placement_id == first_id,
		"Esc 取消确认后仍保留选择")

	close_button.emit_signal("pressed")
	_check(not selection.has_selection() and not detail_panel.visible,
		"关闭按钮只清除选择和面板")
	_check(construction.get_building_count() == baseline_building_count + 2
		and construction.get_occupied_cell_count()
			== baseline_occupied_count + 12,
		"关闭面板不移除建筑或释放占用格")
	selection.select_placement(first_id)

	remove_button.emit_signal("pressed")
	var zoom_before := camera.zoom.x
	scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_UP, Vector2(700.0, 450.0)))
	_check(camera.zoom.x > zoom_before, "确认状态在地图区域仍保留滚轮缩放")
	_check(selection.is_awaiting_removal_confirmation(),
		"滚轮缩放不取消移除确认")

	var first_cells: Array = first_record.occupied_footprint_cells.duplicate()
	confirm_button.emit_signal("pressed")
	await process_frame
	_check(construction.get_building_record(first_id).is_empty(),
		"确认移除删除准确的一条权威记录")
	_check(not is_instance_valid(first_node), "确认移除释放目标世界节点")
	_check(
		construction.get_building_count() == baseline_building_count + 1
		and construction.get_placement_ids() == baseline_ids + [second_id],
		"确认移除保留固定建筑、另一条运行时记录和顺序"
	)
	for cell in first_cells:
		_check(not construction.is_cell_occupied(cell),
			"确认移除释放目标 footprint 占用格")
	for cell in second_record.occupied_footprint_cells:
		_check(construction.get_occupied_placement_id(cell) == second_id,
			"确认移除不影响另一栋建筑占用格")
	_check(not selection.has_selection(), "确认移除清除 selected_placement_id")
	_check(not detail_panel.visible and not selection_outline.visible,
		"确认移除隐藏面板和描边")
	_check(not construction.remove_placed_building(first_id),
		"重复移除不存在的 placement id 安全返回 false")
	_check(construction.get_building_count() == baseline_building_count + 1
		and construction.get_occupied_cell_count()
			== baseline_occupied_count + 6,
		"重复移除不产生二次变化")

	camera.zoom = Vector2.ONE
	camera.position = Vector2(1100.0, 700.0)
	await process_frame
	var original_center: Vector2 = (
		construction.cell_to_map_local(first_origin)
		+ construction.TEST_BUILDING_WORLD_SIZE * 0.5
	)
	var original_screen: Vector2 = construction.map_local_to_screen(original_center)
	construction.begin_placing(original_screen)
	_check(construction.preview_origin_cell == first_origin,
		"既有建造入口重新指向原 footprint")
	_check(construction.preview_valid, "移除后原位置恢复可建")
	_check(construction.confirm_current_preview(), "既有建造流程可在原位置重建")
	var rebuilt_id: int = construction.get_placement_ids().back()
	_check(rebuilt_id == second_id + 1 and rebuilt_id != first_id,
		"原位重建获得新的单调递增 placement id")
	_check(construction.get_building_count() == baseline_building_count + 2
		and construction.get_occupied_cell_count()
			== baseline_occupied_count + 12,
		"原位重建恢复一条记录、一个节点和六个占用格")
	construction.cancel_placing()

	selection.select_placement(rebuilt_id)
	_check(selection.selected_placement_id == rebuilt_id,
		"原位重建建筑可按新 id 重新选择")
	remove_button.emit_signal("pressed")
	construction.begin_placing(Vector2(700.0, 500.0))
	_check(construction.is_placing(), "确认状态可以转入既有建造模式")
	_check(not selection.has_selection() and not detail_panel.visible,
		"进入 placing 清除选择与待确认状态")
	construction.cancel_placing()

	var rebuilt_record: Dictionary = construction.get_building_record(rebuilt_id)
	var rebuilt_node: Node2D = rebuilt_record.node
	selection.select_placement(rebuilt_id)
	rebuilt_node.queue_free()
	await process_frame
	_check(construction.get_building_record(rebuilt_id).is_empty(),
		"意外 tree_exited 幂等清理权威记录")
	for cell in rebuilt_record.occupied_footprint_cells:
		_check(not construction.is_cell_occupied(cell),
			"意外 tree_exited 清理仍属于该 id 的占用格")
	_check(not selection.has_selection()
		and not detail_panel.visible
		and not selection_outline.visible,
		"意外 tree_exited 同步清理选择和 UI")
	_check(construction.get_building_record(second_id).node == second_node,
		"意外 tree_exited 不影响其他建筑")

	scene.queue_free()
	await process_frame
	_finish()


func _wheel_event(
	button_index: MouseButton,
	position: Vector2
) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	return event


func _click_via_root(scene: Node, screen_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_position
	scene._input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_position
	scene._input(release)


func _drag_button_via_root(
	scene: Node,
	button_index: MouseButton,
	start: Vector2,
	finish: Vector2
) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button_index
	press.pressed = true
	press.position = start
	scene._input(press)

	var motion := InputEventMouseMotion.new()
	motion.position = finish
	scene._input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = button_index
	release.pressed = false
	release.position = finish
	scene._input(release)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("BUILDING_LIFECYCLE_SMOKE PASS")
		quit(0)
	else:
		print("BUILDING_LIFECYCLE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

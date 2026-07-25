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
	var construction_preview: Node2D = scene.get_node(
		"MapWorld/ConstructionLayer/ConstructionPreview"
	)
	var detail_panel: Panel = scene.get_node("UI/Shell/BuildingDetailPanel")
	var close_button: Button = detail_panel.get_node("CloseButton")
	var minimap: Control = scene.get_node("UI/Shell/MinimapPlaceholder")
	var construction_entry: Control = scene.get_node(
		"UI/Shell/ConstructionEntryPanel"
	)

	_check(scene.find_children("MapWorld", "Node2D", true, false).size() == 1,
		"场景只有一套 MapWorld")
	_check(scene.find_children("Camera2D", "Camera2D", true, false).size() == 1,
		"场景只有一套 Camera2D")
	_check(scene.find_children("BuildingSelectionController", "Node", true, false).size() == 1,
		"场景只有一个 BuildingSelectionController")
	_check(not selection.has_selection(), "初始没有建筑选择")
	_check(not detail_panel.visible, "详情面板初始隐藏")
	_check(not selection_outline.visible, "选择描边初始隐藏")

	var panel_rect := detail_panel.get_global_rect()
	_check(panel_rect.position.is_equal_approx(Vector2(856.0, 176.0)),
		"详情面板参考位置为 (856, 176)")
	_check(panel_rect.size.is_equal_approx(Vector2(280.0, 360.0)),
		"详情面板尺寸为 280 x 360")
	_check(not panel_rect.intersects(minimap.get_global_rect()),
		"详情面板不与小地图重叠")
	_check(construction_entry.visible, "初始显示右侧建造入口")
	_check(not scene.has_node("UI/Shell/ContextBar"), "底部操作栏已经移除")

	var first_placement_id: int = construction._create_runtime_building(
		Vector2i(25, 15)
	)
	var second_placement_id: int = construction._create_runtime_building(
		Vector2i(30, 18)
	)
	_check(placed_buildings.get_child_count() == 2, "测试创建两栋已放置建筑")
	var first_building: Node2D = construction.get_building_node(first_placement_id)
	var second_building: Node2D = construction.get_building_node(second_placement_id)
	var first_body := first_building.get_node("Body") as Polygon2D
	var original_body_color := first_body.color

	var first_center := _building_screen_center(
		construction,
		first_placement_id
	)
	_click_via_root(scene, first_center)
	_check(selection.selected_placement_id == first_placement_id,
		"小于 8 px 的左键单击按 placement id 选中建筑")
	_check(detail_panel.visible, "选中建筑后显示详情面板")
	_check(not construction_entry.visible, "选中建筑时右侧建造入口让位给详情")
	_check(selection_outline.visible, "选中建筑后显示琥珀色描边")
	_check(selection_outline.global_position.is_equal_approx(first_building.global_position),
		"选择描边与选中建筑世界位置对齐")
	_check(selection_outline.points.size() == 5, "选择描边为闭合矩形")
	_check(selection_outline.default_color == Color(0.72, 0.56, 0.25, 1),
		"选择描边使用独立低饱和琥珀色")
	_check(first_body.color == original_body_color, "选择不修改建筑主体颜色")
	_check(detail_panel.get_node("TargetName").text == "伐木场",
		"面板显示伐木场名称")
	_check(detail_panel.get_node("TargetType").text == "类型：生产建筑",
		"面板显示生产建筑类型")
	_check(detail_panel.get_node("GridPosition").text == "网格位置：(25, 15)",
		"面板显示正确网格位置")
	_check(detail_panel.get_node("Footprint").text == "占地：2 × 2",
		"面板显示 2 x 2 占地")
	_check(
		detail_panel.get_node("PrototypeStatus").text
			== "状态：停用：未接入道路",
		"面板显示未接路状态"
	)

	var second_center := _building_screen_center(
		construction,
		second_placement_id
	)
	_click_via_root(scene, second_center)
	_check(selection.selected_placement_id == second_placement_id,
		"单击另一建筑切换选择")
	_check(detail_panel.get_node("GridPosition").text == "网格位置：(30, 18)",
		"切换选择后面板字段刷新")

	_click_via_root(scene, Vector2(700.0, 520.0))
	_check(not selection.has_selection(), "空白单击取消选择")
	_check(not detail_panel.visible and not selection_outline.visible,
		"空白取消同时隐藏面板和描边")

	first_center = _building_screen_center(construction, first_placement_id)
	_click_via_root(scene, first_center)
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	scene._input(escape_event)
	_check(not selection.has_selection(), "idle Esc 取消选择")

	_click_via_root(scene, first_center)
	close_button.emit_signal("pressed")
	_check(not selection.has_selection(), "显式关闭按钮取消选择")

	_click_via_root(scene, first_center)
	selection.handle_map_click(Vector2(20.0, 20.0))
	_check(selection.selected_placement_id == first_placement_id,
		"常驻 UI 区域单击不穿透且不取消选择")

	var camera_before_drag := camera.position
	_drag_via_root(scene, first_center, first_center + Vector2(12.0, 0.0))
	_check(not camera.position.is_equal_approx(camera_before_drag),
		"达到 8 px 后仍执行原左键 Camera2D 拖动")
	_check(selection.selected_placement_id == first_placement_id,
		"超过阈值的拖动不切换或取消选择")
	_check(scene.active_drag_button == -1, "拖动释放后立即停止")

	var zoom_before := camera.zoom.x
	var wheel_on_map := _wheel_event(MOUSE_BUTTON_WHEEL_UP, Vector2(700.0, 450.0))
	scene._input(wheel_on_map)
	_check(camera.zoom.x > zoom_before, "地图区域滚轮缩放仍有效")
	_check(selection.selected_placement_id == first_placement_id,
		"缩放保留当前选择")

	for zoom_value in [0.6, 1.0, 1.6]:
		camera.zoom = Vector2.ONE * zoom_value
		camera.position = Vector2(1100.0, 700.0)
		await process_frame
		first_center = _building_screen_center(construction, first_placement_id)
		_check(selection.get_building_at_screen_position(first_center) == first_building,
			"zoom %.1f 下命中真实世界建筑" % zoom_value)

	camera.zoom = Vector2.ONE
	camera.position = Vector2(980.0, 620.0)
	await process_frame
	first_center = _building_screen_center(construction, first_placement_id)
	_check(selection.get_building_at_screen_position(first_center) == first_building,
		"相机位移后仍命中正确世界建筑")
	selection.select_building(first_building)

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
		"面板区域左中右键不移动地图")
	_check(is_equal_approx(camera.zoom.x, zoom_before_panel_input),
		"面板区域滚轮不缩放地图")
	_check(selection.selected_placement_id == first_placement_id,
		"面板空白单击不取消选择")

	camera.zoom = Vector2.ONE
	camera.position = Vector2(1100.0, 700.0)
	await process_frame
	selection.select_building(first_building)
	panel_center = detail_panel.get_global_rect().get_center()
	var panel_map_position: Vector2 = construction.screen_to_map_local(panel_center)
	var panel_origin: Vector2i = construction.map_position_to_origin_cell(panel_map_position)
	var blocked_validation: Dictionary = construction.evaluate_origin_cell(panel_origin)
	_check(not blocked_validation.valid and blocked_validation.reason == "被界面遮挡",
		"可见详情面板动态参与建造 UI 遮挡")
	selection.clear_selection()
	var restored_validation: Dictionary = construction.evaluate_origin_cell(panel_origin)
	_check(restored_validation.valid, "面板隐藏后同一区域恢复建造有效性")
	_check(not construction.is_cell_occupied(panel_origin),
		"详情面板遮挡不写入 occupied_cells")

	var camera_before_restored_wheel := camera.position
	var restored_zoom_before := camera.zoom.x
	scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_UP, panel_center))
	_check(camera.zoom.x > restored_zoom_before, "面板隐藏后原区域恢复滚轮缩放")
	_check(not camera.position.is_equal_approx(camera_before_restored_wheel),
		"恢复的滚轮缩放仍以鼠标位置为中心")

	camera.zoom = Vector2.ONE
	camera.position = Vector2(1100.0, 700.0)
	await process_frame
	first_center = _building_screen_center(construction, first_placement_id)
	_click_via_root(scene, first_center)
	_check(selection.has_selection(), "进入建造前存在选中建筑")
	construction.begin_placing(Vector2(700.0, 500.0))
	_check(construction.is_placing(), "进入 placing 状态")
	_check(not selection.has_selection(), "进入 placing 清除当前选择")
	_check(not detail_panel.visible and not selection_outline.visible,
		"进入 placing 隐藏面板和描边")
	var placement_count_before: int = construction.get_building_count()
	var placing_left := InputEventMouseButton.new()
	placing_left.button_index = MOUSE_BUTTON_LEFT
	placing_left.pressed = true
	placing_left.position = Vector2(700.0, 500.0)
	scene._input(placing_left)
	_check(construction.get_building_count() == placement_count_before + 1,
		"placing 左键仍只确认有效建造")
	_check(not selection.has_selection(), "placing 左键不会同时选择建筑")
	construction.cancel_placing()
	_check(not construction_preview.visible, "退出 placing 后建造预览隐藏")

	selection.select_building(second_building)
	second_building.queue_free()
	await process_frame
	_check(not selection.has_selection(), "选中建筑移出场景时安全清除引用")
	_check(construction.get_building_record(second_placement_id).is_empty(),
		"建筑意外离树时清除权威记录")
	_check(not detail_panel.visible and not selection_outline.visible,
		"选中建筑移除后隐藏面板和描边")

	scene.queue_free()
	await process_frame
	_finish()


func _building_screen_center(construction: Node, placement_id: int) -> Vector2:
	var record: Dictionary = construction.get_building_record(placement_id)
	var building: Node2D = record.node
	var selection_bounds: Rect2 = record.selection_bounds
	var map_local_center := building.position + selection_bounds.get_center()
	return construction.map_local_to_screen(map_local_center)


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


func _drag_via_root(scene: Node, start: Vector2, finish: Vector2) -> void:
	_drag_button_via_root(scene, MOUSE_BUTTON_LEFT, start, finish)


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


func _wheel_event(button_index: MouseButton, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	return event


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("BUILDING_SELECTION_SMOKE PASS")
		quit(0)
	else:
		print("BUILDING_SELECTION_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

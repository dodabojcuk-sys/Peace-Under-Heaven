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

	var controller: Node = scene.get_node("ConstructionController")
	var camera: Camera2D = scene.get_node("Camera2D")
	var preview: Node2D = scene.get_node(
		"MapWorld/ConstructionLayer/ConstructionPreview"
	)
	var placed_buildings: Node2D = scene.get_node(
		"MapWorld/ConstructionLayer/PlacedBuildings"
	)
	var build_entry_button: Button = scene.get_node(
		"UI/Shell/ConstructionEntryPanel/BuildEntryButton"
	)
	var construction_menu: Control = scene.get_node(
		"UI/Shell/ConstructionMenu"
	)
	var build_template_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)
	var initial_building_count: int = controller.get_building_count()
	var initial_occupied_count: int = controller.get_occupied_cell_count()

	_check(scene.find_children("MapWorld", "Node2D", true, false).size() == 1,
		"场景只有一套 MapWorld")
	_check(scene.find_children("Camera2D", "Camera2D", true, false).size() == 1,
		"场景只有一套 Camera2D")
	_check(is_equal_approx(controller.GRID_SIZE, 40.0), "网格为 40 世界单位")
	_check(controller.TEST_BUILDING_FOOTPRINT == Vector2i(2, 2),
		"伐木场占地为 2 x 2")
	_check(controller.get_footprint_cells(Vector2i(10, 10)).size() == 4,
		"2 x 2 占地包含四个格")
	_check(initial_building_count == 6, "启动时注册六个固定预置建筑")
	_check(initial_occupied_count > 0, "固定预置建筑写入世界格占用")
	_check(build_entry_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"右侧建造入口主动接收 UI 鼠标事件")
	build_entry_button.emit_signal("pressed")
	_check(controller.is_choosing_template(), "右侧建造入口打开模板列表")
	_check(construction_menu.visible, "模板列表显示当前正式建筑")
	build_template_button.emit_signal("pressed")
	_check(controller.is_placing(), "伐木场模板进入原 placing")
	controller.cancel_placing()

	var reference_map_position := Vector2(1320.0, 920.0)
	var reference_cell: Vector2i = controller.map_position_to_origin_cell(
		reference_map_position
	)
	for zoom_value in [0.6, 1.0, 1.6]:
		camera.zoom = Vector2.ONE * zoom_value
		await process_frame
		var screen_position: Vector2 = controller.map_local_to_screen(
			reference_map_position
		)
		var round_trip: Vector2 = controller.screen_to_map_local(screen_position)
		_check(round_trip.is_equal_approx(reference_map_position),
			"zoom %.1f 下屏幕与 MapWorld 坐标可往返" % zoom_value)
		_check(controller.map_position_to_origin_cell(round_trip) == reference_cell,
			"zoom %.1f 下仍吸附到同一世界网格" % zoom_value)

	camera.zoom = Vector2.ONE
	camera.position = Vector2(1100.0, 700.0)
	await process_frame

	var safe_screen_position := Vector2(680.0, 390.0)
	controller.begin_placing(safe_screen_position)
	_check(controller.is_placing(), "建造入口进入 placing")
	_check(preview.visible, "placing 状态显示预览")
	_check(controller.preview_valid, "安全区域预览有效")
	var first_origin: Vector2i = controller.preview_origin_cell
	_check(controller.confirm_current_preview(), "第一次有效放置成功")
	_check(controller.get_occupied_cell_count() == initial_occupied_count + 4,
		"首次放置在固定占用基线上增加四个格")
	_check(controller.get_building_count() == initial_building_count + 1,
		"首次放置在统一权威记录中增加一条运行时记录")
	_check(placed_buildings.get_child_count() == 1, "首次放置创建一个世界节点")
	_check(controller.preview_origin_cell == first_origin,
		"确认使用当前可见预览的同一网格 intent")
	_check(not controller.preview_valid, "已占用位置的预览变为无效")
	_check(not controller.confirm_current_preview(), "重复覆盖已占用格被拒绝")
	_check(controller.get_occupied_cell_count() == initial_occupied_count + 4,
		"无效确认不改变 occupied_cells")

	controller.cancel_placing()
	_check(not controller.is_placing(), "取消后回到 idle")
	_check(not preview.visible, "取消后预览消失")
	_check(controller.get_building_count() == initial_building_count + 1,
		"取消不删除已放置建筑")

	var ui_overlap_points := {
		"TopStatusBar": Vector2(600.0, 55.0),
		"CityBar": Vector2(100.0, 300.0),
		"MinimapPlaceholder": Vector2(1050.0, 115.0),
		"ConstructionEntryPanel": Vector2(1050.0, 205.0),
	}
	scene.set_city_bar_expanded(true)
	await process_frame
	for ui_name in ui_overlap_points:
		controller.begin_placing(ui_overlap_points[ui_name])
		_check(not controller.preview_valid, "与 %s 投影重叠时无效" % ui_name)
		_check(controller.preview_invalid_reason == "被界面遮挡",
			"%s 重叠由实际 UI rect 判定" % ui_name)
		_check(not controller.confirm_current_preview(),
			"%s 下方左键确认不会放置" % ui_name)
		controller.cancel_placing()
	_check(controller.get_building_count() == initial_building_count + 1,
		"所有 UI 遮挡无效确认均不改变权威记录")
	_check(controller.get_occupied_cell_count() == initial_occupied_count + 4,
		"所有 UI 遮挡无效确认均不改变 occupied_cells")

	controller.begin_placing(ui_overlap_points.CityBar)
	var occluded_cell: Vector2i = controller.preview_origin_cell
	_check(not controller.is_cell_occupied(occluded_cell),
		"UI 遮挡不会把世界格写入 occupied_cells")

	scene.set_city_bar_expanded(false)
	camera.position.x -= 320.0
	await process_frame
	var occluded_cell_center: Vector2 = (
		controller.cell_to_map_local(occluded_cell)
		+ controller.TEST_BUILDING_WORLD_SIZE * 0.5
	)
	var moved_screen_position: Vector2 = controller.map_local_to_screen(
		occluded_cell_center
	)
	controller.update_preview(moved_screen_position)
	_check(controller.preview_origin_cell == occluded_cell,
		"移动相机后仍指向同一世界格")
	_check(controller.preview_valid,
		"同一世界格移入安全可见区后可重新确认")
	controller.cancel_placing()

	controller.begin_placing(Vector2(760.0, 420.0))
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	scene._input(escape_event)
	_check(not controller.is_placing(), "Esc 通过唯一输入入口取消")
	_check(not preview.visible, "Esc 取消后预览消失")

	controller.begin_placing(Vector2(760.0, 420.0))
	var right_event := InputEventMouseButton.new()
	right_event.button_index = MOUSE_BUTTON_RIGHT
	right_event.pressed = true
	right_event.position = Vector2(760.0, 420.0)
	scene._input(right_event)
	_check(not controller.is_placing(), "右键通过唯一输入入口取消")

	controller.begin_placing(Vector2(860.0, 500.0))
	_check(controller.preview_valid, "左键路由测试位置有效")
	var placing_left_camera_position := camera.position
	var placement_count_before_left: int = controller.get_building_count()
	var placing_left_press := InputEventMouseButton.new()
	placing_left_press.button_index = MOUSE_BUTTON_LEFT
	placing_left_press.pressed = true
	placing_left_press.position = Vector2(860.0, 500.0)
	scene._input(placing_left_press)
	_check(controller.get_building_count() == placement_count_before_left + 1,
		"placing 左键通过唯一输入入口确认放置")
	_check(camera.position.is_equal_approx(placing_left_camera_position),
		"placing 左键不移动 Camera2D")
	_check(controller.is_placing(), "确认一次后保持 placing 以便连续放置")
	controller.cancel_placing()

	var idle_camera_position := camera.position
	var left_press := InputEventMouseButton.new()
	left_press.button_index = MOUSE_BUTTON_LEFT
	left_press.pressed = true
	left_press.position = Vector2(600.0, 350.0)
	scene._input(left_press)
	var left_motion := InputEventMouseMotion.new()
	left_motion.position = Vector2(620.0, 350.0)
	scene._input(left_motion)
	var left_release := InputEventMouseButton.new()
	left_release.button_index = MOUSE_BUTTON_LEFT
	left_release.pressed = false
	left_release.position = Vector2(620.0, 350.0)
	scene._input(left_release)
	_check(not camera.position.is_equal_approx(idle_camera_position),
		"idle 状态保留原左键阈值拖动路径")
	_check(scene.active_drag_button == -1, "idle 拖动松开立即停止")

	controller.begin_placing(Vector2(760.0, 420.0))
	var placing_camera_position := camera.position
	var middle_press := InputEventMouseButton.new()
	middle_press.button_index = MOUSE_BUTTON_MIDDLE
	middle_press.pressed = true
	middle_press.position = Vector2(760.0, 420.0)
	scene._input(middle_press)
	var middle_motion := InputEventMouseMotion.new()
	middle_motion.position = Vector2(780.0, 420.0)
	scene._input(middle_motion)
	var middle_release := InputEventMouseButton.new()
	middle_release.button_index = MOUSE_BUTTON_MIDDLE
	middle_release.pressed = false
	middle_release.position = Vector2(780.0, 420.0)
	scene._input(middle_release)
	_check(not camera.position.is_equal_approx(placing_camera_position),
		"placing 状态保留中键 Camera2D 拖动")
	_check(scene.active_drag_button == -1, "placing 中键松开立即停止")

	var zoom_before := camera.zoom.x
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	wheel_event.position = Vector2(780.0, 420.0)
	scene._input(wheel_event)
	_check(camera.zoom.x > zoom_before, "placing 状态保留滚轮缩放")

	controller.cancel_placing()
	scene.queue_free()
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
		print("CONSTRUCTION_PLACEMENT_SMOKE PASS")
		quit(0)
	else:
		print("CONSTRUCTION_PLACEMENT_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

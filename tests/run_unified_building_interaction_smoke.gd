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
	var detail_panel: Panel = scene.get_node("UI/Shell/BuildingDetailPanel")
	var remove_button: Button = detail_panel.get_node("RemoveButton")
	var target_name: Label = detail_panel.get_node("TargetName")
	var target_type: Label = detail_panel.get_node("TargetType")
	var description: Label = detail_panel.get_node("Description")
	var construction_entry: Control = scene.get_node(
		"UI/Shell/ConstructionEntryPanel"
	)
	var build_entry_button: Button = construction_entry.get_node(
		"BuildEntryButton"
	)
	var construction_menu: Control = scene.get_node(
		"UI/Shell/ConstructionMenu"
	)
	var build_template_button: Button = construction_menu.get_node(
		"LoggingCampButton"
	)
	var preview: Node2D = scene.get_node(
		"MapWorld/ConstructionLayer/ConstructionPreview"
	)

	_check(scene.find_children("MapWorld", "Node2D", true, false).size() == 1,
		"场景只有一个 MapWorld")
	_check(scene.find_children("Camera2D", "Camera2D", true, false).size() == 1,
		"场景只有一个 Camera2D")
	_check(scene.find_children("Shell", "Control", true, false).size() == 1,
		"场景只有一个 UI Shell")
	_check(not scene.has_node("UI/Shell/ContextBar"),
		"底部 ContextBar 已完整移除")
	_check(_scene_has_no_retired_bottom_text(scene),
		"场景不再显示建设、派遣、管理或未选择目标")

	var expected_fixed := {
		"Manor": "城主府 L1",
		"Barracks": "兵营 L1",
		"Granary": "粮仓 L2",
		"Academy": "学院 L1",
		"CityGate": "城门 L1",
		"CommandPlatform": "军令台 L1",
		"Noticeboard": "告示板",
	}
	var fixed_ids: Array[int] = []
	for placement_id in construction.get_placement_ids():
		var record: Dictionary = construction.get_building_record(placement_id)
		if record.placement_kind == construction.PLACEMENT_KIND_FIXED:
			fixed_ids.append(placement_id)

	_check(fixed_ids.size() == expected_fixed.size(),
		"七个预置建筑各有一条统一权威记录")
	_check(construction.get_building_count() == 7,
		"初始权威记录只包含七个固定建筑")

	var seen_ids: Dictionary = {}
	for placement_id in construction.get_placement_ids():
		_check(not seen_ids.has(placement_id), "placement_id 唯一")
		seen_ids[placement_id] = true

	for fixed_id in fixed_ids:
		var record: Dictionary = construction.get_building_record(fixed_id)
		var building: CanvasItem = construction.get_building_node(fixed_id)
		_check(building != null, "固定记录指向真实预置节点")
		_check(expected_fixed.get(str(building.name), "") == record.display_name,
			"固定建筑名称来自统一记录")
		_check(record.selectable, "固定建筑可选择")
		_check(not record.removable, "固定建筑不可移除")
		_check(not record.movable, "固定建筑不可移动")
		_check(not record.occupied_footprint_cells.is_empty(),
			"固定建筑保守栅格化为占用格")
		_check(building.get_meta_list() == [&"placement_id"],
			"固定节点 metadata 只保留 placement_id")
		for cell in record.occupied_footprint_cells:
			_check(
				construction.get_occupied_placement_id(cell) == fixed_id,
				"固定建筑占用格归对应 placement_id")

	camera.zoom = Vector2.ONE
	camera.position = Vector2(576.0, 324.0)
	await process_frame
	for fixed_id in fixed_ids:
		selection.clear_selection()
		var fixed_record_for_focus: Dictionary = construction.get_building_record(
			fixed_id
		)
		var fixed_building_for_focus: CanvasItem = construction.get_building_node(
			fixed_id
		)
		scene.center_world_position_in_safe_area(
			fixed_building_for_focus.global_position
				+ (fixed_record_for_focus.selection_bounds as Rect2).get_center()
		)
		await process_frame
		var screen_center := _building_screen_center(
			construction,
			fixed_id
		)
		_click_via_root(scene, screen_center)
		var record: Dictionary = construction.get_building_record(fixed_id)
		_check(selection.selected_placement_id == fixed_id,
			"%s 可通过统一点击路径选择" % record.display_name)
		if StringName(record.template_id) == &"noticeboard":
			_check(
				scene.get_node("UI/Shell/NoticeboardPanel").visible,
				"告示板选择后显示独立任务列表"
			)
			_check(
				not detail_panel.visible,
				"告示板不与军令台或通用详情面板合并"
			)
			continue
		_check(detail_panel.visible, "固定建筑选择后显示右侧详情")
		_check(target_name.text == record.display_name,
			"详情显示固定建筑真实名称")
		var building_data: Dictionary = construction.get_building_data(
			fixed_id
		)
		_check(
			target_type.text.contains(str(building_data.level_text))
				and target_type.text.contains("下一等级：当前切片未开放"),
			"详情显示固定建筑真实等级且不伪造升级"
		)
		_check(
			description.text.contains("前置：初始固定设施")
				and description.text.contains("状态：固定 / 可选择"),
			"详情显示固定设施前置和运行状态"
		)
		_check(not remove_button.visible,
			"固定建筑详情不显示移除入口")
		_check(not construction_entry.visible,
			"固定详情显示时右侧建造入口让位")

	var command_id := _placement_id_for_node_name(
		construction,
		"CommandPlatform"
	)
	selection.select_placement(command_id)
	_check(target_name.text == "军令台 L1", "军令台显示真实名称")
	var first_war_actions: Control = detail_panel.get_node("FirstWarActions")
	_check(
		first_war_actions.visible
			and first_war_actions.get_node("WarIntel").text.contains("北坡敌情")
			and not first_war_actions.get_node("EnterBattleButton").visible,
		"军令台显示真实首战评估且备战早期不伪造执行入口"
	)
	_check(not construction.remove_placed_building(command_id),
		"固定军令台拒绝进入普通移除生命周期")
	_check(not construction.get_building_record(command_id).is_empty(),
		"拒绝移除不会改变军令台权威记录")

	var fixed_record: Dictionary = construction.get_building_record(fixed_ids[0])
	var fixed_validation: Dictionary = construction.evaluate_origin_cell(
		fixed_record.origin_cell
	)
	_check(
		not fixed_validation.valid
		and fixed_validation.reason == "位置已占用",
		"固定建筑占用格阻止重叠建造"
	)

	selection.clear_selection()
	_check(construction_entry.visible, "关闭详情后右侧建造入口恢复")
	_check(not construction_menu.visible, "建造模板列表初始隐藏")
	build_entry_button.emit_signal("pressed")
	_check(construction.is_choosing_template(),
		"右侧建造入口打开当前模板列表")
	_check(construction_menu.visible, "模板列表显示")
	_check(not selection.has_selection(), "打开建造列表清除建筑选择")

	var menu_center := construction_menu.get_global_rect().get_center()
	var camera_before_ui := camera.position
	var zoom_before_ui := camera.zoom.x
	_drag_button_via_root(
		scene,
		MOUSE_BUTTON_LEFT,
		menu_center,
		menu_center + Vector2(24.0, 0.0)
	)
	_drag_button_via_root(
		scene,
		MOUSE_BUTTON_MIDDLE,
		menu_center,
		menu_center + Vector2(24.0, 0.0)
	)
	_drag_button_via_root(
		scene,
		MOUSE_BUTTON_RIGHT,
		menu_center,
		menu_center + Vector2(24.0, 0.0)
	)
	scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_UP, menu_center))
	_check(camera.position.is_equal_approx(camera_before_ui),
		"右侧建造 UI 内左中右键不移动地图")
	_check(is_equal_approx(camera.zoom.x, zoom_before_ui),
		"右侧建造 UI 内滚轮不缩放地图")

	build_template_button.emit_signal("pressed")
	_check(construction.is_placing(), "选择伐木场模板进入 placing")
	_check(preview.visible, "placing 显示既有建造预览")
	_check(not construction_menu.visible, "进入 placing 后模板列表关闭")
	construction.cancel_placing()
	_check(not preview.visible, "取消 placing 隐藏预览")

	selection.select_placement(command_id)
	construction.open_construction_menu()
	_check(not selection.has_selection(), "打开建造会清除固定建筑选择")
	_check(not detail_panel.visible, "打开建造会关闭详情")
	_check(construction.is_choosing_template(), "打开建造进入模板选择")

	construction.begin_placing(Vector2(700.0, 500.0))
	_check(construction.is_placing(), "模板选择可进入 placing")
	selection.select_placement(command_id)
	_check(not construction.is_placing(), "选中建筑会退出建造预览")
	_check(selection.selected_placement_id == command_id,
		"退出建造后显示被选中的固定建筑")

	selection.clear_selection()
	camera.position = Vector2(1100.0, 700.0)
	await process_frame
	var bottom_start := Vector2(670.0, 610.0)
	var bottom_finish := Vector2(650.0, 610.0)
	var camera_before_bottom_drag := camera.position
	_drag_button_via_root(
		scene,
		MOUSE_BUTTON_LEFT,
		bottom_start,
		bottom_finish
	)
	_check(not camera.position.is_equal_approx(camera_before_bottom_drag),
		"底栏删除后原区域没有透明 Control 阻挡地图")

	var fixed_count_before_runtime: int = construction.get_building_count()
	var runtime_id: int = construction._create_runtime_building(Vector2i(20, 20))
	var runtime_record: Dictionary = construction.get_building_record(runtime_id)
	_check(runtime_record.placement_kind == construction.PLACEMENT_KIND_PLACED,
		"运行时建筑使用 placed 能力记录")
	_check(runtime_record.selectable and runtime_record.removable,
		"运行时生产建筑可选择且可移除")
	_check(not runtime_record.movable, "运行时生产建筑仍不可移动")
	_check(_same_record_shape(fixed_record, runtime_record),
		"固定与运行时建筑使用相同记录字段")

	selection.select_placement(runtime_id)
	_check(remove_button.visible, "运行时生产建筑保留安全移除入口")
	selection.request_removal_confirmation()
	_check(selection.is_awaiting_removal_confirmation(),
		"运行时生产建筑仍进入 P0-05 移除确认")
	_check(selection.confirm_removal(), "运行时生产建筑仍可安全移除")
	await process_frame
	_check(construction.get_building_count() == fixed_count_before_runtime,
		"移除运行时建筑后保留全部固定建筑")
	for fixed_id in fixed_ids:
		_check(not construction.get_building_record(fixed_id).is_empty(),
			"运行时移除不影响固定建筑记录")

	scene.queue_free()
	await process_frame
	_finish()


func _placement_id_for_node_name(
	construction: Node,
	node_name: String
) -> int:
	for placement_id in construction.get_placement_ids():
		var building: CanvasItem = construction.get_building_node(placement_id)
		if building != null and str(building.name) == node_name:
			return placement_id
	return -1


func _building_screen_center(
	construction: Node,
	placement_id: int
) -> Vector2:
	var record: Dictionary = construction.get_building_record(placement_id)
	var building: CanvasItem = record.node
	var local_center: Vector2 = record.selection_bounds.get_center()
	var global_center: Vector2 = building.get_global_transform() * local_center
	var map_world: Node2D = construction.map_world
	return construction.map_local_to_screen(map_world.to_local(global_center))


func _scene_has_no_retired_bottom_text(scene: Node) -> bool:
	for label in scene.find_children("*", "Label", true, false):
		if label.text in ["建设", "派遣", "管理", "未选择目标"]:
			return false
	for button in scene.find_children("*", "Button", true, false):
		if button.text in ["建设", "派遣", "管理", "未选择目标"]:
			return false
	return true


func _same_record_shape(first: Dictionary, second: Dictionary) -> bool:
	var first_keys: Array = first.keys()
	var second_keys: Array = second.keys()
	first_keys.sort()
	second_keys.sort()
	return first_keys == second_keys


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


func _check(condition: bool, description_text: String) -> void:
	if condition:
		print("PASS: %s" % description_text)
	else:
		failures.append(description_text)
		push_error("FAIL: %s" % description_text)


func _finish() -> void:
	if failures.is_empty():
		print("UNIFIED_BUILDING_INTERACTION_SMOKE PASS")
		quit(0)
	else:
		print(
			"UNIFIED_BUILDING_INTERACTION_SMOKE FAIL (%d)"
			% failures.size()
		)
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

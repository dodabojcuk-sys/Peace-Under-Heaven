extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可以加载")
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
	var pause_button: Button = scene.get_node(
		"UI/Shell/TopStatusBar/PauseButton"
	)
	var city_bar: Control = scene.get_node("UI/Shell/CityBar")
	var city_bar_toggle: Button = scene.get_node("UI/Shell/CityBarToggle")

	_check(not construction.is_city_time_paused(), "进入场景后时间默认运行")
	_check(pause_button.text == "暂停", "运行态顶部控件显示暂停")
	_check(
		not scene.has_node("UI/Shell/TopStatusBar/EndDayButton"),
		"正式 UI 不存在结束本日入口"
	)
	_check(
		is_equal_approx(construction.SECONDS_PER_DAY, 180.0),
		"每日日长集中为 180 秒正式首战参数"
	)

	construction.set_process(false)
	construction.restart_first_map()
	var initial_food: int = construction.food
	var expected_upkeep: int = construction.get_maintenance_food_cost()
	_check(
		construction.advance_city_time_for_test(
			construction.SECONDS_PER_DAY
		) == 1,
		"未点击按钮也可由模拟时钟跨越日界线"
	)
	_check(
		construction.current_day == 2
			and construction.tech_points == 1
			and construction.food == initial_food - expected_upkeep,
		"一次日界线只结算一次维护与研究"
	)

	construction.restart_first_map()
	construction.advance_city_time_for_test(17.0)
	var progress_before_pause: float = construction.day_elapsed_seconds
	construction.set_city_time_paused(true)
	construction.advance_city_time_for_test(100.0)
	_check(
		construction.current_day == 1
			and is_equal_approx(
				construction.day_elapsed_seconds,
				progress_before_pause
			),
		"暂停冻结日期并保留当天进度"
	)
	_check(pause_button.text == "继续", "暂停态顶部控件显示继续")

	var camera_before_paused_drag := camera.position
	_drag_map(scene, Vector2(600.0, 360.0), Vector2(624.0, 360.0))
	_check(
		not camera.position.is_equal_approx(camera_before_paused_drag),
		"暂停时地图拖拽仍可操作"
	)
	var first_placement_id: int = construction.get_placement_ids()[0]
	selection.select_placement(first_placement_id)
	_check(
		selection.has_selection()
			and construction.is_city_time_paused(),
		"暂停时建筑查看可用且不会改变暂停状态"
	)
	selection.clear_selection()
	construction.open_construction_menu()
	_check(
		construction.is_choosing_template()
			and construction.is_city_time_paused(),
		"暂停时建设规划入口仍可操作"
	)
	construction.cancel_build_interaction()

	construction.set_city_time_paused(false)
	construction.advance_city_time_for_test(
		construction.SECONDS_PER_DAY - progress_before_pause
	)
	_check(
		construction.current_day == 2
			and is_zero_approx(construction.day_elapsed_seconds),
		"继续后从暂停前进度恢复而非重置当天"
	)

	construction.restart_first_map()
	selection.select_placement(first_placement_id)
	_check(
		not construction.is_city_time_paused(),
		"打开普通详情面板不会自动暂停"
	)
	selection.clear_selection()
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(
		not construction.is_city_time_paused(),
		"窗口焦点变化不会主动切换暂停状态"
	)

	var comparison_scene := packed_scene.instantiate()
	root.add_child(comparison_scene)
	await process_frame
	await process_frame
	var comparison: Node = comparison_scene.get_node("ConstructionController")
	var comparison_time_summary: Label = comparison_scene.get_node(
		"UI/Shell/TopStatusBar/TimeSummary"
	)
	comparison.set_process(false)
	construction.restart_first_map()
	comparison.restart_first_map()
	construction.resolve_first_war_for_test(&"VICTORY")
	comparison.resolve_first_war_for_test(&"VICTORY")
	var nine_days_seconds: float = construction.SECONDS_PER_DAY * 9.0
	for _step in range(int(nine_days_seconds)):
		construction.advance_city_time_for_test(1.0)
	comparison.advance_city_time_for_test(nine_days_seconds)
	_check(
		_city_outcome(construction) == _city_outcome(comparison),
		"相同模拟时间在不同帧增量下得到相同日期与事件结果"
	)
	_check(
		comparison.current_day == 10
			and comparison.enemy_count == 56
			and comparison.enemy_fortification == 2
			and comparison.tech_points == 9,
		"大增量不重复或漏掉第 5、8、10 日日界线"
	)

	comparison.restart_first_map()
	comparison.resolve_first_war_for_test(&"VICTORY")
	comparison.advance_city_time_for_test(
		comparison.SECONDS_PER_DAY * 10.0
	)
	_check(
		comparison.current_day == 11
			and not comparison.is_city_time_paused(),
		"运行状态可以正常到达第 11 日"
	)
	comparison.advance_city_time_for_test(comparison.SECONDS_PER_DAY)
	_check(
		comparison.current_day == 12
			and comparison.enemy_count == 64
			and comparison.enemy_fortification == 2
			and comparison.tech_points == 11
			and not comparison.is_city_time_paused(),
		"从第 11 日进入第 12 日不会自动暂停"
	)
	comparison.advance_city_time_for_test(17.0)
	_check(
		comparison.current_day == 12
			and is_equal_approx(comparison.day_elapsed_seconds, 17.0)
			and is_equal_approx(
				comparison.get_day_progress_ratio(),
				17.0 / comparison.SECONDS_PER_DAY
			)
			and comparison_time_summary.text == "第 12 日 · 00:17",
		"第 12 日当天进度继续积累且时间进度不被内容边界封顶"
	)
	comparison.set_city_time_paused(true)
	comparison.advance_city_time_for_test(100.0)
	comparison_scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	comparison_scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(
		comparison.current_day == 12
			and is_equal_approx(comparison.day_elapsed_seconds, 17.0)
			and comparison.is_city_time_paused(),
		"第 12 日只有玩家明确暂停才冻结且焦点变化不改状态"
	)
	comparison.set_city_time_paused(false)
	comparison.advance_city_time_for_test(
		comparison.SECONDS_PER_DAY - 17.0
	)
	_check(
		comparison.current_day == 13
			and is_zero_approx(comparison.day_elapsed_seconds)
			and not comparison.is_city_time_paused()
			and comparison.tech_points == 12,
		"继续后从第 12 日原进度恢复并自动进入第 13 日"
	)
	_check(
		comparison.enemy_count == 64
			and comparison.enemy_fortification == 2
			and comparison.get_last_daily_breakdown().event_food_loss == 0
			and int(
				comparison.get_last_daily_breakdown().stopped_placement_id
			) < 0,
		"第 13 日不重复触发第 12 日特殊事件"
	)

	construction.restart_first_map()
	comparison.restart_first_map()
	construction.resolve_first_war_for_test(&"VICTORY")
	comparison.resolve_first_war_for_test(&"VICTORY")
	var thirteen_and_half_days: float = (
		construction.SECONDS_PER_DAY * 13.5
	)
	for _step in range(int(thirteen_and_half_days)):
		construction.advance_city_time_for_test(1.0)
	comparison.advance_city_time_for_test(thirteen_and_half_days)
	_check(
		_city_outcome(construction) == _city_outcome(comparison)
			and comparison.current_day == 14
			and is_equal_approx(comparison.day_elapsed_seconds, 90.0)
			and not comparison.is_city_time_paused(),
		"大增量跨越第 12、13 日不重复结算、不丢失日期"
	)

	construction.restart_first_map()
	construction.resolve_first_war_for_test(&"VICTORY")
	var expected_threats := {
		5: Vector2i(40, 0),
		8: Vector2i(48, 1),
		10: Vector2i(56, 2),
		12: Vector2i(64, 2),
	}
	for target_day in expected_threats:
		while construction.current_day < target_day:
			construction.advance_one_day_for_test()
		var expected: Vector2i = expected_threats[target_day]
		_check(
			construction.enemy_count == expected.x
				and construction.enemy_fortification == expected.y,
			"第 %d 日威胁仍按原规则触发" % target_day
		)

	construction.restart_first_map()
	var placement_snapshot := _placement_origins(construction)
	_check(
			not scene.is_city_bar_expanded()
			and not city_bar.visible
			and city_bar_toggle.visible
			and scene.get_node("UI/Shell/GovernanceWorkspace").visible,
		"右侧城市经营默认展开且城市切换入口始终可见"
	)
	scene.set_city_bar_expanded(false)
	await process_frame
	_check(
		not scene.is_city_bar_expanded()
			and not city_bar.visible
			and city_bar_toggle.text == "展开",
		"城市序列可以收起"
	)
	_check(
		placement_snapshot == _placement_origins(construction),
		"收起城市序列不修改建筑 placement"
	)
	_check(
		not construction.is_city_time_paused(),
		"收起城市序列不会改变时间运行状态"
	)
	scene.set_city_bar_expanded(true)
	await process_frame

	var all_buildings_fit := true
	for placement_id in construction.get_placement_ids():
		var record: Dictionary = construction.get_building_record(
			placement_id
		)
		var building: CanvasItem = construction.get_building_node(
			placement_id
		)
		var world_rect := _building_world_rect(record, building)
		scene.focus_world_rect_in_safe_area(world_rect)
		await process_frame
		var screen_rect := _map_rect_to_screen(construction, world_rect)
		if not _rect_is_inside(
			screen_rect,
			scene.get_navigation_safe_rect()
		):
			all_buildings_fit = false
			break
	_check(
		all_buildings_fit,
		"默认展开后全部建筑都能通过相机拖动进入安全可见区域"
	)

	scene.set_city_bar_expanded(false)
	await process_frame
	_check(
		not city_bar.visible
			and not selection.is_screen_point_blocked(Vector2(100.0, 300.0)),
		"左侧栏收起后隐藏控件不再拦截地图输入"
	)
	_check(
		placement_snapshot == _placement_origins(construction),
		"收起侧栏不修改建筑 placement"
	)

	var camera_before_toggle_input := camera.position
	var toggle_press := InputEventMouseButton.new()
	toggle_press.button_index = MOUSE_BUTTON_LEFT
	toggle_press.pressed = true
	toggle_press.position = city_bar_toggle.get_global_rect().get_center()
	scene._input(toggle_press)
	_check(
		camera.position.is_equal_approx(camera_before_toggle_input)
			and scene.active_drag_button == -1,
		"侧栏 UI 点击不会穿透到地图拖拽"
	)

	var camera_before_pause_input := camera.position
	var pause_press := InputEventMouseButton.new()
	pause_press.button_index = MOUSE_BUTTON_LEFT
	pause_press.pressed = true
	pause_press.position = pause_button.get_global_rect().get_center()
	scene._input(pause_press)
	_check(
		camera.position.is_equal_approx(camera_before_pause_input)
			and scene.active_drag_button == -1,
		"暂停控件不会触发地图拖拽或建筑选择"
	)

	_check(_count_named(scene, "MapWorld") == 1, "仍只有一个 MapWorld")
	_check(_count_named(scene, "Camera2D") == 1, "仍只有一个 Camera2D")
	_check(
		_count_named(scene, "ConstructionController") == 1,
		"仍只有一个 ConstructionController"
	)
	_check(_count_input_owners(scene) == 1, "仍只有一个正式 _input 所有者")

	comparison_scene.queue_free()
	scene.queue_free()
	await process_frame
	_finish()


func _drag_map(scene: Node, start: Vector2, finish: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	scene._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	scene._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	scene._input(release)


func _city_outcome(construction: Node) -> Dictionary:
	return {
		"day": construction.current_day,
		"wood": construction.wood,
		"food": construction.food,
		"tech_points": construction.tech_points,
		"enemy_count": construction.enemy_count,
		"enemy_fortification": construction.enemy_fortification,
		"day_elapsed_seconds": construction.day_elapsed_seconds,
		"city_time_paused": construction.is_city_time_paused(),
		"last_daily_breakdown": (
			construction.get_last_daily_breakdown()
		),
	}


func _placement_origins(construction: Node) -> Dictionary:
	var result := {}
	for placement_id in construction.get_placement_ids():
		result[placement_id] = construction.get_building_record(
			placement_id
		).origin_cell
	return result


func _building_world_rect(
	record: Dictionary,
	building: CanvasItem
) -> Rect2:
	var bounds: Rect2 = record.selection_bounds
	var transform := building.get_global_transform()
	var first := transform * bounds.position
	var opposite := transform * bounds.end
	return Rect2(first.min(opposite), (opposite - first).abs())


func _map_rect_to_screen(construction: Node, map_rect: Rect2) -> Rect2:
	var first: Vector2 = construction.map_local_to_screen(map_rect.position)
	var opposite: Vector2 = construction.map_local_to_screen(map_rect.end)
	return Rect2(first.min(opposite), (opposite - first).abs())


func _rect_is_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.1
		and inner.position.y >= outer.position.y - 0.1
		and inner.end.x <= outer.end.x + 0.1
		and inner.end.y <= outer.end.y + 0.1
	)


func _count_named(node: Node, node_name: String) -> int:
	var count := 1 if node.name == node_name else 0
	for child in node.get_children():
		count += _count_named(child, node_name)
	return count


func _count_input_owners(node: Node) -> int:
	var count := 0
	if node.get_script() != null and node.has_method("_input"):
		count += 1
	for child in node.get_children():
		count += _count_input_owners(child)
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("CITY_TIME_VIEWPORT_SMOKE PASS")
		quit(0)
	else:
		print("CITY_TIME_VIEWPORT_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

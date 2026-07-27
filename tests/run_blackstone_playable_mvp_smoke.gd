extends SceneTree


var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "城市主场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var city := packed_scene.instantiate()
	root.add_child(city)
	await process_frame
	await process_frame

	var construction: Node = city.get_node("ConstructionController")
	var selection: Node = city.get_node("BuildingSelectionController")
	var theater: BlackstoneExpeditionMvp = city.get_node(
		"UI/BlackstoneExpeditionMvp"
	)
	var city_world: Node2D = city.get_node("MapWorld")
	var city_ui: Control = city.get_node("UI/Shell")
	var entry_button: Button = city.get_node(
		(
			"UI/Shell/BuildingDetailPanel/FirstWarActions/"
			+ "MvpExpeditionButton"
		)
	)
	var result_status: Label = city.get_node(
		(
			"UI/Shell/BuildingDetailPanel/FirstWarActions/"
			+ "MvpResultStatus"
		)
	)
	construction.set_city_time_paused(true)

	_check(
		city.find_children(
			"ConstructionController",
			"Node",
			true,
			false
		).size() == 1,
		"MVP 复用唯一 ConstructionController"
	)
	_check(not theater.visible, "战区初始隐藏")
	var command_platform_id := _placement_id_for_template(
		construction,
		&"command_platform"
	)
	_check(command_platform_id >= 0, "现有军令台记录作为 MVP 入口")
	selection.select_placement(command_platform_id)
	_check(
		entry_button.is_visible_in_tree()
			and entry_button.text == "出征黑石堡"
			and not entry_button.disabled,
		"点击军令台后显示清晰可用的出征黑石堡按钮"
	)
	_check(
		_count_buttons_with_text(city, "出征黑石堡") == 1,
		"城市中只保留一个黑石堡出征入口"
	)
	_check(
		selection.is_screen_point_blocked(
			entry_button.get_global_rect().get_center()
		),
		"出征入口阻止点击穿透到城市地图"
	)

	var wood_before := int(construction.get_city_state().wood)
	entry_button.emit_signal("pressed")
	await process_frame
	_check(city.is_blackstone_expedition_mvp_open(), "城市入口打开战区")
	_check(
		theater.visible and not city_world.visible and not city_ui.visible,
		"战区打开时只隐藏城市表现，不复制城市状态"
	)
	_check(theater.get_soldiers() == 10, "每次出征从 10 名士兵开始")
	_check(
		theater.get_available_node_ids()
			== [
				BlackstoneExpeditionMvp.NODE_REINFORCEMENT,
				BlackstoneExpeditionMvp.NODE_OUTPOST,
			],
		"营地只能前往援军或前哨"
	)

	var marker_start := theater.army_marker.position
	theater.outpost_button.emit_signal("pressed")
	_check(
		theater.get_current_node_id()
			== BlackstoneExpeditionMvp.NODE_CAMP,
		"单击目标节点不再直接派兵"
	)
	_check(
		not theater.begin_command_drag(
			_button_center(theater.reinforcement_button)
		),
		"不能从非当前驻军节点反向发令"
	)
	var camp_center := _button_center(theater.camp_button)
	_check(
		theater.begin_command_drag(camp_center),
		"只能从当前我军营地开始候选拖动"
	)
	theater.update_command_drag(camp_center + Vector2(5.0, 0.0))
	_check(
		not theater.is_command_line_visible(),
		"未超过 10 像素阈值不显示指挥线"
	)
	_check(
		not theater.end_command_drag(camp_center + Vector2(5.0, 0.0))
			and theater.get_current_node_id()
				== BlackstoneExpeditionMvp.NODE_CAMP,
		"轻微点击松开不派兵"
	)

	_check(theater.begin_command_drag(camp_center), "可以重新开始拖动")
	var blank_screen_position := Vector2(760.0, 590.0)
	theater.update_command_drag(blank_screen_position)
	_check(
		theater.is_command_line_visible()
			and theater.get_hovered_target_id() == &""
			and theater.command_line.default_color
				== BlackstoneExpeditionMvp.COMMAND_LINE_INVALID_COLOR,
		"拖向空白显示红色无效指挥线"
	)
	_check(
		not theater.end_command_drag(blank_screen_position)
			and theater.get_soldiers() == 10
			and not theater.is_command_line_visible(),
		"空白处松开取消且不改变状态"
	)

	_check(theater.begin_command_drag(camp_center), "可以检查不可达目标")
	theater.update_command_drag(_button_center(theater.fortress_button))
	_check(
		theater.get_hovered_target_id()
			== BlackstoneExpeditionMvp.NODE_FORTRESS
			and theater.command_line.default_color
				== BlackstoneExpeditionMvp.COMMAND_LINE_INVALID_COLOR,
		"营地拖向不可达黑石堡显示红色拒绝"
	)
	_check(
		not theater.end_command_drag(
			_button_center(theater.fortress_button)
		)
			and theater.get_current_node_id()
				== BlackstoneExpeditionMvp.NODE_CAMP,
		"不可达目标松开不移动、不结算"
	)

	_check(theater.begin_command_drag(camp_center), "可以开始 ESC 取消测试")
	theater.update_command_drag(
		_button_center(theater.reinforcement_button)
	)
	_check(
		theater.is_command_line_visible()
			and theater.command_line.default_color
				== BlackstoneExpeditionMvp.COMMAND_LINE_VALID_COLOR,
		"拖向相邻援军显示绿色有效指挥线"
	)
	_check(
		theater.handle_escape()
			and not theater.is_command_drag_active()
			and not theater.is_command_line_visible()
			and city.is_blackstone_expedition_mvp_open(),
		"拖动中按 ESC 只取消指挥，不退出战区"
	)

	_check(
		_drag_to_button(
			theater,
			theater.camp_button,
			theater.outpost_button
		),
		"从营地拖向前哨松开只执行一次有效命令"
	)
	_check(theater.get_soldiers() == 5, "直接进攻前哨后剩余 5 人")
	_check(
		theater.get_current_node_id()
			== BlackstoneExpeditionMvp.NODE_OUTPOST,
		"军队标记所在节点更新为黑石前哨"
	)
	_check(theater.army_marker.position != marker_start, "军队标记发生可见移动")
	_check(
		_drag_to_button(
			theater,
			theater.outpost_button,
			theater.fortress_button
		),
		"从前哨拖向黑石堡执行第二次命令"
	)
	_check(
		theater.get_outcome()
			== BlackstoneExpeditionMvp.OUTCOME_DEFEAT,
		"5 人直接进攻 8 人的黑石堡必然失败"
	)
	_check(theater.result_panel.visible, "失败显示明确结果面板")
	_check(
		int(construction.get_city_state().wood) == wood_before,
		"失败不永久扣除或增加城市资源"
	)
	theater.return_button.emit_signal("pressed")
	await process_frame
	_check(
		not city.is_blackstone_expedition_mvp_open()
			and city_world.visible
			and city_ui.visible,
		"失败后可以返回同一城市"
	)
	selection.select_placement(command_platform_id)
	_check(
		result_status.text.contains("出征失败"),
		"返回城市后保留本次失败提示"
	)

	entry_button.emit_signal("pressed")
	await process_frame
	_check(theater.get_soldiers() == 10, "无需重启即可再次挑战")
	_check(
		_drag_to_button(
			theater,
			theater.camp_button,
			theater.reinforcement_button
		),
		"从营地拖向山路援军"
	)
	_check(theater.get_soldiers() == 16, "山路援军使兵力增加到 16")
	_check(
		_drag_to_button(
			theater,
			theater.reinforcement_button,
			theater.outpost_button
		),
		"从援军点拖向黑石前哨"
	)
	_check(theater.get_soldiers() == 11, "援军路线攻下前哨后剩余 11 人")
	_check(
		_drag_to_button(
			theater,
			theater.outpost_button,
			theater.fortress_button
		),
		"从前哨拖向黑石堡完成胜利路线"
	)
	_check(
		theater.get_outcome()
			== BlackstoneExpeditionMvp.OUTCOME_VICTORY,
		"11 人进攻 8 人的黑石堡取得胜利"
	)
	_check(theater.get_soldiers() == 3, "胜利后剩余 3 人")
	_check(theater.result_panel.visible, "胜利显示明确结果面板")
	var expected_reward := mini(
		city.MVP_VICTORY_WOOD_REWARD,
		maxi(
			int(construction.get_resource_capacity(&"wood")) - wood_before,
			0
		)
	)
	_check(
		int(construction.get_city_state().wood)
			== wood_before + expected_reward,
		"胜利通过城市权威控制器增加可见木材奖励"
	)
	theater.return_button.emit_signal("pressed")
	await process_frame
	selection.select_placement(command_platform_id)
	_check(
		result_status.text.contains("胜利")
			and result_status.text.contains("木材"),
		"返回城市后显示胜利与木材回写结果"
	)

	entry_button.emit_signal("pressed")
	await process_frame
	_check(
		city.is_blackstone_expedition_mvp_open()
			and not theater.is_command_drag_active()
			and not theater.is_command_line_visible()
			and theater.get_current_node_id()
				== BlackstoneExpeditionMvp.NODE_CAMP,
		"胜利后再次进入时拖线与驻军位置完全重置"
	)
	theater.request_return_to_city()
	await process_frame
	_check(not city.is_blackstone_expedition_mvp_open(), "未完成战斗也可返回城市")

	city.queue_free()
	await process_frame
	_finish()


func _placement_id_for_template(
	construction: Node,
	template_id: StringName
) -> int:
	for placement_id in construction.get_placement_ids():
		var record: Dictionary = construction.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == template_id:
			return placement_id
	return -1


func _count_buttons_with_text(root_node: Node, expected_text: String) -> int:
	var count := 0
	for node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == expected_text:
			count += 1
	return count


func _button_center(button: Button) -> Vector2:
	return button.get_global_rect().get_center()


func _drag_to_button(
	theater: BlackstoneExpeditionMvp,
	source_button: Button,
	target_button: Button
) -> bool:
	var source_position := _button_center(source_button)
	var target_position := _button_center(target_button)
	if not theater.begin_command_drag(source_position):
		return false
	theater.update_command_drag(target_position)
	return theater.end_command_drag(target_position)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		printerr("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("PASS: 黑石堡可玩 MVP smoke（%d 条断言）" % checks)
		quit(0)
		return
	printerr(
		"FAIL: 黑石堡可玩 MVP smoke（%d/%d 失败）"
		% [failures.size(), checks]
	)
	quit(1)

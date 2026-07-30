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
		"军令台显示唯一可用的出征黑石堡按钮"
	)
	_check(
		_count_buttons_with_text(city, "出征黑石堡") == 1,
		"城市中只保留一个黑石堡出征入口"
	)

	var wood_before := int(construction.get_city_state().wood)
	entry_button.emit_signal("pressed")
	await process_frame
	_check(city.is_blackstone_expedition_mvp_open(), "城市入口打开战区")
	_check(
		theater.visible and not city_world.visible and not city_ui.visible,
		"战区打开时只隐藏城市表现，不复制城市状态"
	)
	_assert_fresh_run(theater)
	_assert_v4_scene_contract(theater)
	_assert_dispatch_choice_rounding(theater)
	await _assert_visual_contract(theater)
	_assert_default_route_text_geometry(theater)

	var camp_center := _button_center(theater.camp_button)
	var reinforcement_center := _button_center(
		theater.reinforcement_button
	)
	var outpost_center := _button_center(theater.outpost_button)
	var fortress_center := _button_center(theater.fortress_button)
	var blank_position := Vector2(760.0, 590.0)

	var before_retreat_modal := _state_snapshot(theater)
	theater.cancel_button.emit_signal("pressed")
	await process_frame
	_check(
		theater.get_modal_mode()
			== BlackstoneExpeditionMvp.MODAL_RETREAT_CONFIRM
			and theater.is_modal_open()
			and theater.get_outcome()
				== BlackstoneExpeditionMvp.OUTCOME_NONE,
		"撤退按钮只打开确认弹窗，不伪造战区 outcome"
	)
	_check(
		_state_snapshot(theater) == before_retreat_modal,
		"打开撤退确认不改变驻军、敌军、行军或结果"
	)
	await _send_viewport_mouse_button(
		theater,
		camp_center,
		true,
		MOUSE_BUTTON_LEFT
	)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_retreat_modal,
		"72% 遮罩通过真实 Viewport 输入阻止底层驻军按钮"
	)
	await _send_viewport_mouse_button(
		theater,
		_button_center(theater.dispatch_percent_50),
		true,
		MOUSE_BUTTON_RIGHT
	)
	_check(
		not theater.is_modal_open()
			and theater.get_modal_mode()
				== BlackstoneExpeditionMvp.MODAL_NONE,
		"撤退确认上的真实 Viewport 右键收口到取消意图"
	)
	_check(
		theater.begin_command_interaction(camp_center),
		"关闭撤退确认后底层路线输入立即恢复"
	)
	theater.cancel_command_interaction(false)
	theater.open_retreat_confirmation()
	theater.handle_escape()
	_check(
		not theater.is_modal_open()
			and _state_snapshot(theater) == before_retreat_modal,
		"Esc 关闭撤退确认且无领域副作用"
	)
	theater.open_retreat_confirmation()
	theater.modal_close_button.emit_signal("pressed")
	_check(
		not theater.is_modal_open()
			and _state_snapshot(theater) == before_retreat_modal,
		"撤退确认关闭按钮收口到同一取消意图"
	)

	var before_short_click := _state_snapshot(theater)
	_send_mouse_button(theater, camp_center, true)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_SOURCE_ARMED,
		"真实左键按下己方节点进入 SOURCE_ARMED"
	)
	_send_mouse_motion(theater, camp_center + Vector2(4.0, 0.0))
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_SOURCE_ARMED,
		"不足 8 px 的移动不进入路线选择"
	)
	_send_mouse_button(theater, camp_center + Vector2(4.0, 0.0), false)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_short_click,
		"短按只查看节点信息，不派兵也不打开调遣条"
	)

	var before_invalid := _state_snapshot(theater)
	_begin_route_input(theater, camp_center, blank_position)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_ROUTE_SELECTING
			and theater.is_command_line_visible()
			and theater.command_line.default_color
				== BlackstoneExpeditionMvp.COMMAND_LINE_INVALID_COLOR,
		"拖向空白处进入 ROUTE_SELECTING 并显示红色路线"
	)
	_send_mouse_button(theater, blank_position, false)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_invalid
			and not theater.is_command_line_visible(),
		"空白处松开取消且不改变任何战区状态"
	)

	_begin_route_input(theater, camp_center, fortress_center)
	_check(
		theater.get_hovered_target_id()
			== BlackstoneExpeditionMvp.NODE_FORTRESS
			and theater.command_line.default_color
				== BlackstoneExpeditionMvp.COMMAND_LINE_INVALID_COLOR,
		"不相邻的黑石堡显示无效目标"
	)
	_send_mouse_button(theater, fortress_center, false)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_invalid,
		"不相邻目标松开不创建 pending order"
	)

	_begin_route_input(theater, camp_center, reinforcement_center)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_ROUTE_SELECTING
			and theater.command_line.default_color
				== BlackstoneExpeditionMvp.COMMAND_LINE_VALID_COLOR,
		"相邻援军点显示绿色有效路线"
	)
	_send_mouse_button(theater, reinforcement_center, false)
	_assert_pending_order(
		theater,
		BlackstoneExpeditionMvp.NODE_CAMP,
		BlackstoneExpeditionMvp.NODE_REINFORCEMENT,
		10
	)
	_assert_command_route_text_geometry(
		theater,
		theater.reinforcement_button,
		"调遣高亮路线"
	)
	_check(
		_state_snapshot(theater) == before_invalid,
		"有效路线松开只创建 pending order，不扣兵不结算"
	)
	var release_after_pending := InputEventMouseButton.new()
	release_after_pending.button_index = MOUSE_BUTTON_LEFT
	release_after_pending.pressed = false
	release_after_pending.position = Vector2.ZERO
	theater._gui_input(release_after_pending)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_ORDER_PENDING,
		"ORDER_PENDING 不会被通用左键松开清理"
	)
	theater.handle_escape()
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and not theater.is_dispatch_bar_visible()
			and _state_snapshot(theater) == before_invalid,
		"Esc 取消 pending order 且无副作用"
	)

	_open_pending_by_input(theater, camp_center, reinforcement_center)
	await _send_viewport_mouse_button(
		theater,
		blank_position,
		true,
		MOUSE_BUTTON_RIGHT
	)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_invalid,
		"Viewport 右键在战场空白处取消 pending 且无副作用"
	)

	_open_pending_by_input(theater, camp_center, reinforcement_center)
	var dispatch_background := (
		theater.dispatch_bar.get_global_rect().position
		+ Vector2(590.0, 48.0)
	)
	await _send_viewport_mouse_button(
		theater,
		dispatch_background,
		true,
		MOUSE_BUTTON_RIGHT
	)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_invalid,
		"Viewport 右键在调遣条背景取消 pending 且无副作用"
	)

	_open_pending_by_input(theater, camp_center, reinforcement_center)
	await _send_viewport_mouse_button(
		theater,
		_button_center(theater.dispatch_percent_50),
		true,
		MOUSE_BUTTON_RIGHT
	)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_invalid,
		"Viewport 右键在比例按钮上取消 pending 且不会执行调遣"
	)

	_open_pending_by_input(theater, camp_center, reinforcement_center)
	theater.dispatch_close_button.emit_signal("pressed")
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and _state_snapshot(theater) == before_invalid,
		"调遣条关闭按钮取消且无副作用"
	)

	theater.result_panel.visible = true
	_check(
		theater.begin_command_interaction(camp_center),
		"模型允许下令时，强制显示结果面板不改变命令合法性"
	)
	theater.cancel_command_interaction(false)
	theater._refresh_presentation()
	_check(
		not theater.result_panel.visible,
		"表现刷新会把无结果模型重新投影为隐藏结果面板"
	)
	theater.outcome = BlackstoneExpeditionMvp.OUTCOME_DEFEAT
	theater.result_panel.visible = false
	_check(
		not theater.begin_command_interaction(camp_center),
		"模型已有结果时，即使隐藏结果面板也不能再次下令"
	)
	theater._refresh_presentation()
	_check(
		theater.result_panel.visible,
		"表现刷新会把已有结果模型重新投影为显示结果面板"
	)
	theater.start_new_run()

	_open_pending_by_input(theater, camp_center, reinforcement_center)
	_send_mouse_button(theater, camp_center, true)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and theater.get_pending_order().is_empty(),
		"点击调遣条外部只取消 pending，不用同一次点击启动新命令"
	)
	_send_mouse_button(theater, camp_center, false)
	_check(
		_state_snapshot(theater) == before_invalid,
		"外部取消后的配对松开同样不改变状态"
	)

	# 完整的真实 InputEventMouseButton + MouseMotion 链：
	# IDLE -> SOURCE_ARMED -> ROUTE_SELECTING -> ORDER_PENDING。
	_open_pending_by_input(theater, camp_center, reinforcement_center)
	theater.dispatch_percent_50.emit_signal("pressed")
	var first_army := theater.get_active_marching_army()
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_MARCHING
			and first_army.size() > 0
			and int(first_army.get("total_count", 0)) == 5,
		"点击 50% 从 ORDER_PENDING 创建 5 人 MarchingArmy"
	)
	_check(
		theater.get_garrison(BlackstoneExpeditionMvp.NODE_CAMP) == 5
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_REINFORCEMENT
			) == 0
			and theater.get_total_soldiers() == 10,
		"命令成立只扣来源，抵达前目标不变且总兵力守恒"
	)
	_assert_marching_army_contract(first_army)
	_check(
		not theater.confirm_pending_dispatch_percent(50)
			and theater.get_marching_armies().size() == 1
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_CAMP
			) == 5,
		"连续快速确认不会重复扣兵或创建第二支行军对象"
	)
	_check(
		not theater.begin_command_interaction(camp_center),
		"行军中禁止重复下令"
	)
	var first_duration := float(
		first_army.get("travel_duration", 0.0)
	)
	_check(
		await _assert_real_frame_march(
			theater,
			BlackstoneExpeditionMvp.NODE_REINFORCEMENT,
			0
		),
		"真实连续帧经过 20/50/80/100%，额外松开不再卡死"
	)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and theater.is_reinforcement_claimed()
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_REINFORCEMENT
			) == 11,
		"抵达后才结算 5 人和一次性 +6 援军并回到 IDLE"
	)
	var after_arrival := _state_snapshot(theater)
	_check(
		not theater.advance_marching_time(first_duration)
			and _state_snapshot(theater) == after_arrival,
		"已抵达命令不会二次到达或结算"
	)

	_assert_percent_command(theater, 25, 3, 7)
	_assert_percent_command(theater, 50, 5, 5)
	_assert_percent_command(theater, 75, 8, 2)
	_assert_percent_command(theater, 100, 10, 0)

	theater.start_new_run()
	_open_pending_by_input(theater, camp_center, outpost_center)
	theater.dispatch_percent_25.emit_signal("pressed")
	_advance_active_army_to_arrival(theater)
	_check(
		theater.get_garrison(BlackstoneExpeditionMvp.NODE_CAMP) == 7
			and theater.get_enemy_force(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			) == 5
			and not theater.is_node_friendly(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			),
		"25% 的 3 人进攻失败，未派出的 7 人仍留守"
	)

	theater.start_new_run()
	_issue_and_arrive(
		theater,
		theater.camp_button,
		theater.outpost_button,
		75
	)
	_check(
		theater.get_garrison(BlackstoneExpeditionMvp.NODE_CAMP) == 2
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			) == 3,
		"75% 的 8 人攻下前哨，3 名幸存者驻扎"
	)
	_check(
		theater.get_available_node_ids(
			BlackstoneExpeditionMvp.NODE_CAMP
		) == [
			BlackstoneExpeditionMvp.NODE_REINFORCEMENT,
			BlackstoneExpeditionMvp.NODE_OUTPOST,
		]
			and theater.get_available_node_ids(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			) == [
				BlackstoneExpeditionMvp.NODE_CAMP,
				BlackstoneExpeditionMvp.NODE_REINFORCEMENT,
				BlackstoneExpeditionMvp.NODE_FORTRESS,
			],
		"两个非零己方驻军节点都按各自显式来源保留可发兵路线"
	)
	_check(
		theater.get_available_node_ids(&"").is_empty()
			and theater.get_node_or_null("Battlefield/ArmyMarker") == null,
		"空来源不回退到隐式当前位置，场景不再显示单一我军位置标记"
	)
	var split_state := _state_snapshot(theater)
	_check(
		theater.begin_command_interaction(camp_center),
		"营地非零驻军可以独立成为命令来源"
	)
	theater.cancel_command_interaction(false)
	_check(
		theater.begin_command_interaction(outpost_center),
		"前哨非零驻军可以独立成为命令来源"
	)
	theater.cancel_command_interaction(false)
	_check(
		_state_snapshot(theater) == split_state,
		"两个来源的开始与取消都不改变驻军权威状态"
	)
	_issue_and_arrive(
		theater,
		theater.camp_button,
		theater.outpost_button,
		75
	)
	_check(
		theater.get_garrison(BlackstoneExpeditionMvp.NODE_CAMP) == 0
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			) == 5
			and theater.get_total_soldiers() == 5,
		"己方支援只转移兵力，不复制、不丢失"
	)
	_check(
		not theater.begin_command_interaction(camp_center),
		"零驻军己方节点不能作为发兵源"
	)

	theater.start_new_run()
	_open_pending_by_input(theater, camp_center, reinforcement_center)
	theater._garrisons[BlackstoneExpeditionMvp.NODE_CAMP] = 0
	_check(
		not theater.confirm_pending_dispatch_percent(50)
			and theater.get_marching_armies().is_empty()
			and theater.get_interaction_state()
				== BlackstoneExpeditionMvp.STATE_ORDER_PENDING,
		"确认时重新校验，驻军已变化的陈旧 pending 不会执行"
	)
	theater._garrisons[BlackstoneExpeditionMvp.NODE_CAMP] = 10
	theater.cancel_pending_order(false)

	theater.start_new_run()
	_issue_and_arrive(
		theater,
		theater.camp_button,
		theater.outpost_button,
		100
	)
	_issue_and_arrive(
		theater,
		theater.outpost_button,
		theater.fortress_button,
		100
	)
	_check(
		theater.get_outcome()
			== BlackstoneExpeditionMvp.OUTCOME_DEFEAT,
		"直接进攻路线仍因 5 人不敌 8 人而失败"
	)
	_check(
		theater.is_modal_open()
			and theater.get_modal_mode()
				== BlackstoneExpeditionMvp.MODAL_RESULT
			and theater.result_status_label.text.contains("失败")
			and theater.result_source_label.text.contains("无胜利奖励")
			and not theater.result_status_label.text.contains("已完成"),
		"失败结算只投影失败 Result Modal，不混入胜利或撤退状态"
	)
	_check(
		int(construction.get_city_state().wood) == wood_before,
		"失败不永久扣除或增加城市资源"
	)
	theater.return_button.emit_signal("pressed")
	await process_frame
	selection.select_placement(command_platform_id)
	_check(
		result_status.text.contains("出征失败"),
		"失败回城后保留结果提示"
	)

	entry_button.emit_signal("pressed")
	await process_frame
	_assert_fresh_run(theater)
	_issue_and_arrive(
		theater,
		theater.camp_button,
		theater.reinforcement_button,
		100
	)
	_check(
		theater.get_garrison(
			BlackstoneExpeditionMvp.NODE_REINFORCEMENT
		) == 16,
		"10 人抵达山路援军后得到 +6，共 16 人"
	)
	_issue_and_arrive(
		theater,
		theater.reinforcement_button,
		theater.outpost_button,
		100
	)
	_issue_and_arrive(
		theater,
		theater.outpost_button,
		theater.fortress_button,
		100
	)
	_check(
		theater.get_outcome()
			== BlackstoneExpeditionMvp.OUTCOME_VICTORY
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_FORTRESS
			) == 3,
		"援军路线胜利，3 名幸存者驻扎黑石堡"
	)
	_check(
		theater.is_modal_open()
			and theater.get_modal_mode()
				== BlackstoneExpeditionMvp.MODAL_RESULT
			and theater.result_status_label.text == "已完成"
			and theater.result_title.text == "战区胜利"
			and not theater.result_source_label.text.contains("无胜利奖励"),
		"胜利结算只投影成功 Result Modal，不混入失败或撤退状态"
	)
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
		"胜利通过唯一城市权威控制器奖励木材"
	)
	var wood_after_victory := int(construction.get_city_state().wood)
	theater.dispatch_percent_100.emit_signal("pressed")
	theater.advance_marching_time(100.0)
	_check(
		int(construction.get_city_state().wood) == wood_after_victory,
		"结果后重复按钮和推进不会重复奖励"
	)
	theater.return_button.emit_signal("pressed")
	await process_frame
	selection.select_placement(command_platform_id)
	_check(
		result_status.text.contains("胜利")
			and result_status.text.contains("木材"),
		"胜利回城后显示结果与木材奖励"
	)

	entry_button.emit_signal("pressed")
	await process_frame
	_assert_fresh_run(theater)
	_check(
		not theater.is_dispatch_bar_visible()
			and not theater.is_command_line_visible()
			and theater.get_pending_order().is_empty()
			and theater.get_marching_armies().is_empty()
			and not theater.marching_marker.visible,
		"再次进入时路线、pending、调遣条和行军对象完全重置"
	)
	theater.request_return_to_city()
	await process_frame
	_check(not city.is_blackstone_expedition_mvp_open(), "可返回城市")

	_check(_all_garrisons_non_negative(theater), "全过程无负数驻军")
	city.queue_free()
	await process_frame
	_finish()


func _assert_v4_scene_contract(
	theater: BlackstoneExpeditionMvp
) -> void:
	_check(
		theater.get_node_or_null("Battlefield/RadialMenu") == null,
		"场景树已删除 V3 圆盘节点"
	)
	var options := theater.get_dispatch_options()
	_check(
		options.size() == 1
			and StringName(options[0].get("id", &""))
				== BlackstoneExpeditionMvp.OPTION_INFANTRY
			and String(options[0].get("label", ""))
				== "步兵／驻军",
		"调遣条只保留一个真实可用的步兵／驻军选项"
	)
	_check(
		theater.dispatch_bar.position.y >= 480.0
			and theater.dispatch_bar.size == Vector2(796.0, 110.0),
		"调遣条固定在 Figma 战场底部的 796×110 动作区"
	)
	var percent_25_style := theater.dispatch_percent_25.get_theme_stylebox(
		"normal"
	) as StyleBoxFlat
	var percent_50_style := theater.dispatch_percent_50.get_theme_stylebox(
		"normal"
	) as StyleBoxFlat
	_check(
		percent_25_style != null
			and percent_50_style != null
			and percent_25_style.bg_color
				== BlackstoneExpeditionMvp.COLOR_RAISED
			and percent_50_style.bg_color
				== BlackstoneExpeditionMvp.COLOR_PRIMARY
			and theater.get_marching_armies().is_empty(),
		"50% 默认态使用 Primary 语义色但不自动执行"
	)


func _assert_visual_contract(
	theater: BlackstoneExpeditionMvp
) -> void:
	_check(
		root.size == Vector2i(1152, 648)
			and _control_inside_viewport(theater, theater.get_node("Header"))
			and _control_inside_viewport(
				theater,
				theater.get_node("MissionPanel")
			)
			and _control_inside_viewport(theater, theater.battlefield)
			and _control_inside_viewport(theater, theater.dispatch_bar)
			and _control_inside_viewport(theater, theater.result_panel),
		"1152×648 下顶部、任务、战场、调遣和 Result Modal 均在视口内"
	)
	theater.open_retreat_confirmation()
	await process_frame
	var body_rect := theater.result_details.get_global_rect()
	var source_rect := theater.result_source_box.get_global_rect()
	var actions_rect := Rect2(
		theater.retry_button.get_global_rect().position,
		theater.return_button.get_global_rect().end
			- theater.retry_button.get_global_rect().position
	)
	_check(
		body_rect.end.y <= source_rect.position.y
			and source_rect.end.y <= actions_rect.position.y
			and not body_rect.intersects(actions_rect),
		"Result Modal 正文、来源和动作区按固定层级分离且不重叠"
	)
	_check(
		theater.modal_overlay.z_index > theater.dispatch_bar.z_index
			and theater.result_panel.z_index
				> theater.modal_overlay.z_index
			and theater.modal_overlay.mouse_filter
				== Control.MOUSE_FILTER_STOP,
		"72% 遮罩位于底层 UI 之上、卡片之下并拦截鼠标"
	)
	_check(
		theater.result_details.get_minimum_size().y
				<= theater.result_details.size.y
			and theater.result_source_label.get_minimum_size().x
				<= theater.result_source_label.size.x
			and theater.result_status_label.get_minimum_size().x
				<= theater.result_status_label.size.x,
		"Result Modal 动态正文、来源和状态标签在基准视口无文字裁切"
	)
	theater.cancel_retreat_confirmation()


func _control_inside_viewport(
	theater: BlackstoneExpeditionMvp,
	control: Control
) -> bool:
	var viewport_rect := Rect2(
		theater.get_global_rect().position,
		Vector2(root.size)
	)
	var rect := control.get_global_rect()
	return (
		rect.position.x >= viewport_rect.position.x
		and rect.position.y >= viewport_rect.position.y
		and rect.end.x <= viewport_rect.end.x
		and rect.end.y <= viewport_rect.end.y
	)


func _assert_default_route_text_geometry(
	theater: BlackstoneExpeditionMvp
) -> void:
	var routes := [
		{
			"line": theater.get_node("Battlefield/CampToReinforcement"),
			"target": theater.reinforcement_button,
			"label": "营地→援军",
		},
		{
			"line": theater.get_node("Battlefield/CampToOutpost"),
			"target": theater.outpost_button,
			"label": "营地→前哨",
		},
		{
			"line": theater.get_node("Battlefield/ReinforcementToOutpost"),
			"target": theater.outpost_button,
			"label": "援军→前哨",
		},
		{
			"line": theater.get_node("Battlefield/OutpostToFortress"),
			"target": theater.fortress_button,
			"label": "前哨→黑石堡",
		},
	]
	for route in routes:
		_assert_route_avoids_target_text(
			theater,
			route.get("line") as Line2D,
			route.get("target") as Button,
			"默认态 %s" % route.get("label", "路线")
		)


func _assert_command_route_text_geometry(
	theater: BlackstoneExpeditionMvp,
	target: Button,
	state_label: String
) -> void:
	_assert_route_avoids_target_text(
		theater,
		theater.command_line,
		target,
		state_label
	)
	var arrow_rect := _polygon_global_rect(theater.command_arrow)
	var title_rect := (target.get_node("Name") as Control).get_global_rect()
	var detail_rect := (target.get_node("Detail") as Control).get_global_rect()
	_check(
		not arrow_rect.intersects(title_rect)
			and not arrow_rect.intersects(detail_rect),
		"%s 的路线箭头不与目标标题或说明相交" % state_label
	)


func _assert_route_avoids_target_text(
	theater: BlackstoneExpeditionMvp,
	line: Line2D,
	target: Button,
	state_label: String
) -> void:
	var title_rect := (target.get_node("Name") as Control).get_global_rect()
	var detail_rect := (target.get_node("Detail") as Control).get_global_rect()
	_check(
		not _line_intersects_rect(theater, line, title_rect),
		"%s 不与目标节点标题 rect 相交" % state_label
	)
	_check(
		not _line_intersects_rect(theater, line, detail_rect),
		"%s 不与目标节点说明 rect 相交" % state_label
	)


func _line_intersects_rect(
	theater: BlackstoneExpeditionMvp,
	line: Line2D,
	target_rect: Rect2
) -> bool:
	if line.points.size() < 2:
		return false
	var transform := theater.battlefield.get_global_transform_with_canvas()
	var from := transform * line.points[0]
	var to := transform * line.points[line.points.size() - 1]
	return _segment_intersects_rect(from, to, target_rect.grow(line.width * 0.5))


func _polygon_global_rect(polygon: Polygon2D) -> Rect2:
	var transform := polygon.get_global_transform_with_canvas()
	var bounds := Rect2()
	for index in polygon.polygon.size():
		var point := transform * polygon.polygon[index]
		if index == 0:
			bounds.position = point
		else:
			bounds = bounds.expand(point)
	return bounds


func _segment_intersects_rect(
	from: Vector2,
	to: Vector2,
	rect: Rect2
) -> bool:
	if rect.has_point(from) or rect.has_point(to):
		return true
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for index in corners.size():
		var edge_start: Vector2 = corners[index]
		var edge_end: Vector2 = corners[(index + 1) % corners.size()]
		if Geometry2D.segment_intersects_segment(
			from,
			to,
			edge_start,
			edge_end
		) != null:
			return true
	return false


func _assert_dispatch_choice_rounding(
	theater: BlackstoneExpeditionMvp
) -> void:
	var expected := {
		1: [1, 1, 1, 1],
		2: [1, 1, 2, 2],
		3: [1, 2, 3, 3],
		10: [3, 5, 8, 10],
	}
	for available in expected.keys():
		var choices := theater.build_dispatch_amount_choices(available)
		var amounts: Array[int] = []
		var enabled_amounts: Dictionary = {}
		var duplicates_are_disabled := true
		for choice in choices:
			var amount := int(choice.get("amount", 0))
			amounts.append(amount)
			if bool(choice.get("enabled", false)):
				if enabled_amounts.has(amount):
					duplicates_are_disabled = false
				enabled_amounts[amount] = true
			elif not bool(choice.get("duplicate", false)):
				duplicates_are_disabled = false
		_check(
			amounts == expected[available],
			"%d 人的 25/50/75/100%% 使用向上取整且不越界"
			% available
		)
		_check(
			duplicates_are_disabled,
			"%d 人产生的重复兵数选项被禁用合并" % available
		)


func _assert_pending_order(
	theater: BlackstoneExpeditionMvp,
	source_node_id: StringName,
	target_node_id: StringName,
	expected_available: int
) -> void:
	var pending := theater.get_pending_order()
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_ORDER_PENDING
			and theater.is_dispatch_bar_visible()
			and theater.is_command_line_visible(),
		"有效路线松开进入 ORDER_PENDING 并保留路线高亮"
	)
	for key in [
		"source_node_id",
		"target_node_id",
		"route_id",
		"route",
		"command_type",
		"travel_duration",
		"current_available",
		"dispatch_options",
		"created_at_msec",
		"valid",
	]:
		_check(pending.has(key), "pending order 包含 %s" % key)
	_check(
		StringName(pending.get("source_node_id", &""))
			== source_node_id
			and StringName(pending.get("target_node_id", &""))
				== target_node_id
			and int(pending.get("current_available", 0))
				== expected_available
			and StringName(pending.get("command_type", &""))
				== BlackstoneExpeditionMvp.COMMAND_REINFORCE
			and float(pending.get("travel_duration", 0.0)) >= 6.0
			and bool(pending.get("valid", false)),
		"pending order 固定来源、目标、命令、时长、驻军与有效性"
	)
	_check(
		theater.dispatch_route_label.text.contains("我方营地")
			and theater.dispatch_route_label.text.contains("山路援军")
			and theater.dispatch_route_label.text.contains("接应")
			and theater.dispatch_details_label.text.contains("可派 10"),
		"调遣条清楚显示路线、命令类型、预计时长和真实可派兵力"
	)
	_check(
		theater.dispatch_percent_25.text == "25%"
			and theater.dispatch_percent_50.text == "50%"
			and theater.dispatch_percent_75.text == "75%"
			and theater.dispatch_percent_100.text == "全部"
			and theater.dispatch_percent_25.tooltip_text
				== "派出 3 · 留守 7"
			and theater.dispatch_percent_50.tooltip_text
				== "派出 5 · 留守 5"
			and theater.dispatch_percent_75.tooltip_text
				== "派出 8 · 留守 2"
			and theater.dispatch_percent_100.tooltip_text
				== "派出 10 · 留守 0",
		"四档按钮保持紧凑，真实派出与留守人数保留在可见提示合同"
	)
	_check(
		theater.get_marching_armies().is_empty(),
		"pending order 不是 MarchingArmy，也不会提前创建行军对象"
	)


func _assert_percent_command(
	theater: BlackstoneExpeditionMvp,
	percent: int,
	expected_amount: int,
	expected_remaining: int
) -> void:
	theater.start_new_run()
	_open_pending_by_input(
		theater,
		_button_center(theater.camp_button),
		_button_center(theater.reinforcement_button)
	)
	_check(
		theater.confirm_pending_dispatch_percent(percent),
		"%d%% 调遣按钮可以执行" % percent
	)
	var army := theater.get_active_marching_army()
	_check(
		int(army.get("total_count", 0)) == expected_amount
			and theater.get_garrison(
				BlackstoneExpeditionMvp.NODE_CAMP
			) == expected_remaining,
		"%d%% 实际派 %d、留 %d" % [
			percent,
			expected_amount,
			expected_remaining,
		]
	)


func _begin_route_input(
	theater: BlackstoneExpeditionMvp,
	source_screen: Vector2,
	target_screen: Vector2
) -> void:
	_send_mouse_button(theater, source_screen, true)
	_send_mouse_motion(theater, source_screen + Vector2(9.0, 0.0))
	_send_mouse_motion(theater, target_screen)


func _open_pending_by_input(
	theater: BlackstoneExpeditionMvp,
	source_screen: Vector2,
	target_screen: Vector2
) -> bool:
	_begin_route_input(theater, source_screen, target_screen)
	_send_mouse_button(theater, target_screen, false)
	return (
		theater.get_interaction_state()
		== BlackstoneExpeditionMvp.STATE_ORDER_PENDING
	)


func _issue_and_arrive(
	theater: BlackstoneExpeditionMvp,
	source_button: Button,
	target_button: Button,
	percent: int
) -> bool:
	if not _open_pending_by_input(
		theater,
		_button_center(source_button),
		_button_center(target_button)
	):
		return false
	if not theater.confirm_pending_dispatch_percent(percent):
		return false
	return _advance_active_army_to_arrival(theater)


func _advance_active_army_to_arrival(
	theater: BlackstoneExpeditionMvp
) -> bool:
	var army := theater.get_active_marching_army()
	if army.is_empty():
		return false
	return theater.advance_marching_time(
		float(army.get("travel_duration", 0.0))
	)


func _assert_real_frame_march(
	theater: BlackstoneExpeditionMvp,
	target_node_id: StringName,
	expected_target_garrison_before_arrival: int
) -> bool:
	var original_time_scale := Engine.time_scale
	Engine.time_scale = 8.0
	var checkpoints := {
		20: false,
		50: false,
		80: false,
	}
	var injected_release := false
	var frame_count := 0
	var stagnant_frames := 0
	var maximum_stagnant_frames := 0
	var last_progress := -1.0
	var last_remaining := INF
	var last_marker_distance := -1.0
	var source_position := Vector2(
		theater.get_active_marching_army().get(
			"source_position",
			Vector2.ZERO
		)
	)
	var continuous_values_valid := true
	while theater.is_marching() and frame_count < 600:
		await process_frame
		frame_count += 1
		var army := theater.get_active_marching_army()
		if army.is_empty():
			break
		var progress := float(army.get("progress", -1.0))
		var duration := float(army.get("travel_duration", 0.0))
		var remaining := duration * (1.0 - progress)
		var marker_distance := theater.marching_marker.position.distance_to(
			source_position
		)
		if progress <= last_progress + 0.000001:
			stagnant_frames += 1
			maximum_stagnant_frames = maxi(
				maximum_stagnant_frames,
				stagnant_frames
			)
		else:
			stagnant_frames = 0
		if (
			progress < 0.0
			or progress > 1.0
			or remaining > last_remaining + 0.000001
			or marker_distance + 0.000001 < last_marker_distance
			or theater.get_garrison(target_node_id)
				!= expected_target_garrison_before_arrival
		):
			continuous_values_valid = false
		for checkpoint in checkpoints.keys():
			if progress >= float(checkpoint) / 100.0:
				checkpoints[checkpoint] = true
		if progress >= 0.20 and not injected_release:
			injected_release = true
			var release_event := InputEventMouseButton.new()
			release_event.button_index = MOUSE_BUTTON_LEFT
			release_event.pressed = false
			release_event.position = Vector2.ZERO
			theater._gui_input(release_event)
			_check(
				theater.get_interaction_state()
					== BlackstoneExpeditionMvp.STATE_MARCHING
					and theater.is_marching(),
				"20% 时额外左键松开不会覆盖 MARCHING 状态"
			)
		last_progress = progress
		last_remaining = remaining
		last_marker_distance = marker_distance
	Engine.time_scale = original_time_scale
	_check(
		not paused
			and original_time_scale > 0.0
			and theater.is_processing(),
		"SceneTree 未暂停、time_scale 有效且战区 _process 持续启用"
	)
	_check(
		bool(checkpoints[20])
			and bool(checkpoints[50])
			and bool(checkpoints[80]),
		"连续帧实际经过 20%、50%、80% 三个进度区间"
	)
	_check(
		continuous_values_valid and maximum_stagnant_frames <= 1,
		"进度单调增加、剩余时间单调下降、标记连续前进且目标未提前结算"
	)
	_check(
		frame_count < 600
			and not theater.is_marching()
			and theater.get_marching_armies().is_empty(),
		"行军在规定帧数内达到 100% 并移除已结算对象"
	)
	_check(
		not theater.cancel_button.disabled
			and theater.get_interaction_state()
				== BlackstoneExpeditionMvp.STATE_IDLE,
		"抵达结算后恢复输入状态和返回城市按钮"
	)
	return (
		injected_release
		and bool(checkpoints[20])
		and bool(checkpoints[50])
		and bool(checkpoints[80])
		and continuous_values_valid
		and maximum_stagnant_frames <= 1
		and frame_count < 600
		and not theater.is_marching()
	)


func _assert_marching_army_contract(army: Dictionary) -> void:
	for key in [
		"unique_id",
		"source_node_id",
		"target_node_id",
		"dispatch_option_id",
		"troop_counts",
		"total_count",
		"commander_id",
		"route_id",
		"progress",
		"travel_duration",
		"status",
		"command_type",
		"resolved",
	]:
		_check(army.has(key), "MarchingArmy 包含 %s" % key)
	_check(
		float(army.travel_duration)
			>= BlackstoneExpeditionMvp.MIN_TRAVEL_SECONDS
			and float(army.travel_duration)
				<= BlackstoneExpeditionMvp.MAX_TRAVEL_SECONDS,
		"当前路线行军时长在 6–12 秒"
	)
	_check(
		StringName(army.status)
			== BlackstoneExpeditionMvp.STATE_MARCHING
			and not bool(army.resolved),
		"新行军对象状态为 MARCHING 且尚未结算"
	)


func _assert_fresh_run(theater: BlackstoneExpeditionMvp) -> void:
	_check(theater.get_total_soldiers() == 10, "新战区总兵力为 10")
	_check(
		theater.get_garrison(BlackstoneExpeditionMvp.NODE_CAMP) == 10,
		"新战区 10 人全部驻扎我方营地"
	)
	_check(
		theater.is_node_friendly(BlackstoneExpeditionMvp.NODE_CAMP)
			and not theater.is_node_friendly(
				BlackstoneExpeditionMvp.NODE_REINFORCEMENT
			)
			and not theater.is_node_friendly(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			),
		"新战区仅我方营地属于玩家"
	)
	_check(
		theater.get_enemy_force(BlackstoneExpeditionMvp.NODE_OUTPOST) == 5
			and theater.get_enemy_force(
				BlackstoneExpeditionMvp.NODE_FORTRESS
			) == 8,
		"新战区敌军恢复为前哨 5、黑石堡 8"
	)
	_check(
		theater.get_interaction_state()
			== BlackstoneExpeditionMvp.STATE_IDLE
			and theater.get_pending_order().is_empty()
			and theater.get_marching_armies().is_empty(),
		"新战区为 IDLE 且没有 pending 或行军对象"
	)


func _send_mouse_button(
	theater: BlackstoneExpeditionMvp,
	screen_position: Vector2,
	pressed: bool,
	button_index := MOUSE_BUTTON_LEFT
) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = (
		theater.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)
	theater._gui_input(event)


func _send_mouse_motion(
	theater: BlackstoneExpeditionMvp,
	screen_position: Vector2
) -> void:
	var event := InputEventMouseMotion.new()
	event.position = (
		theater.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)
	theater._gui_input(event)


func _send_viewport_mouse_button(
	theater: BlackstoneExpeditionMvp,
	screen_position: Vector2,
	pressed: bool,
	button_index := MOUSE_BUTTON_LEFT
) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = screen_position
	theater.get_viewport().push_input(event, true)
	await process_frame


func _state_snapshot(theater: BlackstoneExpeditionMvp) -> Dictionary:
	return {
		"garrisons": _garrison_snapshot(theater),
		"enemies": {
			BlackstoneExpeditionMvp.NODE_OUTPOST: theater.get_enemy_force(
				BlackstoneExpeditionMvp.NODE_OUTPOST
			),
			BlackstoneExpeditionMvp.NODE_FORTRESS: theater.get_enemy_force(
				BlackstoneExpeditionMvp.NODE_FORTRESS
			),
		},
		"friendly": {
			BlackstoneExpeditionMvp.NODE_CAMP: theater.is_node_friendly(
				BlackstoneExpeditionMvp.NODE_CAMP
			),
			BlackstoneExpeditionMvp.NODE_REINFORCEMENT:
				theater.is_node_friendly(
					BlackstoneExpeditionMvp.NODE_REINFORCEMENT
				),
			BlackstoneExpeditionMvp.NODE_OUTPOST:
				theater.is_node_friendly(
					BlackstoneExpeditionMvp.NODE_OUTPOST
				),
			BlackstoneExpeditionMvp.NODE_FORTRESS:
				theater.is_node_friendly(
					BlackstoneExpeditionMvp.NODE_FORTRESS
				),
		},
		"reinforcement_claimed": theater.is_reinforcement_claimed(),
		"outcome": theater.get_outcome(),
		"marching": theater.get_marching_armies(),
	}


func _garrison_snapshot(
	theater: BlackstoneExpeditionMvp
) -> Dictionary:
	return {
		BlackstoneExpeditionMvp.NODE_CAMP: theater.get_garrison(
			BlackstoneExpeditionMvp.NODE_CAMP
		),
		BlackstoneExpeditionMvp.NODE_REINFORCEMENT: theater.get_garrison(
			BlackstoneExpeditionMvp.NODE_REINFORCEMENT
		),
		BlackstoneExpeditionMvp.NODE_OUTPOST: theater.get_garrison(
			BlackstoneExpeditionMvp.NODE_OUTPOST
		),
		BlackstoneExpeditionMvp.NODE_FORTRESS: theater.get_garrison(
			BlackstoneExpeditionMvp.NODE_FORTRESS
		),
	}


func _all_garrisons_non_negative(
	theater: BlackstoneExpeditionMvp
) -> bool:
	for value in _garrison_snapshot(theater).values():
		if int(value) < 0:
			return false
	return true


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


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		printerr("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print(
			"PASS: 黑石堡路线先行派遣 V4 smoke（%d 条断言）"
			% checks
		)
		quit(0)
		return
	printerr(
		"FAIL: 黑石堡路线先行派遣 V4 smoke（%d/%d 失败）"
		% [failures.size(), checks]
	)
	quit(1)

extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load(
		"res://scenes/c0_battle_graybox.tscn"
	) as PackedScene
	_check(packed_scene != null, "独立 C0 灰盒场景可以加载")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate() as C0BattleGraybox
	root.add_child(scene)
	await process_frame
	await process_frame

	var title: Label = scene.get_node("UI/RootPanel/Title")
	_check(
		title.text == "C0 Battle Graybox",
		"场景使用明确 C0 Battle Graybox 标识"
	)
	_check(
		not scene.has_method("_input")
			and scene.city_scene.has_method("_input"),
		"灰盒不创建第二个原始 _input 所有者"
	)
	_check(
		not scene.city_scene.visible
			and not scene.city_ui.visible
			and scene.city_scene.process_mode == Node.PROCESS_MODE_DISABLED,
		"战斗期间城市及 CanvasLayer 隐藏且输入处理禁用"
	)
	_check(
		scene.request.phase == BattleRequest.PHASE_RESERVED,
		"灰盒从可配置的 RESERVED 阶段开始"
	)
	var placement_count: int = scene.city_controller.get_building_count()
	var occupied_count: int = scene.city_controller.get_occupied_cell_count()
	_check(
		scene.set_squad_route(1, &"SIDE_GATE"),
		"战前可以用最小按钮切换小队路线"
	)
	_check(
		scene.request.committed_force.squads[0].route_id == &"SIDE_GATE",
		"路线选择写入唯一请求快照"
	)
	_check(scene.start_battle(), "开始按钮进入真实战斗")
	scene.tick_timer.stop()
	_check(
		scene.request.phase == BattleRequest.PHASE_ACTIVE
			and scene.coordinator.active_session != null,
		"启动后创建唯一 ACTIVE BattleSession"
	)
	_check(
		scene.issue_squad_order(1, BattleOrder.Command.ADVANCE) != null,
		"灰盒按钮路径下达前进命令"
	)
	scene.step_battle_for_test(1)
	_check(
		scene.coordinator.active_session.get_squad_state(1).position_fixed == 4,
		"灰盒命令在下一逻辑 tick 生效"
	)
	for squad in scene.coordinator.active_session.squads:
		if int(squad.squad_id) == 1:
			continue
		scene.issue_squad_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		)
	var result := scene.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	_check(
		result != null and result.is_consistent(),
		"灰盒场景可以运行到真实结果"
	)
	var result_panel: Panel = scene.get_node("UI/RootPanel/ResultPanel")
	_check(result_panel.visible, "结果出现后显示 RESULT_PENDING 浮层")
	_check(
		scene.city_controller.get_building_count() == placement_count
			and scene.city_controller.get_occupied_cell_count()
				== occupied_count,
		"战场临时状态不污染城市 placement"
	)
	_check(
		scene.city_controller.infantry_count == 50
			and scene.city_controller.get_available_infantry_count() == 0,
		"结果确认前城市总兵力未提前写伤亡"
	)

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
		print("C0C_GRAYBOX_SCENE_SMOKE PASS")
		quit(0)
	else:
		print("C0C_GRAYBOX_SCENE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

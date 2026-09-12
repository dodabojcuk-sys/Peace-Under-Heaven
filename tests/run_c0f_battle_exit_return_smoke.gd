extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_prebattle_button_return()
	await _check_prebattle_escape_return()
	await _check_active_exit_cancel()
	await _check_active_exit_confirm()
	await _check_result_pending_escape_and_postbattle_return()
	_check_window_quit_is_not_intercepted()
	_finish()


func _check_prebattle_button_return() -> void:
	var setup := await _make_pending_city(30)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	_check(city.enter_first_war_battle(), "正式出征测试进入已付费 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	_check(
		battle != null
			and battle.exit_button.visible
			and battle.exit_button.text == "出征已确认"
			and not battle.exit_button.disabled,
		"已付费 RESERVED 阶段显示可点击的已确认状态"
	)
	if battle == null:
		scene.queue_free()
		await process_frame
		return
	var food_after_departure: int = city.food
	var attempt_after_departure: Dictionary = city.get_expedition_attempt()
	_check(
		not battle.request_exit_or_return()
			and battle.status_label.text.contains("出征已确认且粮草已扣除")
			and city.food == food_after_departure
			and city.get_expedition_attempt() == attempt_after_departure,
		"已付费 RESERVED 阶段拒绝静默返回，粮草与 immutable attempt 零变化"
	)
	_check(battle.start_battle(), "拒绝后仍可正常开始已确认战斗")
	battle.tick_timer.stop()
	_check(
		battle.open_exit_confirmation()
			and battle.confirm_exit_as_retreat(),
		"已确认出征通过真实撤退结算收口"
	)
	await process_frame
	await process_frame
	_check(
		scene.visible
			and scene.process_mode == Node.PROCESS_MODE_INHERIT
			and city.get_formal_battle_scene() == null
			and city.get_first_war_state_id() == &"IN_BATTLE",
		"撤退结算返回同一内城并保留战后摘要门禁"
	)
	var after: Dictionary = city.get_city_state()
	_check(
		int(after.infantry_count) <= 30
			and Dictionary(after.active_battle_reservation).is_empty()
			and StringName(after.last_battle_result_summary.outcome) == &"RETREAT"
			and city.food == food_after_departure,
		"撤退只写入一次逐编队战果，不重复扣除出征粮草"
	)
	scene.queue_free()
	await process_frame


func _check_prebattle_escape_return() -> void:
	var setup := await _make_pending_city(30)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	_check(city.enter_first_war_battle(), "战前 Esc 测试进入已付费正式 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "战前 Esc 测试取得正式 C0")
		scene.queue_free()
		await process_frame
		return
	var food_after_departure: int = city.food
	var attempt_after_departure: Dictionary = city.get_expedition_attempt()
	battle._unhandled_input(_escape_event())
	_check(
		city.get_formal_battle_scene() == battle
			and battle.status_label.text.contains("出征已确认且粮草已扣除")
			and city.food == food_after_departure
			and city.get_expedition_attempt() == attempt_after_departure,
		"战前 Esc 与按钮一致：已付费出征明确拒绝，零退款零状态篡改"
	)
	_check(battle.start_battle(), "Esc 拒绝后仍能开始既有出征")
	battle.tick_timer.stop()
	battle.open_exit_confirmation()
	battle.confirm_exit_as_retreat()
	await process_frame
	await process_frame
	scene.queue_free()
	await process_frame


func _check_active_exit_cancel() -> void:
	var setup := await _make_pending_city(30)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	_check(city.enter_first_war_battle(), "战中取消测试进入正式 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "战中取消测试取得正式 C0")
		scene.queue_free()
		await process_frame
		return
	_check(battle.start_battle(), "战中取消测试启动 BattleSession")
	var digest_before: String = (
		battle.coordinator.active_session.get_state_digest()
	)
	battle._unhandled_input(_escape_event())
	_check(
		battle.exit_confirmation.visible
			and battle.exit_input_blocker.visible
			and battle.tick_timer.is_stopped(),
		"战中 Esc 只打开单个确认框并冻结战斗输入与 tick"
	)
	_check(
		battle.get_node("UI/RootPanel").find_children(
			"ExitConfirmation",
			"Panel",
			true,
			false
		).size() == 1,
		"连续退出请求不会创建第二个确认框节点"
	)
	_check(
		not battle.open_exit_confirmation(),
		"确认框打开时拒绝重复退出请求"
	)
	_check(battle.cancel_exit_confirmation(), "取消退出关闭确认框")
	_check(
		not battle.exit_confirmation.visible
			and not battle.exit_input_blocker.visible
			and not battle.tick_timer.is_stopped()
			and battle.coordinator.active_session.get_state_digest()
				== digest_before,
		"取消退出恢复原战斗且未改变权威状态"
	)
	battle.tick_timer.stop()
	battle._unhandled_input(_escape_event())
	battle._unhandled_input(_escape_event())
	_check(
		not battle.exit_confirmation.visible,
		"连续 Esc 不叠加确认框，第二次按键等同取消"
	)
	battle.open_exit_confirmation()
	battle.confirm_exit_as_retreat()
	await process_frame
	await process_frame
	scene.queue_free()
	await process_frame


func _check_active_exit_confirm() -> void:
	var setup := await _make_pending_city(30)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var before: Dictionary = city.get_city_state()
	_check(city.enter_first_war_battle(), "全军撤退测试进入正式 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "全军撤退测试取得正式 C0")
		scene.queue_free()
		await process_frame
		return
	_check(battle.start_battle(), "全军撤退测试启动 BattleSession")
	battle.tick_timer.stop()
	_check(battle.open_exit_confirmation(), "战中退出先显示后果确认")
	_check(
		battle.confirm_exit_as_retreat(),
		"确认退出通过确定性全军撤退生成并应用正式战果"
	)
	var after_apply: Dictionary = city.get_city_state()
	_check(
		StringName(after_apply.last_battle_result_summary.outcome) == &"RETREAT"
			and int(after_apply.infantry_count)
				== int(before.infantry_count)
					- int(
						after_apply.last_battle_result_summary.casualty_count
					)
			and Dictionary(after_apply.active_battle_reservation).is_empty(),
		"战中退出写回一次撤退伤亡并清理兵力事务"
	)
	_check(
		not battle.confirm_exit_as_retreat(),
		"双击确认被退出防重入保护拒绝"
	)
	await process_frame
	await process_frame
	_check(
		city.get_formal_battle_scene() == null
			and scene.visible
			and scene.process_mode == Node.PROCESS_MODE_INHERIT
			and scene.get_node("Camera2D").enabled
			and city.get_first_war_state_id() == &"IN_BATTLE",
		"全军撤退返回同一内城并恢复输入、镜头和战后摘要门禁"
	)
	var after_return: Dictionary = city.get_city_state()
	_check(
		after_return == after_apply,
		"场景返回不会再次应用撤退战果"
	)
	scene.queue_free()
	await process_frame


func _check_result_pending_escape_and_postbattle_return() -> void:
	var setup := await _make_pending_city(50)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	_check(city.enter_first_war_battle(), "战后返回测试进入正式 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "战后返回测试取得正式 C0")
		scene.queue_free()
		await process_frame
		return
	# Prepared deployment is immutable; the battle may only accept orders.
	_check(battle.start_battle(), "战后返回测试启动 BattleSession")
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		)
	var result: BattleResult = battle.step_battle_for_test(
		BattleSession.MAX_BATTLE_TICKS
	)
	_check(result != null, "战后返回测试生成真实战果")
	if result == null:
		battle.abort_formal_entry()
		scene.queue_free()
		await process_frame
		return
	var before_escape: Dictionary = city.get_city_state()
	battle._unhandled_input(_escape_event())
	_check(
		battle.request.phase == BattleRequest.PHASE_RESULT_PENDING
			and battle.result_panel.visible
			and city.get_city_state() == before_escape,
		"RESULT_PENDING 的 Esc 不绕过战果确认或提前写回"
	)
	var summary: Dictionary = battle.confirm_pending_result()
	_check(
		not summary.is_empty()
			and battle.exit_button.text == "返回黑石城"
			and not battle.exit_button.disabled,
		"战果确认后全局主操作变为返回内城"
	)
	var after_apply: Dictionary = city.get_city_state()
	_check(battle.request_exit_or_return(), "战后全局入口返回内城")
	_check(
		not battle.request_exit_or_return(),
		"重复战后返回请求被防重入保护拒绝"
	)
	await process_frame
	await process_frame
	_check(
		city.get_formal_battle_scene() == null
			and city.get_city_state() == after_apply,
		"战后返回恢复城市且不重复写回战果"
	)
	scene.queue_free()
	await process_frame


func _check_window_quit_is_not_intercepted() -> void:
	_check(
		auto_accept_quit,
		"SceneTree 保持 auto_accept_quit，操作系统关闭窗口未被战斗页吞掉"
	)


func _make_pending_city(player_count: int) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
	var old_count := int(city.infantry_count)
	city.infantry_count = player_count
	city._population_recovery.total_living += player_count - old_count
	city.food = 80
	city._refresh_city_ui()
	return {
		"scene": scene,
		"city": city,
	}


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("C0F_BATTLE_EXIT_RETURN_SMOKE PASS")
		quit(0)
	else:
		print("C0F_BATTLE_EXIT_RETURN_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

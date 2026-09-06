extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_victory_confirmation_and_return()
	await _check_replay_reward_and_invalid_transaction()
	_finish()


func _check_victory_confirmation_and_return() -> void:
	var packed_scene := load(
		"res://scenes/c0_battle_graybox.tscn"
	) as PackedScene
	var scene := packed_scene.instantiate() as C0BattleGraybox
	root.add_child(scene)
	await process_frame
	await process_frame

	for squad in scene.request.committed_force.squads:
		scene.set_squad_route(
			int(squad.squad_id),
			CommittedForceSnapshot.SIDE_ROUTE
		)
	_check(scene.start_battle(), "胜利写回用例进入 ACTIVE 战斗")
	scene.tick_timer.stop()
	for squad in scene.coordinator.active_session.squads:
		scene.issue_squad_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		)
	var result := scene.step_battle_for_test(
		BattleSession.MAX_BATTLE_TICKS
	)
	_check(
		result != null
			and result.outcome == BattleOutcome.Value.VICTORY,
		"真实演算形成待确认胜利"
	)
	_check(
		scene.result_input_blocker.visible
			and scene.result_input_blocker.mouse_filter
				== Control.MOUSE_FILTER_STOP,
		"结果页使用全屏 STOP 遮挡防止点击穿透"
	)
	var city_before: Dictionary = (
		scene.city_controller.get_city_state()
	)
	var summary := scene.confirm_pending_result()
	_check(
		not summary.is_empty()
			and bool(summary.first_clear_granted)
			and int(summary.accepted_wood_reward) == 30
			and int(summary.accepted_food_reward) == 20,
		"首次胜利确认一次性应用木材 30、粮食 20"
	)
	_check(
		scene.city_controller.infantry_count
				== int(city_before.infantry_count) - result.casualty_count
			and scene.city_controller.wood == int(city_before.wood) + 30
			and scene.city_controller.food == int(city_before.food) + 20,
		"伤亡与奖励在确认时一起写入城市权威状态"
	)
	_check(
		scene.city_controller.get_active_battle_reservation().is_empty()
			and scene.city_controller.get_closed_battle_transaction_phase(
				result.transaction_id
			) == &"APPLIED",
		"确认后事务从 RESULT_PENDING 原子进入 APPLIED"
	)
	_check(
		scene.city_controller.has_first_clear(result.first_clear_key),
		"首通幂等键写入唯一城市权威账本"
	)
	var after_first_confirm: Dictionary = (
		scene.city_controller.get_city_state()
	)
	var duplicate_summary := scene.confirm_pending_result()
	var after_duplicate_confirm: Dictionary = (
		scene.city_controller.get_city_state()
	)
	_check(
		duplicate_summary == summary
			and after_duplicate_confirm == after_first_confirm,
		"重复确认返回同一摘要且不重复修改兵力或资源"
	)

	var return_contract := scene.coordinator.request_return_to_city()
	_check(
		return_contract != null
			and not scene.complete_return_for_test(
				return_contract.city_input_restore_frame - 1
			),
		"返回城市在至少一个输入保护帧前拒绝恢复"
	)
	scene.request_return_to_city()
	await process_frame
	await process_frame
	_check(
		not scene.get_node("UI/RootPanel").visible
			and scene.complete_return_for_test(
				return_contract.city_input_restore_frame
			),
		"异步达到保护帧后返回成功且重复返回幂等"
	)
	_check(
		scene.city_scene.visible
			and scene.city_scene.process_mode
				== Node.PROCESS_MODE_INHERIT
			and scene.city_camera.enabled
			and scene.get_viewport().get_camera_2d()
				== scene.city_camera
			and not scene.get_node("UI/RootPanel").visible,
		"返回后恢复城市画面、Camera2D 与输入并隐藏战斗 UI"
	)

	await _check_historical_replay_without_reward(
		scene.city_controller,
		scene.coordinator
	)
	scene.queue_free()
	await process_frame


func _check_historical_replay_without_reward(
	city_controller: Node,
	coordinator: CombatTransactionCoordinator
) -> void:
	var committed := mini(
		50,
		city_controller.get_available_infantry_count()
	)
	var request := coordinator.create_request(committed)
	_check(request != null, "历史重打可以创建新的唯一事务")
	if request == null:
		return
	_check(coordinator.activate_request(), "历史重打事务进入 ACTIVE")
	for squad in request.committed_force.squads:
		squad.route_id = CommittedForceSnapshot.SIDE_ROUTE
	var session := coordinator.create_session()
	if session == null:
		_check(false, "历史重打创建真实 BattleSession")
		return
	for squad in session.squads:
		coordinator.issue_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	var replay_result := session.run_until_complete()
	_check(
		replay_result != null
			and replay_result.outcome == BattleOutcome.Value.VICTORY
			and coordinator.mark_result_pending(),
		"历史重打由真实 BattleSession 进入 RESULT_PENDING"
	)
	if replay_result == null:
		return
	var summary := coordinator.confirm_result()
	_check(
		not summary.is_empty()
		and not bool(summary.first_clear_granted)
			and int(summary.accepted_wood_reward) == 0
			and int(summary.accepted_food_reward) == 0
			and int(summary.city_time_advanced_milliseconds)
				== replay_result.get_duration_milliseconds(),
		"历史重打胜利不重复领取首通奖励"
	)


func _check_replay_reward_and_invalid_transaction() -> void:
	var city_scene := CITY_SCENE.instantiate()
	root.add_child(city_scene)
	await process_frame
	city_scene.visible = false
	city_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var city_controller: Node = city_scene.get_node(
		"ConstructionController"
	)
	city_controller.infantry_count = 10
	var coordinator := CombatTransactionCoordinator.new()
	city_scene.add_child(coordinator)
	coordinator.configure(city_controller)
	var request := coordinator.create_request(10)
	_check(request != null, "非法事务用例建立合法预留")
	if request == null:
		city_scene.queue_free()
		return
	_check(coordinator.activate_request(), "非法事务用例进入 ACTIVE")
	_check(
		city_controller.mark_battle_result_pending(
			request.transaction_id,
			coordinator
		),
		"非法事务用例进入 RESULT_PENDING"
	)
	request.phase = BattleRequest.PHASE_RESULT_PENDING
	var invalid_result := _make_result(
		request,
		&"invalid-transaction-result",
		BattleOutcome.Value.VICTORY,
		10
	)
	invalid_result.transaction_id = &"battle-foreign"
	var before: Dictionary = city_controller.get_city_state()
	var rejected := BattleResultApplier.new(city_controller).apply_authorized(
		request.transaction_id,
		invalid_result.result_id
	)
	var after: Dictionary = city_controller.get_city_state()
	_check(
		rejected.is_empty()
			and after == before
			and StringName(
				city_controller.get_active_battle_reservation().phase
			) == &"RESULT_PENDING",
		"非法 transaction ID 被拒绝且不产生部分写入"
	)
	city_scene.queue_free()
	await process_frame


func _make_result(
	request: BattleRequest,
	result_id: StringName,
	outcome: BattleOutcome.Value,
	survivors: int
) -> BattleResult:
	var result := BattleResult.new()
	result.result_id = result_id
	result.transaction_id = request.transaction_id
	result.session_id = StringName("%s-test-session" % request.transaction_id)
	result.level_id = request.level_id
	result.outcome = outcome
	result.started_day = request.created_day
	result.finished_tick = 1
	result.committed_count = request.committed_force.get_committed_total()
	result.survivor_count = survivors
	result.casualty_count = result.committed_count - survivors
	result.enemy_casualties = request.enemy_force.enemy_count
	result.breached_route = CommittedForceSnapshot.SIDE_ROUTE
	result.orders_digest = "test-orders"
	result.player_snapshot_digest = request.committed_force.get_digest()
	result.enemy_snapshot_digest = request.enemy_force.get_digest()
	result.first_clear_key = BattleSession.FIRST_CLEAR_KEY
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("C0D_RESULT_WRITEBACK_SMOKE PASS")
		quit(0)
	else:
		print("C0D_RESULT_WRITEBACK_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

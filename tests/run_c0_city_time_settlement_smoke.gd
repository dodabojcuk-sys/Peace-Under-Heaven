extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_atomic_coordinator_binding()
	await _check_second_coordinator_zero_write()
	await _check_formal_outcome_time_settlement(
		&"VICTORY",
		50,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.SIDE_ROUTE
	)
	await _check_formal_outcome_time_settlement(
		&"DEFEAT",
		1,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	await _check_formal_outcome_time_settlement(
		&"RETREAT",
		8,
		BattleOrder.Command.RETREAT,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	await _check_cross_day_reward_order()
	await _check_cancel_and_invalid_result_do_not_advance_time()
	await _check_historical_replay_accumulates_time_without_reward()
	await _check_canonical_result_authority()
	await _check_unfinalized_result_has_no_authority()
	_finish()


func _check_atomic_coordinator_binding() -> void:
	var target_scene := CITY_SCENE.instantiate() as Node2D
	var source_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(target_scene)
	root.add_child(source_scene)
	await process_frame
	await process_frame
	var target_city: Node = target_scene.get_node("ConstructionController")
	var source_city: Node = source_scene.get_node("ConstructionController")
	target_city.set_process(false)
	source_city.set_process(false)
	source_city.infantry_count = 50
	var coordinator := CombatTransactionCoordinator.new()
	root.add_child(coordinator)

	var target_before: Dictionary = target_city.get_city_state()
	var one_sided_internal_attempt: bool = (
		target_city._accept_combat_transaction_coordinator_binding(coordinator)
	)
	_check(
		not target_city.has_method("bind_combat_transaction_coordinator")
			and not one_sided_internal_attempt
			and not target_city.is_combat_transaction_coordinator_bound(
				coordinator
			)
			and target_city.get_city_state() == target_before,
		"City 不再暴露单边 bind，未反向指向时内部握手也零写入拒绝"
	)
	_check(
		coordinator.configure(source_city)
			and coordinator.get_bound_city() == source_city
			and source_city.is_combat_transaction_coordinator_bound(coordinator)
			and not target_city.is_combat_transaction_coordinator_bound(
				coordinator
			),
		"原半绑定顺序失败后 coordinator 只与 Source City 原子双向绑定"
	)
	var source_request := coordinator.create_request(50)
	var target_attack_id: StringName = target_city.reserve_battle_force(
		50,
		coordinator
	)
	_check(
		source_request != null
			and target_attack_id == &""
			and target_city.get_active_battle_reservation().is_empty()
			and target_city.get_city_state() == target_before
			and not source_city.get_active_battle_reservation().is_empty(),
		"绑定 Source City 的 coordinator 不能在 Target City 建立驻军预留"
	)
	if source_request == null:
		_check(false, "跨 City 结算攻击前建立 Source City 真实请求")
		target_scene.queue_free()
		source_scene.queue_free()
		coordinator.queue_free()
		await process_frame
		return
	for squad in source_request.committed_force.squads:
		coordinator.set_squad_route(
			int(squad.squad_id),
			CommittedForceSnapshot.SIDE_ROUTE
		)
	var source_activated: bool = coordinator.activate_request()
	var source_session: BattleSession = (
		coordinator.create_session() if source_activated else null
	)
	if source_session != null:
		for squad in source_session.squads:
			coordinator.issue_order(
				int(squad.squad_id),
				BattleOrder.Command.ADVANCE
			)
	var source_result: BattleResult = (
		source_session.run_until_complete()
		if source_session != null
		else null
	)
	var source_pending: bool = (
		source_result != null and coordinator.mark_result_pending()
	)
	var target_before_submit: Dictionary = target_city.get_city_state()
	var target_direct_summary: Dictionary = (
		target_city.apply_battle_result_atomic(
			source_request.transaction_id,
			source_result.result_id
		)
		if source_pending
		else {}
	)
	var target_applier_summary: Dictionary = (
		BattleResultApplier.new(target_city).apply_authorized(
			source_request.transaction_id,
			source_result.result_id
		)
		if source_pending
		else {}
	)
	_check(
		source_pending
			and target_direct_summary.is_empty()
			and target_applier_summary.is_empty()
			and target_city.get_city_state() == target_before_submit
			and target_city.get_committed_battle_result_summary(
				source_result.result_id
			).is_empty()
			and StringName(
				source_city.get_active_battle_reservation().phase
			) == source_city.BATTLE_PHASE_RESULT_PENDING,
		"Source City 真实 terminal result 经 City/Applier 均不能结算到 Target City"
	)
	var source_summary := coordinator.confirm_result()
	_check(
		not source_summary.is_empty()
			and int(source_summary.city_time_advanced_milliseconds) == 125000
			and source_city.get_active_battle_reservation().is_empty(),
		"跨 City 攻击拒绝后 Source City 仍唯一合法结算 125000ms"
	)

	target_scene.queue_free()
	source_scene.queue_free()
	coordinator.queue_free()
	await process_frame


func _check_second_coordinator_zero_write() -> void:
	var owner_scene := CITY_SCENE.instantiate() as Node2D
	var recovery_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(owner_scene)
	root.add_child(recovery_scene)
	await process_frame
	await process_frame
	var owner_city: Node = owner_scene.get_node("ConstructionController")
	var recovery_city: Node = recovery_scene.get_node("ConstructionController")
	owner_city.set_process(false)
	recovery_city.set_process(false)
	var owner := CombatTransactionCoordinator.new()
	var attacker := CombatTransactionCoordinator.new()
	root.add_child(owner)
	root.add_child(attacker)

	_check(
		owner.configure(owner_city)
			and owner.configure(owner_city)
			and owner.get_bound_city() == owner_city
			and owner_city.is_combat_transaction_coordinator_bound(owner),
		"相同 City 与 coordinator 的原子绑定可幂等重复"
	)
	var owner_request := owner.create_request(10)
	if owner_request == null:
		_check(false, "第二 coordinator 攻击前建立 owner 驻军预留")
		owner_scene.queue_free()
		recovery_scene.queue_free()
		owner.queue_free()
		attacker.queue_free()
		await process_frame
		return
	var reservation_before: Dictionary = (
		owner_city.get_active_battle_reservation()
	)
	var state_before: Dictionary = owner_city.get_city_state()
	var time_before := _time_snapshot(owner_city)
	var attacker_bind_result: bool = attacker.configure(owner_city)
	var attacker_reserve_result: StringName = owner_city.reserve_battle_force(
		1,
		attacker
	)
	var attacker_activate_result: bool = (
		owner_city.activate_battle_reservation(
			owner_request.transaction_id,
			attacker
		)
	)
	var attacker_pending_result: bool = (
		owner_city.mark_battle_result_pending(
			owner_request.transaction_id,
			attacker
		)
	)
	var attacker_cancel_result: bool = owner_city.cancel_battle_reservation(
		owner_request.transaction_id,
		attacker
	)
	_check(
		not attacker_bind_result
			and attacker.get_bound_city() == null
			and attacker_reserve_result == &""
			and not attacker_activate_result
			and not attacker_pending_result
			and not attacker_cancel_result,
		"第二 coordinator 绑定与全部驻军 mutator 均确定性拒绝"
	)
	_check(
		owner_city.get_active_battle_reservation() == reservation_before
			and owner_city.get_city_state() == state_before
			and _time_snapshot(owner_city) == time_before
			and owner_city.is_combat_transaction_coordinator_bound(owner),
		"第二 coordinator 失败操作不修改城市时间、驻军预留或 owner"
	)
	_check(
		attacker.configure(recovery_city)
			and attacker.get_bound_city() == recovery_city
			and recovery_city.is_combat_transaction_coordinator_bound(attacker),
		"失败绑定不遗留半状态，attacker 随后可绑定全新 City"
	)
	_check(
		owner.cancel_request()
			and owner_city.get_active_battle_reservation().is_empty(),
		"第二 coordinator 攻击失败后原 owner 仍可合法清理预留"
	)

	owner_scene.queue_free()
	recovery_scene.queue_free()
	owner.queue_free()
	attacker.queue_free()
	await process_frame


func _check_formal_outcome_time_settlement(
	expected_outcome: StringName,
	player_count: int,
	command: BattleOrder.Command,
	_route_id: StringName
) -> void:
	var setup := await _make_pending_city(player_count)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var before: Dictionary = city.get_city_state()
	_check(
		city.advance_city_time_for_test(1.0) == 0
			and city.current_day == int(before.day)
			and city.get_day_elapsed_milliseconds()
				== int(before.day_elapsed_milliseconds) + 1000,
		"%s 主线待处理期间城市时间继续推进" % expected_outcome
	)
	_check(city.enter_first_war_battle(), "%s 进入正式 C0" % expected_outcome)
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "%s 取得正式 C0 场景" % expected_outcome)
		scene.queue_free()
		await process_frame
		return
	# The formal departure snapshot owns routes from R1E onward.
	_check(battle.start_battle(), "%s 启动真实 BattleSession" % expected_outcome)
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), command)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	_check(
		result != null
			and BattleOutcome.to_id(result.outcome) == expected_outcome,
		"%s 由真实 tick 产生 canonical BattleResult" % expected_outcome
	)
	if result == null:
		scene.queue_free()
		await process_frame
		return
	var before_confirm: Dictionary = city.get_city_state()
	await process_frame
	_check(
		city.get_city_state() == before_confirm,
		"%s result pending 与真实等待帧不推进城市时间" % expected_outcome
	)
	var summary := battle.confirm_pending_result()
	var expected_time := _advanced_time(
		int(before_confirm.day),
		roundi(float(before_confirm.day_elapsed_seconds) * 1000.0),
		result.get_duration_milliseconds(),
		roundi(city.SECONDS_PER_DAY * 1000.0)
	)
	_check(
		not summary.is_empty()
			and int(summary.battle_duration_milliseconds)
				== result.finished_tick * BattleSession.TICK_MILLISECONDS
			and int(summary.city_time_advanced_milliseconds)
				== result.get_duration_milliseconds()
			and int(summary.city_time_before_day) == int(before_confirm.day)
			and int(summary.city_time_before_milliseconds)
				== roundi(float(before_confirm.day_elapsed_seconds) * 1000.0)
			and int(summary.city_time_after_day) == int(expected_time.day)
			and int(summary.city_time_after_milliseconds)
				== int(expected_time.elapsed_milliseconds),
		"%s 首次提交精确推进 finished_tick × canonical tick_ms" % expected_outcome
	)
	var after_confirm: Dictionary = city.get_city_state()
	var duplicate := battle.confirm_pending_result()
	_check(
		duplicate == summary and city.get_city_state() == after_confirm,
		"%s 同 result_id 重复确认不二次推进" % expected_outcome
	)
	var return_contract := battle.request_return_to_city()
	_check(return_contract != null, "%s 建立返回保护契约" % expected_outcome)
	if return_contract != null:
		_check(
			battle.complete_return_for_test(
				return_contract.city_input_restore_frame
			)
			and _time_snapshot(city) == _time_snapshot_from_state(after_confirm),
			"%s 重复返回/保护帧不二次推进" % expected_outcome
		)
	var after_return: Dictionary = city.get_city_state()
	_check(
		city.advance_city_time_for_test(1.0) == 0
			and _time_snapshot(city) == _time_snapshot_from_state(after_return),
		"%s 摘要等待期间不再增加时间" % expected_outcome
	)
	if expected_outcome != &"DEFEAT":
		_check(city.acknowledge_first_war_result(), "%s 确认城市摘要" % expected_outcome)
		var after_ack: Dictionary = city.get_city_state()
		city.advance_city_time_for_test(1.0)
		_check(
			roundi(city.day_elapsed_seconds * 1000.0)
				== roundi(float(after_ack.day_elapsed_seconds) * 1000.0) + 1000,
			"%s acknowledge 后从已推进时间继续" % expected_outcome
		)
	scene.queue_free()
	await process_frame


func _check_cross_day_reward_order() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var logging_id: int = city.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7)
	)
	for road_cell in [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
	]:
		city.place_definition_at_cell(&"building.road.t1", road_cell)
	city.advance_one_day_for_test()
	_check(logging_id >= 0, "跨日用例建立已运行伐木场")
	_check(city.is_building_operational(logging_id), "跨日用例伐木场已接入路网并运行")
	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 5.0)
	city.infantry_count = 50
	var wood_capacity: int = city.get_resource_capacity(&"wood")
	city.wood = wood_capacity - 20
	city.day_elapsed_seconds = city.SECONDS_PER_DAY - 0.5
	city._refresh_city_ui()
	_check(city.enter_first_war_battle(), "跨日用例进入正式 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle == null:
		_check(false, "跨日用例取得正式 C0 场景")
		scene.queue_free()
		await process_frame
		return
	battle.start_battle()
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	if result == null:
		_check(false, "跨日用例产生真实胜利结果")
		scene.queue_free()
		await process_frame
		return
	var wood_before: int = city.wood
	var summary := battle.confirm_pending_result()
	var daily_income := int(city.get_last_daily_breakdown().wood_income)
	var expected_reward := mini(
		30,
		maxi(
			wood_capacity - (
				wood_before + daily_income
				- int(city.get_last_daily_breakdown().event_wood_loss)
			),
			0
		)
	)
	_check(
		int(summary.city_time_advanced_days) >= 1
			and daily_income > 0
			and int(summary.accepted_wood_reward) == expected_reward
			and city.wood == (
				wood_before + daily_income
				- int(city.get_last_daily_breakdown().event_wood_loss)
				+ expected_reward
			),
		"跨日时先补算生产，再按战后容量应用奖励；奖励不倒流参与生产"
	)
	scene.queue_free()
	await process_frame


func _check_cancel_and_invalid_result_do_not_advance_time() -> void:
	var setup := await _make_pending_city(20)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	_check(city.enter_first_war_battle(), "已付费 RESERVED 拒绝用例进入正式 C0")
	var battle := city.get_formal_battle_scene() as C0BattleGraybox
	if battle != null:
		var after_departure: Dictionary = city.get_city_state()
		_check(
			not battle.request_exit_or_return()
				and city.get_city_state() == after_departure,
			"已付费 RESERVED 不可无战果取消，时间与 attempt 保持不变"
		)
		battle.start_battle()
		battle.tick_timer.stop()
		battle.open_exit_confirmation()
		battle.confirm_exit_as_retreat()
		await process_frame
		await process_frame
	scene.queue_free()
	await process_frame

	var invalid_scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(invalid_scene)
	await process_frame
	var invalid_city: Node = invalid_scene.get_node("ConstructionController")
	invalid_city.set_process(false)
	invalid_city.infantry_count = 10
	var coordinator := CombatTransactionCoordinator.new()
	invalid_scene.add_child(coordinator)
	coordinator.configure(invalid_city)
	var request := coordinator.create_request(10)
	if request == null:
		_check(false, "非法 result 用例建立请求")
		invalid_scene.queue_free()
		await process_frame
		return
	coordinator.activate_request()
	var invalid_result := _make_result(
		request,
		&"invalid-time-result",
		BattleOutcome.Value.VICTORY,
		10,
		4
	)
	invalid_result.transaction_id = &"battle-foreign"
	var before_invalid: Dictionary = invalid_city.get_city_state()
	_check(
		BattleResultApplier.new(invalid_city).apply_authorized(
				request.transaction_id,
				invalid_result.result_id
			).is_empty()
			and invalid_city.get_city_state() == before_invalid,
		"非法 transaction/result 被拒绝且没有时间或其他部分写入"
	)
	invalid_scene.queue_free()
	await process_frame


func _check_historical_replay_accumulates_time_without_reward() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.infantry_count = 50
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	coordinator.configure(city)
	var first := await _run_fixture_victory(city, coordinator)
	var second := await _run_fixture_victory(city, coordinator)
	if first.is_empty() or second.is_empty():
		_check(false, "历史重打用例形成两次真实 BattleSession 结果")
		scene.queue_free()
		await process_frame
		return
	_check(
		int(second.summary.city_time_advanced_milliseconds)
			== int(second.result.get_duration_milliseconds())
			and not bool(second.summary.first_clear_granted)
			and int(second.summary.accepted_wood_reward) == 0
			and int(second.summary.accepted_food_reward) == 0
			and _elapsed_total_milliseconds(city)
				== int(first.before_elapsed_total)
					+ int(first.result.get_duration_milliseconds())
					+ int(second.result.get_duration_milliseconds()),
		"新 transaction 的历史重打累计推进实际时长但不重复首通奖励"
	)
	scene.queue_free()
	await process_frame


func _check_canonical_result_authority() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.infantry_count = 50
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	coordinator.configure(city)
	var request := coordinator.create_request(50)
	if request == null or not coordinator.activate_request():
		_check(false, "权威性用例建立真实 transaction")
		scene.queue_free()
		await process_frame
		return
	for squad in request.committed_force.squads:
		squad.route_id = CommittedForceSnapshot.SIDE_ROUTE
	var session := coordinator.create_session()
	if session == null:
		_check(false, "权威性用例建立真实 BattleSession")
		scene.queue_free()
		await process_frame
		return
	session.terminal_completed.connect(
		func(payload: BattleResult, exposed_record: Dictionary) -> void:
			payload.finished_tick = 600
			exposed_record.completion.route_ids.append(&"signal-forged-route")
	)
	for squad in session.squads:
		coordinator.issue_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	var canonical := session.run_until_complete()
	var terminal_record := session.get_terminal_authority_record()
	_check(
		canonical != null
			and canonical.outcome == BattleOutcome.Value.VICTORY
			and canonical.get_duration_milliseconds() == 150000
			and int(terminal_record.result.finished_tick) == 500,
		"完成 signal 篡改 payload 前已冻结 125000ms terminal authority"
	)
	if canonical == null:
		scene.queue_free()
		await process_frame
		return
	var authority_copy := BattleResult.from_authority_snapshot(
		session.get_terminal_result_snapshot()
	)
	var impostor := BattleSession.new(request)
	coordinator.active_session = impostor
	var impostor_rejected := not coordinator.mark_result_pending()
	coordinator.active_session = session
	var terminal_copy := session.get_terminal_authority_record()
	terminal_copy.completion.route_ids.append(&"forged-route")
	var pending_registered := coordinator.mark_result_pending()
	var before_forgery: Dictionary = city.get_city_state()
	var forged_duration_summary := coordinator.confirm_result(canonical)
	_check(
		forged_duration_summary.is_empty()
			and coordinator.last_result_error_id == &"RESULT_PAYLOAD_CONFLICT"
			and city.get_city_state() == before_forgery
			and int(session.get_terminal_result_snapshot().finished_tick) == 500
			and session.get_terminal_authority_record().completion.route_ids
				!= terminal_copy.completion.route_ids
			and impostor.session_id == session.session_id
			and impostor_rejected
			and pending_registered
			and city.get_committed_battle_result_summary(
				authority_copy.result_id
			).is_empty(),
		"finalize 后篡改 payload 和 getter 嵌套副本均不能污染 terminal authority"
	)
	canonical.finished_tick = authority_copy.finished_tick
	canonical.outcome = BattleOutcome.Value.RETREAT
	var forged_outcome_summary := coordinator.confirm_result(canonical)
	_check(
		forged_outcome_summary.is_empty()
			and coordinator.last_result_error_id == &"RESULT_PAYLOAD_CONFLICT"
			and city.get_city_state() == before_forgery,
		"篡改非时长结算字段同样被 authority 拒绝"
	)
	var canonical_summary := coordinator.confirm_result()
	var after_canonical: Dictionary = city.get_city_state()
	_check(
		not canonical_summary.is_empty()
			and int(canonical_summary.city_time_advanced_milliseconds)
				== 125000
			and int(canonical_summary.finished_tick) == 500,
		"伪造拒绝后真实 canonical result 仍按 125000ms 首次结算"
	)
	var exact_duplicate := coordinator.confirm_result()
	_check(
		exact_duplicate == canonical_summary
			and city.get_city_state() == after_canonical,
		"完全相同 canonical duplicate 返回原摘要且零写入"
	)
	authority_copy.finished_tick += 100
	var committed_conflict := coordinator.confirm_result(authority_copy)
	_check(
		committed_conflict.is_empty()
			and coordinator.last_result_error_id == &"RESULT_PAYLOAD_CONFLICT"
			and city.get_city_state() == after_canonical,
		"committed 后同 result_id 不同 payload 产生 conflict 且零写入"
	)
	var return_contract := coordinator.request_return_to_city()
	if return_contract != null:
		coordinator.complete_return_to_city(return_contract.city_input_restore_frame)
	scene.queue_free()
	await process_frame


func _check_unfinalized_result_has_no_authority() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.infantry_count = 10
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	coordinator.configure(city)
	var request := coordinator.create_request(10)
	if request == null or not coordinator.activate_request():
		_check(false, "未 finalize 用例建立真实 transaction")
		scene.queue_free()
		await process_frame
		return
	var self_made := _make_result(
		request,
		StringName("%s-result-001" % request.transaction_id),
		BattleOutcome.Value.VICTORY,
		10,
		500
	)
	self_made.session_id = StringName("%s-session" % request.transaction_id)
	var self_made_snapshot := self_made.get_authority_snapshot()
	var before: Dictionary = city.get_city_state()
	var applier := BattleResultApplier.new(city)
	_check(
		city.apply_battle_result_atomic(
				request.transaction_id,
				self_made.result_id
			).is_empty()
			and applier.apply_authorized(
				request.transaction_id,
				self_made.result_id
			).is_empty()
			and applier.last_error_id == &"RESULT_SETTLEMENT_REJECTED"
			and self_made.matches_authority_snapshot(self_made_snapshot)
			and city.get_city_state() == before,
		"未经过真实 finalize 的自造 result 不能注册或提交"
	)
	scene.queue_free()
	await process_frame


func _run_fixture_victory(
	city: Node,
	coordinator: CombatTransactionCoordinator
) -> Dictionary:
	var request := coordinator.create_request(
		mini(50, city.get_available_infantry_count())
	)
	if request == null or not coordinator.activate_request():
		return {}
	for squad in request.committed_force.squads:
		squad.route_id = CommittedForceSnapshot.SIDE_ROUTE
	var session := coordinator.create_session()
	if session == null:
		return {}
	for squad in session.squads:
		coordinator.issue_order(int(squad.squad_id), BattleOrder.Command.ADVANCE)
	var result := session.run_until_complete()
	if result == null or result.outcome != BattleOutcome.Value.VICTORY:
		return {}
	coordinator.mark_result_pending()
	var before_elapsed_total := _elapsed_total_milliseconds(city)
	var summary := coordinator.confirm_result()
	var return_contract := coordinator.request_return_to_city()
	if return_contract == null or not coordinator.complete_return_to_city(
		return_contract.city_input_restore_frame
	):
		return {}
	return {
		"result": result,
		"summary": summary,
		"before_elapsed_total": before_elapsed_total,
	}


func _make_pending_city(player_count: int) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
	city.infantry_count = player_count
	city.food = 80
	city._refresh_city_ui()
	return {"scene": scene, "city": city}


func _advanced_time(
	start_day: int,
	start_elapsed_milliseconds: int,
	duration_milliseconds: int,
	milliseconds_per_day: int
) -> Dictionary:
	var total := start_elapsed_milliseconds + duration_milliseconds
	return {
		"day": start_day + total / milliseconds_per_day,
		"elapsed_milliseconds": total % milliseconds_per_day,
	}


func _elapsed_total_milliseconds(city: Node) -> int:
	return (
		(city.current_day - 1) * roundi(city.SECONDS_PER_DAY * 1000.0)
		+ roundi(city.day_elapsed_seconds * 1000.0)
	)


func _time_snapshot(city: Node) -> Dictionary:
	return {
		"day": city.current_day,
		"elapsed_milliseconds": roundi(city.day_elapsed_seconds * 1000.0),
	}


func _time_snapshot_from_state(state: Dictionary) -> Dictionary:
	return {
		"day": int(state.day),
		"elapsed_milliseconds": roundi(
			float(state.day_elapsed_seconds) * 1000.0
		),
	}


func _make_result(
	request: BattleRequest,
	result_id: StringName,
	outcome: BattleOutcome.Value,
	survivors: int,
	finished_tick: int
) -> BattleResult:
	var result := BattleResult.new()
	result.result_id = result_id
	result.transaction_id = request.transaction_id
	result.session_id = StringName("%s-test-session" % request.transaction_id)
	result.level_id = request.level_id
	result.outcome = outcome
	result.started_day = request.created_day
	result.finished_tick = finished_tick
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
		print("C0_CITY_TIME_SETTLEMENT_SMOKE PASS")
		quit(0)
	else:
		print("C0_CITY_TIME_SETTLEMENT_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

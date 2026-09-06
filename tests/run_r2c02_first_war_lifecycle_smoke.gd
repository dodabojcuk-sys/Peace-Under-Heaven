extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const ORIGIN_CITY_ID := &"blackstone_city"
const DESTINATION_CITY_ID := &"riverbend_city"
const FIRST_WAR_LEVEL_ID := &"first_map.main_assault.v0"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_production_composition_and_pre_activation_cancellation()
	await _check_terminal_outcome(BattleOutcome.Value.VICTORY, 10, 1)
	await _check_terminal_outcome(BattleOutcome.Value.DEFEAT, 1, 100)
	_finish()


func _check_production_composition_and_pre_activation_cancellation() -> void:
	var scene := await _make_city()
	if scene == null:
		return
	var city: Node = scene.get_node("ConstructionController")
	var nation: NationState = city.get_nation_state()
	var city_ids := nation.get_city_ids()
	_check(
		city.get_nation_state() == nation
			and city_ids == [ORIGIN_CITY_ID, DESTINATION_CITY_ID],
		"正式 blank_map 组合只暴露一个 NationState 和两个稳定城市 ID"
	)
	var destination_before := nation.get_city_state(DESTINATION_CITY_ID)
	var resources_before := nation.get_shared_resources()
	var event_count := [0]
	city.city_state_changed.connect(func(): event_count[0] += 1)

	var invalid_before := _atomic_truth(city, nation)
	_check(
		city.reserve_army_dispatch(5, &"", &"route.first_war", 1000).is_empty()
			and city.reserve_army_dispatch(
				5,
				ORIGIN_CITY_ID,
				&"route.first_war",
				1000
			).is_empty()
			and _atomic_truth(city, nation) == invalid_before,
		"固定来源不可覆盖，空目的地和同城目的地均原子拒绝"
	)
	var reservation: Dictionary = city.reserve_army_dispatch(
		10,
		DESTINATION_CITY_ID,
		&"route.first_war.blackstone_riverbend",
		1000
	)
	_check(
		not reservation.is_empty()
			and StringName(reservation.source_node_id) == ORIGIN_CITY_ID
			and StringName(reservation.target_node_id) == DESTINATION_CITY_ID
			and int(reservation.committed_count) == 10,
		"First War prepare 生成稳定城市身份和确定性只读预留描述"
	)
	var detached_reservation: Dictionary = (
		city.get_active_army_dispatch_reservation()
	)
	detached_reservation.committed_count = 999
	_check(
		int(city.get_active_army_dispatch_reservation().committed_count) == 10,
		"预留查询是深拷贝，调用者不能反向改写 authority"
	)
	var reserved_truth := _atomic_truth(city, nation)
	var events_after_reserve := int(event_count[0])
	_check(
		city.reserve_army_dispatch(
			1,
			DESTINATION_CITY_ID,
			&"route.duplicate",
			1000
		).is_empty()
			and _atomic_truth(city, nation) == reserved_truth
			and int(event_count[0]) == events_after_reserve,
		"重复 departure reservation 零写入拒绝且不发送额外事件"
	)
	_check(
		city.cancel_army_dispatch(StringName(reservation.transaction_id))
			and city.get_active_army_dispatch_reservation().is_empty()
			and city.infantry_count == 20
			and nation.get_shared_resources() == resources_before,
		"激活前取消完整释放预留，不扣驻军或资源"
	)
	var cancelled_truth := _atomic_truth(city, nation)
	var events_after_cancel := int(event_count[0])
	_check(
		not city.cancel_army_dispatch(StringName(reservation.transaction_id))
			and _atomic_truth(city, nation) == cancelled_truth
			and int(event_count[0]) == events_after_cancel,
		"重复相同取消安全幂等：不产生第二次写入或事件"
	)
	_check(
		nation.get_city_state(DESTINATION_CITY_ID) == destination_before,
		"预留和取消不改变 Riverbend 的局部状态"
	)
	scene.queue_free()
	await process_frame


func _check_terminal_outcome(
	expected_outcome: BattleOutcome.Value,
	committed_count: int,
	enemy_count: int
) -> void:
	var scene := await _make_city()
	if scene == null:
		return
	var city: Node = scene.get_node("ConstructionController")
	var nation: NationState = city.get_nation_state()
	var destination_before := nation.get_city_state(DESTINATION_CITY_ID)
	var resources_before := nation.get_shared_resources()
	var operation := _depart_and_arrive(city, committed_count)
	_check(
		not operation.is_empty()
			and StringName(operation.army.target_node_id) == DESTINATION_CITY_ID
			and city.mark_army_settlement_pending(
				StringName(operation.army.army_id),
				StringName(operation.army.transaction_id)
			),
		"First War departure 原子扣除一次并到达固定目的地等待结算"
	)
	if operation.is_empty():
		scene.queue_free()
		await process_frame
		return
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	_check(
		coordinator.configure(city),
		"正式城市组合绑定唯一 CombatTransactionCoordinator"
	)
	var request := coordinator.create_army_request(
		StringName(operation.army.army_id),
		FIRST_WAR_LEVEL_ID,
		enemy_count,
		0
	)
	_check(
		request != null
			and request.source_id == &"FIRST_WAR"
			and request.transaction_id == operation.transaction_id
			and coordinator.activate_request()
			and coordinator.create_session() != null,
		"现有 ArmyRegistry 和 Coordinator 直接形成 First War BattleSession"
	)
	if request == null:
		scene.queue_free()
		await process_frame
		return
	var result := _run_to_terminal(coordinator)
	_check(
		result != null
			and result.outcome == expected_outcome
			and result.is_consistent(),
		"BattleSession 只生成一致的 %s terminal facts" % BattleOutcome.to_id(expected_outcome)
	)
	if result == null:
		scene.queue_free()
		await process_frame
		return
	var pending_truth := _atomic_truth(city, nation)
	var forged := BattleResult.from_authority_snapshot(
		result.get_authority_snapshot()
	)
	forged.enemy_casualties += 1
	_check(
		coordinator.confirm_result(forged).is_empty()
			and coordinator.last_result_error_id == &"RESULT_PAYLOAD_CONFLICT"
			and _atomic_truth(city, nation) == pending_truth,
		"冲突 terminal result 在 authority 边界原子拒绝"
	)
	var summary := coordinator.confirm_result()
	var settled_truth := _atomic_truth(city, nation)
	_check(
		not summary.is_empty()
			and int(summary.committed_count) == committed_count
			and int(summary.committed_count)
				== int(summary.casualty_count) + int(summary.survivor_count)
			and coordinator.confirm_result() == summary
			and _atomic_truth(city, nation) == settled_truth,
		"同一 terminal result exactly-once；预留等于损失加幸存"
	)
	var army: Dictionary = city.get_army_state(
		StringName(operation.army.army_id)
	)
	if int(summary.survivor_count) > 0:
		_check(
			StringName(summary.disposition)
				== ArmyRegistry.DISPOSITION_RETURNING_HOME
			and StringName(army.phase) == ArmyRegistry.PHASE_RETURNING
			and StringName(army.target_node_id) == ORIGIN_CITY_ID,
			"所有幸存者只经既有返乡 phase 返回 blackstone_city"
		)
		var returned := _return_army_to_origin(city, army)
		_check(
			not returned.is_empty()
				and int(returned.returned_count) == int(summary.survivor_count)
				and city.infantry_count
					== 20 - int(summary.casualty_count)
				and city.complete_returned_army_to_garrison(
					StringName(operation.army.army_id),
					StringName(operation.army.transaction_id)
				).is_empty(),
			"返乡军队只回补一次 origin garrison，并保持伤亡守恒"
		)
	else:
		_check(
			StringName(summary.disposition)
				== ArmyRegistry.DISPOSITION_CLOSED_LOST
			and StringName(army.phase) == ArmyRegistry.PHASE_CLOSED
			and Dictionary(army.units_by_definition_id).is_empty()
			and city.infantry_count == 20 - int(summary.casualty_count),
			"零幸存失败关闭 Army 记录且不产生 destination 驻扎"
		)
	_check(
		nation.get_city_state(DESTINATION_CITY_ID) == destination_before
			and nation.get_shared_resources() == resources_before,
		"Riverbend owner/faction/local state 与国家资源均无 First War 写入"
	)
	_check(
		not city.export_v5_campaign_snapshot().is_empty(),
		"既有 V5 只保存已存在的 ArmyRegistry 和 settlement facts"
	)
	scene.queue_free()
	await process_frame


func _make_city() -> Node2D:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	if city == null:
		_check(false, "正式城市组合必须提供 ConstructionController")
		return null
	city.set_process(false)
	return scene


func _depart_and_arrive(city: Node, committed_count: int) -> Dictionary:
	var reservation: Dictionary = city.reserve_army_dispatch(
		committed_count,
		DESTINATION_CITY_ID,
		&"route.first_war.blackstone_riverbend",
		1000
	)
	if reservation.is_empty():
		return {}
	var army: Dictionary = city.confirm_army_dispatch(
		StringName(reservation.transaction_id)
	)
	if army.is_empty():
		return {}
	var arrival: Dictionary = city.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		0,
		1000
	)
	return {
		"transaction_id": StringName(reservation.transaction_id),
		"army": arrival.get("army", {}).duplicate(true),
	}


func _run_to_terminal(
	coordinator: CombatTransactionCoordinator
) -> BattleResult:
	for squad in coordinator.active_request.committed_force.squads:
		coordinator.issue_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		)
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		var result := coordinator.advance_battle_tick()
		if result != null:
			return result
	return null


func _return_army_to_origin(city: Node, army: Dictionary) -> Dictionary:
	var army_id := StringName(army.army_id)
	var transaction_id := StringName(army.transaction_id)
	var arrival: Dictionary = city.advance_army_strategic_time(
		army_id,
		transaction_id,
		0,
		int(army.duration_milliseconds)
	)
	if not bool(arrival.get("arrived", false)):
		return {}
	return city.complete_returned_army_to_garrison(army_id, transaction_id)


func _atomic_truth(city: Node, nation: NationState) -> Dictionary:
	return {
		"resources": nation.get_shared_resources(),
		"origin": nation.get_city_state(ORIGIN_CITY_ID),
		"destination": nation.get_city_state(DESTINATION_CITY_ID),
		"garrison": city.infantry_count,
		"reservation": city.get_active_army_dispatch_reservation(),
		"registry": city.get_army_registry_snapshot(),
		"snapshot": city.export_v5_campaign_snapshot(),
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("R2C02_FIRST_WAR_LIFECYCLE_SMOKE PASS")
		quit(0)
		return
	print("R2C02_FIRST_WAR_LIFECYCLE_SMOKE FAIL: %s" % failures)
	quit(1)

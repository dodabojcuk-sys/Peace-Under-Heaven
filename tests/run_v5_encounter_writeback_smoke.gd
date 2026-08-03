extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可加载")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	_check(coordinator.configure(city), "遭遇协调器绑定唯一城市权威")

	var victory_army := _dispatch_and_arrive(
		city,
		10,
		&"node.victory",
		&"route.victory",
		1000
	)
	_check(
		not victory_army.is_empty()
			and city.mark_army_settlement_pending(
				StringName(victory_army.army_id),
				StringName(victory_army.transaction_id)
			),
		"抵达军队通过正式入口进入遭遇等待"
	)
	var victory_request := coordinator.create_army_request(
		StringName(victory_army.army_id),
		&"v5.encounter.victory",
		1,
		0
	)
	_check(
		victory_request != null
			and victory_request.transaction_id
				== victory_army.transaction_id
			and victory_request.committed_force.get_committed_total()
				== 10,
		"遭遇请求从 ArmyState 只读构造同一事务兵力快照"
	)
	_check(
		coordinator.activate_request()
			and coordinator.create_session() != null,
		"ArmyState 遭遇仍复用唯一 BattleSession"
	)
	var victory_result := _run_to_terminal(coordinator, false)
	_check(
		victory_result != null
			and victory_result.outcome == BattleOutcome.Value.VICTORY
			and victory_result.is_consistent(),
		"极简战斗只产出一致的胜利事实"
	)
	var fact_snapshot := victory_result.get_authority_snapshot()
	_check(
		_has_exact_battle_fact_keys(fact_snapshot)
			and not _contains_forbidden_after_state(fact_snapshot),
		"BattleResult 只包含合同事实，不包含城市、ArmyState、存档或 UI 后状态"
	)
	var forged := BattleResult.from_authority_snapshot(fact_snapshot)
	forged.enemy_casualties += 1
	var before_forged := _settlement_truth(city)
	_check(
		coordinator.confirm_result(forged).is_empty()
			and coordinator.last_result_error_id
				== &"RESULT_PAYLOAD_CONFLICT"
			and _settlement_truth(city) == before_forged,
		"篡改 terminal payload 在写回前拒绝且全状态零写入"
	)
	var victory_summary := coordinator.confirm_result()
	_check(
		not victory_summary.is_empty()
			and victory_summary.army_id == victory_army.army_id
			and victory_summary.disposition
				== ArmyRegistry.DISPOSITION_RETURNING_HOME
			and victory_summary.survivor_count
				== victory_result.survivor_count,
		"胜利事实一次性写回为返乡策略"
	)
	var returning_victory: Dictionary = city.get_army_state(
		StringName(victory_army.army_id)
	)
	_check(
		returning_victory.phase == ArmyRegistry.PHASE_RETURNING
			and returning_victory.last_applied_result_id
				== victory_result.result_id
			and returning_victory.units_by_definition_id[
				city.INFANTRY_ROLE.role_id
			] == victory_result.survivor_count
			and city.get_committed_world_infantry_total()
				== 20 - victory_result.casualty_count,
		"返乡军队保留幸存者事实且伤亡后世界总兵力守恒"
	)
	var after_victory := _settlement_truth(city)
	_check(
		coordinator.confirm_result() == victory_summary
			and _settlement_truth(city) == after_victory,
		"相同 result replay 返回同一摘要且不重复写回"
	)
	_check(
		city.apply_battle_result_atomic(
			StringName(victory_army.transaction_id),
			&"result.conflict"
		).is_empty()
			and _settlement_truth(city) == after_victory,
		"同事务冲突 result ID 无法绕过协调器权威"
	)
	_complete_returning_army(
		city,
		coordinator,
		StringName(victory_army.army_id),
		StringName(victory_army.transaction_id)
	)

	var before_retreat_world: int = (
		city.get_committed_world_infantry_total()
	)
	var retreat_army := _dispatch_and_arrive(
		city,
		5,
		&"node.retreat",
		&"route.retreat",
		1200
	)
	_check(
		not retreat_army.is_empty()
			and city.mark_army_settlement_pending(
				StringName(retreat_army.army_id),
				StringName(retreat_army.transaction_id)
			),
		"第二支军队可在首支 CLOSED 后进入遭遇"
	)
	var retreat_request := coordinator.create_army_request(
		StringName(retreat_army.army_id),
		&"v5.encounter.retreat",
		5,
		0
	)
	_check(
		retreat_request != null
			and coordinator.activate_request()
			and coordinator.create_session() != null,
		"撤退遭遇建立真实 BattleSession"
	)
	var retreat_result := _run_to_terminal(coordinator, true)
	_check(
		retreat_result != null
			and retreat_result.outcome == BattleOutcome.Value.RETREAT
			and retreat_result.survivor_count > 0,
		"真实撤退命令产生幸存/伤亡事实"
	)
	var retreat_summary := coordinator.confirm_result()
	var returning: Dictionary = city.get_army_state(
		StringName(retreat_army.army_id)
	)
	_check(
		retreat_summary.disposition
				== ArmyRegistry.DISPOSITION_RETURNING_HOME
			and returning.phase == ArmyRegistry.PHASE_RETURNING
			and returning.source_node_id == &"node.retreat"
			and returning.target_node_id == &"blackstone_city"
			and returning.progress_milliseconds == 0,
		"撤退策略交换稳定节点并进入 RETURNING，不直接写城市驻军"
	)
	var return_arrival: Dictionary = city.advance_army_strategic_time(
		StringName(retreat_army.army_id),
		StringName(retreat_army.transaction_id),
		0,
		int(returning.duration_milliseconds)
	)
	_check(
		return_arrival.arrived
			and return_arrival.army.phase == ArmyRegistry.PHASE_ARRIVED,
		"返回行军仍由同一整数战略时间入口抵达"
	)
	var garrison_before_return: int = city.infantry_count
	var returned: Dictionary = city.complete_returned_army_to_garrison(
		StringName(retreat_army.army_id),
		StringName(retreat_army.transaction_id)
	)
	_check(
		returned.returned_count == retreat_result.survivor_count
			and city.infantry_count
				== garrison_before_return + retreat_result.survivor_count
			and city.get_army_state(
				StringName(retreat_army.army_id)
			).phase == ArmyRegistry.PHASE_CLOSED
			and city.get_committed_world_infantry_total()
				== before_retreat_world - retreat_result.casualty_count,
		"返城一次性把幸存者写入原驻军并保持伤亡守恒"
	)
	var returned_truth := _settlement_truth(city)
	_check(
		city.complete_returned_army_to_garrison(
			StringName(retreat_army.army_id),
			StringName(retreat_army.transaction_id)
		).is_empty()
			and _settlement_truth(city) == returned_truth,
		"重复返回、信号或场景重进不能二次增加驻军"
	)
	_complete_coordinator_return(coordinator)

	var before_defeat_world: int = (
		city.get_committed_world_infantry_total()
	)
	var defeat_army := _dispatch_and_arrive(
		city,
		1,
		&"node.defeat",
		&"route.defeat",
		1000
	)
	_check(
		not defeat_army.is_empty()
			and city.mark_army_settlement_pending(
				StringName(defeat_army.army_id),
				StringName(defeat_army.transaction_id)
			),
		"失败用例建立第三个集合记录"
	)
	var defeat_request := coordinator.create_army_request(
		StringName(defeat_army.army_id),
		&"v5.encounter.defeat",
		100,
		10
	)
	_check(
		defeat_request != null
			and coordinator.activate_request()
			and coordinator.create_session() != null,
		"失败遭遇建立真实 BattleSession"
	)
	var defeat_result := _run_to_terminal(coordinator, false)
	_check(
		defeat_result != null
			and defeat_result.outcome == BattleOutcome.Value.DEFEAT
			and defeat_result.survivor_count == 0,
		"真实失败战斗产出零幸存事实"
	)
	var defeat_summary := coordinator.confirm_result()
	var defeated: Dictionary = city.get_army_state(
		StringName(defeat_army.army_id)
	)
	_check(
		defeat_summary.disposition
				== ArmyRegistry.DISPOSITION_CLOSED_LOST
			and defeated.phase == ArmyRegistry.PHASE_CLOSED
			and Dictionary(defeated.units_by_definition_id).is_empty()
			and city.get_committed_world_infantry_total()
				== before_defeat_world - defeat_result.casualty_count,
		"失败清空该军队幸存组成并关闭记录，不修改 UI 缓存"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _dispatch_and_arrive(
	city: Node,
	quantity: int,
	target_node_id: StringName,
	route_id: StringName,
	duration_milliseconds: int
) -> Dictionary:
	var reservation: Dictionary = city.reserve_army_dispatch(
		quantity,
		target_node_id,
		route_id,
		duration_milliseconds
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
		duration_milliseconds
	)
	return (
		city.get_army_state(StringName(army.army_id))
		if bool(arrival.get("arrived", false))
		else {}
	)


func _run_to_terminal(
	coordinator: CombatTransactionCoordinator,
	order_retreat: bool
) -> BattleResult:
	for squad in coordinator.active_request.committed_force.squads:
		coordinator.issue_order(
			int(squad.squad_id),
			(
				BattleOrder.Command.RETREAT
				if order_retreat
				else BattleOrder.Command.ADVANCE
			)
		)
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		var result := coordinator.advance_battle_tick()
		if result != null:
			return result
	return null


func _complete_coordinator_return(
	coordinator: CombatTransactionCoordinator
) -> void:
	var contract := coordinator.request_return_to_city()
	if contract == null:
		return
	coordinator.complete_return_to_city(
		int(contract.city_input_restore_frame)
	)


func _complete_returning_army(
	city: Node,
	coordinator: CombatTransactionCoordinator,
	army_id: StringName,
	transaction_id: StringName
) -> void:
	_complete_coordinator_return(coordinator)
	var returning: Dictionary = city.get_army_state(army_id)
	if StringName(returning.get("phase", &"")) != ArmyRegistry.PHASE_RETURNING:
		return
	city.advance_army_strategic_time(
		army_id,
		transaction_id,
		0,
		int(returning.duration_milliseconds)
	)
	city.complete_returned_army_to_garrison(army_id, transaction_id)


func _settlement_truth(city: Node) -> Dictionary:
	return {
		"day": city.current_day,
		"elapsed": city.get_day_elapsed_milliseconds(),
		"garrison": city.infantry_count,
		"registry": city.get_army_registry_snapshot(),
		"last_summary": (
			city.get_city_state().last_battle_result_summary
		),
		"world_total": city.get_committed_world_infantry_total(),
	}


func _has_exact_battle_fact_keys(snapshot: Dictionary) -> bool:
	var expected := [
		"breached_route",
		"casualty_count",
		"committed_count",
		"enemy_casualties",
		"enemy_snapshot_digest",
		"finished_tick",
		"first_clear_key",
		"level_id",
		"orders_digest",
		"outcome",
		"player_snapshot_digest",
		"result_id",
		"session_id",
		"started_day",
		"survivor_count",
		"transaction_id",
	]
	var keys := snapshot.keys()
	keys.sort()
	return keys == expected


func _contains_forbidden_after_state(snapshot: Dictionary) -> bool:
	for key in snapshot:
		var text := String(key).to_lower()
		if (
			"after" in text
			or "garrison" in text
			or "army_state" in text
			or "save" in text
			or "ui" in text
			or "reward" in text
			or "city_time" in text
		):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("V5_ENCOUNTER_WRITEBACK_SMOKE PASS")
		quit(0)
		return
	print("V5_ENCOUNTER_WRITEBACK_SMOKE FAIL: %s" % failures)
	quit(1)

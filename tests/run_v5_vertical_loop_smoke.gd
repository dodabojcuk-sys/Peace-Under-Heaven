extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_root := "%s/txwzs-v5-vertical-%d-%d" % [
		OS.get_temp_dir(),
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	_remove_tree(save_root)
	_check(
		DirAccess.make_dir_recursive_absolute(save_root) == OK,
		"建立纵向闭环隔离存档目录"
	)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可加载")
	if packed_scene == null:
		_finish(save_root)
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.set_city_time_paused(true)

	var initial_food: int = city.food
	_check(city.queue_training(), "玩家正式入口建立唯一训练订单")
	_check(
		city.food == initial_food - 15
			and city.training_queued_count == 5
			and city.infantry_count == 20,
		"训练下单只扣城市粮食且尚未写驻军"
	)
	city.recruitment_cap = 20
	city.set_city_time_paused(false)
	var blocked_truth := _training_truth(city)
	var boundary_seconds := (
		float(180001 - int(blocked_truth.elapsed)) / 1000.0
	)
	var blocked_advance: int = city.advance_city_time_for_test(
		boundary_seconds
	)
	_check(
		blocked_advance == 0
			and city.current_day == blocked_truth.day
			and city.get_day_elapsed_milliseconds()
				== 180000
			and city.food == blocked_truth.food
			and city.infantry_count == blocked_truth.garrison
			and city.get_training_queue_snapshot()
				== blocked_truth.queue,
		"边界容量故障使时间停在日界且结算、驻军和队列零写入"
	)
	city.recruitment_cap = 50
	_check(
		city.advance_city_time_for_test(0.001) == 1
			and city.current_day == 2
			and city.infantry_count == 25
			and city.training_queued_count == 0,
		"解除阻断后同一订单只在城市战略日边界完成一次"
	)
	city.set_city_time_paused(true)

	var reservation: Dictionary = city.reserve_army_dispatch(
		10,
		&"node.vertical_target",
		&"route.vertical_target",
		4000
	)
	_check(
		not reservation.is_empty()
			and city.infantry_count == 25
			and city.get_dispatchable_infantry_count() == 15,
		"派遣预留使用权威可派查询且不提前扣驻军"
	)
	var army: Dictionary = city.confirm_army_dispatch(
		StringName(reservation.transaction_id)
	)
	_check(
		not army.is_empty()
			and city.infantry_count == 15
			and city.get_committed_world_infantry_total() == 25,
		"确认派遣一次性创建 ArmyState 并保持世界兵力守恒"
	)
	var partial: Dictionary = city.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		0,
		1500
	)
	var arrival: Dictionary = city.advance_army_strategic_time(
		StringName(army.army_id),
		StringName(army.transaction_id),
		1500,
		2500
	)
	_check(
		partial.success
			and not partial.arrived
			and arrival.success
			and arrival.arrived
			and arrival.army.phase == ArmyRegistry.PHASE_ARRIVED,
		"Army 只由整数城市战略时间从 MARCHING 推进到 ARRIVED"
	)
	_check(
		city.mark_army_settlement_pending(
			StringName(army.army_id),
			StringName(army.transaction_id)
		),
		"到达 Army 经唯一入口进入 SETTLEMENT_PENDING"
	)

	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	_check(coordinator.configure(city), "遭遇协调器绑定唯一城市权威")
	var request := coordinator.create_army_request(
		StringName(army.army_id),
		&"v5.vertical_loop",
		1,
		0
	)
	_check(
		request != null
			and request.committed_force.get_committed_total() == 10
			and coordinator.activate_request()
			and coordinator.create_session() != null,
		"ArmyState 只读构造请求并复用唯一 BattleSession"
	)
	var result := _run_to_terminal(coordinator)
	_check(
		result != null
			and result.outcome == BattleOutcome.Value.VICTORY
			and result.is_consistent(),
		"BattleSession 产生真实、一致的 terminal facts"
	)
	if result == null:
		_finish(save_root)
		return
	var world_before_settlement: int = (
		city.get_committed_world_infantry_total()
	)
	var summary: Dictionary = coordinator.confirm_result()
	var stationed: Dictionary = city.get_army_state(
		StringName(army.army_id)
	)
	_check(
		not summary.is_empty()
			and summary.disposition
				== ArmyRegistry.DISPOSITION_STATIONED_TARGET
			and stationed.phase == ArmyRegistry.PHASE_CLOSED
			and stationed.last_applied_result_id == result.result_id,
		"城市权威入口一次性把胜利事实写为目标驻扎"
	)
	_check(
		city.get_committed_world_infantry_total()
				== world_before_settlement - result.casualty_count
			and stationed.units_by_definition_id[
				city.INFANTRY_ROLE.role_id
			] == result.survivor_count,
		"战果写回后驻军、Army 幸存与伤亡继续守恒"
	)
	var settled_truth := _settlement_truth(city)
	_check(
		coordinator.confirm_result() == summary
			and _settlement_truth(city) == settled_truth,
		"相同 terminal result 重放幂等且零二次写入"
	)

	var return_contract := coordinator.request_return_to_city()
	if return_contract != null:
		coordinator.complete_return_to_city(
			int(return_contract.city_input_restore_frame)
		)
	var save_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var store := V5CampaignSaveStore.new(save_root)
	var save_result: Dictionary = store.save_snapshot(
		save_snapshot,
		Callable(city, "validate_v5_campaign_snapshot")
	)
	_check(
		save_result.success and save_result.save_sequence == 1,
		"完整闭环状态经 V5 writer 发布为第一代"
	)

	var reload_scene := packed_scene.instantiate()
	root.add_child(reload_scene)
	await process_frame
	await process_frame
	var reloaded: Node = reload_scene.get_node("ConstructionController")
	reloaded.set_process(false)
	var load_result: Dictionary = store.load_and_restore(reloaded)
	_check(
		load_result.success
			and reloaded.export_v5_campaign_snapshot() == save_snapshot,
		"新运行时精确恢复训练、城市、驻军、Army 与战果 ledger"
	)
	var restored_army: Dictionary = reloaded.get_army_state(
		StringName(army.army_id)
	)
	_check(
		restored_army.phase == ArmyRegistry.PHASE_CLOSED
			and restored_army.last_applied_result_id == result.result_id
			and reloaded.get_committed_world_infantry_total()
				== city.get_committed_world_infantry_total(),
		"恢复后的 closed Army、result ID 与世界兵力不重复结算"
	)
	_check(
		not _contains_forbidden_value(save_snapshot),
		"纵向闭环存档不含 Node、像素坐标、camera 或 UI 状态"
	)

	scene.queue_free()
	reload_scene.queue_free()
	await process_frame
	_finish(save_root)


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


func _training_truth(city: Node) -> Dictionary:
	return {
		"day": city.current_day,
		"elapsed": city.get_day_elapsed_milliseconds(),
		"food": city.food,
		"garrison": city.infantry_count,
		"queue": city.get_training_queue_snapshot(),
	}


func _settlement_truth(city: Node) -> Dictionary:
	return {
		"day": city.current_day,
		"elapsed": city.get_day_elapsed_milliseconds(),
		"garrison": city.infantry_count,
		"registry": city.get_army_registry_snapshot(),
		"ledger": city.export_v5_campaign_snapshot().settlement_ledger,
		"world_total": city.get_committed_world_infantry_total(),
	}


func _contains_forbidden_value(value) -> bool:
	if value is Node or value is Resource or value is Callable:
		return true
	if value is Dictionary:
		for key in value:
			var text := String(key).to_lower()
			if (
				"pixel" in text
				or "camera" in text
				or "panel" in text
				or "selection" in text
			):
				return true
			if _contains_forbidden_value(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_value(item):
				return true
	return false


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
	push_error("FAIL: %s" % message)


func _finish(save_root: String) -> void:
	_remove_tree(save_root)
	if failures.is_empty():
		print("V5_VERTICAL_LOOP_SMOKE PASS")
		quit(0)
		return
	print("V5_VERTICAL_LOOP_SMOKE FAIL: %s" % [failures])
	quit(1)

extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "主场景可以加载")
	if packed_scene == null:
		_finish()
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var coordinator := CombatTransactionCoordinator.new()
	scene.add_child(coordinator)
	coordinator.configure(city)

	var placement_count: int = city.get_building_count()
	var occupied_count: int = city.get_occupied_cell_count()
	var request := coordinator.create_request(20)
	_check(request != null and request.is_valid(), "创建类型化 BattleRequest")
	_check(
		request.phase == BattleRequest.PHASE_RESERVED,
		"请求从 RESERVED 开始"
	)
	_check(
		request.committed_force is CommittedForceSnapshot
			and request.enemy_force is EnemyForceSnapshot,
		"请求冻结双方快照"
	)
	_check(
		request.committed_force.squads.size() == 3,
		"20 人默认拆成最多三个非空小队"
	)
	_check(
		request.committed_force.squads[0].initial_members == 7
			and request.committed_force.squads[1].initial_members == 7
			and request.committed_force.squads[2].initial_members == 6,
		"余数按小队编号依次分配为 7/7/6"
	)
	_check(
		request.committed_force.squads[0].route_id == &"FRONT_GATE"
			and request.committed_force.squads[1].route_id == &"SIDE_GATE"
			and request.committed_force.squads[2].route_id == &"FRONT_GATE",
		"可逆默认路线为正门/侧门/正门"
	)
	_check(
		city.infantry_count == 20
			and city.get_available_infantry_count() == 0,
		"预留不提前扣总兵力但从可用兵力排除"
	)
	_check(
		city.get_building_count() == placement_count
			and city.get_occupied_cell_count() == occupied_count,
		"预留不污染 placement 或 occupied cells"
	)
	_check(
		coordinator.create_request(1) == null,
		"活动事务期间拒绝第二次预留"
	)
	_check(
		not city.advance_one_day_for_test()
			and not city.restart_first_map()
			and not city.queue_training(),
		"活动预留期间拒绝城市状态修改"
	)

	var transaction_id: StringName = request.transaction_id
	_check(coordinator.cancel_request(), "战斗开始前可以取消")
	_check(
		city.infantry_count == 20
			and city.get_available_infantry_count() == 20
			and not city.is_city_action_locked_for_battle(),
		"战前取消完整释放兵力"
	)
	_check(
		city.get_closed_battle_transaction_phase(transaction_id)
			== city.BATTLE_PHASE_CANCELLED,
		"取消事务记录 CANCELLED"
	)
	_check(
		not city.cancel_battle_reservation(transaction_id, coordinator),
		"重复取消不产生第二次变化"
	)

	var second_request := coordinator.create_request(2)
	_check(second_request != null, "取消后可以建立新事务")
	_check(
		second_request.transaction_id != transaction_id,
		"事务 ID 单调且不复用"
	)
	_check(
		second_request.committed_force.squads.size() == 2
			and second_request.committed_force.squads[0].initial_members == 1
			and second_request.committed_force.squads[1].initial_members == 1,
		"不足三人时只创建非空小队"
	)
	_check(coordinator.activate_request(), "RESERVED 可以进入 ACTIVE")
	_check(
		second_request.phase == BattleRequest.PHASE_ACTIVE,
		"请求和城市预留同步为 ACTIVE"
	)
	_check(
		not coordinator.cancel_request()
			and not city.cancel_battle_reservation(
				second_request.transaction_id,
				coordinator
			),
		"战斗开始后不能伪装成战前取消"
	)
	var second_session := coordinator.create_session()
	if second_session != null:
		for squad in second_session.squads:
			coordinator.issue_order(
				int(squad.squad_id),
				BattleOrder.Command.RETREAT
			)
		second_session.run_until_complete()
	_check(
		second_session != null
			and second_session.result != null
			and coordinator.mark_result_pending(),
		"真实 finalize 后 ACTIVE 可以进入 RESULT_PENDING"
	)
	_check(
		second_request.phase == BattleRequest.PHASE_RESULT_PENDING,
		"结果 pending 生命周期明确"
	)
	_check(
		not coordinator.mark_result_pending(),
		"重复生命周期迁移被拒绝"
	)

	var enemy := second_request.enemy_force
	_check(
		enemy.snapshot_day == 1
			and enemy.enemy_count == 32
			and enemy.fortification_level == 0,
		"敌军快照冻结当前日期、人数和工事"
	)
	_check(
		enemy.route_states[&"FRONT_GATE"].enemy_members == 13
			and enemy.route_states[&"SIDE_GATE"].enemy_members == 19,
		"敌军按正门 40% / 侧门 60% 整数分配"
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
		print("C0A_BATTLE_TRANSACTION_SMOKE PASS")
		quit(0)
	else:
		print("C0A_BATTLE_TRANSACTION_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_outcome_writebacks()
	_check_route_choices()
	_check_render_sampling_independence()
	_finish()


func _check_outcome_writebacks() -> void:
	var victory: Dictionary = await _run_city_battle(
		50,
		1,
		32,
		0,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.SIDE_ROUTE
	)
	_check(
		victory.result.outcome == BattleOutcome.Value.VICTORY
			and int(victory.after.infantry_count)
				== 50 - int(victory.result.casualty_count)
			and bool(victory.summary.first_clear_granted),
		"胜利结果写回实际伤亡并授予一次首通"
	)

	var defeat: Dictionary = await _run_city_battle(
		1,
		12,
		64,
		2,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	_check(
		defeat.result.outcome == BattleOutcome.Value.DEFEAT
			and int(defeat.result.survivor_count) == 0
			and int(defeat.after.infantry_count) == 0
			and not bool(defeat.summary.first_clear_granted),
		"全军失败扣除实际一人且不发奖励"
	)

	var retreat: Dictionary = await _run_city_battle(
		8,
		5,
		40,
		0,
		BattleOrder.Command.RETREAT,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	_check(
		retreat.result.outcome == BattleOutcome.Value.RETREAT
			and int(retreat.result.survivor_count) == 8
			and int(retreat.after.infantry_count) == 8
			and not bool(retreat.summary.first_clear_granted),
		"主动撤退返回全部幸存者且不发奖励"
	)
	_check(
		int(victory.before.building_count)
				== int(victory.after.building_count)
			and int(victory.before.occupied_cell_count)
				== int(victory.after.occupied_cell_count)
			and int(defeat.before.building_count)
				== int(defeat.after.building_count)
			and int(retreat.before.occupied_cell_count)
				== int(retreat.after.occupied_cell_count),
		"胜败撤退均不污染城市建筑记录或占用格"
	)


func _run_city_battle(
	player_count: int,
	day: int,
	enemy_count: int,
	fortification: int,
	command: BattleOrder.Command,
	route_id: StringName
) -> Dictionary:
	var city_scene := CITY_SCENE.instantiate()
	root.add_child(city_scene)
	await process_frame
	city_scene.visible = false
	city_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var city: Node = city_scene.get_node("ConstructionController")
	city.infantry_count = player_count
	city.current_day = day
	city.enemy_count = enemy_count
	city.enemy_fortification = fortification
	var coordinator := CombatTransactionCoordinator.new()
	city_scene.add_child(coordinator)
	coordinator.configure(city)
	var request := coordinator.create_request(player_count)
	for squad in request.committed_force.squads:
		squad.route_id = route_id
	_check(coordinator.activate_request(), "事务进入 ACTIVE")
	var session := coordinator.create_session()
	for squad in session.squads:
		coordinator.issue_order(int(squad.squad_id), command)
	var result := session.run_until_complete()
	_check(
		result != null
			and result.is_consistent()
			and coordinator.mark_result_pending(),
		"实际演算结果进入 RESULT_PENDING"
	)
	var before: Dictionary = city.get_city_state()
	var building_count: int = city.get_building_count()
	var occupied_cell_count: int = city.get_occupied_cell_count()
	var summary := coordinator.confirm_result()
	var after: Dictionary = city.get_city_state()
	before["building_count"] = building_count
	before["occupied_cell_count"] = occupied_cell_count
	after["building_count"] = city.get_building_count()
	after["occupied_cell_count"] = city.get_occupied_cell_count()
	var output := {
		"result": result,
		"summary": summary,
		"before": before,
		"after": after,
	}
	city_scene.queue_free()
	await process_frame
	return output


func _check_route_choices() -> void:
	var front := _make_session(
		50,
		1,
		32,
		0,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	var side := _make_session(
		50,
		1,
		32,
		0,
		CommittedForceSnapshot.SIDE_ROUTE
	)
	for session in [front, side]:
		for squad in session.squads:
			session.issue_order(
				int(squad.squad_id),
				BattleOrder.Command.ADVANCE
			)
	var front_result := front.run_until_complete()
	var side_result := side.run_until_complete()
	_check(
		front_result.outcome == BattleOutcome.Value.VICTORY
			and front_result.breached_route
				== CommittedForceSnapshot.FRONT_ROUTE
			and side_result.outcome == BattleOutcome.Value.VICTORY
			and side_result.breached_route
				== CommittedForceSnapshot.SIDE_ROUTE,
		"正门与侧门都通过各自路线状态产生真实胜利"
	)
	_check(
		front_result.finished_tick != side_result.finished_tick
			or front_result.casualty_count != side_result.casualty_count,
		"两条路线的距离、城门与守军差异产生不同战斗轨迹"
	)


func _check_render_sampling_independence() -> void:
	var dense := _make_session(
		30,
		8,
		48,
		1,
		CommittedForceSnapshot.SIDE_ROUTE
	)
	var sparse := _make_session(
		30,
		8,
		48,
		1,
		CommittedForceSnapshot.SIDE_ROUTE
	)
	for session in [dense, sparse]:
		for squad in session.squads:
			session.issue_order(
				int(squad.squad_id),
				BattleOrder.Command.ADVANCE
			)
	while not dense.completed:
		dense.step_tick()
		dense.get_state_digest()
	var sample_stride := 7
	while not sparse.completed:
		for _index in range(sample_stride):
			if sparse.completed:
				break
			sparse.step_tick()
		sparse.get_state_digest()
	var dense_digest := _result_digest(dense)
	var sparse_digest := _result_digest(sparse)
	_check(
		dense_digest == sparse_digest,
		"不同画面采样频率不改变整数 tick 战斗结果"
	)
	_check(
		not dense.has_method("_process")
			and not dense.has_method("_physics_process"),
		"BattleSession 不依赖渲染帧或 delta"
	)


func _make_session(
	player_count: int,
	day: int,
	enemy_count: int,
	fortification: int,
	route_id: StringName
) -> BattleSession:
	var role := UnitRole.new()
	role.role_id = &"unit_role.infantry_basic"
	role.hp = 100
	role.attack = 10
	role.armor = 0
	role.move_speed = 1.0
	var transaction_id := StringName(
		"c0e-%d-%d-%d-%d" % [
			player_count,
			day,
			enemy_count,
			fortification,
		]
	)
	var committed := CommittedForceSnapshot.create_default(
		transaction_id,
		player_count,
		role,
		&"",
		[],
		1.0,
		1.0,
		false
	)
	for squad in committed.squads:
		squad.route_id = route_id
	var enemy := EnemyForceSnapshot.create(
		transaction_id,
		day,
		enemy_count,
		fortification
	)
	var request := BattleRequest.new(
		transaction_id,
		&"first_map.main_assault.v0",
		day,
		committed,
		enemy
	)
	request.phase = BattleRequest.PHASE_ACTIVE
	return BattleSession.new(request)


func _result_digest(session: BattleSession) -> String:
	var result := session.result
	return "%s|%d|%d|%d|%s|%s" % [
		BattleOutcome.to_id(result.outcome),
		result.finished_tick,
		result.survivor_count,
		result.enemy_casualties,
		result.orders_digest,
		session.get_state_digest(),
	]


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("C0E_COMBAT_CONTRACT_SMOKE PASS")
		quit(0)
	else:
		print("C0E_COMBAT_CONTRACT_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

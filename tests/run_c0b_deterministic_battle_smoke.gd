extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_enemy_snapshots()
	_check_order_boundary_and_integer_motion()
	_check_victory_defeat_and_retreat()
	_check_general_and_supply_damage()
	_check_deterministic_replay()
	_finish()


func _check_enemy_snapshots() -> void:
	var rows := [
		[1, 32, 0, 13, 19, 600, 360],
		[5, 40, 0, 16, 24, 600, 360],
		[8, 48, 1, 20, 28, 720, 480],
		[10, 56, 2, 23, 33, 840, 600],
		[12, 64, 2, 26, 38, 840, 600],
	]
	for row in rows:
		var snapshot := EnemyForceSnapshot.create(
			&"snapshot-test",
			int(row[0]),
			int(row[1]),
			int(row[2])
		)
		_check(
			snapshot.route_states[&"FRONT_GATE"].enemy_members
				== int(row[3])
				and snapshot.route_states[&"SIDE_GATE"].enemy_members
				== int(row[4])
				and snapshot.route_states[&"FRONT_GATE"].gate_hp
				== int(row[5])
				and snapshot.route_states[&"SIDE_GATE"].gate_hp
				== int(row[6]),
			"第 %d 日敌军和工事快照确定" % int(row[0])
		)


func _check_order_boundary_and_integer_motion() -> void:
	var session := _make_session(3, 32, 0, 1)
	var order := session.issue_order(1, BattleOrder.Command.ADVANCE)
	_check(
		order != null
			and order.order_id == 1
			and order.issued_tick == 0,
		"命令使用递增序号并记录 issued tick"
	)
	_check(
		session.get_squad_state(1).active_order
			== BattleOrder.Command.HOLD,
		"命令不会在渲染帧或当前 tick 立即生效"
	)
	_check(
		session.issue_order(1, BattleOrder.Command.RETREAT) == null,
		"同一小队同一 tick 拒绝第二条命令"
	)
	session.step_tick()
	var squad := session.get_squad_state(1)
	_check(
		squad.active_order == BattleOrder.Command.ADVANCE
			and squad.position_fixed == 4,
		"命令在下一 0.25 秒 tick 生效并按定点距离移动"
	)
	var second_order := session.issue_order(1, BattleOrder.Command.HOLD)
	_check(
		second_order != null
			and second_order.order_id == 2
			and second_order.issued_tick == 1,
		"下一 tick 可以下达序号 2"
	)
	_check(
		typeof(squad.total_hp) == TYPE_INT
			and typeof(squad.position_fixed) == TYPE_INT
			and typeof(session.current_tick) == TYPE_INT
			and session.get_state_digest().contains("1:100:4"),
		"战斗状态只记录整数 HP、tick 和定点距离"
	)


func _check_victory_defeat_and_retreat() -> void:
	var victory := _make_session(50, 32, 0, 1, &"SIDE_GATE")
	for squad in victory.squads:
		victory.issue_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		)
	var victory_result := victory.run_until_complete()
	_check(
		victory_result != null
			and victory_result.outcome == BattleOutcome.Value.VICTORY
			and victory_result.breached_route == &"SIDE_GATE"
			and victory_result.is_consistent(),
		"真实 tick 演算产生侧门胜利和一致伤亡"
	)

	var defeat := _make_session(1, 64, 2, 12, &"FRONT_GATE")
	defeat.issue_order(1, BattleOrder.Command.ADVANCE)
	var defeat_result := defeat.run_until_complete()
	_check(
		defeat_result != null
			and defeat_result.outcome == BattleOutcome.Value.DEFEAT
			and defeat_result.survivor_count == 0
			and defeat_result.casualty_count == 1,
		"真实接敌产生全军失败"
	)

	var retreat := _make_session(8, 40, 0, 5)
	for squad in retreat.squads:
		retreat.issue_order(
			int(squad.squad_id),
			BattleOrder.Command.RETREAT
		)
	var retreat_result := retreat.run_until_complete()
	_check(
		retreat_result != null
			and retreat_result.outcome == BattleOutcome.Value.RETREAT
			and retreat_result.survivor_count == 8,
		"主动撤退形成正式 RETREAT 并保留幸存者"
	)


func _check_general_and_supply_damage() -> void:
	var baseline := _make_session(10, 32, 0, 1, &"FRONT_GATE")
	var baseline_damage := baseline._calculate_player_damage(10, 10000)
	var vanguard := _make_session(
		10,
		32,
		0,
		1,
		&"FRONT_GATE",
		11000,
		10000,
		10000
	)
	var vanguard_damage := vanguard._calculate_player_damage(10, 10000)
	var shortage := _make_session(
		10,
		32,
		0,
		1,
		&"FRONT_GATE",
		10000,
		10000,
		9000
	)
	var shortage_damage := shortage._calculate_player_damage(10, 10000)
	var defender := _make_session(
		10,
		32,
		0,
		1,
		&"FRONT_GATE",
		10000,
		11200,
		10000
	)
	_check(
		baseline_damage == 100
			and vanguard_damage == 110
			and shortage_damage == 90,
		"先锋攻击和供给不足使用整数基点"
	)
	_check(
		baseline._calculate_enemy_damage(10, 10000) == 100
			and defender._calculate_enemy_damage(10, 10000) == 89,
		"守备官按 1.12 防御除数减少人员伤害"
	)


func _check_deterministic_replay() -> void:
	var expected := ""
	for iteration in range(100):
		var session := _make_session(30, 48, 1, 8)
		for squad in session.squads:
			session.issue_order(
				int(squad.squad_id),
				BattleOrder.Command.ADVANCE
			)
		var result := session.run_until_complete()
		var digest := "%s|%d|%d|%d|%s" % [
			BattleOutcome.to_id(result.outcome),
			result.finished_tick,
			result.survivor_count,
			result.enemy_casualties,
			session.get_state_digest(),
		]
		if iteration == 0:
			expected = digest
		_check(digest == expected, "确定性重放 %03d/100" % (iteration + 1))


func _make_session(
	player_count: int,
	enemy_count: int,
	fortification: int,
	day: int,
	forced_route: StringName = &"",
	attack_basis_points := 10000,
	defense_basis_points := 10000,
	supply_basis_points := 10000
) -> BattleSession:
	var role := UnitRole.new()
	role.role_id = &"unit_role.infantry_basic"
	role.hp = 100
	role.attack = 10
	role.armor = 0
	role.move_speed = 1.0
	var transaction_id := StringName(
		"test-%d-%d-%d-%d" % [
			player_count,
			enemy_count,
			day,
			failures.size(),
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
	committed.attack_basis_points = attack_basis_points
	committed.defense_basis_points = defense_basis_points
	committed.supply_basis_points = supply_basis_points
	if forced_route != &"":
		for squad in committed.squads:
			squad.route_id = forced_route
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


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("C0B_DETERMINISTIC_BATTLE_SMOKE PASS")
		quit(0)
	else:
		print("C0B_DETERMINISTIC_BATTLE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

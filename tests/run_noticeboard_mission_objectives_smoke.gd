extends SceneTree


const MISSIONS: Array[MissionDefinition] = [
	preload("res://resources/definitions/missions/outskirts_sweep.tres"),
	preload("res://resources/definitions/missions/supply_relief.tres"),
	preload("res://resources/definitions/missions/missing_scout.tres"),
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_definitions()
	_check_eliminate_objective()
	_check_protect_objective()
	_check_scout_objective()
	_finish()


func _check_definitions() -> void:
	var ids := {}
	for mission in MISSIONS:
		_check(mission.is_valid(), "%s schema 合法" % mission.title)
		_check(not ids.has(mission.mission_id), "%s mission_id 唯一" % mission.title)
		ids[mission.mission_id] = true
		_check(
			mission.source == MissionDefinition.SOURCE_NOTICEBOARD
				and mission.return_destination == MissionDefinition.RETURN_CITY,
			"%s 来源和返回目的地正确" % mission.title
		)
	_check(ids.size() == 3, "告示板只注册三项 V0 任务")


func _check_eliminate_objective() -> void:
	var session := _make_session(MISSIONS[0], 18, &"eliminate")
	session.routes[CommittedForceSnapshot.FRONT_ROUTE].enemy_total_hp = 100
	session.routes[CommittedForceSnapshot.SIDE_ROUTE].enemy_total_hp = 0
	session._check_outcome()
	_check(not session.completed, "城郊清剿剩余敌人时不胜利")
	session.routes[CommittedForceSnapshot.FRONT_ROUTE].enemy_total_hp = 0
	session._check_outcome()
	_check(
		session.completed
			and session.result.outcome == BattleOutcome.Value.VICTORY,
		"城郊清剿清空全部敌人后只生成胜利"
	)
	var defeat := _make_session(MISSIONS[0], 1, &"eliminate-defeat")
	defeat.squads[0].total_hp = 0
	defeat._check_outcome()
	_check(
		defeat.result.outcome == BattleOutcome.Value.DEFEAT,
		"城郊清剿全军失去战斗能力后失败"
	)


func _check_protect_objective() -> void:
	var session := _make_session(MISSIONS[1], 20, &"protect")
	session._check_outcome()
	_check(not session.completed, "粮车存活但敌人未清空时不胜利")
	session.mission_objective_state.protect_target_hp = 0
	session._check_outcome()
	_check(
		session.result.outcome == BattleOutcome.Value.DEFEAT,
		"粮车被摧毁后立即失败"
	)
	var victory := _make_session(MISSIONS[1], 20, &"protect-victory")
	victory.routes[CommittedForceSnapshot.FRONT_ROUTE].enemy_total_hp = 0
	victory.routes[CommittedForceSnapshot.SIDE_ROUTE].enemy_total_hp = 0
	victory._check_outcome()
	_check(
		victory.result.outcome == BattleOutcome.Value.VICTORY
			and int(victory.mission_objective_state.protect_target_hp) > 0,
		"粮车存活且敌人清空后胜利"
	)


func _check_scout_objective() -> void:
	var session := _make_session(MISSIONS[2], 15, &"scout")
	session.routes[CommittedForceSnapshot.FRONT_ROUTE].enemy_total_hp = 0
	session.routes[CommittedForceSnapshot.SIDE_ROUTE].enemy_total_hp = 0
	session._check_outcome()
	_check(not session.completed, "未发现斥候时清空敌人也不能胜利")
	session.mission_objective_state.scout_found = true
	session._check_outcome()
	_check(not session.completed, "发现斥候但未撤离时不能胜利")
	session.squads[0].exited = true
	session._check_outcome()
	_check(
		session.result.outcome == BattleOutcome.Value.VICTORY
			and bool(session.mission_objective_state.extraction_reached),
		"发现斥候并有有效小队撤离后胜利"
	)
	var defeat := _make_session(MISSIONS[2], 1, &"scout-defeat")
	defeat.squads[0].total_hp = 0
	defeat._check_outcome()
	_check(
		defeat.result.outcome == BattleOutcome.Value.DEFEAT,
		"失踪斥候任务全军失效后失败"
	)


func _make_session(
	mission: MissionDefinition,
	player_count: int,
	transaction_suffix: String
) -> BattleSession:
	var role := UnitRole.new()
	role.role_id = &"unit_role.infantry_basic"
	role.hp = 100
	role.attack = 10
	role.move_speed = 1.0
	var transaction_id := StringName("mission-%s" % transaction_suffix)
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
	var enemy := EnemyForceSnapshot.create_for_mission(
		transaction_id,
		1,
		mission
	)
	var request := BattleRequest.new(
		transaction_id,
		mission.mission_id,
		1,
		committed,
		enemy,
		false,
		0,
		0,
		MissionDefinition.SOURCE_NOTICEBOARD,
		mission.first_clear_key,
		mission.reward_wood,
		mission.reward_food,
		mission
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
		print("NOTICEBOARD_MISSION_OBJECTIVES_SMOKE_PASS")
		quit(0)
	else:
		print("NOTICEBOARD_MISSION_OBJECTIVES_SMOKE_FAIL count=%d" % failures.size())
		quit(1)

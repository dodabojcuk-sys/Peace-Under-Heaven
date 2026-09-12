extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var city: Node2D
var construction: Node
var selection: Node


func _initialize() -> void:
	# Historical mission contracts use the existing pre-campaign theatre fixture.
	preload("res://scripts/macro_march/macro_march_theater.gd").use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	city = CITY_SCENE.instantiate()
	root.add_child(city)
	await process_frame
	construction = city.get_node("ConstructionController")
	selection = city.get_node("BuildingSelectionController")
	_check_noticeboard_entry_and_cards()
	await _check_prebattle_return()
	await _check_victory_writeback_and_replay()
	await _check_failure_and_retreat_writeback()
	city.queue_free()
	await process_frame
	await process_frame
	city = null
	construction = null
	selection = null
	call_deferred("_finish")


func _check_noticeboard_entry_and_cards() -> void:
	var noticeboard_id := -1
	for placement_id in construction.get_placement_ids():
		if (
			StringName(
				construction.get_building_record(placement_id).template_id
			) == &"noticeboard"
		):
			noticeboard_id = placement_id
			break
	_check(noticeboard_id >= 0, "告示板是独立固定城市入口")
	selection.select_placement(noticeboard_id)
	var panel := city.get_node("UI/Shell/NoticeboardPanel") as Panel
	_check(panel.visible, "点击告示板打开任务列表")
	var ids: Array[StringName] = construction.get_noticeboard_mission_ids()
	_check(ids.size() == 3, "任务列表包含三个定义")
	for mission_id in ids:
		var mission: MissionDefinition = (
			construction.get_noticeboard_mission_definition(mission_id)
		)
		var card: Panel = construction._get_noticeboard_card(mission_id)
		_check(
			(card.get_node("Objective") as Label).text.contains(
				mission.objective_text
			)
				and (card.get_node("RiskReward") as Label).text.contains(
					mission.get_reward_text()
				),
			"%s 卡片显示真实目标和奖励" % mission.title
		)
		_check(
			(card.get_node("StateLabel") as Label).text == "可接受",
			"%s 卡片状态使用中文，不暴露 AVAILABLE" % mission.title
		)


func _check_prebattle_return() -> void:
	var mission_id := &"noticeboard.supply_relief.v0"
	_check(
		construction.start_noticeboard_mission(mission_id),
		"粮道求援传入正确 mission_id 并创建 C0"
	)
	var battle: C0BattleGraybox = construction.get_formal_battle_scene()
	_check(
		battle != null
			and battle.request.level_id == mission_id
			and battle.request.mission_definition.objective_type
				== MissionDefinition.OBJECTIVE_PROTECT,
		"C0 读取粮道求援任务定义"
	)
	_check(
		battle.title_label.text.contains("粮道求援")
			and battle.instruction_label.text.contains("保护粮车")
			and battle.instruction_label.text.contains("粮车"),
		"C0 显示任务名称、目标与实时进度"
	)
	_check(
		not construction.start_noticeboard_mission(
			&"noticeboard.outskirts_sweep.v0"
		),
		"已有任务时不会创建第二个 BattleSession"
	)
	var before: Dictionary = construction.get_city_state()
	_check(battle.request_exit_or_return(), "战前返回建立取消路径")
	await process_frame
	await process_frame
	var after: Dictionary = construction.get_city_state()
	_check(
		construction.get_formal_battle_scene() == null
			and construction.get_active_noticeboard_mission_id() == &""
			and after.committed_battle_result_ids.size()
				== before.committed_battle_result_ids.size(),
		"战前返回零战果并刷新 AVAILABLE 状态"
	)


func _check_victory_writeback_and_replay() -> void:
	var mission_id := &"noticeboard.outskirts_sweep.v0"
	var mission: MissionDefinition = (
		construction.get_noticeboard_mission_definition(mission_id)
	)
	construction.wood = 0
	construction.food = 0
	_check(construction.start_noticeboard_mission(mission_id), "城郊清剿可启动")
	var battle: C0BattleGraybox = construction.get_formal_battle_scene()
	_check(battle.start_battle(), "告示板任务使用现有 BattleSession")
	for route_id in battle.coordinator.active_session.routes:
		battle.coordinator.active_session.routes[route_id].enemy_total_hp = 0
	var result := battle.step_battle_for_test(1)
	_check(
		result != null and result.outcome == BattleOutcome.Value.VICTORY,
		"任务目标产生正式胜利结果"
	)
	var summary := battle.confirm_pending_result()
	_check(
		not summary.is_empty()
			and bool(summary.first_clear_granted)
			and int(summary.accepted_wood_reward) == mission.reward_wood
			and int(summary.accepted_food_reward) == mission.reward_food,
		"首次胜利通过原战果事务发放保守奖励"
	)
	var wood_after: int = int(construction.wood)
	var food_after: int = int(construction.food)
	var duplicate := battle.confirm_pending_result()
	_check(
		duplicate == summary
			and construction.wood == wood_after
			and construction.food == food_after,
		"重复确认不重复结算或奖励"
	)
	_check(battle.request_return_to_city() != null, "胜利可建立返回城市契约")
	_check(battle.complete_return_for_test(999999), "胜利返回内城")
	await process_frame
	_check(
		construction.get_noticeboard_mission_state(mission_id)
			== &"COMPLETED",
		"返回后任务列表刷新为 COMPLETED"
	)
	construction._refresh_noticeboard_ui()
	_check(
		construction.noticeboard_last_result.text.contains("城郊清剿")
			and construction.noticeboard_last_result.text.contains("胜利")
			and not construction.noticeboard_last_result.text.contains(
				"noticeboard."
			),
		"返回摘要显示中文任务名和结果，不暴露 mission_id"
	)

	_check(construction.start_noticeboard_mission(mission_id), "已完成任务可重玩")
	var replay: C0BattleGraybox = construction.get_formal_battle_scene()
	replay.start_battle()
	for route_id in replay.coordinator.active_session.routes:
		replay.coordinator.active_session.routes[route_id].enemy_total_hp = 0
	replay.step_battle_for_test(1)
	var replay_summary := replay.confirm_pending_result()
	_check(
		not bool(replay_summary.first_clear_granted)
			and int(replay_summary.accepted_wood_reward) == 0
			and int(replay_summary.accepted_food_reward) == 0,
		"重玩胜利不重复发放首胜奖励"
	)
	replay.request_return_to_city()
	replay.complete_return_for_test(999999)
	await process_frame
	await process_frame


func _check_failure_and_retreat_writeback() -> void:
	var food_before := int(construction.food)
	var wood_before := int(construction.wood)
	var protect_id := &"noticeboard.supply_relief.v0"
	_check(construction.start_noticeboard_mission(protect_id), "粮道求援可重入")
	var failure_battle: C0BattleGraybox = construction.get_formal_battle_scene()
	failure_battle.start_battle()
	failure_battle.coordinator.active_session.mission_objective_state.protect_target_hp = 0
	var failure_result := failure_battle.step_battle_for_test(1)
	_check(
		failure_result.outcome == BattleOutcome.Value.DEFEAT,
		"粮车摧毁产生正式失败"
	)
	var failure_summary := failure_battle.confirm_pending_result()
	_check(
		int(failure_summary.accepted_wood_reward) == 0
			and int(failure_summary.accepted_food_reward) == 0,
		"任务失败不发放奖励"
	)
	failure_battle.request_return_to_city()
	failure_battle.complete_return_for_test(999999)
	await process_frame
	await process_frame

	var scout_id := &"noticeboard.missing_scout.v0"
	_check(construction.start_noticeboard_mission(scout_id), "失踪斥候可启动")
	var retreat_battle: C0BattleGraybox = construction.get_formal_battle_scene()
	retreat_battle.start_battle()
	var session: BattleSession = retreat_battle.coordinator.active_session
	session.request_forced_retreat()
	for squad in session.squads:
		retreat_battle.coordinator.issue_order(
			int(squad.squad_id),
			BattleOrder.Command.RETREAT
		)
	var retreat_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		retreat_result = retreat_battle.step_battle_for_test(1)
		if retreat_result != null:
			break
	_check(
		retreat_result != null
			and retreat_result.outcome == BattleOutcome.Value.RETREAT,
		"失踪斥候未完成目标时全军撤退产生正式 RETREAT"
	)
	var retreat_summary := retreat_battle.confirm_pending_result()
	_check(
		int(retreat_summary.accepted_wood_reward) == 0
			and int(retreat_summary.accepted_food_reward) == 0
			and int(construction.wood) == wood_before
			and int(construction.food) == food_before,
		"撤退不发放任务奖励"
	)
	retreat_battle.request_return_to_city()
	retreat_battle.complete_return_for_test(999999)
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("NOTICEBOARD_FLOW_SMOKE_PASS")
		quit(0)
	else:
		print("NOTICEBOARD_FLOW_SMOKE_FAIL count=%d" % failures.size())
		quit(1)

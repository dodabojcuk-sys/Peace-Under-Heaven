extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_warning_and_command_platform()
	await _check_formal_outcome(
		&"VICTORY",
		50,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.SIDE_ROUTE
	)
	await _check_formal_outcome(
		&"DEFEAT",
		1,
		BattleOrder.Command.ADVANCE,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	await _check_formal_outcome(
		&"RETREAT",
		8,
		BattleOrder.Command.RETREAT,
		CommittedForceSnapshot.FRONT_ROUTE
	)
	await _check_command_platform_retreat()
	_finish()


func _check_warning_and_command_platform() -> void:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	city.set_process(false)
	var command_id := _find_command_platform(city)
	_check(command_id >= 0, "军令台仍来自六个固定建筑记录")

	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 5.0)
	selection.select_placement(command_id)
	var war_actions: Control = scene.get_node(
		"UI/Shell/BuildingDetailPanel/FirstWarActions"
	)
	var war_intel: Label = war_actions.get_node("WarIntel")
	_check(
		city.current_day == 6
			and city.get_first_war_state_id() == &"WARNING",
		"第 6 日进入一次性预警"
	)
	_check(
		war_actions.visible
			and "距离敌袭" in war_intel.text
			and "守军" in war_intel.text
			and "减损线" in war_intel.text
			and "建议" in war_intel.text,
		"选择军令台可查看倒计时、真实兵力粮草城防和建议"
	)

	city.advance_city_time_for_test(city.SECONDS_PER_DAY)
	_check(
		city.current_day == 7
			and city.get_first_war_state_id() == &"PENDING"
			and war_actions.get_node("EnterBattleButton").visible
			and war_actions.get_node("OrderRetreatButton").visible,
		"第 7 日军令台提供进入战场和下令撤退"
	)
	scene.queue_free()
	await process_frame


func _check_formal_outcome(
	expected_outcome: StringName,
	player_count: int,
	command: BattleOrder.Command,
	route_id: StringName
) -> void:
	var setup: Dictionary = await _make_pending_city(
		player_count,
		80,
		true
	)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var city_before: Dictionary = city.get_city_state()
	_check(city.enter_first_war_battle(), "%s 路径从军令台进入 C0" % expected_outcome)
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	_check(
		battle != null
			and battle.formal_city_mode
			and battle.city_scene == scene
			and battle.city_controller == city
			and battle.request.formal_city_entry,
		"%s 路径复用当前真实城市而非隐藏 fixture" % expected_outcome
	)
	if battle == null:
		scene.queue_free()
		await process_frame
		return

	for squad in battle.request.committed_force.squads:
		battle.set_squad_route(int(squad.squad_id), route_id)
	_check(battle.start_battle(), "%s 路径启动真实 C0 tick 演算" % expected_outcome)
	battle.tick_timer.stop()
	for squad in battle.coordinator.active_session.squads:
		battle.issue_squad_order(int(squad.squad_id), command)
	var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
	_check(
		result != null
			and BattleOutcome.to_id(result.outcome) == expected_outcome,
		"%s 路径由真实交战生成结果" % expected_outcome
	)
	if result == null:
		scene.queue_free()
		battle.queue_free()
		await process_frame
		return

	var summary: Dictionary = battle.confirm_pending_result()
	var after_first_apply: Dictionary = city.get_city_state()
	var duplicate_summary: Dictionary = battle.confirm_pending_result()
	var after_duplicate_apply: Dictionary = city.get_city_state()
	_check(
		not summary.is_empty()
			and bool(summary.formal_city_entry)
			and int(summary.actual_food_cost)
				== city.get_first_war_food_cost(player_count),
		"%s 路径写回真实粮草消耗" % expected_outcome
	)
	_check(
		summary == duplicate_summary
			and after_first_apply == after_duplicate_apply,
		"%s 路径重复确认不二次写回" % expected_outcome
	)
	_check(
		int(after_first_apply.infantry_count)
			== int(city_before.infantry_count) - int(summary.casualty_count),
		"%s 路径按真实伤亡更新城市兵力" % expected_outcome
	)

	var return_contract := battle.coordinator.request_return_to_city()
	_check(return_contract != null, "%s 路径生成返回城市契约" % expected_outcome)
	if return_contract != null:
		_check(
			battle.complete_return_for_test(
				return_contract.city_input_restore_frame
			),
			"%s 路径通过输入保护帧返回同一城市" % expected_outcome
		)
	await process_frame
	_check(
		scene.visible
			and scene.process_mode == Node.PROCESS_MODE_INHERIT
			and city.get_formal_battle_scene() == null,
		"%s 路径恢复城市控制且释放临时战场" % expected_outcome
	)

	if expected_outcome == &"VICTORY":
		_check(
			int(summary.enemy_count_after) == 0
				and int(summary.city_defense_damage) == 0
				and bool(summary.first_clear_granted),
			"胜利清除本次威胁、保留城防并只授予一次首通"
		)
	elif expected_outcome == &"RETREAT":
		_check(
			int(summary.city_defense_damage)
				== city.FIRST_WAR_RETREAT_DEFENSE_DAMAGE
				and int(summary.enemy_count_after) > 0,
			"战场主动撤退保留敌军并承担城防损伤"
		)
	else:
		_check(
			int(summary.city_defense_after) == 0
				and city.city_fallen
				and city.get_first_war_state_id() == &"RESOLVED_DEFEAT",
			"失败写回全军结果并进入城市失守"
		)

	_check(
		city.is_first_war_time_blocked(),
		"%s 摘要确认前或失败后战略时间保持锁定" % expected_outcome
	)
	_check(city.acknowledge_first_war_result(), "%s 摘要可确认一次" % expected_outcome)
	if expected_outcome == &"DEFEAT":
		_check(
			not city.is_first_war_time_blocked()
				and city.get_first_war_state_id() == &"RESOLVED_DEFEAT",
			"失败摘要确认后解除战略时间阻断，避免永久死档"
		)
	else:
		_check(
			not city.is_first_war_time_blocked()
				and city.get_first_war_state_id()
					== StringName("RESOLVED_%s" % expected_outcome),
			"%s 摘要确认后解除战争阻断" % expected_outcome
		)
		var threat_after_war: int = city.enemy_count
		city.advance_city_time_for_test(city.SECONDS_PER_DAY)
		_check(
			city.current_day == 8
				and city.enemy_count == threat_after_war,
			"%s 后续通用日结算不重新生成已结算首战" % expected_outcome
		)
	_check(
		not city.acknowledge_first_war_result(),
		"%s 摘要拒绝重复确认" % expected_outcome
	)
	scene.queue_free()
	await process_frame


func _check_command_platform_retreat() -> void:
	var setup: Dictionary = await _make_pending_city(20, 80, true)
	var scene: Node2D = setup.scene
	var city: Node = setup.city
	var selection: Node = setup.selection
	selection.select_placement(_find_command_platform(city))
	var before: Dictionary = city.get_city_state()
	_check(
		city.request_first_war_retreat_confirmation(),
		"军令台战前撤退先显示明确后果确认"
	)
	city.cancel_first_war_retreat_confirmation()
	_check(
		city.get_city_state() == before,
		"取消战前撤退不修改城市权威状态"
	)
	city.request_first_war_retreat_confirmation()
	_check(city.confirm_first_war_retreat(), "确认后走正式撤退事务")
	var summary: Dictionary = city.get_city_state().last_battle_result_summary
	_check(
		StringName(summary.outcome) == &"RETREAT"
			and bool(summary.formal_city_entry)
			and int(summary.actual_food_cost) > 0
			and int(summary.city_defense_damage)
				== city.FIRST_WAR_RETREAT_DEFENSE_DAMAGE,
		"军令台撤退产生粮草和城防后果且不伪装胜利"
	)
	var after_apply: Dictionary = city.get_city_state()
	_check(
		not city.confirm_first_war_retreat()
			and city.get_city_state() == after_apply,
		"重复军令台撤退不会二次结算"
	)
	_check(
		city.acknowledge_first_war_result()
			and city.get_first_war_state_id() == &"RESOLVED_RETREAT"
			and not city.is_first_war_time_blocked(),
		"确认撤退摘要后恢复城市战略时间"
	)
	scene.queue_free()
	await process_frame


func _make_pending_city(
	player_count: int,
	food_count: int,
	select_command_platform: bool
) -> Dictionary:
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	city.set_process(false)
	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 6.0)
	city.infantry_count = player_count
	city.food = food_count
	city._refresh_city_ui()
	if select_command_platform:
		selection.select_placement(_find_command_platform(city))
	return {
		"scene": scene,
		"city": city,
		"selection": selection,
	}


func _find_command_platform(city: Node) -> int:
	for placement_id in city.get_placement_ids():
		var record: Dictionary = city.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == &"command_platform":
			return placement_id
	return -1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("P1E_FIRST_WAR_CLOSED_LOOP_SMOKE PASS")
		quit(0)
	else:
		print("P1E_FIRST_WAR_CLOSED_LOOP_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)

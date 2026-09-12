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
	_check_pure_projection_and_selection()
	_check_eliminate_projection()
	_check_protect_projection()
	_check_scout_projection()
	await _check_scene_selection_and_single_command_path()
	await _check_resolution_layouts()
	_finish()


func _check_pure_projection_and_selection() -> void:
	var setup := _make_session(MISSIONS[0], 18, &"presentation-pure")
	var request: BattleRequest = setup.request
	var session: BattleSession = setup.session
	var before := session.get_state_digest()
	var first := BattlePresentationModel.build_snapshot(
		request,
		session,
		MISSIONS[0],
		1
	)
	var first_repeat := BattlePresentationModel.build_snapshot(
		request,
		session,
		MISSIONS[0],
		1
	)
	var second := BattlePresentationModel.build_snapshot(
		request,
		session,
		MISSIONS[0],
		2
	)
	_check(
		session.get_state_digest() == before,
		"表现投影不会推进 tick、下达命令或修改 BattleSession"
	)
	_check(
		first == first_repeat,
		"相同权威状态重复生成完全一致的表现投影"
	)
	_check(
		first.routes == second.routes
			and first.objective == second.objective,
		"切换选择只改变 UI 选择，不改变路线或任务投影"
	)
	_check(
		bool(first.squads[0].selected)
			and not bool(first.squads[1].selected)
			and bool(second.squads[1].selected),
		"表现模型始终只有一个选中小队"
	)
	_check(
		not str(first.phase_text).contains("RESERVED")
			and not str(first.phase_text).contains("ACTIVE")
			and not str(first.objective_text).contains("ELIMINATE_ALL")
			and not str(first.objective.progress_text).contains(
				"ELIMINATE_ALL"
			),
		"玩家可见投影不泄露原始状态枚举"
	)


func _check_eliminate_projection() -> void:
	var setup := _make_session(MISSIONS[0], 18, &"presentation-eliminate")
	var snapshot := BattlePresentationModel.build_snapshot(
		setup.request,
		setup.session,
		MISSIONS[0],
		1
	)
	_check(
		snapshot.routes.size() == 2
			and int(snapshot.routes[0].enemy_count) == 7
			and int(snapshot.routes[1].enemy_count) == 5,
		"清剿任务同时投影两条路线的真实敌军余量"
	)
	_check(
		float(snapshot.routes[0].enemy_position_ratio) == 1.0
			and float(snapshot.routes[1].enemy_position_ratio) == 1.0,
		"敌军只投影在权威规则支持的路线尽头，不伪造移动"
	)
	_check(
		str(snapshot.routes[0].enemy_status) == "据守路线尽头"
			and str(snapshot.routes[1].enemy_status)
				== "据守路线尽头",
		"未接敌时明确显示敌军据守状态"
	)
	var session: BattleSession = setup.session
	for route_id in [
		CommittedForceSnapshot.FRONT_ROUTE,
		CommittedForceSnapshot.SIDE_ROUTE,
	]:
		var route: Dictionary = session.routes[route_id]
		route.enemy_total_hp = 0
		session.routes[route_id] = route
	var cleared := BattlePresentationModel.build_snapshot(
		setup.request,
		session,
		MISSIONS[0],
		1
	)
	_check(
		int(cleared.routes[0].enemy_count) == 0
			and int(cleared.routes[1].enemy_count) == 0
			and bool(cleared.objective.completed),
		"真实敌军清零后两路消失且目标投影完成"
	)


func _check_protect_projection() -> void:
	var setup := _make_session(MISSIONS[1], 20, &"presentation-protect")
	var session: BattleSession = setup.session
	_move_protect_enemies_to_objective(session)
	session.mission_objective_state.protect_target_hp = 300
	var before := session.get_state_digest()
	var snapshot := BattlePresentationModel.build_snapshot(
		setup.request,
		session,
		MISSIONS[1],
		1
	)
	var objective: Dictionary = snapshot.objective
	_check(
		bool(objective.show_wagon)
			and int(objective.wagon_hp) == 300
			and int(objective.wagon_max_hp) == 420,
		"护送任务投影固定粮车和真实生命值"
	)
	_check(
		bool(objective.wagon_danger)
			and Array(objective.attacking_routes).size() == 2,
		"无人拦截时粮车显示两路威胁"
	)
	_check(
		session.get_state_digest() == before,
		"读取粮车危险方向不会修改任务目标状态"
	)
	session.mission_objective_state.protect_target_hp = 0
	var destroyed := BattlePresentationModel.build_snapshot(
		setup.request,
		session,
		MISSIONS[1],
		1
	)
	_check(
		bool(destroyed.objective.failed)
			and int(destroyed.objective.wagon_hp) == 0,
		"粮车权威生命归零后表现投影明确失败"
	)


func _check_scout_projection() -> void:
	var setup := _make_session(MISSIONS[2], 15, &"presentation-scout")
	var session: BattleSession = setup.session
	var hidden := BattlePresentationModel.build_snapshot(
		setup.request,
		session,
		MISSIONS[2],
		1
	)
	_check(
		bool(hidden.objective.show_search)
			and StringName(hidden.objective.revealed_route_id) == &""
			and str(hidden.objective.search_zones[0].label) == "搜索区？"
			and str(hidden.objective.search_zones[1].label) == "搜索区？",
		"发现前只显示两个中性搜索区，不泄露斥候真实路线"
	)
	session.mission_objective_state.scout_found = true
	var found := BattlePresentationModel.build_snapshot(
		setup.request,
		session,
		MISSIONS[2],
		1
	)
	_check(
		StringName(found.objective.revealed_route_id)
				== MISSIONS[2].scout_route_id
			and str(found.objective.search_zones[1].label)
				== "已找到斥候",
		"发现后才投影真实搜索结果"
	)
	_check(
		not bool(found.objective.extraction_reached)
			and str(found.objective.progress_text).contains("撤离区"),
		"侦察任务持续显示返回安全撤离区的下一步"
	)
	var switched := BattlePresentationModel.build_snapshot(
		setup.request,
		session,
		MISSIONS[2],
		-1
	)
	var selected_count := 0
	for squad in switched.squads:
		if bool(squad.selected):
			selected_count += 1
	_check(
		selected_count == 0,
		"新任务不继承上一场的表现层选择"
	)


func _check_scene_selection_and_single_command_path() -> void:
	root.size = Vector2i(1152, 648)
	var packed := load(
		"res://scenes/c0_battle_graybox.tscn"
	) as PackedScene
	var scene := packed.instantiate() as C0BattleGraybox
	root.add_child(scene)
	await process_frame
	await process_frame
	(scene._squad_markers[2] as Button).emit_signal("pressed")
	_check(
		scene._selected_squad_id == 2
			and scene.selected_squad_title.text.contains("二队"),
		"点击小队标记后底部命令区跟随唯一选中小队"
	)
	var protect_setup := _make_session(
		MISSIONS[1],
		20,
		&"presentation-ui-protect"
	)
	_move_protect_enemies_to_objective(protect_setup.session)
	var protect_snapshot := BattlePresentationModel.build_snapshot(
		protect_setup.request,
		protect_setup.session,
		MISSIONS[1],
		1
	)
	scene._refresh_mission_objects(protect_snapshot.objective)
	scene._refresh_route_ui(
		protect_snapshot.routes[0],
		scene.front_route_name_label,
		scene.front_state_label,
		scene.front_enemy_marker,
		scene.front_enemy_count_label,
		scene.front_gate,
		protect_snapshot.objective
	)
	_check(
		scene.wagon_panel.visible
			and scene.wagon_label.text.contains("粮车")
			and int(scene.wagon_health.value) == 420,
		"护送任务显示固定粮车及权威生命条"
	)
	_check(
		scene.front_enemy_marker.visible
			and scene.wagon_label.text.contains("遭受威胁")
			and scene.front_enemy_count_label.text.contains("瞭望台完工后显示兵力"),
		"已抵达保护目标的路线显示威胁，同时在侦察前保留兵力未知"
	)
	var scout_setup := _make_session(
		MISSIONS[2],
		15,
		&"presentation-ui-scout"
	)
	var scout_snapshot := BattlePresentationModel.build_snapshot(
		scout_setup.request,
		scout_setup.session,
		MISSIONS[2],
		1
	)
	scene._refresh_mission_objects(scout_snapshot.objective)
	_check(
		scene.front_search_zone.visible
			and scene.side_search_zone.visible
			and scene.extraction_zone.visible
			and (
				scene.front_search_zone.get_node("Label") as Label
			).text == "搜索区？"
			and (
				scene.side_search_zone.get_node("Label") as Label
			).text == "搜索区？",
		"侦察任务在场景中显示中性搜索区和撤离区"
	)
	_check(scene.start_battle(), "可读战场仍通过原事务启动真实战斗")
	scene.tick_timer.stop()
	var digest_before_refresh := (
		scene.coordinator.active_session.get_state_digest()
	)
	scene._refresh_battle_ui()
	_check(
		scene.coordinator.active_session.get_state_digest()
			== digest_before_refresh,
		"场景 UI 刷新不产生伤亡、命令或结果"
	)
	scene.selected_advance_button.emit_signal("pressed")
	_check(
		scene.coordinator.active_session.accepted_orders.size() == 1
			and scene.coordinator.active_session.accepted_orders[0].squad_id == 2,
		"底部推进按钮只向选中小队提交一次真实命令"
	)
	scene.selected_advance_button.emit_signal("pressed")
	_check(
		scene.coordinator.active_session.accepted_orders.size() == 1,
		"同一 tick 重复点击不会绕过 BattleSession 命令约束"
	)
	for squad in scene.coordinator.active_session.squads:
		if int(squad.squad_id) == 2:
			continue
		scene.issue_squad_order(
			int(squad.squad_id),
			BattleOrder.Command.ADVANCE
		)
	var result := scene.step_battle_for_test(
		BattleSession.MAX_BATTLE_TICKS
	)
	_check(
		result != null
			and scene.selected_advance_button.disabled
			and scene.selected_hold_button.disabled
			and scene.selected_retreat_button.disabled,
		"战斗结束后全部选中小队命令禁用"
	)
	var buttons := scene.get_node("UI/RootPanel").find_children(
		"*",
		"Button",
		true,
		false
	)
	var has_test_button := false
	for button in buttons:
		var text := str(button.text).to_lower()
		if (
			text.contains("test")
			or text.contains("fixture")
			or text.contains("pass")
		):
			has_test_button = true
	_check(not has_test_button, "可运行场景不暴露默认测试按钮")
	_check(
		not scene.has_method("_input")
			and scene.has_method("_unhandled_input"),
		"表现层未创建第二个原始输入所有者"
	)
	scene.queue_free()
	await process_frame


func _check_resolution_layouts() -> void:
	var packed := load(
		"res://scenes/c0_battle_graybox.tscn"
	) as PackedScene
	for resolution in [
		Vector2i(1152, 648),
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
	]:
		root.size = resolution
		var scene := packed.instantiate() as C0BattleGraybox
		root.add_child(scene)
		await process_frame
		await process_frame
		var root_panel := scene.get_node("UI/RootPanel") as Control
		var battlefield := root_panel.get_node("Battlefield") as Control
		var front_lane := root_panel.get_node("FrontLane") as Control
		var side_lane := root_panel.get_node("SideLane") as Control
		var squad_controls := root_panel.get_node(
			"SquadControls"
		) as Control
		var selected_panel := root_panel.get_node(
			"SelectedSquadPanel"
		) as Control
		_check(
			root_panel.size == Vector2(resolution)
				and battlefield.get_rect().end.y
					<= squad_controls.position.y
				and front_lane.position.y >= battlefield.position.y
				and side_lane.get_rect().end.y
					<= battlefield.get_rect().end.y
				and selected_panel.get_rect().end.x
					<= root_panel.size.x
				and selected_panel.get_rect().end.y
					<= root_panel.size.y,
			"%dx%d 下主战场、路线和底部命令区无裁切"
			% [resolution.x, resolution.y]
		)
		scene.queue_free()
		await process_frame


func _make_session(
	mission: MissionDefinition,
	player_count: int,
	transaction_suffix: StringName
) -> Dictionary:
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
	return {
		"request": request,
		"session": BattleSession.new(request),
	}


## Protect-route warnings describe enemies that have actually reached the
## protected objective. The fixture advances only that positional authority;
## production code still derives the warning without mutating battle state.
func _move_protect_enemies_to_objective(session: BattleSession) -> void:
	for route_id in session.routes:
		var route: Dictionary = session.routes[route_id]
		route.enemy_position_fixed = route.distance_fixed
		session.routes[route_id] = route


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("C0_BATTLE_PRESENTATION_SMOKE PASS")
		quit(0)
	else:
		print(
			"C0_BATTLE_PRESENTATION_SMOKE FAIL (%d)"
			% failures.size()
		)
		quit(1)

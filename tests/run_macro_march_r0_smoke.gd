extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0
var _scenario_seed_snapshot: Dictionary = {}


func _initialize() -> void:
	THEATER.use_regression_definition_for_tests()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var context := await _new_city(50)
	var scene: Node = context.scene
	var city: Node = context.city
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	_check(
		scene.open_macro_march_r0()
			and macro_screen.visible
			and scene.return_from_macro_march_r0(),
		"正式城市入口打开唯一宏观军令界面并可安全返回，不走旧 MVP 写入路径"
	)
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var selected: Array[StringName] = [
		StringName(roster[0].formation_id), StringName(roster[1].formation_id),
	]
	var baseline: Dictionary = city.export_v5_campaign_snapshot()
	var bad: Dictionary = city.commit_macro_march_from_city(
		selected, &"northwatch_garrison", &"road.unknown", []
	)
	_check(
		not bool(bad.success)
			and StringName(bad.error_id) == &"UNKNOWN_ROAD"
			and city.export_v5_campaign_snapshot() == baseline,
		"草稿的非法道路或终点不会扣粮、扣编队或创建军令"
	)
	_check(
		city.set_macro_march_route_blocked_for_scenario(&"road.blackstone.northwatch.lowland", true)
			and StringName(city.commit_macro_march_from_city(
				selected, &"northwatch_garrison", &"road.blackstone.northwatch.lowland", Array(route.points)
			).error_id) == &"ROAD_BLOCKED"
			and city.export_v5_campaign_snapshot() == baseline
			and city.set_macro_march_route_blocked_for_scenario(&"road.blackstone.northwatch.lowland", false),
		"确认前道路转为受阻时拒绝军令，编队和粮草保持不变"
	)
	var draw_a := THEATER.choose_route_from_draw(
		&"blackstone_city", &"northwatch_garrison", Array(route.points)
	)
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var draw_b := THEATER.choose_route_from_draw(
		&"blackstone_city", &"northwatch_garrison", Array(ridge.points)
	)
	_check(
		bool(draw_a.valid) and bool(draw_b.valid)
			and StringName(draw_a.route.route_id) != StringName(draw_b.route.route_id)
			and Array(draw_a.route.points) != Array(draw_b.route.points),
		"两条绘制道路保留不同的实际多段路径，不静默改为最短直线"
	)
	var first_count := int(roster[0].member_count)
	var second_count := int(roster[1].member_count)
	var third_count := int(roster[2].member_count)
	var food_before: int = city.food
	var issued: Dictionary = city.commit_macro_march_from_city(
		selected,
		&"northwatch_garrison",
		StringName(route.route_id),
		Array(route.points)
	)
	var army: Dictionary = issued.get("army", {})
	var macro: Dictionary = army.get("macro_march", {})
	_check(
		bool(issued.success)
			and StringName(army.phase) == ArmyRegistry.PHASE_MARCHING
			and int(city.food) == food_before - city.get_macro_march_food_cost(first_count + second_count)
			and int(city.get_formation_roster()[0].member_count) == 0
			and int(city.get_formation_roster()[1].member_count) == 0
			and int(city.get_formation_roster()[2].member_count) == third_count
			and int(army.units_by_definition_id[city.INFANTRY_ROLE.role_id]) == first_count + second_count,
		"确认军令精确抽取所选编队，未选编队不变，并按当前粮草公式只扣一次"
	)
	var after_issue: Dictionary = city.export_v5_campaign_snapshot()
	var duplicate: Dictionary = city.commit_macro_march_from_city(
		selected,
		&"northwatch_garrison",
		StringName(route.route_id),
		Array(route.points)
	)
	_check(
		not bool(duplicate.success) and city.export_v5_campaign_snapshot() == after_issue,
		"已发布军令拒绝重复确认、取消或改道，快照不产生第二笔扣粮"
	)
	city.city_time_paused = true
	_check(
		city.advance_macro_march_time(StringName(army.army_id), StringName(macro.order_id), 0, 1000).is_empty(),
		"暂停时宏观行军不推进"
	)
	city.city_time_paused = false
	city.city_time_speed = 2.0
	var advanced: Dictionary = city.advance_macro_march_time(
		StringName(army.army_id), StringName(macro.order_id), 0, 1000
	)
	_check(
		bool(advanced.success) and int(advanced.army.macro_march.progress_millis) == 2000,
		"行军使用城市暂停和速度状态，以逻辑毫秒推进"
	)
	var before_block := _progress_before_segment(
		Array(route.points), int(route.blockable_segment_index), int(macro.total_millis)
	)
	city.set_macro_march_route_blocked_for_scenario(StringName(route.route_id), true)
	var blocked: Dictionary = city.block_macro_march_at_segment(
		StringName(army.army_id), StringName(macro.order_id),
		int(route.blockable_segment_index), before_block, &"临时路旁驻扎点"
	)
	_check(
		not blocked.is_empty()
			and StringName(blocked.phase) == ArmyRegistry.PHASE_BLOCKED
			and int(blocked.macro_march.progress_millis) == before_block
			and StringName(blocked.macro_march.temporary_station_point) == &"临时路旁驻扎点",
		"支路中断在受阻段之前的实际路径位置临时驻扎，不传送或任意停靠"
	)
	var food_after_issue: int = city.food
	var resumed: Dictionary = city.resume_blocked_macro_march(
		StringName(army.army_id), StringName(macro.order_id)
	)
	city.set_macro_march_route_blocked_for_scenario(StringName(route.route_id), false)
	_check(
		not resumed.is_empty()
			and StringName(resumed.phase) == ArmyRegistry.PHASE_MARCHING
			and city.food == food_after_issue,
		"道路恢复后保留同一 order_id、路线和粮食事务，自动继续不重复收费"
	)
	var arrival: Dictionary = city.advance_macro_march_time(
		StringName(army.army_id), StringName(macro.order_id),
		int(resumed.macro_march.progress_millis), int(resumed.macro_march.total_millis)
	)
	_check(
		bool(arrival.success)
			and bool(arrival.arrived)
			and StringName(arrival.army.phase) == ArmyRegistry.PHASE_STATIONED,
		"到达友方驻扎点完成本段军令，不宣称战斗或攻城胜利"
	)
	var second_route: Dictionary = THEATER.get_route(&"road.northwatch.reedbank")
	var food_before_second: int = city.food
	var second: Dictionary = city.commit_macro_march_from_station(
		StringName(army.army_id), &"reedbank_garrison", StringName(second_route.route_id), Array(second_route.points)
	)
	_check(
		bool(second.success)
			and StringName(second.army.army_id) == StringName(army.army_id)
			and StringName(second.army.macro_march.order_id) != StringName(macro.order_id)
			and int(second.army.units_by_definition_id[city.INFANTRY_ROLE.role_id]) == first_count + second_count
			and city.food < food_before_second,
		"驻扎点后续发令保留军队身份和原兵力，不从黑石城重新生成士兵"
	)
	var cold_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	await _drop_scene(scene)
	var restored_context := await _new_city(50)
	var restored: Node = restored_context.city
	var restore: Dictionary = restored.restore_v5_campaign_snapshot(cold_snapshot)
	var restored_army: Dictionary = restored.get_macro_march_army()
	_check(
		bool(restore.success)
			and StringName(restored_army.phase) == ArmyRegistry.PHASE_MARCHING
			and restored_army.macro_march == second.army.macro_march,
		"隔离冷恢复保留在途军令、实际路径、进度和精确编队，不创建新订单"
	)
	var legacy := baseline.duplicate(true)
	_check(
		bool(restored.validate_v5_campaign_snapshot(legacy).valid)
			and restored.get_expedition_attempt().is_empty(),
		"旧 V6/R1E 快照保持可验证，不能凭迁移凭空生成宏观军令"
	)
	await _drop_scene(restored_context.scene)
	await _run_map_draft_contract()
	await _run_camera_and_layout_contract()
	_finish()


func _run_map_draft_contract() -> void:
	var context := await _new_city(80)
	var scene: Node = context.scene
	var city: Node = context.city
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	scene.open_macro_march_r0()
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var roster: Array[Dictionary] = city.get_formation_roster()
	macro_screen._selected_formation_ids = [StringName(roster[0].formation_id)]
	for point in Array(route.points):
		macro_screen._draw_points.append(Vector2(point))
	macro_screen._finish_draw()
	var drafted := macro_screen._draft_route.duplicate(true)
	var food_before: int = city.food
	macro_screen._confirm_draft()
	var armies: Array = city.get_macro_march_read_model().armies
	_check(
		not drafted.is_empty()
			and Array(drafted.get("points", [])).size() >= 2
		and not armies.is_empty()
		and city.food < food_before,
		"自动化地图绘线草稿经确认进入正式军令，运行时字段不会破坏扣费或发令"
	)
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	macro_screen._engineering_mode = true
	macro_screen._engineering_engineer_id = engineer_id
	macro_screen._engineering_source_point_id = &"blackstone_city"
	macro_screen._draw_points = [Vector2(150, 430), Vector2(475, 420), Vector2(710, 410)]
	macro_screen._finish_draw()
	_check(
		StringName(macro_screen._engineering_draft.get("road_kind", &"")) == FieldTacticsState.ROAD_NORMAL
			and THEATER.route_crosses_water(Array(macro_screen._engineering_draft.get("route_world_points", []))),
		"自动化地图工程绘线保留陆地材料，并将跨水事实交给权威分段规划"
	)
	macro_screen._engineering_draft = {}
	var construction_food_before: int = city.food
	macro_screen._engineering_mode = true
	macro_screen._engineering_engineer_id = engineer_id
	macro_screen._engineering_source_point_id = &"blackstone_city"
	macro_screen._draw_points = [Vector2(150, 430), Vector2(290, 410), Vector2(470, 355)]
	macro_screen._finish_draw()
	var engineering_draft := macro_screen._engineering_draft.duplicate(true)
	var construction_food_after_draft: int = city.food
	macro_screen._confirm_draft()
	_check(
		bool(engineer_dispatch.get("success", false))
		and not engineering_draft.is_empty()
		and String(engineering_draft.get("requested_target_point_id", &"")) == ""
		and int(engineering_draft.get("food_cost", 0)) == 5
		and construction_food_after_draft == construction_food_before
		and city.food < construction_food_before
		and not Dictionary(city.get_field_tactics_read_model().projects_by_id).is_empty(),
		"自动化工程绘线松手只形成草稿，确认后才扣资源并创建施工项目"
	)
	var remote_engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var remote_engineer_id := StringName(Dictionary(remote_engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	macro_screen._selected_specialist_id = remote_engineer_id
	macro_screen._side_road_button.emit_signal("pressed")
	var remote_source_click := InputEventMouseButton.new()
	remote_source_click.button_index = MOUSE_BUTTON_LEFT
	remote_source_click.pressed = true
	remote_source_click.position = macro_screen._world_to_screen(Vector2(THEATER.get_point(&"northwatch_garrison").world_position))
	macro_screen._on_gui_input(remote_source_click)
	var remote_route: Dictionary = THEATER.get_route(&"road.northwatch.reedbank")
	var remote_press := InputEventMouseButton.new()
	remote_press.button_index = MOUSE_BUTTON_LEFT
	remote_press.pressed = true
	remote_press.position = macro_screen._world_to_screen(Vector2(Array(remote_route.points).front()))
	macro_screen._on_gui_input(remote_press)
	macro_screen._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for remote_point in Array(remote_route.points).slice(1):
		var remote_motion := InputEventMouseMotion.new()
		remote_motion.position = macro_screen._world_to_screen(Vector2(remote_point))
		macro_screen._on_gui_input(remote_motion)
	var remote_release := InputEventMouseButton.new()
	remote_release.button_index = MOUSE_BUTTON_LEFT
	remote_release.pressed = false
	remote_release.position = macro_screen._world_to_screen(Vector2(Array(remote_route.points).back()))
	macro_screen._on_gui_input(remote_release)
	var remote_draft := macro_screen._engineering_draft.duplicate(true)
	_check(
		bool(remote_engineer_dispatch.get("success", false))
			and StringName(remote_draft.get("source_point_id", &"")) == &"northwatch_garrison"
			and StringName(remote_draft.get("requested_target_point_id", &"")) == &"reedbank_garrison"
			and not bool(remote_draft.get("build_camp", true))
			and int(remote_draft.get("travel_milliseconds", 0)) > 0
			and int(remote_draft.get("food_cost", 0)) == 5,
		"正式鼠标入口可选择工程师、远端施工起点并连接已有驻点，权威预览提供到场时间与费用"
	)
	await _drop_scene(scene)
	await _run_mouse_selection_and_replacement_contract()


func _run_mouse_selection_and_replacement_contract() -> void:
	var context := await _new_city(100)
	var scene: Node = context.scene
	var city: Node = context.city
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	scene.open_macro_march_r0()
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var roster: Array[Dictionary] = city.get_formation_roster()
	var first: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(route.route_id), Array(route.points))
	var second: Dictionary = city.commit_macro_march_from_city([StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(route.route_id), Array(route.points))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = macro_screen._world_to_screen(Vector2(Array(route.points).front()))
	macro_screen._on_gui_input(click)
	var first_selected := macro_screen._selected_army_id
	macro_screen._on_gui_input(click)
	var second_selected := macro_screen._selected_army_id
	var scout_food_before: int = city.food
	macro_screen._scout_button.emit_signal("pressed")
	var field_after_scout_dispatch: Dictionary = city.get_field_tactics_read_model()
	var scout_ids: Array = Dictionary(field_after_scout_dispatch.get("specialists_by_id", {})).keys()
	scout_ids.sort()
	var scout_id := StringName(scout_ids.filter(func(id): return StringName(Dictionary(field_after_scout_dispatch.specialists_by_id[id]).get("role", &"")) == FieldTacticsState.SPECIALIST_SCOUT).front())
	var scout_before_order: Dictionary = Dictionary(field_after_scout_dispatch.specialists_by_id[scout_id])
	var scout_target_click := InputEventMouseButton.new()
	scout_target_click.button_index = MOUSE_BUTTON_LEFT
	scout_target_click.pressed = true
	scout_target_click.position = macro_screen._world_to_screen(Vector2(THEATER.get_point(&"northwatch_garrison").world_position))
	macro_screen._on_gui_input(scout_target_click)
	var scout_after_order: Dictionary = Dictionary(city.get_field_tactics_read_model().specialists_by_id[scout_id])
	_check(
		StringName(scout_before_order.get("phase", &"")) == FieldTacticsState.SPECIALIST_IDLE
			and not String(macro_screen._status_label.text).contains("已出发")
			and StringName(scout_after_order.get("phase", &"")) == FieldTacticsState.SPECIALIST_MOVING
			and StringName(scout_after_order.get("target_point_id", &"")) == &"northwatch_garrison"
			and String(macro_screen._specialist_status_label.text).contains("在途")
			and city.food == scout_food_before - 4,
		"正式侦察按钮先创建待命单位，再由地图点击写入实际目标和移动状态"
	)
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	var repair_route := [Vector2i(150, 430), Vector2i(355, 470), Vector2i(500, 440)]
	var built_for_repair: Dictionary = city.begin_field_road_project(
		StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
		&"blackstone_city", &"camp.site.repair", repair_route, FieldTacticsState.ROAD_NORMAL, true
	)
	city.advance_war_loop_time(int(Dictionary(built_for_repair.get("project", {})).get("required_milliseconds", 0)))
	var repair_road_id := StringName(Dictionary(built_for_repair.get("project", {})).get("road_id", &""))
	field.damage_road(repair_road_id, 999)
	var repair_click := InputEventMouseButton.new()
	repair_click.button_index = MOUSE_BUTTON_LEFT
	repair_click.pressed = true
	repair_click.position = macro_screen._world_to_screen(Vector2(355, 470))
	macro_screen._on_gui_input(repair_click)
	macro_screen._side_road_button.emit_signal("pressed")
	var repair_project_id := StringName(Dictionary(field.specialists_by_id[StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))]).get("project_id", &""))
	_check(
		macro_screen._selected_damaged_road_id == &""
			and repair_project_id != &"" and not field.is_route_open(repair_road_id),
		"自动化鼠标命中受损道路并点击维修入口，会创建到场维修而不立即放行"
	)
	var engineer_id := StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))
	var lost_scout := Dictionary(field.specialists_by_id[scout_id])
	var lost_engineer := Dictionary(field.specialists_by_id[engineer_id])
	lost_scout.alive = false
	lost_engineer.alive = false
	field.specialists_by_id[scout_id] = lost_scout
	field.specialists_by_id[engineer_id] = lost_engineer
	macro_screen._selected_army_id = &""
	macro_screen.refresh()
	_check(
		bool(first.success) and bool(second.success)
			and first_selected != &"" and second_selected != &"" and first_selected != second_selected
			and macro_screen._scout_button.visible and macro_screen._engineer_button.visible
			and String(macro_screen._specialist_status_label.text).contains("阵亡"),
		"鼠标命中同点重叠军队可轮换选队；死亡历史不会阻止补派"
	)
	var selected_siege := macro_screen._siege_for_army({
		"active_siege": {"army_id": &"army.first", "gate_hp": 99},
		"sieges": [{"army_id": &"army.first", "gate_hp": 99}, {"army_id": &"army.second", "gate_hp": 41}],
	}, &"army.second")
	_check(int(selected_siege.get("gate_hp", 0)) == 41, "攻城详情按选中 army_id 读取对应交战，而非兼容用第一场攻城")
	await _drop_scene(scene)


func _run_camera_and_layout_contract() -> void:
	var context := await _new_city(100)
	var scene: Node = context.scene
	var city: Node = context.city
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	scene.open_macro_march_r0()
	for viewport_size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		macro_screen.refresh()
		var map_rect := macro_screen._map_rect()
		var panel_rect := macro_screen._side_panel_rect()
		var all_controls: Array[Control] = [
			macro_screen._detail_label,
			macro_screen._specialist_status_label,
			macro_screen._formation_scroll,
			macro_screen._confirm_button,
			macro_screen._scout_button,
			macro_screen._engineer_button,
			macro_screen._side_road_button,
			macro_screen._resume_project_button,
			macro_screen._interrupted_project_selector,
			macro_screen._return_button,
		]
		var controls_fit := map_rect.end.x < panel_rect.position.x
		var controls_do_not_overlap := true
		for control in all_controls:
			if not control.visible:
				continue
			var control_rect := control.get_global_rect()
			controls_fit = controls_fit and control_rect.position.x >= panel_rect.position.x and control_rect.end.x <= float(viewport_size.x) and control_rect.position.y >= panel_rect.position.y and control_rect.end.y <= float(viewport_size.y)
			for other in all_controls:
				if control == other or not other.visible:
					continue
				controls_do_not_overlap = controls_do_not_overlap and not control_rect.intersects(other.get_global_rect())
		_check(
			controls_fit and controls_do_not_overlap
				and macro_screen._map_canvas.get_parent() == macro_screen and macro_screen._map_canvas.clip_contents
				and macro_screen._map_canvas.get_global_rect() == map_rect
				and not macro_screen._map_canvas.get_global_rect().intersects(panel_rect)
				and macro_screen._formation_scroll.get_parent() == macro_screen and macro_screen._interrupted_project_selector.get_parent() == macro_screen and macro_screen._formation_buttons.all(func(button: Button) -> bool: return button.get_parent() == macro_screen._formation_list),
			"自动化 UI 布局在 %d×%d 下保持裁剪地图、滚动编队和可见行动区互不覆盖" % [viewport_size.x, viewport_size.y]
		)
	root.size = Vector2i(1152, 648)
	await process_frame
	macro_screen.refresh()
	# Exercise zoom/pan from a stable interior view rather than coupling this
	# input contract to the player-facing sample theatre's opening framing.
	macro_screen._camera_center = Vector2(500, 325)
	macro_screen._camera_zoom = 0.78
	var anchor := macro_screen._map_rect().get_center() + Vector2(80, -35)
	var world_before_zoom := macro_screen._screen_to_world(anchor)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = anchor
	macro_screen._on_gui_input(wheel)
	var zoom_anchor_preserved := macro_screen._screen_to_world(anchor).distance_to(world_before_zoom) < 0.01
	var camera_before_pan: Vector2 = macro_screen._camera_center
	var pan_start := InputEventMouseButton.new()
	pan_start.button_index = MOUSE_BUTTON_MIDDLE
	pan_start.pressed = true
	pan_start.position = macro_screen._map_rect().get_center()
	macro_screen._on_gui_input(pan_start)
	var pan_motion := InputEventMouseMotion.new()
	pan_motion.position = pan_start.position + Vector2(80, 0)
	macro_screen._on_gui_input(pan_motion)
	var pan_end := InputEventMouseButton.new()
	pan_end.button_index = MOUSE_BUTTON_MIDDLE
	pan_end.pressed = false
	pan_end.position = pan_motion.position
	macro_screen._on_gui_input(pan_end)
	_check(
		zoom_anchor_preserved and macro_screen._camera_center.distance_to(camera_before_pan) > 1.0,
		"自动化鼠标事件验证滚轮以光标为锚缩放，中键平移只改变地图相机"
	)
	macro_screen._camera_center = Vector2(500, 325)
	macro_screen._camera_zoom = 1.0
	var first_button: Button = macro_screen._formation_buttons.front()
	await process_frame
	await process_frame
	_check(
		is_instance_valid(first_button) and macro_screen._formation_buttons.front() == first_button,
		"编队 roster 未变化时跨帧保留同一个控件实例，按下与松开不会落到重建按钮"
	)
	macro_screen._selected_formation_ids = [StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))]
	var snapshot_before_preview: Dictionary = city.export_v5_campaign_snapshot()
	var command_preview := macro_screen._dispatch_adapter.get_macro_march_command_preview(macro_screen._selected_formation_ids)
	var preview_count := int(command_preview.get("committed_total", 0))
	_check(
		preview_count > 0
			and int(command_preview.get("food_cost", -1)) == city.get_macro_march_food_cost(preview_count)
			and city.export_v5_campaign_snapshot() == snapshot_before_preview,
		"地图显示的选队人数与粮食预估来自控制器只读预览，不创建第二套扣粮规则"
	)
	var route: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = macro_screen._world_to_screen(Vector2(Array(route.points).front()))
	macro_screen._on_gui_input(press)
	macro_screen._process(MacroMarchR0.DRAW_HOLD_SECONDS + 0.01)
	for point_value in Array(route.points).slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = macro_screen._world_to_screen(Vector2(point_value))
		macro_screen._on_gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = macro_screen._world_to_screen(Vector2(Array(route.points).back()))
	macro_screen._on_gui_input(release)
	_check(
		not macro_screen._draft_route.is_empty()
			and not macro_screen._map_rect().intersects(macro_screen._return_button.get_global_rect()),
		"自动化鼠标拖线在正式地图入口生成可确认草稿，右侧控件不会向地图点击穿透"
	)
	macro_screen._draw_points.clear()
	macro_screen._draft_route = {}
	var seven_member_formation_id := StringName(Dictionary(city.get_formation_roster().front()).get("formation_id", &""))
	var seven_member_count := int(Dictionary(city.get_formation_roster().front()).get("member_count", 0))
	var issued: Dictionary = city.commit_macro_march_from_city(
		[seven_member_formation_id], &"northwatch_garrison", StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	# This fixture calls the authority directly rather than through MacroMarch's
	# confirm button. Mirror the real UI's successful-confirm cleanup so the
	# remaining selected formation cannot be interpreted as a new city draft.
	macro_screen._selected_formation_ids.clear()
	macro_screen.refresh()
	var active_army: Dictionary = Dictionary(issued.get("army", {}))
	var formation_label := str(macro_screen._formation_buttons.front().text)
	_check(
		bool(issued.get("success", false))
			and seven_member_count == 7
			and int(Dictionary(city.get_formation_roster().front()).get("member_count", -1)) == 0
			and macro_screen._army_member_count(active_army) == seven_member_count
			and formation_label.contains("已出征（当前 7 人）")
			and macro_screen._status_label.text.contains("黑石城 → 北望驻扎点"),
		"正式地图将城内编队的 0 人标为已出征，按军队快照显示当前 7 人，并保留原军令起点与目标"
	)
	await _drop_scene(scene)


func _new_city(food_amount: int) -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	# Each contract below issues production events. Restore one pristine snapshot
	# before an independent scene so a dispatched formation, project, or patrol
	# from an earlier contract cannot invalidate a later UI assertion.
	if _scenario_seed_snapshot.is_empty():
		_scenario_seed_snapshot = city.export_v5_campaign_snapshot()
	else:
		var restored: Dictionary = city.restore_v5_campaign_snapshot(_scenario_seed_snapshot.duplicate(true))
		if not bool(restored.get("success", false)):
			push_error("Macro March smoke could not restore its pristine scenario snapshot: %s" % str(restored))
	city.set_process(false)
	city.food = food_amount
	return {"scene": scene, "city": city}


func _drop_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _progress_before_segment(points: Array, segment_index: int, total_millis: int) -> int:
	var total := 0.0
	var prior := 0.0
	for index in range(1, points.size()):
		var length := Vector2(points[index - 1]).distance_to(Vector2(points[index]))
		total += length
		if index < segment_index:
			prior += length
	return roundi(float(total_millis) * prior / maxf(total, 1.0))


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("MACRO_MARCH_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error("MACRO_MARCH_R0_SMOKE FAIL: %s" % failure)
		quit(1)

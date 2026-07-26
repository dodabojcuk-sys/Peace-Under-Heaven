extends SceneTree


const PresentationModel = preload(
	"res://scripts/world_map/world_map_presentation_model.gd"
)

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

	var construction: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	var world_map: WorldMapController = scene.get_node("CampaignWorldMap")
	var camera: Camera2D = scene.get_node("Camera2D")
	var city_map: Node2D = scene.get_node("MapWorld")
	var city_ui: Control = scene.get_node("UI/Shell")
	var model := PresentationModel.new()
	construction.set_city_time_paused(true)

	_check(
		scene.find_children("Camera2D", "Camera2D", true, false).size() == 1,
		"城市和战役地图复用唯一 Camera2D"
	)
	_check(
		_count_input_owners(scene) == 1,
		"主场景继续只有一个 _input 权威所有者"
	)
	_check(not world_map.is_world_map_open(), "战役地图初始隐藏")

	var city_gate_id := _placement_id_for_template(
		construction,
		&"city_gate"
	)
	_check(city_gate_id >= 0, "现有城门记录作为战役地图入口")
	selection.select_placement(city_gate_id)
	var gate_actions: Control = scene.get_node(
		"UI/Shell/BuildingDetailPanel/CityGateActions"
	)
	_check(
		gate_actions.visible
			and gate_actions.get_node("EnterWorldMapButton").visible,
		"选择城门显示明确的进入战役地图操作"
	)
	gate_actions.get_node("EnterWorldMapButton").emit_signal("pressed")
	await process_frame
	_check(scene.is_campaign_world_map_open(), "城门入口打开独立战役地图")
	_check(
		world_map.visible
			and not city_map.visible
			and not city_ui.visible,
		"战役地图打开时隐藏城市表现而不复制城市状态"
	)

	var snapshot := world_map.get_snapshot()
	var nodes: Array = snapshot.get("nodes", [])
	var roads: Array = snapshot.get("roads", [])
	_check(
		world_map.overview_button.text == "地图全览"
			and world_map.home_button.text == "定位黑石城",
		"全览与定位黑石城使用不同且准确的按钮语义"
	)
	_check(
		_all_nodes_inside_safe_area(
			world_map,
			nodes,
			scene.get_viewport_rect(),
			42.0
		),
		"默认镜头在实际可视安全区内同时包含五个节点"
	)
	_check(nodes.size() == 5, "战役地图包含五个规定节点")
	_check(roads.size() == 5, "战役地图包含五条规定道路")
	_check(_unique_ids(nodes), "五个节点 ID 唯一")
	_check(_unique_ids(roads), "五条道路 ID 唯一")
	_check(_road_endpoints_valid(nodes, roads), "所有道路端点引用有效")
	_check(_all_nodes_connected(nodes, roads), "战役地图不存在孤立节点")

	var blackstone := model.get_node(snapshot, &"blackstone_city")
	var riverbend := model.get_node(snapshot, &"riverbend_city")
	var supply_route := model.get_node(
		snapshot,
		&"riverbend_supply_route"
	)
	_check(
		StringName(blackstone.owner) == &"PLAYER"
			and blackstone.name == "黑石城",
		"黑石城是醒目的玩家主城"
	)
	_check(
		StringName(riverbend.owner) == &"ENEMY"
			and riverbend.name == "河湾城",
		"河湾城是敌方重要目标城"
	)
	_check(supply_route.status == "危险", "河湾粮道明确显示危险")
	_check(
		Vector2(blackstone.position).x < Vector2(riverbend.position).x,
		"黑石城在西、河湾城在东"
	)
	_check(
		Vector2(
			model.get_node(snapshot, &"north_slope_outpost").position
		).y < Vector2(blackstone.position).y,
		"北坡哨站位于黑石城北侧"
	)
	_check(
		Vector2(
			model.get_node(snapshot, &"southern_village").position
		).y > Vector2(blackstone.position).y,
		"南部村庄位于黑石城南侧"
	)
	_check(
		_has_road_status(roads, &"OPEN")
			and _has_road_status(roads, &"DANGEROUS")
			and _has_road_status(roads, &"BLOCKED")
			and _has_road_status(roads, &"UNSCOUTED"),
		"道路同时覆盖畅通、危险、封锁和未侦察状态"
	)
	for road_encoding in [
		{"status": &"OPEN", "pattern": &"SOLID", "symbol": "✓"},
		{
			"status": &"DANGEROUS",
			"pattern": &"DASHED_WARNING",
			"symbol": "!",
		},
		{
			"status": &"BLOCKED",
			"pattern": &"BROKEN_BLOCK",
			"symbol": "×",
		},
		{
			"status": &"UNSCOUTED",
			"pattern": &"DOTTED_UNKNOWN",
			"symbol": "?",
		},
	]:
		var encoding := world_map.world_canvas.get_road_visual_encoding(
			StringName(road_encoding.status)
		)
		_check(
			StringName(encoding.pattern)
				== StringName(road_encoding.pattern)
				and str(encoding.symbol) == str(road_encoding.symbol),
			"%s 道路具有独立于颜色的线型和符号" % str(
				road_encoding.status
			)
		)
	_check(
		world_map.world_canvas.get_faction_symbol(&"PLAYER")
			!= world_map.world_canvas.get_faction_symbol(&"ENEMY")
			and world_map.world_canvas.get_faction_symbol(&"FRIENDLY")
				!= world_map.world_canvas.get_faction_symbol(&"NEUTRAL"),
		"玩家、敌方、友好和中立使用可读阵营符号"
	)

	var city_state_before: Dictionary = construction.get_city_state()
	var presentation_again := model.build_snapshot(
		city_state_before,
		_mission_fixture(construction)
	)
	var city_state_after_projection: Dictionary = construction.get_city_state()
	_check(
		presentation_again == model.build_snapshot(
			city_state_before,
			_mission_fixture(construction)
		),
		"同一状态产生确定性一致投影"
	)
	_check(
		city_state_before == city_state_after_projection,
		"只读投影不修改城市、任务、资源或战斗状态"
	)
	_check(
		StringName(snapshot.formation.position_source)
			== &"NON_PERSISTENT_PRESENTATION_FIXTURE"
			and not bool(snapshot.formation.persistent),
		"玩家编队位置明确标记为非持久表现 fixture"
	)
	_check(
		str(snapshot.formation.troop_summary).contains(
			str(construction.get_available_infantry_count())
		),
		"编队兵力摘要读取当前城市真实兵力"
	)

	world_map.handle_world_click(Vector2(riverbend.position))
	await process_frame
	_check(
		world_map.get_selected_kind() == &"NODE"
			and world_map.get_selected_id() == &"riverbend_city",
		"点击河湾城只选择一个 UI 节点"
	)
	_check(
		world_map.side_panel.visible
			and world_map.panel_title.text == "河湾城"
			and world_map.info_label.text.contains("敌方"),
		"河湾城侧板显示类型、归属、状态和侦察边界"
	)
	_check(
		_selected_anchor_is_visible(world_map, scene.get_viewport_rect()),
		"河湾城侧板打开后选中城池保持在未遮挡区域"
	)
	_check(
		world_map.set_target_node(&"riverbend_city"),
		"河湾城可设置为计划行军目标"
	)
	var route_preview := world_map.get_planned_route()
	_check(
		not (route_preview.get("road_ids", []) as Array).is_empty()
			and bool(route_preview.contains_blocked_road),
		"计划路线显示真实道路状态并保留封锁警告"
	)
	_check(
		str(route_preview.status).contains("尚未")
			or str(route_preview.status).contains("封锁"),
		"路线预览明确说明未实现正式行军或存在阻断"
	)
	var route_encoding := (
		world_map.world_canvas.get_route_preview_visual_encoding()
	)
	_check(
		StringName(route_encoding.pattern) == &"DOUBLE_DASHED_ARROW"
			and str(route_encoding.label).contains("尚未出征")
			and not bool(route_encoding.persistent),
		"计划路线使用双层虚线箭头并明确不是正式出征"
	)

	var dangerous_road := model.get_road(
		snapshot,
		&"southern_village_to_supply_route"
	)
	world_map.handle_world_click(Vector2(dangerous_road.path[1]))
	_check(
		world_map.get_selected_kind() == &"ROAD"
			and world_map.info_label.text.contains("河湾南路")
			and world_map.info_label.text.contains("危险"),
		"点击危险道路显示起止点与中文状态"
	)
	world_map.handle_world_click(Vector2(snapshot.formation.position))
	_check(
		world_map.get_selected_kind() == &"FORMATION"
			and world_map.info_label.text.contains("非持久"),
		"点击编队显示摘要并明确位置不属于正式权威状态"
	)
	world_map.handle_world_click(Vector2(2200.0, 1320.0))
	_check(
		world_map.get_selected_kind() == &""
			and not world_map.side_panel.visible,
		"点击空白区域只取消选择"
	)
	_check(
		construction.get_city_state() == city_state_before,
		"节点、道路、编队选择和路线预览不修改城市状态"
	)

	var camera_before_drag := camera.position
	_drag_via_root(
		scene,
		Vector2(560.0, 420.0),
		Vector2(610.0, 450.0)
	)
	_check(
		not camera.position.is_equal_approx(camera_before_drag),
		"战役地图复用现有真实鼠标位置差值拖动"
	)
	_check(
		world_map.get_selected_kind() == &"",
		"地图拖动不误触发节点行动"
	)
	var panel_point := world_map.top_bar.get_global_rect().get_center()
	var camera_before_ui := camera.position
	scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_UP, panel_point))
	_check(
		camera.position.is_equal_approx(camera_before_ui),
		"固定 UI 区滚轮不穿透到地图"
	)

	for _index in range(30):
		scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_DOWN, Vector2(500, 400)))
	_check(is_equal_approx(camera.zoom.x, scene.MIN_ZOOM), "缩放受最小值约束")
	for _index in range(30):
		scene._input(_wheel_event(MOUSE_BUTTON_WHEEL_UP, Vector2(500, 400)))
	_check(is_equal_approx(camera.zoom.x, scene.MAX_ZOOM), "缩放受最大值约束")

	camera.position = Vector2(1900.0, 1200.0)
	scene.center_world_map_on_home()
	await process_frame
	var home_screen := (
		world_map.world_canvas.get_global_transform_with_canvas()
		* world_map.get_home_position()
	)
	var safe_center := world_map.get_navigation_safe_rect(
		scene.get_viewport_rect()
	).get_center()
	_check(
		home_screen.distance_to(safe_center) < 2.0,
		"定位黑石城按钮恢复合理镜头中心"
	)
	world_map.select_node(&"riverbend_city")
	world_map.overview_button.emit_signal("pressed")
	await process_frame
	_check(
		not world_map.side_panel.visible
			and world_map.get_selected_kind() == &""
			and _all_nodes_inside_safe_area(
				world_map,
				nodes,
				scene.get_viewport_rect(),
				42.0
			),
		"地图全览关闭侧板并恢复五节点全貌"
	)

	world_map.select_node(&"riverbend_supply_route")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._input(escape)
	_check(
		scene.is_campaign_world_map_open()
			and not world_map.side_panel.visible,
		"Esc 先关闭当前信息面板"
	)
	scene._input(escape)
	await process_frame
	_check(
		not scene.is_campaign_world_map_open()
			and city_map.visible
			and city_ui.visible,
		"没有面板时 Esc 返回原内城"
	)
	_check(
		world_map.get_selected_kind() == &"",
		"切换场景后不残留旧选择"
	)
	scene.open_campaign_world_map()
	world_map.select_node(&"riverbend_supply_route")
	_check(
		world_map.view_task_button.visible
			and not world_map.view_task_button.disabled,
		"有真实关联任务的节点显示查看任务操作"
	)
	world_map.view_task_button.emit_signal("pressed")
	await process_frame
	_check(
		not scene.is_campaign_world_map_open()
			and scene.get_node("UI/Shell/NoticeboardPanel").visible,
		"查看关联任务返回内城并打开现有告示板"
	)
	_check(
		construction.get_noticeboard_mission_state(
			&"noticeboard.supply_relief.v0"
		) == &"AVAILABLE",
		"查看任务不会自动启动或推进任务状态"
	)
	selection.clear_selection()

	for viewport_size in [
		Vector2i(1152, 648),
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
	]:
		root.size = viewport_size
		await process_frame
		scene.open_campaign_world_map()
		await process_frame
		var top_rect := world_map.top_bar.get_global_rect()
		var side_rect := world_map.side_panel.get_global_rect()
		_check(
			top_rect.position.x >= -0.1
				and top_rect.end.x <= viewport_size.x + 0.1
				and top_rect.end.y <= viewport_size.y,
			"%dx%d 顶部导航不裁切" % [
				viewport_size.x,
				viewport_size.y,
			]
		)
		_check(
			_all_nodes_inside_safe_area(
				world_map,
				world_map.get_snapshot().get("nodes", []),
				scene.get_viewport_rect(),
				42.0
			),
			"%dx%d 默认全览包含五节点安全边距" % [
				viewport_size.x,
				viewport_size.y,
			]
		)
		world_map.select_node(&"riverbend_city")
		await process_frame
		side_rect = world_map.side_panel.get_global_rect()
		_check(
			side_rect.position.x >= 0.0
				and side_rect.end.x <= viewport_size.x + 0.1
				and side_rect.position.y >= top_rect.end.y
				and side_rect.end.y <= viewport_size.y + 0.1,
			"%dx%d 轻量侧板在窗口内且不遮住整张地图" % [
				viewport_size.x,
				viewport_size.y,
			]
		)
		_check(
			_selected_anchor_is_visible(
				world_map,
				scene.get_viewport_rect()
			),
			"%dx%d 河湾城侧板不会遮住当前选择" % [
				viewport_size.x,
				viewport_size.y,
			]
		)
		world_map.overview_button.emit_signal("pressed")
		await process_frame
		_check(
			_all_nodes_inside_safe_area(
				world_map,
				world_map.get_snapshot().get("nodes", []),
				scene.get_viewport_rect(),
				42.0
			),
			"%dx%d 全览按钮恢复五节点全貌" % [
				viewport_size.x,
				viewport_size.y,
			]
		)
		scene.return_from_campaign_world_map()

	root.size = Vector2i(1152, 648)
	await process_frame
	_check(
		construction.get_city_state() == city_state_before,
		"完整进入、查看、退出流程不修改权威状态"
	)
	_check(
		scene.find_children(
			"CombatTransactionCoordinator",
			"Node",
			true,
			false
		).is_empty(),
		"查看战役地图不创建 BattleSession 或战果事务"
	)
	_check(
		not _script_contains_input_owner(
			"res://scripts/world_map/world_map_controller.gd"
		),
		"WorldMapController 不新增 _input 所有权"
	)
	_check(
		not _script_contains_forbidden_persistence(
			"res://scripts/world_map/world_map_controller.gd"
		)
			and not _script_contains_forbidden_persistence(
				"res://scripts/world_map/world_map_presentation_model.gd"
			),
		"战役地图不写 FileAccess、存档或第二套 CityState"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _mission_fixture(construction: Node) -> Array[Dictionary]:
	var missions: Array[Dictionary] = []
	for mission_id in construction.get_noticeboard_mission_ids():
		var mission = construction.get_noticeboard_mission_definition(mission_id)
		missions.append({
			"mission_id": mission.mission_id,
			"display_name": mission.title,
			"objective_summary": mission.objective_text,
			"state": construction.get_noticeboard_mission_state(mission_id),
			"state_label": "测试状态",
		})
	return missions


func _all_nodes_inside_safe_area(
	world_map: WorldMapController,
	nodes: Array,
	viewport_rect: Rect2,
	margin: float
) -> bool:
	var safe_rect := world_map.get_navigation_safe_rect(
		viewport_rect
	).grow(-margin)
	for node in nodes:
		var screen_position := (
			world_map.world_canvas.get_global_transform_with_canvas()
			* Vector2(node.get("position", Vector2.ZERO))
		)
		if not safe_rect.has_point(screen_position):
			return false
	return true


func _selected_anchor_is_visible(
	world_map: WorldMapController,
	viewport_rect: Rect2
) -> bool:
	var screen_position := (
		world_map.world_canvas.get_global_transform_with_canvas()
		* world_map.get_selected_anchor_world()
	)
	var safe_rect := world_map.get_navigation_safe_rect(
		viewport_rect
	).grow(-48.0)
	return (
		safe_rect.has_point(screen_position)
		and not world_map.side_panel.get_global_rect().has_point(
			screen_position
		)
	)


func _placement_id_for_template(
	construction: Node,
	template_id: StringName
) -> int:
	for placement_id in construction.get_placement_ids():
		var record: Dictionary = construction.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == template_id:
			return placement_id
	return -1


func _unique_ids(items: Array) -> bool:
	var seen: Dictionary = {}
	for item in items:
		var item_id := StringName(item.get("id", &""))
		if item_id == &"" or seen.has(item_id):
			return false
		seen[item_id] = true
	return true


func _road_endpoints_valid(nodes: Array, roads: Array) -> bool:
	var node_ids: Dictionary = {}
	for node in nodes:
		node_ids[StringName(node.get("id", &""))] = true
	for road in roads:
		if (
			not node_ids.has(StringName(road.get("from", &"")))
			or not node_ids.has(StringName(road.get("to", &"")))
		):
			return false
	return true


func _all_nodes_connected(nodes: Array, roads: Array) -> bool:
	var connected: Dictionary = {}
	for road in roads:
		connected[StringName(road.get("from", &""))] = true
		connected[StringName(road.get("to", &""))] = true
	for node in nodes:
		if not connected.has(StringName(node.get("id", &""))):
			return false
	return true


func _has_road_status(roads: Array, status: StringName) -> bool:
	for road in roads:
		if StringName(road.get("status", &"")) == status:
			return true
	return false


func _count_input_owners(scene: Node) -> int:
	var count := 0
	for child in _walk_nodes(scene):
		var script = child.get_script()
		if script == null:
			continue
		var source := str(script.source_code)
		if source.contains("func _input("):
			count += 1
	return count


func _walk_nodes(root_node: Node) -> Array[Node]:
	var nodes: Array[Node] = [root_node]
	for child in root_node.get_children():
		nodes.append_array(_walk_nodes(child))
	return nodes


func _script_contains_input_owner(path: String) -> bool:
	var source := FileAccess.get_file_as_string(path)
	return source.contains("func _input(")


func _script_contains_forbidden_persistence(path: String) -> bool:
	var source := FileAccess.get_file_as_string(path)
	return (
		source.contains("FileAccess.open")
		or source.contains("CityState.new")
		or source.contains("BattleSession.new")
	)


func _drag_via_root(
	scene: Node,
	start: Vector2,
	finish: Vector2
) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	scene._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	scene._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	scene._input(release)


func _wheel_event(button_index: int, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	return event


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("WORLD_MAP_V0_SMOKE_PASS")
		quit(0)
	else:
		print("WORLD_MAP_V0_SMOKE_FAIL count=%d" % failures.size())
		quit(1)
